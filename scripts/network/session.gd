extends Node

signal changed
var simulation: Simulation
var service: LobbyService
var state: Dictionary = {}
var inputs: Dictionary = {}
var local_id := "solo"
var screen := "lobby"
var error := ""
var profile: Dictionary = {}
var offered: Array = []
var match_id := ""
var solo_start := 0
var dedicated := false
var online := false
var connected := false
var connecting := false
var room: Dictionary = {}
var directory: Array = []
var server_url := "ws://127.0.0.1:9080"
var request_times: Dictionary = {}
var send_time := 0.0
var pending_input: Dictionary = {}
var is_ready := false
var save_path := ProfileStore.SAVE_PATH

func _ready() -> void:
	dedicated = "--server" in OS.get_cmdline_user_args()
	if dedicated:
		service = LobbyService.new()
		multiplayer.server_relay = false
		var port := int(OS.get_environment("GRAVE_PORT")) if not OS.get_environment("GRAVE_PORT").is_empty() else 9080
		var peer := WebSocketMultiplayerPeer.new()
		peer.inbound_buffer_size = 1048576
		peer.outbound_buffer_size = 1048576
		var result := peer.create_server(port)
		if result != OK:
			push_error("Unable to bind WebSocket port %d: %s" % [port,error_string(result)])
			get_tree().quit(1)
			return
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_disconnected.connect(on_peer_disconnected)
		print("Grave Maintenance authoritative WebSocket server on port %d" % port)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-profile="): save_path = "user://" + arg.trim_prefix("--test-profile=") + ".json"
	profile = ProfileStore.load_profile(save_path)
	reset_offers()
	if OS.has_feature("web"):
		var configured = JavaScriptBridge.eval("window.GRAVE_SERVER_URL || ((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.hostname + ':9080')")
		if configured is String: server_url = configured
	multiplayer.connected_to_server.connect(on_connected)
	multiplayer.connection_failed.connect(func(): disconnect_online("Could not connect. Check the WebSocket server address."))
	multiplayer.server_disconnected.connect(func(): disconnect_online("Connection lost. Contributed equipment remains at risk; reconnect to recover a finished shift receipt."))

func reset_offers() -> void:
	offered.clear()
	for item in profile.owned:
		if item.type in ProfileStore.STARTERS: offered.append(item.id)
	is_ready = false

func connect_online(url: String) -> void:
	if connected:
		command("list",{})
		return
	if connecting: return
	error = ""
	server_url = url.strip_edges()
	if not server_url.begins_with("ws://") and not server_url.begins_with("wss://"):
		error = "Use a ws:// or wss:// server address."
		changed.emit()
		return
	var peer := WebSocketMultiplayerPeer.new()
	peer.inbound_buffer_size = 1048576
	peer.outbound_buffer_size = 1048576
	var result := peer.create_client(server_url)
	if result != OK:
		error = "Could not start a WebSocket connection."
		changed.emit()
		return
	online = true
	connecting = true
	multiplayer.multiplayer_peer = peer
	changed.emit()

func on_connected() -> void:
	connected = true
	connecting = false
	local_id = str(multiplayer.get_unique_id())
	command("list",{})
	for id in ProfileStore.pending_ids(profile): command("recover",{"uid":profile.uid,"match_id":id})
	changed.emit()

func on_peer_disconnected(peer: int) -> void:
	service.remove_peer(peer)
	request_times.erase(peer)
	dispatch()

func disconnect_online(message: String = "") -> void:
	if multiplayer.multiplayer_peer != null: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	connected = false
	connecting = false
	room = {}
	directory = []
	local_id = "solo"
	error = message
	screen = "lobby"
	inputs.clear()
	pending_input.clear()
	reset_offers()
	changed.emit()

func command(op: String, data: Dictionary) -> void:
	if connected: _command.rpc_id(1,op,data)

func create_room(locked: bool, password: String) -> void:
	command("create",{"title":profile.name + "'s night crew","locked":locked,"password":password,"profile":profile})

func join_room(code: String, password: String = "") -> void:
	command("join",{"code":code,"password":password,"profile":profile})

func leave_room() -> void:
	command("leave",{})

func set_ready(value: bool) -> void:
	is_ready = value
	if online and not room.is_empty(): command("ready",{"ready":value})
	else: changed.emit()

func start_match() -> void:
	if online and not room.is_empty(): command("start",{})
	elif is_ready: start_solo()

func start_solo() -> void:
	if online: disconnect_online()
	local_id = "solo"
	var loadout: Array = []
	for item in profile.owned:
		if item.id in offered: loadout.append(item.duplicate(true))
	simulation = Simulation.new({"solo":{"name":profile.name}},loadout)
	match_id = Crypto.new().generate_random_bytes(12).hex_encode()
	ProfileStore.reserve(profile,match_id,loadout)
	ProfileStore.save_profile(profile,save_path)
	solo_start = Time.get_ticks_usec()
	state = simulation.state
	screen = "match"
	error = ""
	inputs.clear()
	changed.emit()

