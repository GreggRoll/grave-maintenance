class_name LobbyService
extends RefCounted

# Runs only on the dedicated server. Clients submit intent, never world state.
var rooms: Dictionary = {}
var memberships: Dictionary = {}
var outbox: Array = []
var archived: Dictionary = {}
var snapshot_time := 0.0

func emit_to(peer: int, kind: String, data: Dictionary) -> void:
	outbox.append({"peer":peer,"kind":kind,"data":data})

func reject(peer: int, message: String) -> void:
	emit_to(peer,"error",{"message":message})

func directory() -> Array:
	var result: Array = []
	for room in rooms.values():
		if room.phase == "lobby" and not room.locked:
			result.append({"code":room.code,"title":room.title,"count":room.members.size()})
	return result

func public_room(room: Dictionary) -> Dictionary:
	var members := {}
	for id in room.members:
		var member: Dictionary = room.members[id]
		var equipment: Array = []
		var value := 0.0
		for item in member.profile.owned:
			if item.id in member.offered:
				equipment.append(Catalog.tool(item.type).name)
				value += float(Catalog.tool(item.type).price)
		members[id] = {"name":member.profile.name,"uid":member.profile.uid,"ready":member.ready,"equipment":equipment,"offered_ids":member.offered.duplicate(),"value":value,"connected":member.connected}
	return {"code":room.code,"title":room.title,"locked":room.locked,"host":room.host,"phase":room.phase,"members":members}

func publish(room: Dictionary) -> void:
	var data := public_room(room)
	for id in room.members:
		if room.members[id].connected: emit_to(int(id),"lobby",data)

func valid_profile(profile: Dictionary) -> bool:
	if not profile.get("uid","") is String or str(profile.get("uid","")).length() < 12: return false
	if not profile.get("owned",null) is Array or profile.owned.size() > 24: return false
	if not profile.get("pending",null) is Dictionary or not profile.get("settled",null) is Array: return false
	if not profile.get("cash",null) is float and not profile.get("cash",null) is int: return false
	if not is_finite(float(profile.cash)) or profile.cash < 0: return false
	var ids: Array = []
	for item in profile.owned:
		if not item is Dictionary: return false
		if not item.get("id",null) is String or not item.get("type",null) is String: return false
		if item.id in ids or not Catalog.equipment.has(item.type) or item.get("owner","") != profile.uid: return false
		ids.append(item.id)
	return true

func request(peer: int, op: String, data: Dictionary) -> void:
	var id := str(peer)
	if op == "list":
		emit_to(peer,"directory",{"rooms":directory()})
		return
	if op == "recover":
		var key := str(data.get("uid","")) + ":" + str(data.get("match_id",""))
		if archived.has(key): emit_to(peer,"recovered",archived[key])
		return
	if op in ["create","join"]:
		if memberships.has(id):
			reject(peer,"Leave your current room first.")
			return
		if not data.get("profile",null) is Dictionary or not valid_profile(data.profile):
			reject(peer,"Invalid local crew profile.")
			return
		var room: Dictionary
		if op == "create":
			if rooms.size() >= 64:
				reject(peer,"The server is full. Try again shortly.")
				return
			var locked: bool = data.get("locked",false)
			var password := str(data.get("password",""))
			if locked and password.length() < 1:
				reject(peer,"Locked rooms need a password.")
				return
			var code := Crypto.new().generate_random_bytes(3).hex_encode().to_upper()
			while rooms.has(code): code = Crypto.new().generate_random_bytes(3).hex_encode().to_upper()
			var salt := Crypto.new().generate_random_bytes(12).hex_encode()
			room = {"code":code,"title":str(data.get("title","Night crew")).left(32),"locked":locked,"password_hash":(salt + password).sha256_text(),"salt":salt,"host":id,"members":{},"phase":"lobby","simulation":null,"inputs":{},"input_times":{},"start_usec":0,"match_id":""}
			rooms[code] = room
		else:
			var code := str(data.get("code","")).to_upper().strip_edges()
			if not rooms.has(code):
				reject(peer,"No room with that code.")
				return
			room = rooms[code]
			if room.phase != "lobby" or room.members.size() >= 4:
				reject(peer,"That room is full or already on shift.")
				return
			if room.locked and (room.salt + str(data.get("password",""))).sha256_text() != room.password_hash:
				reject(peer,"Incorrect room password.")
				return
		for member in room.members.values():
			if member.profile.uid == data.profile.uid:
				reject(peer,"This saved employee is already in the room. Use another browser profile for a second player.")
				return
		var profile: Dictionary = data.profile.duplicate(true)
		profile.name = str(profile.get("name","Groundskeeper")).left(18)
		room.members[id] = {"profile":profile,"offered":[],"ready":false,"connected":true}
		var already_offered := 0
		for other in room.members.values(): already_offered += other.offered.size()
		for item in profile.owned:
			if item.type in ProfileStore.STARTERS and already_offered + room.members[id].offered.size() < int(Catalog.contract.trailer_capacity): room.members[id].offered.append(item.id)
		memberships[id] = room.code
		publish(room)
		return
	if not memberships.has(id):
		reject(peer,"Join a room first.")
		return
	var room: Dictionary = rooms[memberships[id]]
	var member: Dictionary = room.members[id]
	if op == "leave":
		remove_peer(peer)
		emit_to(peer,"left",{})
		return
	if op == "return" and room.phase == "results":
		room.phase = "lobby"
		for key in room.members.keys():
			if not room.members[key].connected: room.members.erase(key)
		for m in room.members.values():
			m.ready = false
			m.offered = []
			for item in m.profile.owned:
				if item.type in ProfileStore.STARTERS: m.offered.append(item.id)
		publish(room)
		return
	if room.phase != "lobby":
		reject(peer,"Lobby changes are closed during a shift.")
		return
	match op:
		"loadout":
			if not data.get("offered",null) is Array:
				reject(peer,"Invalid contribution.")
				return
			if data.has("profile") and data.profile is Dictionary and valid_profile(data.profile) and data.profile.uid == member.profile.uid:
				member.profile = data.profile.duplicate(true)
			var accepted: Array = []
			var available := int(Catalog.contract.trailer_capacity)
			for key in room.members:
				if key != id: available -= room.members[key].offered.size()
			for item in member.profile.owned:
				if item.id in data.offered and accepted.size() < available: accepted.append(item.id)
			member.offered = accepted
			member.ready = false
			publish(room)
		"ready":
			member.ready = bool(data.get("ready",false))
			publish(room)
		"start":
			if room.host != id:
				reject(peer,"Only the room host can start the shift.")
				return
			for m in room.members.values():
				if not m.ready:
					reject(peer,"Every employee must be ready.")
					return
			start(room)

