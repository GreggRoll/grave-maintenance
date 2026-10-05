class_name Simulation
extends RefCounted

var map := Cemetery.new()
var state: Dictionary
var rng := RandomNumberGenerator.new()

func _init(roster: Dictionary = {}, contributions: Array = []) -> void:
	rng.randomize()
	var grass := PackedByteArray()
	grass.resize(map.grass.size())
	grass.fill(0)
	var leaves := PackedFloat32Array()
	leaves.resize(map.leaves.size())
	leaves.fill(0)
	state = {"elapsed":0.0,"ended":false,"players":{},"equipment":EquipmentSystem.spawn(contributions),"grass":grass,"leaves":leaves,"graves":map.graves.duplicate(true),"cans":map.cans.duplicate(true),"monsters":[],"notice":"Clock in. Clock out alive.","notice_time":5.0,"results":{},"witches":false}
	for id in roster:
		state.players[id] = {"id":id,"name":roster[id].name,"pos":Vector2(565 + state.players.size() * 29,1350),"facing":Vector2.UP,"alive":true,"extracted":false,"equipment":"","bags":[],"sound":0.0,"sound_danger":0.0,"ghost_cooldown":0.0,"cooldown":0.0,"bump_cooldown":0.0,"clean_target":-1,"using":false,"hint":""}
		state.players[id].velocity = Vector2.ZERO
		state.players[id].bag_stress = 0.0

func tick(dt: float, inputs: Dictionary, real_elapsed: float = -1.0) -> void:
	if state.ended: return
	state.elapsed = real_elapsed if real_elapsed >= 0 else state.elapsed + dt
	state.notice_time = maxf(0,state.notice_time - dt)
	for id in state.players:
		var p: Dictionary = state.players[id]
		if not p.alive or p.extracted: continue
		var input: Dictionary = inputs.get(id,{})
		p.cooldown = maxf(0,p.cooldown - dt)
		p.bump_cooldown = maxf(0,p.bump_cooldown - dt)
		p.ghost_cooldown = maxf(0,p.ghost_cooldown - dt)
		p.bag_stress = maxf(0,p.bag_stress - dt * 0.04)
		var direction: Vector2 = input.get("move",Vector2.ZERO).limit_length(1)
		var facing: Vector2 = input.get("face",p.facing)
		if facing.length() > 0.1: p.facing = facing.normalized()
		var tool := Catalog.tool(state.equipment[p.equipment].type) if not p.equipment.is_empty() else {}
		var speed: float = float(Catalog.contract.walk_speed) if tool.is_empty() else float(tool.get("speed",Catalog.contract.walk_speed))
		var radius := 13.0
		if not tool.is_empty() and tool.category == "mowing": radius = 19.0 + int(tool.tier) * 4
		if not tool.is_empty() and tool.category == "trash": radius = 23.0
		var old: Vector2 = p.pos
		p.velocity = p.velocity.move_toward(direction * speed,dt * float(tool.get("acceleration",480.0)))
		var attempted: Vector2 = p.velocity * dt
		p.pos = map.move_body(p.pos,attempted,radius)
		var hit: bool = p.pos.distance_to(old) < attempted.length() * 0.75 and attempted.length() > 0.1
		if hit and p.bump_cooldown <= 0 and not p.bags.is_empty():
			TrashSystem.bump(state,p,maxf(0,(p.velocity.length() - 50) / 140) * float(tool.get("force",0.9)) * float(tool.get("protection",1.0)))
			p.bump_cooldown = 0.7
		if not tool.is_empty() and tool.category == "mowing":
			if state.elapsed < 300: TaskSystem.mow(state,map,p.pos + p.facing * 15,float(tool.radius))
			if hit and p.bump_cooldown <= 0: mower_impact(p,tool,p.velocity.length())
		if hit: p.velocity = (p.pos - old) / maxf(dt,0.001)
		p.using = input.get("use",false)
		if not tool.is_empty() and tool.category == "leaves" and p.using and state.elapsed < 300:
			TaskSystem.clear_leaves(state,map,p,tool,dt)
		else:
			p.sound = maxf(0,p.sound - 18 * dt)
			p.sound_danger = maxf(0,p.sound_danger - 3 * dt)
		p.clean_target = -1
		if not tool.is_empty() and tool.category == "graves" and state.elapsed < 300:
			CleaningSystem.clean(state,p,tool,dt,input.get("click",false),p.using)
		if input.get("drop",false):
			if not tool.is_empty() and tool.category == "trash": EquipmentSystem.release(state,p)
			elif not p.bags.is_empty(): TrashSystem.drop(state,p,p.velocity.length() / 210.0)
			else: EquipmentSystem.release(state,p)
		if input.get("click",false) and state.elapsed < 300: interact(p,input.get("target",Vector2(INF,INF)))
		if input.get("extract",false) and state.elapsed < 300 and Cemetery.EXTRACTION.grow(40).has_point(p.pos):
			p.extracted = true
			p.using = false
			EquipmentSystem.release(state,p)
			while not p.bags.is_empty(): TrashSystem.drop(state,p)
		# Keep shared items attached to their carrier for rendering and recovery.
		for bag_id in p.bags: state.cans[bag_id].bag_pos = p.pos
	for id in state.players:
		var p: Dictionary = state.players[id]
		if not p.alive or p.extracted: continue
		for other_id in state.players:
			if id >= other_id: continue
			var other: Dictionary = state.players[other_id]
			if not other.alive or other.extracted or p.pos.distance_to(other.pos) >= 31: continue
			var relative: float = (p.velocity - other.velocity).length()
			if relative > 130 and p.bump_cooldown <= 0:
				TrashSystem.bump(state,p,(relative - 80) / 170)
				TrashSystem.bump(state,other,(relative - 80) / 170)
				p.bump_cooldown = 1.0
				other.bump_cooldown = 1.0
			var away: Vector2 = other.pos.direction_to(p.pos)
			p.pos = map.move_body(p.pos,away * 3,13)
			other.pos = map.move_body(other.pos,-away * 3,13)
	MonsterSystem.tick(state,map,dt,kill)
	if state.elapsed >= 300 and not state.witches:
		state.witches = true
		state.notice = "3:00 AM. THE WITCHES ARE HERE."
		state.notice_time = 15.0
		for p in state.players.values():
			if p.alive and not p.extracted: MonsterSystem.spawn(state,"witch",Vector2(p.pos.x,35),"THE WITCHING HOUR")
	if state.elapsed >= 312:
		for id in state.players:
			if state.players[id].alive and not state.players[id].extracted: kill(id)
	var remaining := 0
	for p in state.players.values():
		if p.alive and not p.extracted: remaining += 1
	if remaining == 0: finish()

