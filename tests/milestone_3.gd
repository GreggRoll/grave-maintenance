extends SceneTree

func _initialize() -> void:
	var sim := Simulation.new({"solo":{"name":"Test"}},[])
	var p: Dictionary = sim.state.players.solo
	p.pos = sim.state.cans[0].pos + Vector2(0,30)
	assert(TrashSystem.interact(sim.state,p,{}))
	assert(p.bags.size() == 1)
	p.pos = sim.state.cans[1].pos
	assert(not TrashSystem.interact(sim.state,p,{}))
	assert(TrashSystem.interact(sim.state,p,Catalog.tool("wagon")))
	assert(p.bags.size() == 2)
	TrashSystem.bump(sim.state,p,0.01)
	assert(sim.state.monsters.is_empty())
	TrashSystem.bump(sim.state,p,1.0)
	assert(sim.state.monsters[0].kind == "werewolf")
	p.pos = Vector2(800,205)
	assert(TrashSystem.interact(sim.state,p,Catalog.tool("wagon")))
	assert(p.bags.is_empty())
	assert(TaskSystem.progress(sim.state).trash == 0.25)
	assert(TrashSystem.capacity(Catalog.tool("utility_cart")) == 4)
	print("MILESTONE 3 PASS: eight bags, capacities, safe contact, werewolf, dumpster delivery")
	quit()
