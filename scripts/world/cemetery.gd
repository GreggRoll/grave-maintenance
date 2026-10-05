class_name Cemetery
extends RefCounted

const SIZE := Vector2(1100, 1420)
const TRAILER := Rect2(630, 1230, 250, 100)
const EXTRACTION := Rect2(370, 1245, 185, 110)
const BUILDING := Rect2(385, 55, 330, 150)
const DUMPSTER := Rect2(765, 110, 125, 72)
const CELL := 28
var graves: Array = []
var grass: Array = []
var leaves: Array[Vector2] = []
var cans: Array = []
var trees: Array = []
var obstacles: Array[Rect2] = []
var navigation := AStarGrid2D.new()

func _init() -> void:
	var positions := [Vector2(200,335),Vector2(388,355),Vector2(717,328),Vector2(898,348),Vector2(188,650),Vector2(375,674),Vector2(728,666),Vector2(905,645),Vector2(209,972),Vector2(380,952),Vector2(716,963),Vector2(899,978)]
	for i in positions.size():
		graves.append({"id":i,"pos":positions[i],"clean":0.0,"awake":false,"vampire":false})
		obstacles.append(Rect2(positions[i] - Vector2(23,33), Vector2(46,58)))
	for p in [Vector2(110,250),Vector2(978,250),Vector2(109,525),Vector2(980,530),Vector2(115,840),Vector2(973,841),Vector2(118,1110),Vector2(980,1110)]:
		cans.append({"pos":p,"empty":false,"delivered":false,"bag_pos":p,"holder":"","disturbed":false})
	for p in [Vector2(70,100),Vector2(1030,100),Vector2(50,405),Vector2(1050,410),Vector2(50,735),Vector2(1050,745),Vector2(50,1050),Vector2(1045,1060)]:
		trees.append(p)
		obstacles.append(Rect2(p - Vector2(18,18),Vector2(36,36)))
	obstacles.append(BUILDING)
	obstacles.append(DUMPSTER)
	var leaf_rng := RandomNumberGenerator.new()
	leaf_rng.seed = 771
	for i in 210:
		var p: Vector2
		if i < 60: p = Vector2(leaf_rng.randf_range(135,965),leaf_rng.randf_range(1200,1220))
		elif i < 140: p = Vector2(leaf_rng.randf_range(90,1010),495 if i % 2 else 815) + Vector2(0,leaf_rng.randf_range(-42,42))
		else: p = Vector2(leaf_rng.randf_range(492,610),leaf_rng.randf_range(240,1120))
		leaves.append(p)
	for y in range(245,1150,CELL):
		for x in range(90,1020,CELL):
			var p := Vector2(x,y)
			if is_path(p) or collides(p,20): continue
			grass.append(p)
	navigation.region = Rect2i(0,0,44,57)
	navigation.cell_size = Vector2(25,25)
	navigation.offset = Vector2(12.5,12.5)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for y in 57:
		for x in 44:
			if collides(Vector2(x * 25 + 12.5,y * 25 + 12.5),14): navigation.set_point_solid(Vector2i(x,y))

func is_path(p: Vector2) -> bool:
	return absf(p.x - 551) < 58 or absf(p.y - 495) < 45 or absf(p.y - 815) < 45

func collides(p: Vector2, radius: float) -> bool:
	if p.x < 30 + radius or p.x > 1070 - radius or p.y < 30 + radius or p.y > 1390 - radius: return true
	for obstacle in obstacles:
		if obstacle.grow(radius).has_point(p): return true
	return false

func move_body(p: Vector2, displacement: Vector2, radius: float) -> Vector2:
	# Axis separation produces sliding and prevents high-speed tunnelling.
	var steps := maxi(1, int(ceil(displacement.length() / 7.0)))
	var step := displacement / steps
	for _i in steps:
		if not collides(p + Vector2(step.x,0),radius): p.x += step.x
		if not collides(p + Vector2(0,step.y),radius): p.y += step.y
	return p

func pursuit_direction(origin: Vector2, target: Vector2) -> Vector2:
	var a := Vector2i(clampi(int(origin.x / 25),0,43),clampi(int(origin.y / 25),0,56))
	var b := Vector2i(clampi(int(target.x / 25),0,43),clampi(int(target.y / 25),0,56))
	var path := navigation.get_point_path(a,b,true)
	if path.size() > 1: return origin.direction_to(path[1])
	return origin.direction_to(target)

func visible(a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1,int(a.distance_to(b) / 15))
	for i in range(1,steps):
		if collides(a.lerp(b,float(i) / steps),2): return false
	return true

func free_position(p: Vector2, body_radius: float = 14.0) -> Vector2:
	p = p.clamp(Vector2(48,48),SIZE - Vector2(48,48))
	if not collides(p,body_radius): return p
	for radius in range(20,301,20):
		for i in 16:
			var candidate := p + Vector2.from_angle(i * TAU / 16) * radius
			if not collides(candidate,body_radius): return candidate
	return Vector2(550,1150)
