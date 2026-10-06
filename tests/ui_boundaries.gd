extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func find_button(node: Node, value: String) -> Button:
	if node is Button and node.text == value: return node
	for child in node.get_children():
		var found := find_button(child,value)
		if found != null: return found
	return null

func has_label(node: Node, value: String) -> bool:
	if node is Label and node.text == value: return true
	for child in node.get_children():
		if has_label(child,value): return true
	return false

func run_checks() -> void:
	# Mistakes on the road still wake a threat, but cannot make the trailer unsafe.
	for kind in ["zombie","ghost","werewolf","vampire"]:
		var sim := Simulation.new({"one":{"name":"Test"}},[])
		var p: Dictionary = sim.state.players.one
		p.pos = Vector2(551,1185)
		MonsterSystem.spawn(sim.state,kind,Vector2(550,1200),"test")
		for i in 600: MonsterSystem.tick(sim.state,sim.map,0.05,sim.kill)
		assert(p.alive)
		assert(Cemetery.GROUNDS.grow(-12).has_point(sim.state.monsters[0].pos))
		# Chasing a player into the gate cannot bypass the boundary, even during a dash.
		p.pos = Vector2(551,1130)
		MonsterSystem.tick(sim.state,sim.map,0.1,func(_id): pass)
		p.pos = Vector2(551,1300)
		for i in 50: MonsterSystem.tick(sim.state,sim.map,0.1,sim.kill)
		assert(p.alive and Cemetery.GROUNDS.has_point(sim.state.monsters[0].pos))
	var witch := Simulation.new({"one":{"name":"Test"}},[])
	witch.state.players.one.pos = Vector2(551,1300)
	MonsterSystem.spawn(witch.state,"witch",Vector2(551,1120),"test")
	for i in 60: MonsterSystem.tick(witch.state,witch.map,0.05,witch.kill)
	assert(not witch.state.players.one.alive)
	# Real UI flow: identity/browser first; ownership and trailer become separate steps.
	var session: Node = root.get_node("Session")
	session.save_path = "user://ui_boundary_test.json"
	session.profile = ProfileStore.new_profile()
	session.reset_offers()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.lobby_model.attempted_connection = true
	assert(main.ui.find_child("PlayerName",true,false) != null)
	assert(find_button(main.ui,"Host a game") != null)
	assert(main.ui.find_child("Tab_shop",true,false) == null)
	await create_timer(.2).timeout
	var field: LineEdit = main.ui.find_child("PlayerName",true,false)
	field.grab_focus()
	field.text = "Test Employee"
	field.text_changed.emit(field.text)
	var point := find_button(main.ui,"Host a game").get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await create_timer(.1).timeout
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click,true)
	await create_timer(.1).timeout
	click.pressed = false
	root.push_input(click,true)
	await create_timer(.1).timeout
	assert(session.profile.name == "Test Employee" and main.lobby_model.home_mode == "host")
	find_button(main.ui,"Play solo").pressed.emit()
	assert(main.ui.find_child("Tab_trailer",true,false) != null)
	session.room = {"code":"ABCDEF","host":"friend","locked":false,"members":{"friend":{"name":"Alex","equipment":["Zero-Turn Mower"],"ready":false,"value":500}}}
	main.rebuild()
	assert(has_label(main.ui,"Packed by Alex · Replacement $500"))
	session.room = {}
	main.rebuild()
	assert(find_button(main.ui,"Start shift").disabled)
	main.ui.find_child("Tab_shop",true,false).pressed.emit()
	find_button(main.ui,"Buy · $100").pressed.emit()
	assert(session.profile.cash == 50)
	assert(main.lobby_model.tab == "inventory")
	assert(session.offered.size() == 3) # Buying does not silently risk new equipment.
	find_button(main.ui,"Pack").pressed.emit()
	assert(session.offered.size() == 4)
	find_button(main.ui,"I'm ready").pressed.emit()
	assert(not find_button(main.ui,"Start shift").disabled)
	main.queue_free()
	await create_timer(.2).timeout
	DirAccess.remove_absolute("user://ui_boundary_test.json")
	print("UI / BOUNDARY PASS: browser-first flow, separate shop/ownership/loadout, explicit packing, safe street, witch exception")
	quit()
