extends GdUnitTestSuite

const ClanBomberTouchOverlay = preload("res://presentation/clanbomber_touch_overlay.gd")

func test_touch_overlay_initialization_and_force_visible() -> void:
	var overlay := ClanBomberTouchOverlay.new()
	overlay.force_visible = true
	add_child(overlay)
	auto_free(overlay)
	
	assert_bool(overlay.is_touch_active).is_true()
	assert_object(overlay.dpad_base).is_not_null()
	assert_object(overlay.bomb_btn).is_not_null()
	assert_object(overlay.pause_btn).is_not_null()

func test_touch_overlay_gameplay_visibility() -> void:
	var overlay := ClanBomberTouchOverlay.new()
	overlay.force_visible = true
	add_child(overlay)
	auto_free(overlay)
	
	overlay.set_gameplay_active(false)
	assert_bool(overlay.dpad_base.visible).is_false()
	assert_bool(overlay.bomb_btn.visible).is_false()
	
	overlay.set_gameplay_active(true)
	assert_bool(overlay.dpad_base.visible).is_true()
	assert_bool(overlay.bomb_btn.visible).is_true()

func test_touch_overlay_dpad_drag_and_direction() -> void:
	var overlay := ClanBomberTouchOverlay.new()
	overlay.force_visible = true
	add_child(overlay)
	auto_free(overlay)
	
	overlay.set_gameplay_active(true)
	var center = Vector2(100.0, 400.0)
	overlay._handle_touch_down(0, center)
	# Nach rechts ziehen
	overlay._handle_touch_drag(0, center + Vector2(40.0, 0.0))
	assert_int(overlay.current_direction.x).is_equal(1)
	assert_int(overlay.current_direction.y).is_equal(0)
	
	# Nach oben ziehen
	overlay._handle_touch_drag(0, center + Vector2(0.0, -40.0))
	assert_int(overlay.current_direction.x).is_equal(0)
	assert_int(overlay.current_direction.y).is_equal(-1)
	
	# Loslassen
	overlay._handle_touch_up(0)
	assert_int(overlay.current_direction.x).is_equal(0)
	assert_int(overlay.current_direction.y).is_equal(0)

func test_touch_overlay_bomb_and_pause_signals() -> void:
	var overlay := ClanBomberTouchOverlay.new()
	overlay.force_visible = true
	add_child(overlay)
	auto_free(overlay)
	overlay.set_gameplay_active(true)
	
	var bomb_fired := [false]
	overlay.bomb_pressed.connect(func(): bomb_fired[0] = true)
	var bomb_pos = overlay.bomb_btn.position + Vector2(10.0, 10.0)
	overlay._handle_touch_down(1, bomb_pos)
	assert_bool(bomb_fired[0]).is_true()
	overlay._handle_touch_up(1)
	
	var pause_fired := [false]
	overlay.pause_pressed.connect(func(): pause_fired[0] = true)
	overlay.pause_btn.pressed.emit()
	assert_bool(pause_fired[0]).is_true()
