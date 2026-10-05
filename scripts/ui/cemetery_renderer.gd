class_name CemeteryRenderer
extends Node2D

const CREAM := Color("e4e4c9")
const INK := Color("12282a")
const GOLD := Color("ecb46e")
var map := Cemetery.new()
var camera := Vector2(550,1030)
var zoom := 1.0
var origin := Vector2.ZERO
var input: InputController
var font := ThemeDB.fallback_font
var time := 0.0

func _process(dt: float) -> void:
	time += dt
	visible = Session.screen == "match"
	if visible:
		var size := get_viewport_rect().size
		zoom = 1.35 if size.x < 1000 else 1.15
		var target := camera
		if Session.state.players.has(Session.local_id):
			var player: Dictionary = Session.state.players[Session.local_id]
			target = player.pos
			if not player.alive or player.extracted:
				for other in Session.state.players.values():
					if other.alive and not other.extracted:
						target = other.pos
						break
		var half_y := size.y / zoom / 2.0
		var half_x := size.x / zoom / 2.0
		target.x = clampf(target.x,minf(half_x,550),maxf(1100 - half_x,550))
		var south_padding := 170.0 if size.x < 1000 else 0.0
		target.y = clampf(target.y,minf(half_y,710),maxf(1420 + south_padding - half_y,710))
		camera = camera.lerp(target,1.0 - exp(-dt * 7))
		origin = size / 2.0 - camera * zoom
		queue_redraw()

func screen_to_world(p: Vector2) -> Vector2:
	return (p - origin) / zoom

func world_to_screen(p: Vector2) -> Vector2:
	return p * zoom + origin

