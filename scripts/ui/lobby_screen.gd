class_name LobbyScreen
extends RefCounted

const GOLD := Color("edbb76")
const MUTED := Color("91aaa5")
const CATEGORIES := ["mowing","leaves","trash","graves"]
const TITLES := {"mowing":"Mowing","leaves":"Leaf clearing","trash":"Trash transport","graves":"Grave cleaning"}
var app: Node
var model: Dictionary
var narrow := false
var touch_ui := false

func build(parent: Control, owner: Node, settings: Dictionary) -> void:
	app = owner
	model = settings
	narrow = parent.get_viewport_rect().size.x < 1000
	touch_ui = app.input.touch_enabled
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + edge,24 if narrow else 40)
	if app.input.touch_enabled: margin.add_theme_constant_override("margin_top",maxi(24,roundi(app.input.safe_top_css * app.input.safe_scale())))
	parent.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",20)
	scroll.add_child(body)
	text(body,"BRIAR HOLLOW   /   NIGHT CREW",15,GOLD)
	text(body,"Grave Maintenance",38 if narrow else 46)
	if not Session.error.is_empty(): text(body,Session.error,18,Color("f0a78b"))
	if not model.message.is_empty(): text(body,model.message,18,GOLD)
	if not Session.room.is_empty() or model.preparing: build_preparation(body)
	else: build_browser(body)
	if (narrow or touch_ui) and (not Session.room.is_empty() or model.preparing):
		margin.add_theme_constant_override("margin_bottom",170 + roundi(maxf(30,app.input.safe_bottom_css * app.input.safe_scale())))
		build_mobile_footer(parent)

func text(parent: Node, value: String, size: int = 20, color: Color = Color("e5e8d8")) -> Label:
	if touch_ui and not narrow and size < 32: size = roundi(size * 1.3)
	var node: Label = app.label(parent,value,size,color)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func action(parent: Node, value: String, callback: Callable, primary: bool = false) -> Button:
	var node: Button = app.button(parent,value,callback)
	node.custom_minimum_size.y = 84 if narrow or touch_ui else 58
	if touch_ui: node.add_theme_font_size_override("font_size",26)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if primary:
		var style := StyleBoxFlat.new()
		style.bg_color = GOLD
		style.set_corner_radius_all(10)
		style.set_content_margin_all(16)
		node.add_theme_stylebox_override("normal",style)
		var hover := style.duplicate()
		hover.bg_color = GOLD.lightened(0.12)
		node.add_theme_stylebox_override("hover",hover)
		node.add_theme_color_override("font_color",Color("152b2c"))
		node.add_theme_color_override("font_hover_color",Color("152b2c"))
	return node

