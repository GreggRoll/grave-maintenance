extends SceneTree

var session: Node
var host := false
var joined := false
var readied := false
var started := false
var frames_seen := 0
var began := Time.get_ticks_msec()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	session = root.get_node("Session")
	host = "--host-test" in OS.get_cmdline_user_args()
	session.profile = ProfileStore.new_profile()
	session.reset_offers()
	var url := "ws://127.0.0.1:9080"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-server="): url = arg.trim_prefix("--test-server=")
	session.connect_online(url)

func _process(_dt: float) -> bool:
	if session == null: return false
	if Time.get_ticks_msec() - began > 20000:
		push_error("NETWORK TEST TIMEOUT: screen=%s connected=%s room=%s ready=%s started=%s error=%s" % [session.screen,session.connected,session.room,readied,started,session.error])
		quit(1)
		return false
	if session.connected and not joined:
		if host:
			session.create_room(false,"")
			joined = true
		elif FileAccess.file_exists("/tmp/grave_network_room.txt"):
			var code := FileAccess.get_file_as_string("/tmp/grave_network_room.txt").strip_edges()
			if code.length() == 6:
				session.join_room(code)
				joined = true
	if not session.room.is_empty() and not readied:
		if host:
			var file := FileAccess.open("/tmp/grave_network_room.tmp",FileAccess.WRITE)
			file.store_string(session.room.code)
			file.close()
			DirAccess.rename_absolute("/tmp/grave_network_room.tmp","/tmp/grave_network_room.txt")
		session.set_ready(true)
		readied = true
	if host and not started and not session.room.is_empty() and session.room.members.size() == 4:
		var all_ready := true
		for m in session.room.members.values():
			if not m.ready: all_ready = false
		if all_ready:
			session.start_match()
			started = true
	if session.screen == "match":
		frames_seen += 1
		assert(session.state.players.size() == 4)
		var p: Dictionary = session.state.players[session.local_id]
		var move := Vector2.LEFT if p.pos.x > 520 else Vector2.ZERO
		session.submit_input({"move":move,"face":Vector2.UP,"extract":p.pos.x <= 520 and frames_seen > 30})
	if session.screen == "results":
		assert(frames_seen > 30)
		assert(session.state.results.deaths == 0)
		assert(session.profile.pending.is_empty())
		print("NETWORK CLIENT PASS: four-player room, synchronized movement, extraction, settlement; id=" + session.local_id)
		quit()
	return false