func text_at(p: Vector2, text: String, color: Color = CREAM, size: int = 14) -> void:
	draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw() -> void:
	if Session.state.is_empty(): return
	var state: Dictionary = Session.state
	draw_set_transform(origin,0,Vector2.ONE * zoom)
	draw_rect(Rect2(-400,-400,1900,2200),Color("101e26"))
	draw_rect(Rect2(25,25,1050,1365),Color("263d33"))
	draw_rect(Rect2(78,240,947,905),Color("35503a"))
	# Geometric path network, clearly separated from grass.
	for path in [Rect2(492,205,118,1015),Rect2(78,450,947,90),Rect2(78,770,947,90),Rect2(95,195,935,60)]:
		draw_rect(path,Color("666b5d"))
		draw_rect(path.grow(-5),Color("777969"))
	for i in map.grass.size():
		var p: Vector2 = map.grass[i]
		if state.grass[i] == 1:
			draw_rect(Rect2(p - Vector2(14,14),Vector2(28,28)),Color("46674a"))
		else:
			var tint := Color("5c7852") if i % 3 else Color("718554")
			draw_line(p - Vector2(4,-4),p + Vector2(-3,-7),tint,2)
			draw_line(p + Vector2(1,5),p + Vector2(5,-5),tint,2)
	for i in map.leaves.size():
		if state.leaves[i] >= 100: continue
		var p: Vector2 = map.leaves[i] + Vector2(0,state.leaves[i] * 0.18)
		var color := Color("c19354") if i % 3 else Color("c07846")
		color.a = 1.0 - state.leaves[i] / 120.0
		var angle := i * 1.37
		draw_line(p - Vector2.from_angle(angle) * 5,p + Vector2.from_angle(angle) * 5,color,4)
	# Fence, open gate and street.
	for x in range(25,1080,25):
		draw_line(Vector2(x,26),Vector2(x,43),Color("9d9e7c"),3)
		if x < 485 or x > 618: draw_line(Vector2(x,1158),Vector2(x,1178),Color("9d9e7c"),3)
	for x in [25,1075]:
		draw_line(Vector2(x,26),Vector2(x,1165),Color("839078"),3)
		for y in range(30,1170,25): draw_line(Vector2(x - 5,y),Vector2(x + 5,y),Color("9d9e7c"),3)
	draw_line(Vector2(25,34),Vector2(1075,34),Color("9d9e7c"),2)
	draw_rect(Rect2(25,1184,1050,205),Color("363e45"))
	draw_line(Vector2(25,1184),Vector2(1075,1184),Color("aaaa91"),4)
	for x in range(65,1080,100): draw_rect(Rect2(x,1370,45,4),Color("ada98a"))
	# Maintenance shed and dumpster.
	draw_rect(Cemetery.BUILDING.grow(6),Color("142329"))
	draw_rect(Cemetery.BUILDING,Color("637377"))
	draw_rect(Rect2(376,48,348,45),Color("8b9690"))
	draw_rect(Rect2(523,154,54,51),Color("273c3d"))
	draw_rect(Rect2(410,150,68,34),Color("d4b66c"))
	draw_rect(Rect2(620,150,68,34),Color("d4b66c"))
	text_at(Vector2(428,126),"MAINTENANCE",INK,25)
	draw_rect(Cemetery.DUMPSTER.grow(4),INK)
	draw_rect(Cemetery.DUMPSTER,Color("587969"))
	draw_rect(Rect2(759,104,138,15),Color("8aa186"))
	text_at(Vector2(778,153),"DUMPSTER",CREAM,15)
	for grave in state.graves: draw_grave(grave)
	for can in state.cans:
		draw_circle(can.pos + Vector2(2,6),19,Color(0,0,0,0.2))
		draw_rect(Rect2(can.pos - Vector2(12,15),Vector2(24,30)),Color("455b57"))
		draw_rect(Rect2(can.pos - Vector2(15,18),Vector2(30,7)),Color("849387"))
		if not can.empty: draw_circle(can.pos,7,Color("d1b282"))
		elif not can.delivered and can.holder.is_empty(): draw_bag(can.bag_pos)
	for p in map.trees: draw_tree(p)
	# Warm pools of light at the cemetery entrance.
	for x in [470,631]:
		draw_circle(Vector2(x,1160),57,Color(0.94,0.72,0.4,0.07))
		draw_circle(Vector2(x,1160),36,Color(0.94,0.72,0.4,0.1))
		draw_rect(Rect2(x - 3,1133,6,44),Color("202e34"))
		draw_circle(Vector2(x,1133),7,GOLD)
	draw_truck()
	for item in state.equipment.values():
		if item.holder.is_empty():
			draw_tool(item.pos,item.type,Vector2.UP)
			for i in item.get("cargo",[]).size(): draw_bag(item.pos + Vector2(-12 + i * 8,0))
	if state.players.has(Session.local_id):
		var player: Dictionary = state.players[Session.local_id]
		if player.alive and not player.extracted and player.equipment.is_empty():
			var id := EquipmentSystem.nearest(state,player,input.aim_point() if input != null else Vector2(INF,INF))
			if not id.is_empty():
				var p: Vector2 = state.equipment[id].pos
				draw_arc(p,24,0,TAU,30,GOLD,2)
				text_at(p + Vector2(-30,-33),Catalog.tool(state.equipment[id].type).name,GOLD,13)
	for monster in state.monsters: draw_monster(monster)
	for p in state.players.values(): draw_player(p)
	if state.players.has(Session.local_id):
		var p: Dictionary = state.players[Session.local_id]
		if p.alive and not p.extracted and p.clean_target >= 0:
			var grave: Dictionary = state.graves[p.clean_target]
			var pos: Vector2 = grave.pos + Vector2(-72,-65)
			draw_rect(Rect2(pos - Vector2(7,22),Vector2(158,51)),Color("132a2c"))
			text_at(pos,"CLEANLINESS   %d%%" % roundi(grave.clean),CREAM,13)
			draw_rect(Rect2(pos + Vector2(0,8),Vector2(142,9)),Color("3d5149"))
			var color := Color("92c891") if grave.clean <= 105 else Color("eb9669")
			draw_rect(Rect2(pos + Vector2(0,8),Vector2(142 * minf(grave.clean,130) / 130.0,9)),color)
			draw_line(pos + Vector2(142 * 95.0 / 130,5),pos + Vector2(142 * 95.0 / 130,20),CREAM,1)
			draw_line(pos + Vector2(142 * 105.0 / 130,5),pos + Vector2(142 * 105.0 / 130,20),CREAM,1)
	# Screen-space touch joystick stays readable as the camera moves.
	draw_set_transform(Vector2.ZERO)
	# Dark HUD backing and urgent edge pulses keep warnings readable over grass.
	draw_rect(Rect2(16,14,275,200),Color(0.035,0.08,0.1,0.82))
	draw_rect(Rect2(get_viewport_rect().size.x / 2 - 154,12,308,70),Color(0.035,0.08,0.1,0.8))
	if state.players.has(Session.local_id):
		var p: Dictionary = state.players[Session.local_id]
		if not p.equipment.is_empty() or not p.bags.is_empty(): draw_rect(Rect2(16,225,355,170),Color(0.035,0.08,0.1,0.82))
	if state.notice_time > 0 or state.elapsed >= 270:
		draw_rect(Rect2(24,get_viewport_rect().size.y - 122,get_viewport_rect().size.x - 48,52),Color(0.08,0.07,0.06,0.84))
	if state.elapsed >= 295:
		var color := Color(0.8,0.22,0.18,0.10 + absf(sin(time * 5)) * 0.14)
		draw_rect(get_viewport_rect().grow(-8),color,false,18)
	if input != null and input.touch_enabled and input.stick_id >= 0:
		draw_circle(input.stick_origin,70,Color(0.9,0.9,0.8,0.12))
		draw_arc(input.stick_origin,70,0,TAU,40,Color(0.9,0.9,0.8,0.4),3)
		draw_circle(input.stick_origin + input.touch_move * 55,25,Color(0.9,0.9,0.8,0.4))

