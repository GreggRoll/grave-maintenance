class_name MonsterSystem
extends RefCounted

static func spawn(state: Dictionary, kind: String, pos: Vector2, cause: String) -> void:
	state.monsters.append({"kind":kind,"pos":pos,"age":0.0,"target":"","path_time":0.0,"direction":Vector2.ZERO,"last_seen":pos,"memory":0.0})
	state.notice = cause
	state.notice_time = 5.0

static func tick(state: Dictionary, map: Cemetery, dt: float, kill: Callable) -> void:
	for monster in state.monsters:
		if monster.kind != "witch": monster.pos = map.monster_position(monster.pos,monster.kind == "ghost")
		monster.age += dt
		if monster.age < 1.5: continue
		var target := ""
		var distance := INF
		for id in state.players:
			var p: Dictionary = state.players[id]
			if not p.alive or p.extracted: continue
			if monster.kind != "witch" and not Cemetery.GROUNDS.has_point(p.pos): continue
			if monster.kind == "zombie" and not map.visible(monster.pos,p.pos) and monster.target != id: continue
			var d: float = p.pos.distance_to(monster.pos)
			if d < distance:
				target = id
				distance = d
		if target.is_empty(): continue
		monster.target = target
		var p: Dictionary = state.players[target]
		if monster.kind == "werewolf":
			if map.visible(monster.pos,p.pos):
				monster.last_seen = p.pos
				monster.memory = 7.0
			else:
				monster.memory = maxf(0,monster.memory - dt)
				if monster.memory <= 0: continue
		monster.path_time -= dt
		if monster.path_time <= 0:
			var goal: Vector2 = monster.last_seen if monster.kind == "werewolf" else p.pos
			if monster.kind == "ghost" and distance > 140: goal += Vector2(sin(monster.age * 1.7),cos(monster.age * 1.3)) * 65
			monster.direction = monster.pos.direction_to(goal) if monster.kind in ["ghost","witch"] else map.pursuit_direction(monster.pos,goal)
			monster.path_time = 0.35
		var speed := 53.0
		if monster.kind == "ghost": speed = 91.0 if int(monster.age) % 7 < 5 else 120.0
		if monster.kind == "witch": speed = 420.0
		if monster.kind == "werewolf": speed = 158.0
		if monster.kind == "vampire":
			var phase: float = fmod(monster.age,4.0)
			speed = 61.0
			if distance < 190 and phase >= 3.2: speed = 255.0
			elif distance < 190 and phase >= 2.6: speed = 12.0
		if monster.kind in ["ghost","witch"]: monster.pos += monster.direction * speed * dt
		else: monster.pos = map.move_body(monster.pos,monster.direction * speed * dt,12)
		if monster.kind != "witch": monster.pos = map.monster_position(monster.pos,monster.kind == "ghost")
		if monster.pos.distance_to(p.pos) < 23: kill.call(target)
