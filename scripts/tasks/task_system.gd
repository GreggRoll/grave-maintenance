class_name TaskSystem
extends RefCounted

static func mow(state: Dictionary, map: Cemetery, pos: Vector2, radius: float) -> void:
	for i in map.grass.size():
		if state.grass[i] == 0 and pos.distance_squared_to(map.grass[i]) < radius * radius:
			state.grass[i] = 1

static func progress(state: Dictionary) -> Dictionary:
	var cut := 0
	for value in state.grass: cut += value
	var cleared := 0
	for value in state.leaves: cleared += value
	var delivered := 0
	for can in state.cans:
		if can.delivered: delivered += 1
	var clean := 0
	for grave in state.graves:
		if grave.clean >= 95: clean += 1
	return {"mowing":float(cut) / maxi(1,state.grass.size()),"leaves":float(cleared) / maxi(1,state.leaves.size()) / 100.0,"trash":float(delivered) / 8.0,"graves":float(clean) / 12.0}

static func clear_leaves(state: Dictionary, map: Cemetery, p: Dictionary, tool: Dictionary, dt: float) -> void:
	var center: Vector2 = p.pos + p.facing * 30
	for i in map.leaves.size():
		if center.distance_squared_to(map.leaves[i]) <= float(tool.radius) * float(tool.radius):
			state.leaves[i] = minf(100.0,state.leaves[i] + float(tool.rate) * dt)
	p.sound = minf(100.0,p.sound + float(tool.noise) * dt)
	if p.sound >= 85:
		p.sound_danger += dt
		if p.sound_danger >= 2.5 and p.ghost_cooldown <= 0:
			MonsterSystem.spawn(state,"ghost",p.pos + Vector2(100,-100),"%s made too much noise. A ghost heard." % p.name)
			p.ghost_cooldown = 25.0
			p.sound_danger = 0.0
	else: p.sound_danger = maxf(0,p.sound_danger - dt * 2)

static func payout(state: Dictionary) -> Dictionary:
	var completion := progress(state)
	var rows := {}
	var gross := 0.0
	for category in completion:
		rows[category] = snappedf(completion[category] * float(Catalog.contract.maximum_payout) / 4.0,0.01)
		gross += rows[category]
	var deaths := 0
	for p in state.players.values():
		if not p.alive: deaths += 1
	var penalty := minf(1.0,deaths * float(Catalog.contract.death_penalty))
	var total := 0.0 if deaths == state.players.size() else snappedf(gross * (1.0 - penalty),0.01)
	return {"rows":rows,"completion":completion,"gross":gross,"deaths":deaths,"penalty":penalty,"total":total}
