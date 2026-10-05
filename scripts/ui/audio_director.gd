class_name AudioDirector
extends Node

var cue := AudioStreamPlayer.new()
var work := AudioStreamPlayer.new()
var sounds := {}
var last_screen := ""
var last_monsters := 0
var last_alive := true
var warning_level := 0
var repeat_timer := 0.0
var last_clean := -1.0

func _ready() -> void:
	add_child(cue)
	add_child(work)
	for name in ["shift","warning","danger","death","work","spray"]:
		sounds[name] = load("res://assets/audio/%s.wav" % name)
	cue.volume_db = -8
	work.volume_db = -17

func play(name: String) -> void:
	cue.stream = sounds[name]
	cue.play()

func _process(dt: float) -> void:
	if Session.screen != "match":
		work.stop()
		last_screen = Session.screen
		return
	var s: Dictionary = Session.state
	if s.is_empty() or not s.players.has(Session.local_id): return
	var p: Dictionary = s.players[Session.local_id]
	if last_screen != "match":
		last_monsters = 0
		last_alive = true
		warning_level = 0
		last_clean = -1
		play("shift")
	last_screen = "match"
	if s.monsters.size() > last_monsters: play("danger")
	last_monsters = s.monsters.size()
	if last_alive and not p.alive: play("death")
	last_alive = p.alive
	var level := 0
	for threshold in Catalog.contract.warning_times:
		if s.elapsed >= threshold: level += 1
	if s.witches: level = 4
	if level > warning_level:
		play("warning" if level < 3 else "danger")
		warning_level = level
		if level >= 3 and OS.has_feature("web"): JavaScriptBridge.eval("if(navigator.vibrate)navigator.vibrate([120,70,120])")
	repeat_timer -= dt
	if p.alive and not p.extracted and not p.equipment.is_empty():
		var tool := Catalog.tool(s.equipment[p.equipment].type)
		if (tool.category == "mowing" and p.velocity.length() > 4) or (tool.category == "leaves" and p.using):
			if repeat_timer <= 0:
				work.stream = sounds.work
				work.play()
				repeat_timer = 0.42
		if tool.category == "graves" and p.clean_target >= 0:
			var amount: float = s.graves[p.clean_target].clean
			if last_clean >= 0 and amount > last_clean and repeat_timer <= 0:
				work.stream = sounds.spray
				work.play()
				repeat_timer = 0.15
			last_clean = amount
