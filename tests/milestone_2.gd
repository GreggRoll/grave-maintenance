extends SceneTree

func _initialize() -> void:
	var sim := Simulation.new({"solo":{"name":"Test"}},[])
	var p: Dictionary = sim.state.players.solo
	p.pos = sim.map.leaves[0]
	p.facing = Vector2.ZERO
	TaskSystem.clear_leaves(sim.state,sim.map,p,Catalog.tool("rake"),1)
	assert(TaskSystem.progress(sim.state).leaves > 0)
	assert(sim.state.monsters.is_empty())
	for _i in 100: TaskSystem.clear_leaves(sim.state,sim.map,p,Catalog.tool("backpack_blower"),0.1)
	assert(sim.state.monsters.size() == 1)
	assert(sim.state.monsters[0].kind == "ghost")
	var sound: float = p.sound
	sim.tick(1,{})
	assert(p.sound < sound)
	print("MILESTONE 2 PASS: visible leaf work, quiet rake, danger dwell, ghost, sound decay")
	quit()
