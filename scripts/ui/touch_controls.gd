class_name TouchControls
extends Control

var controller: InputController

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if controller == null: return
	var layout := controller.touch_layout()
	var center: Vector2 = layout.stick
	draw_circle(center,layout.radius,Color(0.04,0.10,0.12,0.85))
	draw_arc(center,layout.radius,0,TAU,64,Color("8ca89e"),3)
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		draw_line(center + direction * 72,center + direction * 84,Color("abc2af"),4)
	var knob := center + controller.touch_move * 67
	draw_circle(knob,33,Color("e5bb78") if controller.stick_id >= 0 else Color("75978d"))
	draw_circle(knob,24,Color("314d47"))
	draw_string(ThemeDB.fallback_font,center + Vector2(-35,136),"MOVE",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("ccd8c4"))
	draw_action(layout.use,controller.use_text,controller.held,true)
	draw_action(layout.drop,controller.drop_text,false,false)

func draw_action(rect: Rect2, value: String, active: bool, primary: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4cc88") if active else Color("e8b879") if primary else Color("233e42")
	style.border_color = Color("b7cbb5")
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	draw_style_box(style,rect)
	var font := ThemeDB.fallback_font
	var color := Color("183030") if primary else Color("e5e8d8")
	var size := 27
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	draw_string(font,rect.get_center() + Vector2(-width / 2,9),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
