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
var last_screen := ""

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
	Session.changed.connect(rebuild)
	get_viewport().size_changed.connect(resize_layout)
	resize_layout()
	rebuild()

func resize_layout() -> void:
	var window := get_window()
	var desired := Vector2i(720,1100) if window.size.x < window.size.y else Vector2i(1440,900)
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
	if get_viewport().get_visible_rect().size.x < 1000 and size < 32: size = roundi(size * 1.3)
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	if text.length() > 40: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func button(parent: Node, text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	if get_viewport().get_visible_rect().size.x < 1000:
		node.custom_minimum_size.y = 84
		node.add_theme_font_size_override("font_size",24)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func rebuild() -> void:
	input.reset()
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	modal = null
	last_screen = Session.screen
	if Session.screen == "match": build_hud()
	elif Session.screen == "results": build_results()
	else: build_lobby()

func centered_panel(width: float = 680) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(width,get_viewport().get_visible_rect().size.x - 48)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",18)
	panel.add_child(box)
	return box

func build_lobby() -> void:
	var narrow := get_viewport().get_visible_rect().size.x < 1000
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + edge,28)
	ui.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",18)
	scroll.add_child(box)
	var masthead: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
	box.add_child(masthead)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	masthead.add_child(title)
	label(title,"BRIAR HOLLOW  /  NIGHT CREW",15,Color("e5ae68"))
	label(title,"GRAVE MAINTENANCE",38 if narrow else 48)
	label(title,"An honest night's work. A questionable workplace.",18,Color("91aaa2"))
	label(title,"YOUR BALANCE   $%.2f" % Session.profile.cash,23,Color("e5ae68"))
	var contract := PanelContainer.new()
	box.add_child(contract)
	var contract_box := VBoxContainer.new()
	contract.add_child(contract_box)
	label(contract_box,"10 PM — 3 AM   /   5 MINUTES   /   UP TO 4 EMPLOYEES",17,Color("e5ae68"))
	label(contract_box,"Mow. Clear leaves. Collect 8 bags. Clean 12 graves.",23)
	label(contract_box,"$1,000 maximum · Each job pays 25% · Death costs the team 15%\nReturn equipment to the trailer, then leave at the truck before the witches arrive.",17,Color("91aaa2"))
	if not Session.error.is_empty():
		var error_node := label(box,Session.error,18,Color("e4a086"))
		error_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var columns: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
	columns.add_theme_constant_override("separation",20)
	box.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.9
	left.add_theme_constant_override("separation",16)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",16)
	columns.add_child(right)
	build_crew(left)
	build_loadout(right)
	build_shop(right)
	label(box,"WASD  move  ·  Mouse  face  ·  Left click  use / take / interact  ·  Right click  drop / return",16,Color("91aaa2"))
	if input.touch_enabled: label(box,"TOUCH: Drag the left side to move. Use the right-side buttons to work and return tools.",16,Color("91aaa2"))

func build_crew(parent: Node) -> void:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	panel.add_child(box)
	label(box,"01   /   YOUR CREW",16,Color("e5ae68"))
	var name_row := HBoxContainer.new()
	box.add_child(name_row)
	var name_edit := LineEdit.new()
	name_edit.text = Session.profile.name
	name_edit.max_length = 18
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)
	button(name_row,"SAVE NAME",func(): Session.set_player_name(name_edit.text))
	if Session.room.is_empty():
		label(box,"SOLO SHIFT   /   1 EMPLOYEE",21)
		var offered_value := 0.0
		var names := PackedStringArray()
		for item in Session.profile.owned:
			if item.id in Session.offered:
				names.append(Catalog.tool(item.type).name)
				offered_value += float(Catalog.tool(item.type).price)
		label(box,Session.profile.name + ("  ·  READY" if Session.is_ready else "  ·  NOT READY"),20)
		var list := label(box,", ".join(names) + "\nEquipment at risk: $%.0f" % offered_value,17,Color("91aaa2"))
		list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		label(box,("LOCKED ROOM  /  " if Session.room.locked else "PUBLIC ROOM  /  ") + Session.room.code,22)
		label(box,"Share this code with your crew." + (" Password required." if Session.room.locked else ""),16,Color("91aaa2"))
		for id in Session.room.members:
			var m: Dictionary = Session.room.members[id]
			label(box,m.name + ("  ·  READY" if m.ready else "  ·  NOT READY") + ("  / HOST" if id == Session.room.host else ""),20)
			var list := label(box,", ".join(PackedStringArray(m.equipment)) + "\nEquipment at risk: $%.0f" % m.value,16,Color("91aaa2"))
			list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button(box,"LEAVE ROOM",Session.leave_room)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	button(actions,"UNREADY" if Session.is_ready else "I'M READY",func(): Session.set_ready(not Session.is_ready))
	var start := button(actions,"CLOCK IN  >",Session.start_match)
	start.disabled = not Session.is_ready
	if not Session.room.is_empty():
		start.disabled = Session.room.host != Session.local_id
		for m in Session.room.members.values():
			if not m.ready: start.disabled = true
	if Session.room.is_empty(): build_network(parent)

