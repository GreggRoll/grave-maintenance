extends SceneTree

func _initialize() -> void:
	var sim := Simulation.new({"solo":{"name":"Test"}},[])
	var p: Dictionary = sim.state.players.solo
	p.pos = sim.state.graves[0].pos + Vector2(0,65)
	p.facing = Vector2.UP
	for _i in 10:
		p.cooldown = 0
		CleaningSystem.clean(sim.state,p,Catalog.tool("spray"),0.1,true,true)
	assert(sim.state.graves[0].clean == 100)
	assert(sim.state.monsters.is_empty())
	assert(is_equal_approx(TaskSystem.progress(sim.state).graves,1.0 / 12.0))
	CleaningSystem.clean(sim.state,p,Catalog.tool("hose"),0.1,false,true)
	assert(sim.state.monsters.is_empty())
	for _i in 10: CleaningSystem.clean(sim.state,p,Catalog.tool("pressure_washer"),0.1,false,true)
	assert(sim.state.monsters[0].kind == "vampire")
	print("MILESTONE 4 PASS: precise sprays, ideal stop, safe overshoot, vampire consequence")
	quit()
