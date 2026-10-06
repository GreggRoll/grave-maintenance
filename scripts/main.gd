extends Node

var renderer: CemeteryRenderer
var input: InputController
var ui: Control
var clock_label: Label
var task_label: Label
var context_label: Label
var notice_label: Label
var extract_button: Button
var modal: Control
var rebuilding := false
var last_screen := ""
var lobby_model := {"preparing":false,"tab":"trailer","category":"mowing","home_mode":"","locked":false,"password":"","code":"","advanced":false,"attempted_connection":false,"message":"","name_draft":"","show_crew":false}

func _ready() -> void:
	if Session.dedicated: return
	renderer = CemeteryRenderer.new()
	add_child(renderer)
	input = InputController.new()
	input.renderer = renderer
	renderer.input = input
	add_child(input)
	add_child(AudioDirector.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ui.theme = make_theme()
	lobby_model.name_draft = Session.profile.name
	Session.changed.connect(rebuild)
	get_viewport().size_changed.connect(resize_layout)
	resize_layout()
	rebuild()

func resize_layout() -> void:
	var window := get_window()
	var desired := Vector2i(720,1100) if window.size.x < window.size.y else Vector2i(1440,900)
	if input != null and input.touch_enabled and window.size.x >= window.size.y: desired = Vector2i(1280,720)
	if window.content_scale_size != desired: window.content_scale_size = desired
	if not last_screen.is_empty(): call_deferred("rebuild")

func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 19
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("24393c")
	normal.border_color = Color("5b756e")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	normal.content_margin_left = 19
	normal.content_margin_right = 19
	normal.content_margin_top = 13
	normal.content_margin_bottom = 13
	var hover := normal.duplicate()
	hover.bg_color = Color("3b534d")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("5b6750")
	for type in ["Button","LineEdit","OptionButton"]:
		theme.set_stylebox("normal",type,normal)
		theme.set_stylebox("hover",type,hover)
		theme.set_stylebox("pressed",type,pressed)
		theme.set_color("font_color",type,Color("e9e6d0"))
	var panel := normal.duplicate()
	panel.bg_color = Color("10272d")
	panel.content_margin_left = 26
	panel.content_margin_right = 26
	panel.content_margin_top = 24
	panel.content_margin_bottom = 24
	theme.set_stylebox("panel","PanelContainer",panel)
	theme.set_color("font_color","Label",Color("e0e4ce"))
	return theme

func label(parent: Node, text: String, size: int = 19, color: Color = Color("e0e4ce")) -> Label:
	var node := Label.new()
	node.text = text
	if (input.touch_enabled or get_viewport().get_visible_rect().size.x < 1000) and size < 32: size = roundi(size * 1.3)
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	if text.length() > 40: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func button(parent: Node, text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	if input.touch_enabled or get_viewport().get_visible_rect().size.x < 1000:
		node.custom_minimum_size.y = 84
		node.add_theme_font_size_override("font_size",24)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func rebuild() -> void:
	if rebuilding: return
	rebuilding = true
	input.reset()
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	modal = null
	last_screen = Session.screen
	if Session.screen == "match": build_hud()
	elif Session.screen == "results": build_results()
	else: build_lobby()
	rebuilding = false

func centered_panel(width: float = 680) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + edge,24)
	if input.touch_enabled:
		margin.add_theme_constant_override("margin_top",maxi(24,roundi(input.safe_top_css * input.safe_scale())))
		margin.add_theme_constant_override("margin_bottom",maxi(24,roundi(input.safe_bottom_css * input.safe_scale())))
	ui.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(width,get_viewport().get_visible_rect().size.x - 48)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",18)
	panel.add_child(box)
	return box

func build_lobby() -> void:
	LobbyScreen.new().build(ui,self,lobby_model)
	if not lobby_model.attempted_connection and Session.room.is_empty():
		lobby_model.attempted_connection = true
		call_deferred("connect_browser")

func connect_browser() -> void:
	if Session.screen == "lobby" and not lobby_model.preparing: Session.connect_online(Session.server_url)

func build_hud() -> void:
	var brand := label(ui,"GM / NIGHT CREW" if get_viewport().get_visible_rect().size.x < 1000 else "GM  /  BRIAR HOLLOW",20,Color("d4ba87"))
	brand.position = Vector2(28,24)
	clock_label = label(ui,"10:00 PM",40)
	clock_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	clock_label.offset_left = -150
	clock_label.offset_right = 150
	clock_label.offset_top = 20
	clock_label.offset_bottom = 75
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	task_label = label(ui,"",21)
	task_label.position = Vector2(28,73)
	notice_label = label(ui,"",20,Color("e5ae68"))
	notice_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	notice_label.offset_left = 28
	notice_label.offset_right = -28
	notice_label.offset_top = -116
	notice_label.offset_bottom = -68
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_label = label(ui,"",19)
	context_label.position = Vector2(28,230)
	context_label.size.x = 370
	context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extract_button = button(ui,"EXTRACT  >",request_extract)
	extract_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	extract_button.offset_left = -250
	extract_button.offset_right = -28
	extract_button.offset_top = -90
	extract_button.offset_bottom = -28
	var help := label(ui,"WASD  MOVE     LMB  USE / TAKE     RMB  DROP / RETURN",15,Color("a7b8ac"))
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 28
	help.offset_top = -37
	help.size.x = 365 if input.touch_enabled else 800
	if input.touch_enabled:
		brand.visible = false
		help.visible = false
		var top := maxf(20,input.safe_top_css * input.safe_scale())
		clock_label.offset_top = top + 6
		clock_label.offset_bottom = top + 65
		task_label.position = Vector2(32,top + 78)
		task_label.size.x = get_viewport().get_visible_rect().size.x - 64
		task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		context_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		context_label.offset_left = 28
		context_label.offset_right = -28
		context_label.offset_top = -360
		context_label.offset_bottom = -290
		context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notice_label.offset_top = -440
		notice_label.offset_bottom = -370
		extract_button.offset_top = -530
		extract_button.offset_bottom = -446
		extract_button.offset_left = -275
		if get_viewport().get_visible_rect().size.y < 800:
			context_label.offset_left = 330
			context_label.offset_right = -270
			context_label.offset_top = -126
			context_label.offset_bottom = -30
			notice_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
			notice_label.offset_top = top + 170
			notice_label.offset_bottom = top + 240
			extract_button.offset_top = -380
			extract_button.offset_bottom = -296
		var controls := TouchControls.new()
		controls.controller = input
		ui.add_child(controls)

func _process(_dt: float) -> void:
	if Session.screen != "match": return
	var s: Dictionary = Session.state
	if s.is_empty() or not s.players.has(Session.local_id): return
	var p: Dictionary = s.players[Session.local_id]
	input.blocked = modal != null or not p.alive or p.extracted
	var packet := input.packet()
	if modal != null:
		packet.move = Vector2.ZERO
		packet.use = false
		packet.click = false
		packet.drop = false
	elif packet.click and p.equipment.is_empty() and p.bags.is_empty() and Cemetery.EXTRACTION.grow(40).has_point(p.pos) and EquipmentSystem.nearest(s,p,input.aim_point()).is_empty():
		packet.click = false
		request_extract()
	Session.submit_input(packet)
	clock_label.text = Catalog.clock(s.elapsed)
	var progress := TaskSystem.progress(s)
	task_label.text = "MOWING   %3d%%\nLEAVES    %3d%%\nTRASH       %d / 8\nGRAVES     %d / 12" % [roundi(progress.mowing * 100),roundi(progress.leaves * 100),roundi(progress.trash * 8),roundi(progress.graves * 12)]
	if input.touch_enabled:
		task_label.text = "Mow %d%%    Leaves %d%%\nTrash %d/8    Graves %d/12" % [roundi(progress.mowing * 100),roundi(progress.leaves * 100),roundi(progress.trash * 8),roundi(progress.graves * 12)]
	context_label.text = "ON FOOT"
	if not p.equipment.is_empty():
		context_label.text = Catalog.tool(s.equipment[p.equipment].type).name + "\nRight click to disengage / return"
		if Catalog.tool(s.equipment[p.equipment].type).category == "leaves":
			context_label.text += "\nHOLD LEFT CLICK TO CLEAR\nQUIET [%s%s] LOUD  %d%%" % ["|".repeat(int(p.sound / 10)),".".repeat(10 - int(p.sound / 10)),roundi(p.sound)]
			if p.sound >= 85: context_label.text += "\nDANGER! Pause to quiet down."
		if Catalog.tool(s.equipment[p.equipment].type).category == "graves":
			context_label.text += "\nCLICK TO SPRAY" if Catalog.tool(s.equipment[p.equipment].type).tier == 1 else "\nHOLD TO WASH"
			context_label.text += "\nSTOP AT 95–105%"
		if Catalog.tool(s.equipment[p.equipment].type).category == "trash":
			context_label.text += "\nBAGS %d / %d\nLeft click to collect / deliver" % [p.bags.size(),TrashSystem.capacity(Catalog.tool(s.equipment[p.equipment].type))]
	elif not p.alive: context_label.text = "YOU DIED\nWatching the remaining crew."
	elif p.extracted: context_label.text = "SAFELY IN THE TRUCK\nWaiting for the remaining crew."
	else:
		if not p.bags.is_empty(): context_label.text = "CARRYING %d BAG(S)\nLeft click by dumpster to deliver\nRight click to drop a bag" % p.bags.size()
		var id := EquipmentSystem.nearest(s,p,input.aim_point())
		if not id.is_empty(): context_label.text = "LEFT CLICK  ·  " + Catalog.tool(s.equipment[id].type).name
		elif Cemetery.EXTRACTION.grow(40).has_point(p.pos): context_label.text = "LEFT CLICK  ·  EXTRACT AT TRUCK"
		else:
			for can in s.cans:
				if not can.delivered and can.holder.is_empty() and p.pos.distance_to(can.bag_pos) < 63:
					context_label.text = "LEFT CLICK  ·  TAKE TRASH BAG"
					break
	if not p.bags.is_empty() and Cemetery.DUMPSTER.grow(65).has_point(p.pos): context_label.text = "LEFT CLICK  ·  DELIVER BAGS"
	if input.touch_enabled:
		context_label.text = context_label.text.replace("LEFT CLICK","USE").replace("Left click","Use").replace("Right click","Drop / Return").replace("right click","Drop / Return").replace("CLICK TO SPRAY","TAP USE TO SPRAY").replace("HOLD TO WASH","HOLD USE TO WASH")
	if input.touch_enabled:
		input.use_text = "Take"
		input.drop_text = "Drop"
		if not p.equipment.is_empty():
			var tool := Catalog.tool(s.equipment[p.equipment].type)
			input.use_text = "Move to mow" if tool.category == "mowing" else "Hold to clear" if tool.category == "leaves" else "Tap to spray" if tool.tier == 1 and tool.category == "graves" else "Hold to wash" if tool.category == "graves" else "Collect bags"
			input.drop_text = "Return tool" if Cemetery.TRAILER.grow(28).has_point(p.pos) else "Exit" if tool.category in ["mowing","trash"] else "Drop tool"
			context_label.text = tool.name
			if tool.category == "leaves": context_label.text += " · Noise %d%%" % roundi(p.sound) + (" — pause!" if p.sound >= 85 else "")
			if tool.category == "graves": context_label.text += " · Stop at 95–105%"
		elif not p.bags.is_empty():
			input.use_text = "Deliver bag" if Cemetery.DUMPSTER.grow(65).has_point(p.pos) else "Take"
			context_label.text = "Carrying %d bag(s) · Deliver to the north dumpster" % p.bags.size()
		elif Cemetery.EXTRACTION.grow(40).has_point(p.pos) and EquipmentSystem.nearest(s,p,input.aim_point()).is_empty():
			input.use_text = "Extract"
		if not p.bags.is_empty() and Cemetery.DUMPSTER.grow(65).has_point(p.pos): input.use_text = "Unload bags"
		if not p.alive or p.extracted: input.use_text = "Watching"
		if context_label.text == "ON FOOT": context_label.text = "Tap a nearby tool or use Take. Drag MOVE to walk."
	extract_button.visible = p.alive and not p.extracted and s.elapsed < 300 and Cemetery.EXTRACTION.grow(40).has_point(p.pos)
	notice_label.text = s.notice if s.notice_time > 0 else ""
	if s.elapsed >= 295: notice_label.text = "RETURN NOW. THE WITCHING HOUR IS HERE."
	elif s.elapsed >= 285: notice_label.text = "2:45 AM  /  RETURN YOUR EQUIPMENT AND EXTRACT"
	elif s.elapsed >= 270: notice_label.text = "2:30 AM  /  THE WITCHING HOUR APPROACHES"
	if s.witches: notice_label.text = "3:00 AM  /  THE WITCHES ARE HERE"
	clock_label.add_theme_color_override("font_color",Color("e99b7c") if s.elapsed >= 285 else Color("e4e4c9"))
	if s.elapsed >= 295: clock_label.modulate.a = 0.65 + 0.35 * absf(sin(Time.get_ticks_msec() / 180.0))

func request_extract() -> void:
	if modal != null: return
	var count := EquipmentSystem.lost_count(Session.state)
	if count == 0:
		input.extract = true
		return
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.05,0.06,0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shade)
	input.reset()
	input.blocked = true
	modal = shade
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",20)
	center.add_child(box)
	label(box,"%d EQUIPMENT ITEMS ARE STILL OUTSIDE" % count,27,Color("e5ae68"))
	label(box,"They will be lost when the last employee leaves.\nThe shift clock keeps running.",20)
	button(box,"LEAVE ANYWAY",func(): input.extract = true; close_modal())
	button(box,"GO BACK FOR THEM",close_modal)

