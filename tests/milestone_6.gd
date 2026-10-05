extends SceneTree

func _initialize() -> void:
	var service := LobbyService.new()
	var profiles: Array = []
	for _i in 5: profiles.append(ProfileStore.new_profile())
	service.request(2,"create",{"profile":profiles[0],"locked":true,"password":"moon"})
	var code: String = service.memberships["2"]
	assert(service.directory().is_empty())
	assert(not service.public_room(service.rooms[code]).has("password_hash"))
	service.request(3,"join",{"profile":profiles[1],"code":code,"password":"wrong"})
	assert(not service.memberships.has("3"))
	for i in range(1,4): service.request(i + 2,"join",{"profile":profiles[i],"code":code,"password":"moon"})
	service.request(6,"join",{"profile":profiles[4],"code":code,"password":"moon"})
	assert(not service.memberships.has("6"))
	service.request(2,"start",{})
	assert(service.rooms[code].phase == "lobby")
	for peer in range(2,6): service.request(peer,"ready",{"ready":true})
	service.request(3,"start",{})
	assert(service.rooms[code].phase == "lobby")
	service.request(2,"start",{})
	var room: Dictionary = service.rooms[code]
	assert(room.phase == "match")
	assert(room.simulation.state.players.size() == 4)
	assert(room.simulation.state.equipment.size() == 12)
	service.input(2,{"move":Vector2(999,0),"face":Vector2.UP})
	assert(room.inputs["2"].move.length() <= 1)
	service.input(2,{"move":Vector2(INF,0),"face":Vector2.UP})
	assert(room.inputs["2"].move.is_finite())
	var sim: Simulation = room.simulation
	sim.state.grass.fill(1)
	for p in sim.state.players.values():
		p.pos = Vector2(470,1300)
		p.extracted = true
	sim.finish()
	service.settle(room)
	assert(sim.state.results.total == 250)
	var sum := 0.0
	for share in sim.state.results.shares.values(): sum += share
	assert(is_equal_approx(sum,250.0))
	assert(is_equal_approx(room.members["2"].profile.cash,212.5))
	service.request(2,"return",{})
	assert(room.phase == "lobby")
	assert(not room.members["2"].ready)
	print("MILESTONE 6 PASS: passwords, private listing, four-player cap, host readiness, loadout, authority, split payout, replay")
	quit()
