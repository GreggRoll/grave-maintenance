class_name InputController
extends Node

var renderer: CemeteryRenderer
var held := false
var clicked := false
var dropped := false
var extract := false
var touch_enabled := false
var stick_id := -1
var use_id := -1
var stick_origin := Vector2.ZERO
var stick_current := Vector2.ZERO
var touch_move := Vector2.ZERO
var touch_face := Vector2.UP
var touch_target := Vector2(INF,INF)
var using_touch := false
var blocked := false
var safe_bottom_css := 0.0
var safe_top_css := 0.0
var css_width := 0.0
var use_text := "Take"
var drop_text := "Drop"
var mouse_touch := false

func aim_point() -> Vector2:
	if using_touch and Session.state.has("players") and Session.state.players.has(Session.local_id):
		if touch_target.is_finite(): return touch_target
		return Session.state.players[Session.local_id].pos + touch_face * 28
	return renderer.screen_to_world(renderer.get_global_mouse_position())

func touch_layout() -> Dictionary:
	var size := get_viewport().get_visible_rect().size
	var bottom := maxf(30,safe_bottom_css * safe_scale())
	return {"stick":Vector2(140,size.y - bottom - 130),"radius":100.0,
		"use":Rect2(size.x - 240,size.y - bottom - 126,210,100),
		"drop":Rect2(size.x - 240,size.y - bottom - 240,210,90)}

func safe_scale() -> float:
	return get_viewport().get_visible_rect().size.x / maxf(1,css_width if css_width > 0 else get_window().size.x)

func refresh_safe_area() -> void:
	if OS.has_feature("web"):
		css_width = float(JavaScriptBridge.eval("window.innerWidth"))
		safe_bottom_css = float(JavaScriptBridge.eval("parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--safe-bottom')) || 0"))
		safe_top_css = float(JavaScriptBridge.eval("parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--safe-top')) || 0"))

func _ready() -> void:
	touch_enabled = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		touch_enabled = bool(JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches || new URLSearchParams(location.search).get('touch') === '1'"))
	refresh_safe_area()
	get_viewport().size_changed.connect(refresh_safe_area)
	using_touch = touch_enabled

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: reset()

func _input(event: InputEvent) -> void:
	# Mouse support makes the phone layout usable on hybrid devices and in previews.
	if touch_enabled and Session.screen == "match" and not blocked and event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		var layout := touch_layout()
		var over_controls: bool = layout.use.has_point(event.position) or layout.drop.has_point(event.position) or event.position.distance_to(layout.stick) < layout.radius * 1.6
		if (event.pressed and over_controls) or (not event.pressed and mouse_touch):
			mouse_touch = event.pressed
			var finger := InputEventScreenTouch.new()
			finger.index = 999
			finger.position = event.position
			finger.pressed = event.pressed
			_input(finger)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and mouse_touch and stick_id == 999:
		var drag := InputEventScreenDrag.new()
		drag.index = 999
		drag.position = event.position
		_input(drag)
		get_viewport().set_input_as_handled()
		return
	# Releases must arrive even when another finger is over a GUI control.
	if event is InputEventScreenTouch and not event.pressed:
		if event.index == stick_id:
			stick_id = -1
			touch_move = Vector2.ZERO
		if event.index == use_id:
			use_id = -1
			held = false
	if Session.screen != "match" or blocked or not touch_enabled: return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		using_touch = true
		var layout := touch_layout()
		if event is InputEventScreenTouch and event.pressed:
			if layout.use.has_point(event.position):
				if use_id < 0: use_id = event.index; held = true; clicked = true
				get_viewport().set_input_as_handled()
			elif layout.drop.has_point(event.position):
				dropped = true
				held = false
				use_id = -1
				get_viewport().set_input_as_handled()
			elif event.position.distance_to(layout.stick) < layout.radius * 1.6 and stick_id < 0:
				stick_id = event.index
				stick_origin = layout.stick
				update_stick(event.position)
				get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag and event.index == stick_id:
			update_stick(event.position)
			get_viewport().set_input_as_handled()

func update_stick(position: Vector2) -> void:
	stick_current = position
	var offset := position - stick_origin
	var distance := offset.length()
	touch_move = Vector2.ZERO if distance < 12 else offset.normalized() * minf(1,(distance - 12) / 68.0)
	if touch_move.length() > 0.05:
		touch_face = touch_move.normalized()
		touch_target = Vector2(INF,INF)

func _unhandled_input(event: InputEvent) -> void:
	if Session.screen != "match" or blocked: return
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
	if event is InputEventScreenTouch and event.pressed and touch_enabled:
		using_touch = true
		if Session.state.players.has(Session.local_id):
			var p: Dictionary = Session.state.players[Session.local_id]
			touch_target = renderer.screen_to_world(event.position)
			touch_face = p.pos.direction_to(touch_target)
			if p.pos.distance_to(touch_target) < 120: clicked = true

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
	if blocked:
		result.move = Vector2.ZERO
		result.use = false
		result.click = false
		result.drop = false
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
	use_id = -1
	touch_move = Vector2.ZERO
	touch_target = Vector2(INF,INF)
	blocked = false
	mouse_touch = false
