extends SceneTree

func _initialize() -> void:
	var profile := ProfileStore.new_profile()
	var other := ProfileStore.new_profile()
	assert(profile.owned.size() == 3)
	assert(ProfileStore.buy(profile,"gas_mower"))
	assert(profile.cash == 50)
	assert(not ProfileStore.buy(profile,"zero_turn"))
	var item: Dictionary = profile.owned[3]
	var recovered: Dictionary = other.owned[0]
	var sim := Simulation.new({"a":{"name":"A"},"b":{"name":"B"}},[item,recovered])
	ProfileStore.reserve(profile,"test",[item,recovered])
	ProfileStore.reserve(other,"test",[item,recovered])
	assert(profile.owned.size() == 3)
	sim.state.equipment[item.id].returned = false
	assert(ProfileStore.settle(profile,"test",sim.state,123.45))
	assert(is_equal_approx(profile.cash,173.45))
	assert(profile.owned.size() == 3)
	assert(ProfileStore.settle(other,"test",sim.state,123.45))
	assert(other.owned.size() == 3)
	assert(not ProfileStore.settle(profile,"test",sim.state,123.45))
	ProfileStore.reserve(profile,"interrupted",[])
	ProfileStore.reserve(profile,"next",[])
	assert(ProfileStore.pending_ids(profile).size() == 2)
	assert(ProfileStore.settle(profile,"interrupted",sim.state,0.0))
	assert(ProfileStore.pending_ids(profile) == ["next"])
	assert(ProfileStore.settle(profile,"next",sim.state,0.0))
	assert(profile.pending.is_empty())
	ProfileStore.save_profile(profile,"user://test_profile.json")
	assert(is_equal_approx(ProfileStore.load_profile("user://test_profile.json").cash,173.45))
	DirAccess.remove_absolute("user://test_profile.json")
	print("MILESTONE 5 PASS: prices, buying, reservation, owner recovery, losses, idempotent saved settlement")
	quit()