func start(room: Dictionary) -> void:
	var roster := {}
	var loadout: Array = []
	for id in room.members:
		var member: Dictionary = room.members[id]
		roster[id] = {"name":member.profile.name}
		for item in member.profile.owned:
			if item.id in member.offered: loadout.append(item.duplicate(true))
	if loadout.size() > int(Catalog.contract.trailer_capacity):
		reject(int(room.host),"The trailer is full. Remove some equipment offers.")
		return
	room.simulation = Simulation.new(roster,loadout)
	room.match_id = Crypto.new().generate_random_bytes(12).hex_encode()
	room.start_usec = Time.get_ticks_usec()
	room.phase = "match"
	for id in room.members:
		ProfileStore.reserve(room.members[id].profile,room.match_id,loadout)
		emit_to(int(id),"started",{"state":room.simulation.state,"match_id":room.match_id,"loadout":loadout})

func input(peer: int, data: Dictionary) -> void:
	var id := str(peer)
	if not memberships.has(id): return
	var room: Dictionary = rooms[memberships[id]]
	if room.phase != "match": return
	if not data.get("move",null) is Vector2 or not data.get("face",null) is Vector2: return
	if not data.move.is_finite() or not data.face.is_finite(): return
	var sanitized := {"move":data.move.limit_length(1),"face":data.face.limit_length(1),"use":bool(data.get("use",false)),"click":bool(data.get("click",false)),"drop":bool(data.get("drop",false)),"extract":bool(data.get("extract",false))}
	if data.get("target",null) is Vector2 and data.target.is_finite(): sanitized.target = data.target
	# Preserve one-shot actions if two network packets land in a physics tick.
	var old: Dictionary = room.inputs.get(id,{})
	for key in ["click","drop","extract"]: sanitized[key] = sanitized[key] or old.get(key,false)
	room.inputs[id] = sanitized
	room.input_times[id] = Time.get_ticks_usec()

func tick(dt: float) -> void:
	snapshot_time += dt
	var send_snapshot := snapshot_time >= 0.05
	if send_snapshot: snapshot_time = 0.0
	for room in rooms.values():
		if room.phase != "match": continue
		for id in room.inputs:
			if Time.get_ticks_usec() - room.input_times.get(id,0) > 600000: room.inputs[id] = {}
		room.simulation.tick(dt,room.inputs,(Time.get_ticks_usec() - room.start_usec) / 1000000.0)
		for packet in room.inputs.values():
			packet.click = false
			packet.drop = false
			packet.extract = false
		if room.simulation.state.ended:
			settle(room)
		elif send_snapshot:
			for id in room.members:
				if room.members[id].connected: emit_to(int(id),"snapshot",{"state":room.simulation.state})

func settle(room: Dictionary) -> void:
	room.phase = "results"
	var state: Dictionary = room.simulation.state
	var cents := roundi(state.results.total * 100)
	var count: int = room.members.size()
	var index := 0
	state.results.shares = {}
	for id in room.members:
		var member: Dictionary = room.members[id]
		var share := (float(cents / count) + (1.0 if index < cents % count else 0.0)) / 100.0
		state.results.shares[id] = share
		ProfileStore.settle(member.profile,room.match_id,state,share)
		var result := {"state":state,"match_id":room.match_id,"share":share}
		archived[member.profile.uid + ":" + room.match_id] = result.duplicate(true)
		if member.connected: emit_to(int(id),"ended",result)
		index += 1
	# Keep bounded reconnect receipts in memory; accounts remain local in this MVP.
	while archived.size() > 256: archived.erase(archived.keys()[0])
	var connections := 0
	for member in room.members.values():
		if member.connected: connections += 1
	if connections == 0: rooms.erase(room.code)

func remove_peer(peer: int) -> void:
	var id := str(peer)
	if not memberships.has(id): return
	var room: Dictionary = rooms[memberships[id]]
	memberships.erase(id)
	if room.phase == "match":
		room.members[id].connected = false
		room.inputs.erase(id)
		room.simulation.kill(id)
	else:
		room.members.erase(id)
	if room.members.is_empty():
		rooms.erase(room.code)
		return
	if room.host == id:
		for candidate in room.members:
			if room.members[candidate].connected:
				room.host = candidate
				break
	if room.phase == "lobby": publish(room)
