class_name CleaningSystem
extends RefCounted

static func target(state: Dictionary, p: Dictionary) -> int:
	var index := -1
	var best := 86.0
	for i in state.graves.size():
		var grave: Dictionary = state.graves[i]
		var to: Vector2 = p.pos.direction_to(grave.pos)
		var distance: float = p.pos.distance_to(grave.pos)
		if distance > 82 or to.dot(p.facing) < -0.1: continue
		var score: float = distance - to.dot(p.facing) * 20
		if score < best:
			best = score
			index = i
	return index

static func clean(state: Dictionary, p: Dictionary, tool: Dictionary, dt: float, clicked: bool, held: bool) -> void:
	p.clean_target = target(state,p)
	if p.clean_target < 0: return
	var amount := 0.0
	if tool.tier == 1:
		if clicked and p.cooldown <= 0:
			amount = float(tool.rate)
			p.cooldown = 0.16
	elif held: amount = float(tool.rate) * dt
	if amount <= 0: return
	var grave: Dictionary = state.graves[p.clean_target]
	grave.clean = minf(180,grave.clean + amount)
	if grave.clean > 105 and not grave.vampire:
		grave.overclean = grave.get("overclean",0.0) + maxf(0,grave.clean - 105) / 18.0 * (0.16 if tool.tier == 1 else dt)
		if grave.overclean >= 1.0 or grave.clean >= 130:
			grave.vampire = true
			MonsterSystem.spawn(state,"vampire",grave.pos + Vector2(0,64),"%s over-cleaned a grave. A vampire is awake." % p.name)