func draw_grave(grave: Dictionary) -> void:
	var p: Vector2 = grave.pos
	var clean: float = clampf(grave.clean / 100.0,0,1)
	ellipse_shape(p + Vector2(3,25),Vector2(31,12),Color(0,0,0,0.25))
	draw_rect(Rect2(p - Vector2(28,-17),Vector2(56,12)),Color("33464b"))
	var color := Color("6b7260").lerp(Color("c2d0c7"),clean)
	draw_rect(Rect2(p - Vector2(23,10),Vector2(46,32)),color)
	draw_circle(p - Vector2(0,10),23,color)
	draw_rect(Rect2(p - Vector2(17,10),Vector2(34,28)),color.lightened(0.08),false,2)
	draw_line(p + Vector2(-8,-8),p + Vector2(8,-8),Color("425254"),3)
	draw_line(p + Vector2(0,-16),p + Vector2(0,5),Color("425254"),3)
	if clean < 0.95:
		for j in 5:
			draw_circle(p + Vector2(-15 + j * 7,9 + (j % 2) * 7),4 * (1 - clean),Color("8a733f"))
	if grave.awake: draw_line(p + Vector2(-15,27),p + Vector2(15,35),Color("121b1c"),7)
	if clean >= 0.95: draw_circle(p + Vector2(22,-25),5,Color("98dba0"))

func draw_tree(p: Vector2) -> void:
	draw_circle(p + Vector2(7,12),42,Color(0,0,0,0.2))
	draw_rect(Rect2(p - Vector2(7,-5),Vector2(14,35)),Color("625442"))
	draw_circle(p - Vector2(0,10),38,Color("224a42"))
	draw_circle(p - Vector2(15,17),25,Color("31594a"))
	draw_circle(p + Vector2(17,-22),24,Color("3e6753"))

