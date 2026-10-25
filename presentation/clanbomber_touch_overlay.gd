extends CanvasLayer
class_name ClanBomberTouchOverlay

## ClanBomberTouchOverlay: On-Screen Touch-Steuerung für Tablets & WebGL2
## Bietet ein 4-Wege-Steuerkreuz (D-Pad links), Bomben-Button (rechts) und Pause-Taste.

signal bomb_pressed
signal pause_pressed

@export var force_visible: bool = false
@export var dpad_radius: float = 75.0

var is_touch_active: bool = false
var is_gameplay_active: bool = false
var current_direction: Vector2i = Vector2i.ZERO

var _dpad_touch_id: int = -1
var _bomb_touch_id: int = -1

var _dpad_center: Vector2 = Vector2.ZERO
var _dpad_default_pos: Vector2 = Vector2(130.0, 580.0)

var root_control: Control
var dpad_base: Panel
var dpad_knob: Panel
var bomb_btn: Button
var pause_btn: Button

func _ready() -> void:
	layer = 20
	_detect_touch_device()
	if not is_instance_valid(root_control):
		_build_ui()
	_update_visibility()
	var vp = get_viewport()
	if vp and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)

func _detect_touch_device() -> void:
	if force_visible:
		is_touch_active = true
		return
	is_touch_active = DisplayServer.is_touchscreen_available() \
		or OS.has_feature("web_android") \
		or OS.has_feature("web_ios") \
		or OS.has_feature("mobile") \
		or OS.has_feature("touchscreen")

func _get_viewport_size() -> Vector2:
	var vp = get_viewport()
	if vp:
		return vp.get_visible_rect().size
	return Vector2(1024.0, 720.0)

func set_gameplay_active(active: bool) -> void:
	is_gameplay_active = active
	_reset_dpad()
	_update_visibility()

func _update_visibility() -> void:
	if not is_instance_valid(root_control):
		return
	root_control.visible = is_touch_active
	var active = is_touch_active and is_gameplay_active
	if is_instance_valid(dpad_base):
		dpad_base.visible = active
	if is_instance_valid(bomb_btn):
		bomb_btn.visible = active
	if is_instance_valid(pause_btn):
		pause_btn.visible = active

func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "ClanBomberTouchRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	var vp_size = _get_viewport_size()
	_dpad_default_pos = Vector2(130.0, maxf(vp_size.y - 130.0, 200.0))
	_dpad_center = _dpad_default_pos

	# --- 1. D-Pad Steuerkreuz Basis (Links) ---
	dpad_base = Panel.new()
	dpad_base.name = "DpadBase"
	dpad_base.custom_minimum_size = Vector2(dpad_radius * 2.0, dpad_radius * 2.0)
	dpad_base.size = dpad_base.custom_minimum_size
	dpad_base.position = _dpad_center - Vector2(dpad_radius, dpad_radius)
	dpad_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var base_style = StyleBoxFlat.new()
	base_style.set_corner_radius_all(int(dpad_radius))
	base_style.bg_color = Color(0.08, 0.08, 0.12, 0.5)
	base_style.border_color = Color(0.8, 0.3, 0.1, 0.7)
	base_style.border_width_left = 3
	base_style.border_width_top = 3
	base_style.border_width_right = 3
	base_style.border_width_bottom = 3
	dpad_base.add_theme_stylebox_override("panel", base_style)
	root_control.add_child(dpad_base)

	dpad_knob = Panel.new()
	dpad_knob.name = "DpadKnob"
	var knob_rad = 30.0
	dpad_knob.custom_minimum_size = Vector2(knob_rad * 2.0, knob_rad * 2.0)
	dpad_knob.size = dpad_knob.custom_minimum_size
	dpad_knob.position = Vector2(dpad_radius - knob_rad, dpad_radius - knob_rad)
	dpad_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var knob_style = StyleBoxFlat.new()
	knob_style.set_corner_radius_all(int(knob_rad))
	knob_style.bg_color = Color(1.0, 0.45, 0.1, 0.85)
	knob_style.border_color = Color(1.0, 1.0, 1.0, 0.9)
	knob_style.border_width_left = 2
	knob_style.border_width_top = 2
	knob_style.border_width_right = 2
	knob_style.border_width_bottom = 2
	dpad_knob.add_theme_stylebox_override("panel", knob_style)
	dpad_base.add_child(dpad_knob)

	# --- 2. Bomben-Button (Rechts) ---
	bomb_btn = Button.new()
	bomb_btn.name = "TouchBombBtn"
	bomb_btn.text = "💣\nBOMB"
	bomb_btn.focus_mode = Control.FOCUS_NONE
	bomb_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE # Über Multi-Touch abgefragt
	var b_radius = 48.0
	bomb_btn.custom_minimum_size = Vector2(b_radius * 2.0, b_radius * 2.0)
	bomb_btn.size = bomb_btn.custom_minimum_size
	
	var b_style = StyleBoxFlat.new()
	b_style.set_corner_radius_all(int(b_radius))
	b_style.bg_color = Color(0.2, 0.05, 0.05, 0.75)
	b_style.border_color = Color(1.0, 0.25, 0.2, 0.9)
	b_style.border_width_left = 3
	b_style.border_width_top = 3
	b_style.border_width_right = 3
	b_style.border_width_bottom = 3
	bomb_btn.add_theme_stylebox_override("normal", b_style)
	bomb_btn.add_theme_stylebox_override("pressed", b_style)
	bomb_btn.add_theme_color_override("font_color", Color.WHITE)
	bomb_btn.add_theme_font_size_override("font_size", 16)
	root_control.add_child(bomb_btn)

	# --- 3. Pause Button (Oben Rechts) ---
	pause_btn = Button.new()
	pause_btn.name = "TouchPauseBtn"
	pause_btn.text = "⏸️"
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var p_style = StyleBoxFlat.new()
	p_style.set_corner_radius_all(14)
	p_style.bg_color = Color(0.1, 0.12, 0.18, 0.7)
	p_style.border_color = Color(0.5, 0.6, 0.8, 0.8)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	pause_btn.add_theme_stylebox_override("normal", p_style)
	pause_btn.add_theme_stylebox_override("pressed", p_style)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.pressed.connect(_on_pause_pressed)
	root_control.add_child(pause_btn)

	_layout_buttons(vp_size)

