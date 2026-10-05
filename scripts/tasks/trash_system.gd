class_name TrashSystem
extends RefCounted

static func capacity(tool: Dictionary) -> int:
	return int(tool.get("capacity",1)) if tool.is_empty() or tool.get("category","") == "trash" else 0

static func interact(state: Dictionary, p: Dictionary, tool: Dictionary) -> bool:
	if capacity(tool) == 0: return false
	if not p.bags.is_empty() and Cemetery.DUMPSTER.grow(65).has_point(p.pos):
		for index in p.bags:
			state.cans[index].delivered = true
			state.cans[index].holder = ""
		p.bags.clear()
		state.notice = "Bags delivered. The dumpster approves."
		state.notice_time = 3.0
		return true
	if p.bags.size() >= capacity(tool): return false
	var nearest := -1
	var distance := 63.0
	for i in state.cans.size():
		var bag: Dictionary = state.cans[i]
		if bag.delivered or not bag.holder.is_empty(): continue
		var pos: Vector2 = bag.bag_pos if bag.empty else bag.pos
		var d: float = p.pos.distance_to(pos)
		if d < distance:
			nearest = i
			distance = d
	if nearest < 0: return false
	state.cans[nearest].empty = true
	state.cans[nearest].holder = p.id
	p.bags.append(nearest)
	return true

static func drop(state: Dictionary, p: Dictionary, severity: float = 0.0) -> void:
	if p.bags.is_empty(): return
	var index: int = p.bags.pop_back()
	var bag: Dictionary = state.cans[index]
	bag.holder = ""
	bag.bag_pos = p.pos + p.facing * 23
	if severity >= 0.65: disturb(state,p,index,severity)

static func bump(state: Dictionary, p: Dictionary, severity: float) -> void:
	if p.bags.is_empty() or severity < 0.15: return
	p.bag_stress += severity
	if p.bag_stress >= 0.65:
		disturb(state,p,p.bags[0],p.bag_stress)
		p.bag_stress = 0.0

static func disturb(state: Dictionary, p: Dictionary, index: int, severity: float) -> void:
	var bag: Dictionary = state.cans[index]
	if severity < 0.65 or bag.disturbed: return
	bag.disturbed = true
	MonsterSystem.spawn(state,"werewolf",p.pos + Vector2(100,-70),"%s mishandled a bag. A werewolf smelled it." % p.name)