func interact(p: Dictionary, target: Vector2 = Vector2(INF,INF)) -> void:
	var tool := Catalog.tool(state.equipment[p.equipment].type) if not p.equipment.is_empty() else {}
	if TrashSystem.interact(state,p,tool): return
	if not p.equipment.is_empty(): return
	var nearest := EquipmentSystem.nearest(state,p,target)
	if not nearest.is_empty():
		var item: Dictionary = state.equipment[nearest]
		if item.cargo.size() + p.bags.size() > TrashSystem.capacity(Catalog.tool(item.type)): return
		p.equipment = nearest
		state.equipment[nearest].holder = p.id
		state.equipment[nearest].returned = false
		var equipped := Catalog.tool(item.type)
		if equipped.category in ["mowing","trash"]:
			p.pos = map.free_position(item.pos,19 + int(equipped.tier) * 4 if equipped.category == "mowing" else 23)
			p.velocity = Vector2.ZERO
		if Catalog.tool(item.type).category == "trash":
			p.bags.append_array(item.cargo)
			item.cargo.clear()
			for index in p.bags: state.cans[index].holder = p.id

func mower_impact(p: Dictionary, tool: Dictionary, speed: float) -> void:
	p.bump_cooldown = 1.2
	var severity: float = maxf(0,(speed - 42.0) / 150.0) * float(tool.force)
	if severity < 0.08: return
	for grave in state.graves:
		if not grave.awake and p.pos.distance_to(grave.pos) < 74 and rng.randf() < severity:
			grave.awake = true
			MonsterSystem.spawn(state,"zombie",grave.pos + Vector2(0,56),"%s clipped a grave. A zombie woke up." % p.name)
			break

func kill(id: String) -> void:
	var p: Dictionary = state.players[id]
	if not p.alive or p.extracted: return
	p.alive = false
	EquipmentSystem.release(state,p)
	while not p.bags.is_empty(): TrashSystem.drop(state,p)
	state.notice = "%s is dead. Recover their equipment." % p.name
	state.notice_time = 5.0

func finish() -> void:
	state.ended = true
	state.results = TaskSystem.payout(state)
