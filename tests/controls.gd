extends SceneTree

func _initialize() -> void:
	call_deferred("run_controls")

func frames(count: int) -> void:
	await create_timer(float(count) / 60.0).timeout

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func mouse(main: Node, which: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = pressed
	event.position = main.renderer.world_to_screen(main.get_node("/root/Session").state.players.solo.pos)
	root.push_input(event,true)

func run_controls() -> void:
	var session: Node = root.get_node("Session")
	session.save_path = "user://controls_test.json"
	session.profile = ProfileStore.new_profile()
	session.reset_offers()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	session.start_solo()
	main.input.touch_enabled = false
	await frames(3)
	var p: Dictionary = session.state.players.solo
	p.pos = Vector2(551,1110)
	key(KEY_W,true)
	await frames(30)
	key(KEY_W,false)
	assert(p.pos.y < 1090)
	await frames(12)
	p.pos = Vector2(654,1254)
	await frames(3)
	mouse(main,MOUSE_BUTTON_LEFT,true)
	await frames(3)
	mouse(main,MOUSE_BUTTON_LEFT,false)
	assert(not p.equipment.is_empty())
	assert(session.state.equipment[p.equipment].type == "push_mower")
	key(KEY_W,true)
	await frames(105)
	key(KEY_W,false)
	await frames(12)
	assert(TaskSystem.progress(session.state).mowing > 0)
	key(KEY_S,true)
	await frames(105)
	key(KEY_S,false)
	await frames(12)
	mouse(main,MOUSE_BUTTON_RIGHT,true)
	await frames(3)
	mouse(main,MOUSE_BUTTON_RIGHT,false)
	assert(p.equipment.is_empty())
	assert(EquipmentSystem.lost_count(session.state) == 0)
	# Touch drag direction and release go through the real controller.
	main.input.touch_enabled = true
	var layout: Dictionary = main.input.touch_layout()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = layout.stick
	touch.pressed = true
	root.push_input(touch,true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = layout.stick + Vector2(90,0)
	root.push_input(drag,true)
	assert(main.input.packet().move == Vector2.RIGHT)
	var use := InputEventScreenTouch.new()
	use.index = 1
	use.position = layout.use.get_center()
	use.pressed = true
	root.push_input(use,true)
	var simultaneous: Dictionary = main.input.packet()
	assert(simultaneous.move == Vector2.RIGHT and simultaneous.use and simultaneous.click)
	# Releasing movement must stop it while the other finger keeps using the tool.
	touch.pressed = false
	root.push_input(touch,true)
	var stopped: Dictionary = main.input.packet()
	assert(stopped.move == Vector2.ZERO and stopped.use)
	use.pressed = false
	root.push_input(use,true)
	assert(not main.input.packet().use)
	# A lost browser focus cannot leave movement or the trigger stuck on.
	root.push_input(touch,true)
	main.input._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(main.input.packet().move == Vector2.ZERO and not main.input.held)
	main.input.touch_enabled = false
	p.pos = Vector2(470,1300)
	main.extract_button.pressed.emit()
	await frames(5)
	assert(session.screen == "results")
	assert(session.profile.owned.size() == 3)
	assert(session.profile.cash > 150)
	assert(not is_instance_valid(main.clock_label))
	main.queue_free()
	await frames(12)
	DirAccess.remove_absolute("user://controls_test.json")
	print("CONTROLS PASS: physical WASD, mouse pickup, mowing, return, touch drag/release, GUI extraction and saved payout")
	quit()