func ellipse_shape(p: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24: points.append(p + Vector2(cos(i * TAU / 24),sin(i * TAU / 24)) * radii)
	draw_colored_polygon(points,color)

func draw_truck() -> void:
	draw_rect(Cemetery.EXTRACTION.grow(15),Color(0.8,0.68,0.4,0.1))
	draw_rect(Cemetery.EXTRACTION.grow(15),GOLD,false,2)
	draw_rect(Rect2(373,1264,168,73),Color("d6c8a0"))
	draw_rect(Rect2(383,1272,46,57),Color("2a4249"))
	draw_rect(Rect2(435,1275,95,51),Color("b2ab8c"))
	draw_rect(Rect2(386,1260,28,9),INK)
	draw_rect(Rect2(386,1334,28,9),INK)
	draw_rect(Rect2(505,1260,26,9),INK)
	draw_rect(Rect2(505,1334,26,9),INK)
	draw_line(Vector2(541,1300),Vector2(630,1300),Color("8a9290"),5)
	text_at(Vector2(397,1310),"GM",GOLD,19)
	text_at(Vector2(385,1372),"EXTRACT HERE",GOLD,16)
	draw_rect(Cemetery.TRAILER.grow(6),Color("12272b"))
	draw_rect(Cemetery.TRAILER,Color("686e63"))
	draw_rect(Cemetery.TRAILER.grow(-5),Color("3f5149"))
	draw_rect(Cemetery.TRAILER,Color("a6bba2"),false,3)
	for x in [652,829]: draw_rect(Rect2(x,1328,29,10),INK)
	text_at(Vector2(651,1220),"TRAILER  /  RETURN TO KEEP",Color("a6bba2"),16)

func draw_tool(p: Vector2, kind: String, face: Vector2) -> void:
	var tool := Catalog.tool(kind)
	if tool.is_empty(): return
	draw_circle(p + Vector2(3,5),17,Color(0,0,0,0.2))
	var color := GOLD if int(tool.tier) == 1 else Color("c1784e") if int(tool.tier) == 2 else Color("9da5c5")
	if tool.category == "mowing":
		var width := 13 + int(tool.tier) * 4
		draw_rect(Rect2(p - Vector2(width,13),Vector2(width * 2,25)),color)
		draw_circle(p,7,INK)
		for offset in [Vector2(-width,-9),Vector2(width,-9),Vector2(-width,10),Vector2(width,10)]: draw_circle(p + offset,4,Color("18262a"))
		draw_line(p,p - face * 26,Color("b6bda7"),3)
	elif kind == "rake":
		draw_line(p - face * 10,p + face * 20,GOLD,3)
		var edge: Vector2 = face.orthogonal()
		draw_line(p + face * 20 - edge * 12,p + face * 20 + edge * 12,CREAM,3)
		for i in range(-2,3): draw_line(p + face * 20 + edge * i * 5,p + face * 26 + edge * i * 5,CREAM,2)
	elif tool.category == "trash":
		draw_rect(Rect2(p - Vector2(19,20),Vector2(38,40)),color)
		draw_rect(Rect2(p - Vector2(14,14),Vector2(28,30)),INK)
		for offset in [Vector2(-20,-15),Vector2(20,-15),Vector2(-20,15),Vector2(20,15)]: draw_circle(p + offset,5,Color("172629"))
		draw_line(p,p - face * 34,CREAM,3)
	else:
		draw_circle(p,10,color)
		draw_line(p,p + face * 24,CREAM,4)

func draw_player(p: Dictionary) -> void:
	if p.extracted: return
	var pos: Vector2 = p.pos
	if not p.alive:
		ellipse_shape(pos,Vector2(18,8),Color("ac7355"))
		text_at(pos + Vector2(-18,-20),"R.I.P.",Color("dd9078"),12)
		return
	var face: Vector2 = p.facing
	var equipped := {}
	if not p.equipment.is_empty(): equipped = Catalog.tool(Session.state.equipment[p.equipment].type)
	if not equipped.is_empty() and equipped.category in ["mowing","trash"]: pos -= face * (8 if equipped.get("capacity",0) == 4 else 27)
	ellipse_shape(pos + Vector2(0,11),Vector2(15,8),Color(0,0,0,0.3))
	var palette := [Color("e3bc74"),Color("8ab4d0"),Color("c78db9"),Color("95c795")]
	var index: int = Session.state.players.keys().find(p.id)
	var color: Color = palette[index % 4]
	draw_circle(pos,12,color.darkened(0.25))
	draw_circle(pos + face * 6,8,Color("d0b692"))
	draw_circle(pos - face * 3,8,color)
	draw_line(pos + face * 9 - face.orthogonal() * 5,pos + face * 9 + face.orthogonal() * 5,INK,3)
	draw_arc(pos,20,face.angle() - 0.4,face.angle() + 0.4,8,GOLD,2)
	if p.id == Session.local_id: draw_arc(pos,18,0,TAU,32,Color(0.95,0.9,0.7,0.3),1)
	text_at(pos + Vector2(-27,-30),p.name.left(12),color,12)
	if not p.equipment.is_empty():
		var tool: Dictionary = Session.state.equipment[p.equipment]
		draw_tool(p.pos if equipped.category in ["mowing","trash"] else pos + face * 24,tool.type,face)
		if p.using and Catalog.tool(tool.type).category == "leaves":
			draw_arc(pos + face * 30,float(Catalog.tool(tool.type).radius),face.angle() - 0.7,face.angle() + 0.7,15,Color(0.8,0.8,0.6,0.35),2)
	for i in p.bags.size(): draw_bag(p.pos + Vector2(-14 + i * 10,10))

func draw_monster(m: Dictionary) -> void:
	if m.kind == "ghost" and int(m.age) % 7 >= 5: return
	var p: Vector2 = m.pos
	var color := Color("99b46c")
	if m.kind == "witch": color = Color("bb8ed1")
	if m.kind == "ghost": color = Color("aed8d3")
	if m.kind == "werewolf": color = Color("c98256")
	if m.kind == "vampire": color = Color("d393ab")
	if m.kind == "vampire" and fmod(m.age,4.0) >= 2.6:
		draw_arc(p,25 + sin(time * 18) * 3,0,TAU,25,Color("f49d94"),2)
	draw_circle(p,18,Color(0,0,0,0.2))
	draw_circle(p,14,color)
	draw_circle(p + Vector2(-5,-4),3,Color("f7b383"))
	draw_circle(p + Vector2(5,-4),3,Color("f7b383"))
	draw_line(p + Vector2(-20,8),p + Vector2(20,5),color,5)
	text_at(p + Vector2(-25,-26),m.kind.to_upper(),color,11)

func draw_bag(p: Vector2) -> void:
	draw_circle(p + Vector2(2,4),12,Color(0,0,0,0.25))
	ellipse_shape(p,Vector2(10,13),Color("35363e"))
	draw_line(p + Vector2(-5,-13),p + Vector2(5,-13),Color("d1b28c"),3)
	draw_line(p + Vector2(-5,0),p + Vector2(-2,7),Color("666571"),2)
