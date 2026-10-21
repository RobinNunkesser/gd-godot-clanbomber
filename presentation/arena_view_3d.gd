class_name ArenaView3D
extends Node3D
## 2.5D-Präsentation mit Kenney-Assets (CC0). Liest nur den Zustand der Simulation. 1 Zelle = 1 Einheit, y ist oben.

const CELL := SimConstants.CELL_SIZE
const CHARACTER_DIR := "res://assets/models/characters/"
const CHARACTER_LETTERS := ["a", "d", "h", "k", "m", "o", "q", "r"]
const FLOOR_SCENE := preload("res://assets/models/arena/template-floor.glb")
const PLAYER_COLORS: Array[Color] = [
	Color("e8504a"), Color("4a90e8"), Color("5bc45b"), Color("e8c84a"),
	Color("b06ae0"), Color("e88a4a"), Color("4ac8c8"), Color("d0d0d0"),
]
const EXTRA_COLORS := {
	SimExtra.Type.POWER: Color("ff7043"), SimExtra.Type.BOMB: Color("90a4ae"),
	SimExtra.Type.SKATEBOARD: Color("66bb6a"), SimExtra.Type.KICK: Color("42a5f5"),
	SimExtra.Type.GLOVE: Color("ab47bc"), SimExtra.Type.OVERDRIVE: Color("ffee58"),
	SimExtra.Type.REVERSE: Color("8d6e63"), SimExtra.Type.AUTOBOMB: Color("ec407a"),
}
const EXTRA_LETTERS := {
	SimExtra.Type.POWER: "P", SimExtra.Type.BOMB: "B", SimExtra.Type.SKATEBOARD: "S",
	SimExtra.Type.KICK: "K", SimExtra.Type.GLOVE: "G",
	SimExtra.Type.OVERDRIVE: "O", SimExtra.Type.REVERSE: "R", SimExtra.Type.AUTOBOMB: "A",
}
const ARROW_GLYPHS := {
	SimTile.Type.ARROW_LEFT: "<", SimTile.Type.ARROW_RIGHT: ">",
	SimTile.Type.ARROW_UP: "^", SimTile.Type.ARROW_DOWN: "v",
}

const DISEASES: Array[int] = [SimExtra.Type.OVERDRIVE, SimExtra.Type.REVERSE, SimExtra.Type.AUTOBOMB]

var world: SimWorld

var _static_root: Node3D
var _boxes: Dictionary = {}
var _bombs: Dictionary = {}
var _extras: Dictionary = {}
var _flames: Dictionary = {}
var _players: Dictionary = {}
var _time := 0.0

var _wall_mesh := BoxMesh.new()
var _box_mesh := BoxMesh.new()
var _bomb_mesh := SphereMesh.new()
var _flame_mesh := BoxMesh.new()
var _extra_mesh := BoxMesh.new()
var _materials: Dictionary = {}


func _ready() -> void:
	_wall_mesh.size = Vector3(1, 0.6, 1)
	_box_mesh.size = Vector3(0.88, 0.88, 0.88)
	_bomb_mesh.radius = 0.36
	_bomb_mesh.height = 0.72
	_flame_mesh.size = Vector3(0.9, 0.5, 0.9)
	_extra_mesh.size = Vector3(0.5, 0.5, 0.5)
	_setup_environment()


func _setup_environment() -> void:
	var camera := Camera3D.new()
	camera.fov = 45.0
	camera.current = true
	add_child(camera)
	var center := Vector3(SimConstants.GRID_WIDTH / 2.0, 0.0, SimConstants.GRID_HEIGHT / 2.0)
	var pitch := deg_to_rad(78.0)
	camera.position = center + Vector3(0, sin(pitch), cos(pitch)) * 17.5
	camera.rotation.x = -pitch
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, -30, 0)
	light.shadow_enabled = true
	add_child(light)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1b1b24")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.85)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func bind(p_world: SimWorld) -> void:
	world = p_world
	for node in [_static_root]:
		if node != null:
			node.queue_free()
	for dict: Dictionary in [_boxes, _bombs, _extras, _flames, _players]:
		for node: Node in dict.values():
			node.queue_free()
		dict.clear()
	_static_root = Node3D.new()
	add_child(_static_root)
	_build_board()
	for id: int in world.players:
		_players[id] = _make_player(id)
	visible = true


