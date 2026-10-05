class_name ProfileStore
extends RefCounted

const SAVE_PATH := "user://crew_profile.json"
const STARTERS := ["push_mower","rake","spray"]

static func new_profile() -> Dictionary:
	var uid := Crypto.new().generate_random_bytes(12).hex_encode()
	var profile := {"version":1,"uid":uid,"name":"Groundskeeper","cash":float(Catalog.contract.starting_cash),"owned":[],"pending":{},"settled":[]}
	for kind in STARTERS: profile.owned.append(make_item(kind,uid))
	return profile

static func make_item(kind: String, uid: String) -> Dictionary:
	return {"id":Crypto.new().generate_random_bytes(12).hex_encode(),"type":kind,"owner":uid}

static func load_profile(path: String = SAVE_PATH) -> Dictionary:
	if FileAccess.file_exists(path):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
		if saved is Dictionary and saved.get("version",0) == 1 and saved.has("uid") and saved.has("owned") and saved.has("pending") and saved.has("settled"):
			return saved
	var created := new_profile()
	save_profile(created,path)
	return created

static func save_profile(profile: Dictionary, path: String = SAVE_PATH) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profile))
		file.close()

static func buy(profile: Dictionary, kind: String) -> bool:
	var tool := Catalog.tool(kind)
	if tool.is_empty(): return false
	# Basic replacements are free, but ownership is still individual and finite.
	if profile.cash < float(tool.price) or profile.owned.size() >= 24: return false
	if float(tool.price) == 0:
		for item in profile.owned:
			if item.type == kind: return false
	profile.cash = snappedf(profile.cash - float(tool.price),0.01)
	profile.owned.append(make_item(kind,profile.uid))
	return true

static func reserve(profile: Dictionary, match_id: String, equipment: Array) -> void:
	if match_id in pending_ids(profile): return
	var reserved: Array = []
	for item in equipment:
		if item.owner != profile.uid: continue
		for owned in profile.owned.duplicate():
			if owned.id == item.id:
				reserved.append(owned)
				profile.owned.erase(owned)
	var previous: Array = profile.pending.get("previous",[]).duplicate(true)
	if not profile.pending.is_empty(): previous.append({"match_id":profile.pending.match_id,"items":profile.pending.items.duplicate(true)})
	profile.pending = {"match_id":match_id,"items":reserved,"previous":previous}

static func pending_ids(profile: Dictionary) -> Array:
	var ids: Array = []
	if profile.pending.is_empty(): return ids
	ids.append(profile.pending.match_id)
	for entry in profile.pending.get("previous",[]): ids.append(entry.match_id)
	return ids

static func settle(profile: Dictionary, match_id: String, state: Dictionary, share: float) -> bool:
	if match_id in profile.settled or match_id not in pending_ids(profile): return false
	var receipt: Dictionary = profile.pending
	var previous: Array = profile.pending.get("previous",[]).duplicate(true)
	if receipt.match_id != match_id:
		for entry in previous:
			if entry.match_id == match_id:
				receipt = entry
				previous.erase(entry)
				break
	for item in receipt.items:
		if state.equipment.has(item.id) and state.equipment[item.id].returned and state.equipment[item.id].owner == profile.uid:
			profile.owned.append(item)
	profile.cash = snappedf(profile.cash + share,0.01)
	if profile.pending.match_id == match_id:
		profile.pending = previous.pop_back() if not previous.is_empty() else {}
	if not profile.pending.is_empty(): profile.pending.previous = previous
	profile.settled.append(match_id)
	if profile.settled.size() > 100: profile.settled.pop_front()
	return true