func submit_input(packet: Dictionary) -> void:
	if online:
		for key in ["click","drop","extract"]: packet[key] = packet.get(key,false) or pending_input.get(key,false)
		pending_input = packet
	else:
		var old: Dictionary = inputs.get(local_id,{})
		for key in ["click","drop","extract"]: packet[key] = packet.get(key,false) or old.get(key,false)
		inputs[local_id] = packet

func _physics_process(dt: float) -> void:
	if dedicated:
		service.tick(dt)
		dispatch()
		return
	if screen != "match": return
	if online:
		send_time += dt
		if connected and send_time >= 1.0 / 30.0 and not pending_input.is_empty():
			_input_packet.rpc_id(1,pending_input)
			for key in ["click","drop","extract"]: pending_input[key] = false
			send_time = 0.0
		return
	if simulation == null: return
	simulation.tick(dt,inputs,(Time.get_ticks_usec() - solo_start) / 1000000.0)
	for packet in inputs.values():
		packet.click = false
		packet.drop = false
		packet.extract = false
	if state.ended:
		ProfileStore.settle(profile,match_id,state,state.results.total)
		ProfileStore.save_profile(profile,save_path)
		screen = "results"
		changed.emit()

func dispatch() -> void:
	var peers := multiplayer.get_peers()
	var transport: WebSocketMultiplayerPeer = multiplayer.multiplayer_peer
	for event in service.outbox:
		if event.peer in peers and transport.get_peer(event.peer).get_ready_state() == WebSocketPeer.STATE_OPEN:
			_receive.rpc_id(event.peer,event.kind,event.data)
	service.outbox.clear()

@rpc("any_peer","call_remote","reliable")
func _command(op: String, data: Dictionary) -> void:
	if not dedicated: return
	var peer := multiplayer.get_remote_sender_id()
	var now := Time.get_ticks_msec()
	var budget: Dictionary = request_times.get(peer,{"time":now,"count":0})
	if now - budget.time > 1000: budget = {"time":now,"count":0}
	budget.count += 1
	request_times[peer] = budget
	if budget.count > 12: return
	service.request(peer,op,data)
	dispatch()

@rpc("any_peer","call_remote","unreliable")
func _input_packet(data: Dictionary) -> void:
	if dedicated: service.input(multiplayer.get_remote_sender_id(),data)

@rpc("authority","call_remote","reliable")
func _receive(kind: String, data: Dictionary) -> void:
	if dedicated: return
	match kind:
		"error":
			error = data.message
			changed.emit()
		"directory":
			directory = data.rooms
			changed.emit()
		"lobby":
			if screen == "results": reset_offers()
			room = data
			screen = "lobby"
			error = ""
			if room.members.has(local_id):
				is_ready = room.members[local_id].ready
				offered = room.members[local_id].offered_ids.duplicate()
			changed.emit()
		"left":
			room = {}
			is_ready = false
			command("list",{})
			changed.emit()
		"started":
			state = data.state
			match_id = data.match_id
			ProfileStore.reserve(profile,match_id,data.loadout)
			ProfileStore.save_profile(profile,save_path)
			screen = "match"
			pending_input.clear()
			changed.emit()
		"snapshot":
			if screen == "match": state = data.state
		"ended":
			state = data.state
			ProfileStore.settle(profile,data.match_id,state,data.share)
			ProfileStore.save_profile(profile,save_path)
			screen = "results"
			changed.emit()
		"recovered":
			if ProfileStore.settle(profile,data.match_id,data.state,data.share):
				ProfileStore.save_profile(profile,save_path)
				reset_offers()
				error = "Your finished shift and returned equipment were recovered."
				changed.emit()

func back_to_lobby() -> void:
	reset_offers()
	if online and not room.is_empty(): command("return",{})
	else:
		screen = "lobby"
		changed.emit()

func buy(kind: String) -> void:
	if screen != "lobby": return
	if ProfileStore.buy(profile,kind):
		ProfileStore.save_profile(profile,save_path)
		update_loadout()

func toggle_offer(id: String) -> void:
	if id in offered: offered.erase(id)
	else:
		var total := offered.size()
		if not room.is_empty():
			for peer in room.members:
				if peer != local_id: total += room.members[peer].equipment.size()
		if total >= int(Catalog.contract.trailer_capacity):
			error = "The trailer holds %d tools. Remove an offer first." % int(Catalog.contract.trailer_capacity)
			changed.emit()
			return
		offered.append(id)
	update_loadout()

func set_player_name(value: String, notify: bool = true) -> void:
	profile.name = value.strip_edges().left(18)
	if profile.name.is_empty(): profile.name = "Groundskeeper"
	ProfileStore.save_profile(profile,save_path)
	update_loadout(notify)

func update_loadout(notify: bool = true) -> void:
	is_ready = false
	if online and not room.is_empty(): command("loadout",{"offered":offered,"profile":profile})
	elif notify: changed.emit()