func card(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	panel.add_child(box)
	return box

func row(parent: Node, responsive: bool = false) -> BoxContainer:
	var node: BoxContainer = VBoxContainer.new() if responsive and narrow else HBoxContainer.new()
	node.add_theme_constant_override("separation",14)
	parent.add_child(node)
	return node

func edit(parent: Node, placeholder: String, value: String = "", secret: bool = false) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.text = value
	field.secret = secret
	field.custom_minimum_size.y = 84 if narrow or touch_ui else 58
	field.add_theme_font_size_override("font_size",26 if narrow or touch_ui else 22)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(field)
	return field

func redraw() -> void:
	app.rebuild()

func build_browser(body: Node) -> void:
	text(body,"Find your crew. Clock in for five minutes. Get out before 3 AM.",20,MUTED)
	var identity := card(body)
	text(identity,"YOUR NAME",16,GOLD)
	var name_field := edit(identity,"Enter your name",model.name_draft)
	name_field.name = "PlayerName"
	name_field.max_length = 18
	name_field.text_changed.connect(func(value): model.name_draft = value)
	name_field.text_submitted.connect(func(value): save_name(value))
	# Focus loss happens on mouse-down. Keep the clicked button alive until release.
	name_field.focus_exited.connect(func(): save_name(name_field.text,false); name_field.text = model.name_draft)
	text(identity,"Your name is saved automatically when you leave this field.",16,MUTED)
	var choices := row(body,true)
	action(choices,"Host a game",func(): model.home_mode = "host"; redraw(),true)
	action(choices,"Join with a code",func(): model.home_mode = "join"; redraw())
	action(choices,"Play solo",func(): save_name(model.name_draft); model.preparing = true; model.message = ""; Session.disconnect_online(); redraw())
	if model.home_mode == "host": build_host(body)
	elif model.home_mode == "join": build_join(body)
	var browser := card(body)
	var header := row(browser,true)
	text(header,"PUBLIC GAMES",23).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var refresh := action(header,"Connecting…" if Session.connecting else "Refresh",func(): save_name(model.name_draft); Session.connect_online(Session.server_url))
	refresh.disabled = Session.connecting
	if not Session.connected:
		text(browser,"Connecting to the co-op server…" if Session.connecting else "Server unavailable. Retry, or play a solo shift.",20,MUTED)
	elif Session.directory.is_empty():
		text(browser,"No crews clocking in yet",24)
		text(browser,"Host a public game and friends can find it here. Private games use a code and password.",18,MUTED)
	else:
		for entry in Session.directory:
			var game := row(browser,true)
			var details := VBoxContainer.new()
			details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			game.add_child(details)
			text(details,entry.title,22)
			text(details,"%d / 4 employees   ·   Room %s" % [entry.count,entry.code],17,MUTED)
			action(game,"Join game",func(): save_name(model.name_draft); Session.join_room(entry.code)).disabled = entry.count >= 4
	var advanced := action(body,"Hide connection settings" if model.advanced else "Connection settings",func(): model.advanced = not model.advanced; redraw())
	advanced.add_theme_color_override("font_color",MUTED)
	if model.advanced:
		var connection := card(body)
		text(connection,"Server address",18,MUTED)
		var address := edit(connection,"wss://your-server",Session.server_url)
		action(connection,"Connect to this server",func(): Session.disconnect_online(); Session.connect_online(address.text))

func save_name(value: String, notify: bool = true) -> void:
	var clean := value.strip_edges().left(18)
	if clean.is_empty(): clean = "Groundskeeper"
	model.name_draft = clean
	if clean != Session.profile.name: Session.set_player_name(clean,notify)

func build_host(body: Node) -> void:
	var box := card(body)
	text(box,"HOST YOUR CREW",23,GOLD)
	text(box,"You choose when the shift starts. Up to four employees can join.",18,MUTED)
	var options := row(box,true)
	action(options,"✓ Public" if not model.locked else "Public",func(): model.locked = false; redraw())
	action(options,"✓ Private" if model.locked else "Private",func(): model.locked = true; redraw())
	if model.locked:
		text(box,"Hidden from the browser. Share the room code and password.",18,MUTED)
		var password := edit(box,"Set a room password",model.password,true)
		password.text_changed.connect(func(value): model.password = value)
	else: text(box,"Listed in the server browser. Anyone can join.",18,MUTED)
	var create := action(box,"Create private game" if model.locked else "Create public game",func(): save_name(model.name_draft); Session.create_room(model.locked,model.password),true)
	create.disabled = not Session.connected
	if not Session.connected: text(box,"Connect to the server to host. Solo works offline.",18,MUTED)

func build_join(body: Node) -> void:
	var box := card(body)
	text(box,"JOIN YOUR FRIENDS",23,GOLD)
	var code := edit(box,"Six-character room code",model.code)
	code.max_length = 6
	code.text_changed.connect(func(value): model.code = value.to_upper())
	var password := edit(box,"Password (private games only)",model.password,true)
	password.text_changed.connect(func(value): model.password = value)
	action(box,"Join game",func(): save_name(model.name_draft); Session.join_room(model.code,model.password),true).disabled = not Session.connected

func build_preparation(body: Node) -> void:
	var header := row(body)
	var online := not Session.room.is_empty()
	text(header,("PRIVATE" if Session.room.get("locked",false) else "PUBLIC") + " GAME  ·  " + Session.room.code if online else "SOLO SHIFT",22,GOLD).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action(header,"Leave game" if online else "Back to servers",func(): model.preparing = false; model.home_mode = ""; model.message = ""; Session.set_ready(false); Session.leave_room() if online else redraw())
	var summary := card(body)
	text(summary,"Prepare the trailer",30)
	text(summary,"5 minutes · $1,000 maximum · Return tools to keep them",18,MUTED)
	var metrics := row(summary)
	text(metrics,("Wallet\n$%.2f" if narrow else "WALLET  $%.2f") % Session.profile.cash,22,GOLD)
	text(metrics,("At risk\n$%.0f" if narrow else "YOUR GEAR AT RISK  $%.0f") % risk_value(),20)
	text(metrics,("Trailer\n%d / %d" if narrow else "TRAILER  %d / %d") % [slots(),int(Catalog.contract.trailer_capacity)],20)
	if narrow or touch_ui:
		action(body,("Hide crew" if model.show_crew else "Show crew") + (" · Code " + Session.room.code if online else " · Solo"),func(): model.show_crew = not model.show_crew; redraw())
	var columns := row(body,true)
	var crew := card(columns)
	crew.get_parent().visible = not (narrow or touch_ui) or model.show_crew
	if not narrow: crew.get_parent().custom_minimum_size.x = 330
	text(crew,"YOUR CREW",17,GOLD)
	if online:
		text(crew,"Invite code: " + Session.room.code,22)
		for id in Session.room.members:
			var member: Dictionary = Session.room.members[id]
			text(crew,member.name + ("  ·  Host" if id == Session.room.host else ""),21)
			text(crew,("Ready" if member.ready else "Preparing") + "  ·  $%.0f at risk" % member.value,17,Color("a3d8ac") if member.ready else MUTED)
			text(crew,", ".join(PackedStringArray(member.equipment)) if not member.equipment.is_empty() else "No tools packed",16,MUTED)
	else:
		text(crew,Session.profile.name,22)
		text(crew,"Ready" if Session.is_ready else "Preparing",18,MUTED)
	if not narrow and not touch_ui: build_ready_actions(crew)
	text(crew,"Everyone must be ready. The host starts the shift." if online else "Pack your tools, mark ready, then start.",17,MUTED)
	var kit := VBoxContainer.new()
	kit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kit.size_flags_stretch_ratio = 2.4
	kit.add_theme_constant_override("separation",14)
	columns.add_child(kit)
	var tabs := row(kit)
	for entry in [["trailer","Trailer"],["inventory","My equipment"],["shop","Shop"]]:
		var select := action(tabs,entry[1],func(): model.tab = entry[0]; model.message = ""; redraw(),model.tab == entry[0])
		select.name = "Tab_" + entry[0]
	if model.tab == "shop": build_shop(kit)
	else: build_equipment(kit,model.tab == "trailer")

func build_ready_actions(parent: Node) -> void:
	var ready := action(parent,"✓ Ready" if Session.is_ready else "I'm ready",func(): Session.set_ready(not Session.is_ready),true)
	ready.name = "ReadyButton"
	var allowed := Session.is_ready
	if not Session.room.is_empty():
		allowed = Session.room.host == Session.local_id
		for member in Session.room.members.values(): allowed = allowed and member.ready
	var start := action(parent,"Start shift",Session.start_match,true)
	start.name = "StartShift"
	start.disabled = not allowed

func build_mobile_footer(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 16
	panel.offset_right = -16
	var bottom := maxf(30,app.input.safe_bottom_css * app.input.safe_scale())
	panel.offset_top = -132 - bottom
	panel.offset_bottom = -bottom
	parent.add_child(panel)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",14)
	panel.add_child(actions)
	build_ready_actions(actions)

func risk_value() -> float:
	var result := 0.0
	for item in Session.profile.owned:
		if item.id in Session.offered: result += Catalog.tool(item.type).price
	return result

func slots() -> int:
	var count := Session.offered.size()
	for id in Session.room.get("members",{}):
		if id != Session.local_id: count += Session.room.members[id].equipment.size()
	return count

func build_equipment(parent: Node, packed_only: bool) -> void:
	text(parent,"On the trailer" if packed_only else "Your equipment",26)
	text(parent,"The whole crew's packed tools appear here. Anything unpacked stays safe at home." if packed_only else "You own these tools. Pack only what you want to risk on this shift.",18,MUTED)
	var groups := GridContainer.new()
	groups.columns = 2 if packed_only and not narrow else 1
	groups.add_theme_constant_override("h_separation",14)
	groups.add_theme_constant_override("v_separation",14)
	parent.add_child(groups)
	for category in CATEGORIES:
		var section := card(groups)
		text(section,TITLES[category].to_upper(),17,GOLD)
		var count := 0
		for item in Session.profile.owned:
			var tool := Catalog.tool(item.type)
			if tool.category != category or (packed_only and item.id not in Session.offered): continue
			count += 1
			var item_row := row(section)
			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_row.add_child(info)
			text(info,tool.name,23)
			if packed_only: text(info,"Yours · " + Session.profile.name,17,MUTED)
			text(info,("Packed" if item.id in Session.offered else "At home") + "  ·  Replacement $%.0f" % tool.price,17,Color("a3d8ac") if item.id in Session.offered else MUTED)
			if not packed_only: text(info,tool.description,17,MUTED)
			var pack := action(item_row,"Unpack" if item.id in Session.offered else "Pack",func(): Session.toggle_offer(item.id))
			pack.size_flags_horizontal = Control.SIZE_FILL
			pack.custom_minimum_size.x = 145 if narrow else 105
		if packed_only:
			for member_id in Session.room.get("members",{}):
				if member_id == Session.local_id: continue
				var member: Dictionary = Session.room.members[member_id]
				for tool_name in member.equipment:
					for kind in Catalog.equipment:
						var tool := Catalog.tool(kind)
						if tool.name != tool_name or tool.category != category: continue
						count += 1
						text(section,tool.name,23)
						text(section,"Packed by %s · Replacement $%.0f" % [member.name,tool.price],17,Color("a3d8ac"))
		if count == 0:
			text(section,"Hands carry one bag — no tool required." if category == "trash" else "No equipment packed" if packed_only else "No equipment owned",18,MUTED)
	if packed_only: action(parent,"Choose more equipment",func(): model.tab = "inventory"; redraw())
	if not packed_only: action(parent,"Buy better equipment",func(): model.tab = "shop"; redraw(),true)

func build_shop(parent: Node) -> void:
	text(parent,"Equipment shop",26)
	text(parent,"Purchases go into My equipment. Pack them before the shift. Prices are per item.",18,MUTED)
	if narrow:
		var filter := OptionButton.new()
		filter.custom_minimum_size.y = 84
		filter.add_theme_font_size_override("font_size",26)
		for category in CATEGORIES: filter.add_item(TITLES[category])
		filter.selected = CATEGORIES.find(model.category)
		filter.item_selected.connect(func(index): model.category = CATEGORIES[index]; redraw())
		parent.add_child(filter)
	else:
		var filters := row(parent)
		for category in CATEGORIES:
			action(filters,TITLES[category],func(): model.category = category; redraw(),model.category == category)
	var grid := GridContainer.new()
	grid.columns = 1 if narrow else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",14)
	parent.add_child(grid)
	for kind in Catalog.equipment:
		var tool := Catalog.tool(kind)
		if tool.category != model.category: continue
		var box := card(grid)
		text(box,"BASIC" if tool.tier == 1 else "UPGRADE" if tool.tier == 2 else "PRO",15,GOLD)
		text(box,tool.name,25)
		text(box,tool.description,19,MUTED)
		var owned := 0
		for item in Session.profile.owned:
			if item.type == kind: owned += 1
		text(box,"You own %d" % owned,18,MUTED)
		var affordable: bool = Session.profile.cash >= tool.price
		var already: bool = tool.price == 0 and owned > 0
		var buy := action(box,"Already owned" if already else "Claim free basic" if tool.price == 0 else "Buy · $%.0f" % tool.price,func():
			model.message = tool.name + " added to your equipment. Pack it to use it."
			model.tab = "inventory"
			Session.buy(kind),true)
		buy.disabled = already or not affordable or Session.profile.owned.size() >= 24
		if not already: text(box,"Balance after purchase: $%.2f" % (Session.profile.cash - tool.price) if affordable else "Need $%.2f more" % (tool.price - Session.profile.cash),17,MUTED)
