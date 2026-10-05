class_name InputController
extends Node

var renderer: CemeteryRenderer
var held := false
var clicked := false
var dropped := false
var extract := false
var touch_enabled := false
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_current := Vector2.ZERO
var touch_move := Vector2.ZERO
var touch_face := Vector2.UP
var using_touch := false

func aim_point() -> Vector2:
	if using_touch and Session.state.has("players") and Session.state.players.has(Session.local_id):
		return Session.state.players[Session.local_id].pos + touch_face * 28
	return renderer.screen_to_world(renderer.get_global_mouse_position())

func _ready() -> void:
	touch_enabled = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		touch_enabled = bool(JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches || new URLSearchParams(location.search).get('touch') === '1'"))
	using_touch = touch_enabled

func _unhandled_input(event: InputEvent) -> void:
	if Session.screen != "match": return
	if event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION and touch_enabled: return
		using_touch = false
		if event.button_index == MOUSE_BUTTON_LEFT:
			held = event.pressed
			if event.pressed: clicked = true
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			dropped = true
			held = false
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION: using_touch = false
	if event is InputEventScreenTouch:
		using_touch = true
		if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x * 0.48 and stick_id == -1:
			stick_id = event.index
			stick_origin = event.position
			stick_current = event.position
		elif not event.pressed and event.index == stick_id:
			stick_id = -1
			touch_move = Vector2.ZERO
	if event is InputEventScreenDrag and event.index == stick_id:
		stick_current = event.position
		touch_move = (stick_current - stick_origin) / 65.0
		touch_move = touch_move.limit_length(1)
		if touch_move.length() > 0.05: touch_face = touch_move.normalized()

func packet() -> Dictionary:
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): move.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): move.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): move.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): move.x += 1
	if touch_enabled and touch_move.length() > 0: move = touch_move
	var face := touch_face
	var target := aim_point()
	if not using_touch and Session.state.has("players") and Session.state.players.has(Session.local_id):
		face = Session.state.players[Session.local_id].pos.direction_to(target)
	var result := {"move":move.limit_length(1),"face":face,"target":target,"use":held,"click":clicked,"drop":dropped,"extract":extract}
	clicked = false
	dropped = false
	extract = false
	return result

func reset() -> void:
	held = false
	clicked = false
	dropped = false
	extract = false
	stick_id = -1
	touch_move = Vector2.ZERO