func build_network(parent: Node) -> void:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	panel.add_child(box)
	label(box,"CO-OP   /   PUBLIC & PRIVATE ROOMS",16,Color("e5ae68"))
	var url := LineEdit.new()
	url.text = Session.server_url
	url.placeholder_text = "ws://server:9080"
	box.add_child(url)
	var connect_button := button(box,"REFRESH PUBLIC ROOMS" if Session.connected else "CONNECT TO SERVER",func(): Session.connect_online(url.text))
	connect_button.disabled = Session.connecting
	if Session.connecting: label(box,"Connecting…",18)
	if not Session.connected: return
	var password := LineEdit.new()
	password.placeholder_text = "Password for a locked room"
	password.secret = true
	password.max_length = 64
	box.add_child(password)
	var hosts := HBoxContainer.new()
	box.add_child(hosts)
	button(hosts,"HOST PUBLIC",func(): Session.create_room(false,""))
	button(hosts,"HOST LOCKED",func(): Session.create_room(true,password.text))
	var joins := HBoxContainer.new()
	box.add_child(joins)
	var code := LineEdit.new()
	code.placeholder_text = "Room code"
	code.max_length = 6
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	joins.add_child(code)
	button(joins,"JOIN CODE",func(): Session.join_room(code.text,password.text))
	if Session.directory.is_empty(): label(box,"No public rooms yet. Host one for your crew.",16,Color("91aaa2"))
	for entry in Session.directory:
		button(box,"%s  ·  %d/4  ·  %s" % [entry.title,entry.count,entry.code],func(): Session.join_room(entry.code))
	button(box,"DISCONNECT / SOLO",func(): Session.disconnect_online())

func build_loadout(parent: Node) -> void:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	panel.add_child(box)
	label(box,"02   /   OWNED EQUIPMENT",16,Color("e5ae68"))
	var slots := Session.offered.size()
	if not Session.room.is_empty():
		for peer in Session.room.members:
			if peer != Session.local_id: slots += Session.room.members[peer].equipment.size()
	label(box,"Offer tools to the trailer.   %d / %d slots" % [slots,int(Catalog.contract.trailer_capacity)],18,Color("91aaa2"))
	if Session.profile.owned.is_empty(): label(box,"Your tools were lost. Claim free basics in the shop.",18)
	for item in Session.profile.owned:
		var row := HBoxContainer.new()
		box.add_child(row)
		var description := label(row,Catalog.tool(item.type).name + "   ·   $%.0f" % Catalog.tool(item.type).price,20)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button(row,"REMOVE" if item.id in Session.offered else "OFFER",func(): Session.toggle_offer(item.id))
	label(box,"Returned tools go back to their owner. Anything left outside is lost.",16,Color("91aaa2"))

func build_shop(parent: Node) -> void:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	panel.add_child(box)
	label(box,"03   /   EQUIPMENT SHOP",16,Color("e5ae68"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",8)
	box.add_child(grid)
	for kind in Catalog.equipment:
		var tool := Catalog.tool(kind)
		var node := button(grid,"%s   $%.0f" % [tool.name,tool.price],func(): Session.buy(kind))
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.add_theme_font_size_override("font_size",22 if get_viewport().get_visible_rect().size.x < 1000 else 17)
		node.tooltip_text = tool.description
		node.disabled = Session.profile.cash < tool.price
		if tool.price == 0:
			for item in Session.profile.owned:
				if item.type == kind: node.disabled = true

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
		help.text = "DRAG LEFT SIDE TO MOVE"
		var use := button(ui,"USE / TAKE",func(): pass)
		use.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		use.offset_left = -250
		use.offset_right = -28
		use.offset_top = -220
		use.offset_bottom = -134
		use.button_down.connect(func(): input.held = true; input.clicked = true)
		use.button_up.connect(func(): input.held = false)
		var drop := button(ui,"DROP / RETURN",func(): input.dropped = true; input.held = false)
		drop.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		drop.offset_left = -250
		drop.offset_right = -28
		drop.offset_top = -326
		drop.offset_bottom = -240

func _process(_dt: float) -> void:
	if Session.screen != "match": return
	var s: Dictionary = Session.state
	if s.is_empty() or not s.players.has(Session.local_id): return
	var p: Dictionary = s.players[Session.local_id]
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
