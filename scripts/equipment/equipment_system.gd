class_name EquipmentSystem
extends RefCounted

static func spawn(contributions: Array) -> Dictionary:
	var result := {}
	for i in contributions.size():
		var item: Dictionary = contributions[i].duplicate(true)
		item.pos = slot(i)
		item.holder = ""
		item.returned = true
		item.slot = i
		item.tier = int(Catalog.tool(item.type).tier)
		item.cargo = []
		result[item.id] = item
	return result

static func slot(index: int) -> Vector2:
	return Vector2(654 + (index % 6) * 39,1254 + (index / 6) * 32)

static func release(state: Dictionary, player: Dictionary) -> void:
	if player.equipment.is_empty(): return
	var item: Dictionary = state.equipment[player.equipment]
	if Catalog.tool(item.type).category == "trash":
		item.cargo = player.bags.duplicate()
		for index in player.bags:
			state.cans[index].holder = "equipment:" + item.id
			state.cans[index].bag_pos = player.pos
		player.bags.clear()
	item.holder = ""
	item.pos = player.pos
	item.returned = Cemetery.TRAILER.grow(28).has_point(player.pos)
	if item.returned: item.pos = slot(item.slot)
	player.equipment = ""

static func lost_count(state: Dictionary) -> int:
	var count := 0
	for item in state.equipment.values():
		if not item.returned: count += 1
	return count

static func nearest(state: Dictionary, player: Dictionary, target: Vector2 = Vector2(INF,INF)) -> String:
	var selected := ""
	var score := INF
	# A precise cursor hit wins over proximity in a densely packed trailer.
	if target.is_finite():
		for id in state.equipment:
			var item: Dictionary = state.equipment[id]
			if not item.holder.is_empty() or player.pos.distance_to(item.pos) > 64: continue
			if not player.bags.is_empty() and Catalog.tool(item.type).category != "trash": continue
			var d: float = target.distance_to(item.pos)
			if d < 30 and d < score:
				selected = id
				score = d
		if not selected.is_empty(): return selected
	score = INF
	for id in state.equipment:
		var item: Dictionary = state.equipment[id]
		if not item.holder.is_empty(): continue
		if not player.bags.is_empty() and Catalog.tool(item.type).category != "trash": continue
		var distance: float = player.pos.distance_to(item.pos)
		if distance > 64: continue
		var facing: float = player.pos.direction_to(item.pos).dot(player.facing)
		var candidate: float = distance + (1.0 - facing) * 24
		if candidate < score:
			selected = id
			score = candidate
	return selected