func _layout_buttons(vp_size: Vector2) -> void:
	_dpad_default_pos = Vector2(130.0, maxf(vp_size.y - 130.0, 200.0))
	if _dpad_touch_id == -1:
		_dpad_center = _dpad_default_pos
		if is_instance_valid(dpad_base):
			dpad_base.position = _dpad_center - Vector2(dpad_radius, dpad_radius)

	if is_instance_valid(bomb_btn):
		bomb_btn.position = Vector2(vp_size.x - 135.0, vp_size.y - 135.0)

	if is_instance_valid(pause_btn):
		pause_btn.size = Vector2(50.0, 44.0)
		pause_btn.position = Vector2(vp_size.x - 65.0, 16.0)

func _on_viewport_resized() -> void:
	_layout_buttons(_get_viewport_size())

func _on_pause_pressed() -> void:
	pause_pressed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_touch_active or not is_gameplay_active:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_handle_touch_down(touch.index, touch.position)
		else:
			_handle_touch_up(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_handle_touch_drag(drag.index, drag.position)

func _handle_touch_down(index: int, pos: Vector2) -> void:
	var vp_size = _get_viewport_size()

	# 1. Bomben-Button Hit-Test
	if is_instance_valid(bomb_btn) and bomb_btn.get_global_rect().has_point(pos):
		_bomb_touch_id = index
		bomb_pressed.emit()
		_pulse_button(bomb_btn, true)
		return

	# 2. D-Pad: Beliebiger Touch auf linker Bildschirmhälfte
	if pos.x < vp_size.x * 0.5 and _dpad_touch_id == -1:
		_dpad_touch_id = index
		_dpad_center = pos
		dpad_base.position = _dpad_center - Vector2(dpad_radius, dpad_radius)
		_update_dpad(pos)

func _handle_touch_drag(index: int, pos: Vector2) -> void:
	if index == _dpad_touch_id:
		_update_dpad(pos)

func _handle_touch_up(index: int) -> void:
	if index == _dpad_touch_id:
		_dpad_touch_id = -1
		_reset_dpad()
	elif index == _bomb_touch_id:
		_bomb_touch_id = -1
		_pulse_button(bomb_btn, false)

func _update_dpad(pos: Vector2) -> void:
	var diff = pos - _dpad_center
	var dist = diff.length()
	if dist > dpad_radius:
		diff = diff.normalized() * dpad_radius

	var knob_rad = 30.0
	dpad_knob.position = (diff + Vector2(dpad_radius, dpad_radius)) - Vector2(knob_rad, knob_rad)

	# 4-Wege-Richtung bestimmen (wie ClanBomber-Simulation)
	if dist < 18.0:
		current_direction = Vector2i.ZERO
	else:
		if absf(diff.x) > absf(diff.y):
			current_direction = Vector2i(int(signf(diff.x)), 0)
		else:
			current_direction = Vector2i(0, int(signf(diff.y)))

func _reset_dpad() -> void:
	current_direction = Vector2i.ZERO
	var knob_rad = 30.0
	if is_instance_valid(dpad_knob):
		dpad_knob.position = Vector2(dpad_radius - knob_rad, dpad_radius - knob_rad)
	if is_instance_valid(dpad_base):
		_dpad_center = _dpad_default_pos
		dpad_base.position = _dpad_center - Vector2(dpad_radius, dpad_radius)

func _pulse_button(btn: Button, pressed: bool) -> void:
	if not is_instance_valid(btn):
		return
	var target_scale = Vector2(0.9, 0.9) if pressed else Vector2(1.0, 1.0)
	var tween = create_tween()
	tween.tween_property(btn, "scale", target_scale, 0.08).set_trans(Tween.TRANS_QUAD)