func close_modal() -> void:
	if modal != null:
		modal.queue_free()
		modal = null
		input.blocked = false

func build_results() -> void:
	var box := centered_panel()
	var result: Dictionary = Session.state.results
	label(box,"BRIAR HOLLOW  /  SHIFT REPORT",16,Color("e5ae68"))
	label(box,"CLOCKED OUT.",45)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",26)
	grid.add_theme_constant_override("v_separation",12)
	box.add_child(grid)
	for category in result.rows:
		var title := label(grid,category.to_upper(),22)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var completion := "%d%%" % roundi(result.completion[category] * 100)
		if category == "trash": completion = "%d/8" % roundi(result.completion[category] * 8)
		if category == "graves": completion = "%d/12" % roundi(result.completion[category] * 12)
		label(grid,completion,22)
		label(grid,"$%.2f" % result.rows[category],22)
	label(box,"Gross                          $%.2f\nEmployee deaths (%d)     -%d%%" % [result.gross,result.deaths,roundi(result.penalty * 100)],20,Color("9baca3"))
	label(box,"TEAM PAYOUT   $%.2f" % result.total,32,Color("e5ae68"))
	var share: float = result.get("shares",{}).get(Session.local_id,result.total)
	label(box,"YOUR SHARE   $%.2f     /     BALANCE   $%.2f" % [share,Session.profile.cash],21)
	label(box,"Equipment left behind: %d" % EquipmentSystem.lost_count(Session.state),19)
	var losses := PackedStringArray()
	for item in Session.state.equipment.values():
		if item.owner == Session.profile.uid and not item.returned: losses.append(Catalog.tool(item.type).name)
	if not losses.is_empty(): label(box,"YOUR LOST TOOLS: " + ", ".join(losses),18,Color("e4a086"))
	button(box,"ANOTHER SHIFT  >",Session.back_to_lobby)