func _build_board() -> void:
	for y in world.board.height:
		for x in world.board.width:
			var cell := Vector2i(x, y)
			var tile := world.board.get_tile(cell)
			if tile == SimTile.Type.NONE:
				continue
			var center := Vector3(x + 0.5, 0, y + 0.5)
			if tile == SimTile.Type.WALL:
				_add_mesh(_static_root, _wall_mesh, _material(Color("5b6470")), center + Vector3(0, 0.3, 0))
				continue
			var floor_node: Node3D = FLOOR_SCENE.instantiate()
			floor_node.scale = Vector3.ONE * 0.25
			floor_node.position = center
			_static_root.add_child(floor_node)
			match tile:
				SimTile.Type.BOX:
					_boxes[cell] = _add_mesh(self, _box_mesh, _material(Color("b07a45")), center + Vector3(0, 0.44, 0))
				SimTile.Type.ICE:
					var ice := _add_plane(_material(Color(0.6, 0.85, 1.0, 0.55), true), center + Vector3(0, 0.02, 0))
					_static_root.add_child(ice)
				SimTile.Type.TRAP:
					var disc := MeshInstance3D.new()
					var cylinder := CylinderMesh.new()
					cylinder.top_radius = 0.34
					cylinder.bottom_radius = 0.34
					cylinder.height = 0.03
					disc.mesh = cylinder
					disc.material_override = _material(Color("2b1d17"))
					disc.position = center + Vector3(0, 0.02, 0)
					_static_root.add_child(disc)
				_:
					if ARROW_GLYPHS.has(tile):
						_add_floor_glyph(center, ARROW_GLYPHS[tile], tile)


func _add_floor_glyph(center: Vector3, glyph: String, tile: int) -> void:
	var label := Label3D.new()
	label.text = glyph
	label.font_size = 160
	label.pixel_size = 0.006
	label.modulate = Color("5d4037")
	label.outline_size = 0
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.position = center + Vector3(0, 0.03, 0)
	_static_root.add_child(label)


func _make_player(id: int) -> Node3D:
	var root := Node3D.new()
	var letter: String = CHARACTER_LETTERS[(id - 1) % CHARACTER_LETTERS.size()]
	var model: Node3D = load("%scharacter-%s.glb" % [CHARACTER_DIR, letter]).instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * 0.35
	root.add_child(model)
	var ring := MeshInstance3D.new()
	var torus := CylinderMesh.new()
	torus.top_radius = 0.42
	torus.bottom_radius = 0.42
	torus.height = 0.02
	ring.mesh = torus
	ring.material_override = _material(PLAYER_COLORS[(id - 1) % PLAYER_COLORS.size()])
	ring.position = Vector3(0, 0.02, 0)
	root.add_child(ring)
	var tag := Label3D.new()
	tag.name = "Tag"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 96
	tag.pixel_size = 0.006
	tag.position = Vector3(0, 1.25, 0)
	tag.no_depth_test = true
	root.add_child(tag)
	add_child(root)
	var animations := _animation_player(root)
	if animations != null:
		animations.play("idle")
	return root


func _animation_player(root: Node) -> AnimationPlayer:
	return root.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _process(delta: float) -> void:
	if world == null:
		return
	_time += delta
	_sync_boxes()
	_sync_bombs()
	_sync_extras()
	_sync_flames()
	_sync_players()


func _sync_boxes() -> void:
	for cell: Vector2i in _boxes.keys():
		if world.board.get_tile(cell) != SimTile.Type.BOX:
			_boxes[cell].queue_free()
			_boxes.erase(cell)


