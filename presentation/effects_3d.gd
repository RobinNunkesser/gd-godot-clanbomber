class_name Effects3D
extends Node3D
## Juice für die 3D-Ansicht: Partikel, Lichtblitze und Kamerawackeln. Reine Präsentation, liest nur Signale.

const SHAKE_DECAY := 6.0
const MAX_SHAKE := 0.45

var camera: Camera3D

var shake_multiplier: float = 1.0

var _shake := 0.0
var _camera_base := Vector3.ZERO
var _time := 0.0
var _hitstop_token := 0


func attach_camera(p_camera: Camera3D) -> void:
	camera = p_camera
	_camera_base = p_camera.position


func _process(delta: float) -> void:
	if camera == null:
		return
	_time += delta
	_shake = maxf(_shake - SHAKE_DECAY * delta * MAX_SHAKE, 0.0)
	var offset := Vector3(sin(_time * 53.0), 0.0, cos(_time * 47.0)) * _shake
	camera.position = _camera_base + offset


func add_shake(amount: float) -> void:
	if shake_multiplier <= 0.0:
		return
	_shake = minf(_shake + amount * shake_multiplier, MAX_SHAKE)


func hitstop(duration_s := 0.038, time_scale := 0.05) -> void:
	if not is_inside_tree():
		return
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = time_scale
	get_tree().create_timer(duration_s, true, false, true).timeout.connect(func() -> void:
		if _hitstop_token == token:
			Engine.time_scale = 1.0
	)


func cancel_hitstop() -> void:
	_hitstop_token += 1
	Engine.time_scale = 1.0


func explosion(cells: Array[Vector2i], origin: Vector2i, listener_cell := Vector2i(-1, -1)) -> void:
	var dist_factor := 1.0
	if listener_cell.x >= 0:
		var dist := origin.distance_to(listener_cell)
		dist_factor = clampf(1.25 - (dist / 14.0) * 0.75, 0.4, 1.25)
	add_shake((0.12 + 0.02 * cells.size()) * dist_factor)
	_flash(_cell_pos(origin, 0.8), Color("ffb347"), 6.0, 0.25)
	for cell in cells:
		_burst(_cell_pos(cell, 0.3), Color("ffcc33"), Color("ff3c00"), 6, 2.2, 0.45, 0.1)
	_burst(_cell_pos(origin, 0.4), Color("555555"), Color("222222"), 14, 1.2, 0.9, 0.22, true)


func box_break(cell: Vector2i) -> void:
	_burst(_cell_pos(cell, 0.5), Color("a0703a"), Color("5c3b1a"), 16, 3.2, 0.7, 0.12, true)


func pickup(pos: Vector3, color: Color) -> void:
	_burst(pos + Vector3(0, 0.6, 0), color.lightened(0.4), color, 14, 2.4, 0.6, 0.08)
	_flash(pos + Vector3(0, 0.8, 0), color, 2.5, 0.2)


func pickup_text(pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.text = text
	label.modulate = color
	label.outline_modulate = Color.BLACK
	label.outline_size = 18
	label.font_size = 72
	label.pixel_size = 0.0055
	label.position = pos + Vector3(0, 0.9, 0)
	label.scale = Vector3.ONE * 0.5
	add_child(label)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.9, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "scale", Vector3.ONE * 1.15, 0.18).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector3.ONE * 1.0, 0.15)
	var fade_tween := create_tween()
	fade_tween.tween_interval(0.40)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.35)
	fade_tween.tween_callback(label.queue_free)


func confetti(pos: Vector3) -> void:
	var colors := [Color("ff1744"), Color("ffea00"), Color("00e676"), Color("2979ff"), Color("d500f9")]
	for i in colors.size():
		var particles := CPUParticles3D.new()
		particles.position = pos + Vector3(0, 3.0, 0)
		particles.emitting = false
		particles.one_shot = true
		particles.explosiveness = 0.9
		particles.amount = 25
		particles.lifetime = 1.4
		particles.direction = Vector3.UP
		particles.spread = 70.0
		particles.initial_velocity_min = 2.5
		particles.initial_velocity_max = 5.0
		particles.gravity = Vector3(0, -5.5, 0)
		particles.scale_amount_min = 0.5
		particles.scale_amount_max = 1.2
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.12, 0.07)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i]
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.emission_enabled = true
		mat.emission = colors[i]
		mat.emission_energy_multiplier = 0.5
		mesh.material = mat
		particles.mesh = mesh
		add_child(particles)
		particles.emitting = true
		get_tree().create_timer(1.8).timeout.connect(particles.queue_free)


func death(pos: Vector3, color: Color) -> void:
	add_shake(0.25)
	_burst(pos + Vector3(0, 0.5, 0), Color.WHITE, color, 28, 3.6, 0.9, 0.14)
	_flash(pos + Vector3(0, 0.8, 0), color, 4.0, 0.3)


func bomb_placed(pos: Vector3) -> void:
	_burst(pos + Vector3(0, 0.1, 0), Color("cccccc"), Color("888888"), 6, 0.9, 0.35, 0.1)


func tile_drop(cell: Vector2i) -> void:
	add_shake(0.06)
	_burst(_cell_pos(cell, 0.3), Color("9a8f7a"), Color("4a4338"), 10, 1.6, 0.6, 0.12, true)


func trap_sprung(cell: Vector2i) -> void:
	add_shake(0.1)
	_flash(_cell_pos(cell, 0.6), Color("e040fb"), 5.0, 0.35)
	_burst(_cell_pos(cell, 0.3), Color("ff80ab"), Color("7b1fa2"), 16, 2.8, 0.65, 0.12)


func _cell_pos(cell: Vector2i, height: float) -> Vector3:
	return Vector3(cell.x + 0.5, height, cell.y + 0.5)


func _flash(pos: Vector3, color: Color, energy: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 5.0
	light.position = pos
	add_child(light)
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, seconds)
	tween.tween_callback(light.queue_free)


# Einmaliger Partikelstoß; gravity=true lässt Trümmer fallen, sonst steigen sie leicht auf.
func _burst(pos: Vector3, color_a: Color, color_b: Color, amount: int, speed: float,
		lifetime: float, size: float, gravity := false) -> void:
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = Vector3.UP
	particles.spread = 180.0 if gravity else 120.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -9.0 if gravity else 1.0, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = color_b
	material.emission_energy_multiplier = 0.6
	mesh.material = material
	particles.mesh = mesh
	var ramp := Gradient.new()
	ramp.set_color(0, color_a)
	ramp.set_color(1, Color(color_b, 0.0))
	particles.color_ramp = ramp
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(lifetime + 0.3).timeout.connect(particles.queue_free)
