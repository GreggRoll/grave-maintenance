extends SceneTree

func _initialize() -> void:
	var sim := Simulation.new({"a":{"name":"A"},"b":{"name":"B"}},[{"id":"cart","type":"utility_cart","owner":"a"}])
	var a: Dictionary = sim.state.players.a
	var b: Dictionary = sim.state.players.b
	a.pos = Vector2(654,1254)
	sim.interact(a)
	assert(a.equipment == "cart")
	b.pos = a.pos
	sim.interact(b)
	assert(b.equipment.is_empty()) # Server serializes contested pickups.
	for index in 4:
		a.pos = sim.state.cans[index].pos
		assert(TrashSystem.interact(sim.state,a,Catalog.tool("utility_cart")))
	EquipmentSystem.release(sim.state,a)
	assert(a.bags.is_empty())
	assert(sim.state.equipment.cart.cargo.size() == 4)
	b.pos = sim.state.equipment.cart.pos
	sim.interact(b)
	assert(b.bags.size() == 4)
	b.pos = Vector2(800,208)
	assert(TrashSystem.interact(sim.state,b,Catalog.tool("utility_cart")))
	assert(TaskSystem.progress(sim.state).trash == 0.5)
	sim.kill("b")
	assert(sim.state.equipment.cart.holder.is_empty())
	a.pos = sim.state.equipment.cart.pos
	sim.interact(a)
	a.pos = Vector2(705,1270)
	EquipmentSystem.release(sim.state,a)
	assert(sim.state.equipment.cart.returned)
	assert(sim.state.equipment.cart.owner == "a")
	# The supplied payout example is reproducible to the cent.
	sim.state.grass.resize(100)
	sim.state.grass.fill(0)
	for i in 82: sim.state.grass[i] = 1
	sim.state.leaves.resize(100)
	sim.state.leaves.fill(0)
	for i in 64: sim.state.leaves[i] = 100
	for i in 6: sim.state.cans[i].delivered = true
	for i in 9: sim.state.graves[i].clean = 100
	var payout := TaskSystem.payout(sim.state)
	assert(is_equal_approx(payout.gross,740.0))
	assert(is_equal_approx(payout.total,629.0))
	# Light contact never wakes a grave; a severe zero-turn crash can.
	var crash := Simulation.new({"a":{"name":"A"}},[])
	var p: Dictionary = crash.state.players.a
	p.pos = crash.state.graves[0].pos + Vector2(0,64)
	crash.mower_impact(p,Catalog.tool("push_mower"),12)
	assert(crash.state.monsters.is_empty())
	crash.mower_impact(p,Catalog.tool("zero_turn"),250)
	assert(crash.state.graves[0].awake)
	assert(crash.state.monsters[0].kind == "zombie")
	# No work or extraction succeeds after the exactly 300-second cutoff.
	var end := Simulation.new({"a":{"name":"A"}},[])
	end.state.players.a.pos = Vector2(470,1300)
	end.tick(0.01,{},299.9)
	assert(end.state.monsters.is_empty())
	end.tick(0.01,{"a":{"extract":true}},300.0)
	assert(end.state.witches)
	assert(not end.state.players.a.extracted)
	end.tick(0.01,{},312.0)
	assert(end.state.ended and end.state.results.total == 0)
	var waypoint := sim.map.free_position(Cemetery.BUILDING.get_center())
	assert(not sim.map.collides(waypoint,14))
	var selection := Simulation.new({"a":{"name":"A"}},[{"id":"m","type":"push_mower","owner":"a"},{"id":"r","type":"rake","owner":"a"}])
	selection.state.players.a.pos = Vector2(689,1260)
	assert(EquipmentSystem.nearest(selection.state,selection.state.players.a,Vector2(654,1254)) == "m")
	selection.interact(selection.state.players.a,Vector2(654,1254))
	assert(selection.state.players.a.equipment == "m")
	print("REGRESSIONS PASS: pickup races, cart cargo, teammate recovery, $629 example, safe contact, 300-second cutoff")
	quit()