func _sync_bombs() -> void:
	var live: Dictionary = {}
	for bomb in world.bombs:
		live[bomb.id] = true
		if bomb.trapped:
			if _bombs.has(bomb.id):
				_bombs[bomb.id].visible = false
			continue
		var node: MeshInstance3D = _bombs.get(bomb.id)
		if node == null:
			node = _add_mesh(self, _bomb_mesh, _material(Color("202226")), Vector3.ZERO)
			_bombs[bomb.id] = node
		node.visible = true
		var lift := 0.4
		if bomb.flying or bomb.trap_flight:
			lift = 1.2
		var pulse := 1.0 + 0.08 * sin(bomb.timer_ms * 0.02)
		node.scale = Vector3.ONE * pulse
		node.position = _world_pos(Vector2(bomb.pos)) + Vector3(0, lift, 0)
	for id: int in _bombs.keys():
		if not live.has(id):
			_bombs[id].queue_free()
			_bombs.erase(id)


func _sync_extras() -> void:
	for cell: Vector2i in _extras.keys():
		if not world.extras.has(cell) or _extras[cell].get_meta("type") != world.extras[cell]:
			_extras[cell].queue_free()
			_extras.erase(cell)
	for cell: Vector2i in world.extras:
		if not _extras.has(cell):
			_extras[cell] = _make_extra(cell, world.extras[cell])
		var node: Node3D = _extras[cell]
		node.position.y = 0.45 + 0.08 * sin(_time * 3.0 + cell.x)
		node.rotation.y = _time * 1.5


func _make_extra(cell: Vector2i, type: int) -> Node3D:
	var root := Node3D.new()
	root.set_meta("type", type)
	root.position = Vector3(cell.x + 0.5, 0.45, cell.y + 0.5)
	_add_mesh(root, _extra_mesh, _material(EXTRA_COLORS.get(type, Color.WHITE)), Vector3.ZERO)
	for side in [0.0, PI]:
		var label := Label3D.new()
		label.text = EXTRA_LETTERS.get(type, "?")
		label.font_size = 128
		label.pixel_size = 0.0045
		label.modulate = Color.BLACK
		label.outline_size = 0
		label.position = Vector3(0, 0, 0.26 if side == 0.0 else -0.26)
		label.rotation.y = side
		root.add_child(label)
	add_child(root)
	return root


func _sync_flames() -> void:
	var cells: Dictionary = {}
	for explosion in world.explosions:
		for cell in explosion.cells:
			cells[cell] = true
	for cell: Vector2i in _flames.keys():
		if not cells.has(cell):
			_flames[cell].queue_free()
			_flames.erase(cell)
	for cell: Vector2i in cells:
		if not _flames.has(cell):
			var flame := _add_mesh(self, _flame_mesh, _flame_material(), Vector3(cell.x + 0.5, 0.3, cell.y + 0.5))
			_flames[cell] = flame
		_flames[cell].scale.y = 1.0 + 0.3 * sin(_time * 30.0 + cell.x * 2.0)


func _sync_players() -> void:
	for id: int in _players:
		var player: SimPlayer = world.players[id]
		var node: Node3D = _players[id]
		node.position = _world_pos(Vector2(player.pos))
		var face := Vector2(player.facing)
		node.get_node("Model").rotation.y = atan2(face.x, face.y)
		var anims := _animation_player(node)
		var wanted := "idle"
		if not player.alive:
			wanted = "die"
		elif player.moved:
			wanted = "sprint" if player.speed() > 130 else "walk"
		if anims != null and anims.current_animation != wanted:
			if anims.current_animation != "die":
				anims.play(wanted)
		var tag: Label3D = node.get_node("Tag")
		tag.visible = player.alive and player.is_diseased()
		if tag.visible:
			tag.text = EXTRA_LETTERS[player.disease]
			tag.modulate = EXTRA_COLORS[player.disease]


# Pixel (obere linke Ecke eines 40×40-Objekts) -> Mittelpunkt der Figur am Boden.
func _world_pos(pixel: Vector2) -> Vector3:
	return Vector3(pixel.x / CELL + 0.5, 0.0, pixel.y / CELL + 0.5)


func _add_mesh(parent: Node, mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	parent.add_child(node)
	return node


func _add_plane(material: Material, pos: Vector3) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1, 1)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	return node


func _material(color: Color, transparent := false) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(true), transparent]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = material
	return material


func _flame_material() -> StandardMaterial3D:
	var key := "flame"
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ff9f1c")
	material.emission_enabled = true
	material.emission = Color("ff6a00")
	material.emission_energy_multiplier = 2.0
	_materials[key] = material
	return material
