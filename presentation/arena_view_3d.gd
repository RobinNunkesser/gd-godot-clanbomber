class_name ArenaView3D
extends Node3D
## 2.5D-Präsentation mit Kenney-Assets (CC0). Liest nur den Zustand der Simulation. 1 Zelle = 1 Einheit, y ist oben.

const CELL := SimConstants.CELL_SIZE
const PLATFORMER_DIR := "res://assets/models/platformer/"
const CHARACTER_MODELS := ["oozi", "oobi", "oopi", "oodi", "human", "orc", "oozi", "oobi"]
const WALL_SCENE := preload("res://assets/models/mini-dungeon/wall.glb")
const TRAP_SCENE := preload("res://assets/models/mini-dungeon/trap.glb")
const BOX_SCENE := preload("res://assets/models/mini-dungeon/barrel.glb")
const BOMB_SCENE := preload("res://assets/models/platformer/bomb.glb")
const FLOOR_SCENE := preload("res://assets/models/mini-dungeon/floor.glb")
const PLAYER_COLORS: Array[Color] = [
	Color("e8504a"), Color("4a90e8"), Color("5bc45b"), Color("e8c84a"),
	Color("b06ae0"), Color("e88a4a"), Color("4ac8c8"), Color("d0d0d0"),
]
const EXTRA_MODELS := {
	SimExtra.Type.POWER: "res://assets/models/mini-dungeon/weapon-sword.glb",
	SimExtra.Type.BOMB: "res://assets/models/mini-dungeon/pot.glb",
	SimExtra.Type.SKATEBOARD: "res://assets/models/mini-dungeon/coin.glb",
	SimExtra.Type.KICK: "res://assets/models/mini-dungeon/weapon-spear.glb",
	SimExtra.Type.GLOVE: "res://assets/models/mini-dungeon/shield-round.glb",
	SimExtra.Type.OVERDRIVE: "res://assets/models/mini-dungeon/potion.glb",
	SimExtra.Type.REVERSE: "res://assets/models/mini-dungeon/potion.glb",
	SimExtra.Type.AUTOBOMB: "res://assets/models/mini-dungeon/potion.glb",
}
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
var _walls: Dictionary = {}
var _tile_roots: Dictionary = {}
var _observer: Node3D
var _bombs: Dictionary = {}
var _extras: Dictionary = {}
var _flames: Dictionary = {}
var _players: Dictionary = {}
var _time := 0.0

var _wall_mesh := BoxMesh.new()
var _box_mesh := BoxMesh.new()
var _bomb_mesh := SphereMesh.new()
var _materials: Dictionary = {}
var _effects := Effects3D.new()


func _ready() -> void:
	_wall_mesh.size = Vector3(1, 0.6, 1)
	_box_mesh.size = Vector3(0.88, 0.88, 0.88)
	_bomb_mesh.radius = 0.36
	_bomb_mesh.height = 0.72
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
	add_child(_effects)
	_effects.attach_camera(camera)
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
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func bind(p_world: SimWorld) -> void:
	world = p_world
	_connect_effects()
	for node in [_static_root]:
		if node != null:
			node.queue_free()
	if _observer != null:
		_observer.queue_free()
		_observer = null
	for dict: Dictionary in [_boxes, _walls, _tile_roots, _bombs, _extras, _flames, _players]:
		for node: Node in dict.values():
			node.queue_free()
		dict.clear()
	_static_root = Node3D.new()
	add_child(_static_root)
	_build_board()
	for id: int in world.players:
		_players[id] = _make_player(id)
	visible = true


func _connect_effects() -> void:
	world.bomb_exploded.connect(func(_b: SimBomb, e: SimExplosion) -> void: _effects.explosion(e.cells, e.origin))
	world.box_destroyed.connect(func(c: Vector2i) -> void: _effects.box_break(c))
	world.bomb_placed.connect(func(b: SimBomb) -> void: _effects.bomb_placed(_world_pos(Vector2(b.pos))))
	world.tile_vanishing.connect(func(c: Vector2i) -> void: _effects.tile_drop(c))
	world.extra_collected.connect(func(id: int, type: int) -> void:
		var player: SimPlayer = world.players[id]
		var color: Color = EXTRA_COLORS.get(type, Color.WHITE)
		_effects.pickup(_world_pos(Vector2(player.pos)), color))
	world.player_died.connect(func(id: int, _k: int) -> void:
		var player: SimPlayer = world.players[id]
		_effects.death(_world_pos(Vector2(player.pos)), PLAYER_COLORS[(id - 1) % PLAYER_COLORS.size()]))


func _build_board() -> void:
	for y in world.board.height:
		for x in world.board.width:
			var cell := Vector2i(x, y)
			var tile := world.board.get_tile(cell)
			if tile == SimTile.Type.WALL:
				_make_wall(cell)
			elif tile != SimTile.Type.NONE:
				_make_tile_root(cell, tile)


func _make_wall(cell: Vector2i) -> void:
	var wall: Node3D = WALL_SCENE.instantiate()
	wall.scale = Vector3(0.98, 1.0, 0.98)
	wall.position = Vector3(cell.x + 0.5, 0, cell.y + 0.5)
	_static_root.add_child(wall)
	_walls[cell] = wall


# Boden samt Markierung (Eis, Falle, Pfeil) in einem Knoten, damit er beim Verschwinden als Ganzes schrumpft.
func _make_tile_root(cell: Vector2i, tile: int) -> void:
	var root := Node3D.new()
	root.position = Vector3(cell.x + 0.5, 0, cell.y + 0.5)
	_static_root.add_child(root)
	_tile_roots[cell] = root
	var floor_node: Node3D = FLOOR_SCENE.instantiate()
	floor_node.scale = Vector3.ONE * 1.005
	root.add_child(floor_node)
	match tile:
		SimTile.Type.BOX:
			var crate: Node3D = BOX_SCENE.instantiate()
			crate.scale = Vector3.ONE * 1.75
			crate.position = root.position
			add_child(crate)
			_boxes[cell] = crate
		SimTile.Type.ICE:
			root.add_child(_add_plane(_material(Color(0.6, 0.85, 1.0, 0.55), true), Vector3(0, 0.02, 0)))
		SimTile.Type.TRAP:
			var trap: Node3D = TRAP_SCENE.instantiate()
			trap.scale = Vector3(0.9, 0.5, 0.9)
			root.add_child(trap)
		_:
			if ARROW_GLYPHS.has(tile):
				_add_floor_glyph(root, ARROW_GLYPHS[tile])


# Mauern verschwinden, neuer Boden entsteht, verschwindende Felder schrumpfen, Löcher sind leer.
func _sync_tiles() -> void:
	for cell: Vector2i in _walls.keys():
		if world.board.get_tile(cell) != SimTile.Type.WALL:
			_walls[cell].queue_free()
			_walls.erase(cell)
	for y in world.board.height:
		for x in world.board.width:
			var cell := Vector2i(x, y)
			var tile := world.board.get_tile(cell)
			if tile != SimTile.Type.WALL and tile != SimTile.Type.NONE and tile != SimTile.Type.VANISHING and not _tile_roots.has(cell):
				_make_tile_root(cell, tile)
	for cell: Vector2i in _tile_roots.keys():
		var root: Node3D = _tile_roots[cell]
		var tile := world.board.get_tile(cell)
		if tile == SimTile.Type.NONE:
			root.queue_free()
			_tile_roots.erase(cell)
		elif tile == SimTile.Type.VANISHING:
			var ratio := clampf(float(world.vanishing.get(cell, 0)) / SimConstants.VANISH_MS, 0.0, 1.0)
			root.scale = Vector3(ratio, 1.0, ratio)


func _add_floor_glyph(parent: Node3D, glyph: String) -> void:
	var label := Label3D.new()
	label.text = glyph
	label.font_size = 160
	label.pixel_size = 0.006
	label.modulate = Color("5d4037")
	label.outline_size = 0
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.position = Vector3(0, 0.03, 0)
	parent.add_child(label)


func _make_player(id: int) -> Node3D:
	var root := Node3D.new()
	var model: Node3D = load(_character_path(CHARACTER_MODELS[(id - 1) % CHARACTER_MODELS.size()])).instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * 0.85
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


func _character_path(name: String) -> String:
	if name == "human" or name == "orc":
		return "res://assets/models/mini-dungeon/character-%s.glb" % name
	return "%scharacter-%s.glb" % [PLATFORMER_DIR, name]


func _animation_player(root: Node) -> AnimationPlayer:
	return root.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _process(delta: float) -> void:
	if world == null:
		return
	_time += delta
	_sync_tiles()
	_sync_boxes()
	_sync_observer()
	_sync_bombs()
	_sync_extras()
	_sync_flames()
	_sync_players()


func _sync_observer() -> void:
	if _observer == null:
		_observer = _make_observer()
	_observer.visible = world.is_sudden_death()
	if not _observer.visible:
		return
	var pos := world.observer.position_px() / CELL
	_observer.position = Vector3(pos.x + 0.5, 1.4 + 0.15 * sin(_time * 4.0), pos.y + 0.5)
	_observer.rotation.y = _time * 2.0


func _make_observer() -> Node3D:
	var root := Node3D.new()
	var mesh := _add_mesh(root, _bomb_mesh, _flame_material(), Vector3.ZERO)
	mesh.scale = Vector3.ONE * 0.8
	var label := Label3D.new()
	label.text = "!"
	label.font_size = 128
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.0, 0)
	root.add_child(label)
	add_child(root)
	return root


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
		var node: Node3D = _bombs.get(bomb.id)
		if node == null:
			node = BOMB_SCENE.instantiate()
			add_child(node)
			_bombs[bomb.id] = node
		node.visible = true
		var lift := 0.0
		if bomb.flying or bomb.trap_flight:
			lift = 0.8
		var pulse := 1.0 + 0.08 * sin(bomb.timer_ms * 0.02)
		pulse *= 1.0 + 0.25 * maxf(1.0 - (SimConstants.BOMB_COUNTDOWN_MS - bomb.timer_ms) / 150.0, 0.0)
		node.scale = Vector3.ONE * 1.5 * pulse
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
		(node.get_meta("spinner") as Node3D).rotation.y = _time * 1.5


func _make_extra(cell: Vector2i, type: int) -> Node3D:
	var root := Node3D.new()
	root.set_meta("type", type)
	root.position = Vector3(cell.x + 0.5, 0.45, cell.y + 0.5)
	var model: Node3D = load(EXTRA_MODELS.get(type, "res://assets/models/mini-dungeon/potion.glb")).instantiate()
	var pivot := Node3D.new()
	pivot.rotation.x = 0.7
	root.add_child(pivot)
	var spinner := Node3D.new()
	pivot.add_child(spinner)
	spinner.add_child(model)
	root.set_meta("spinner", spinner)
	_fit_model(model, 1.0)
	if type in DISEASES:
		var tint := _material(EXTRA_COLORS[type])
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = tint
	var label := Label3D.new()
	label.text = EXTRA_LETTERS.get(type, "?")
	label.font_size = 128
	label.pixel_size = 0.0032
	label.modulate = EXTRA_COLORS.get(type, Color.WHITE)
	label.outline_size = 24
	label.outline_modulate = Color.BLACK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0, 1.0, 0)
	root.add_child(label)
	add_child(root)
	return root


# Scales the model so its largest dimension is `size` and centers it on the origin.
func _fit_model(model: Node3D, size: float) -> void:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b: AABB = m.global_transform * m.get_aabb() if m.is_inside_tree() else m.transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first or box.get_longest_axis_size() <= 0.0:
		return
	var k := size / box.get_longest_axis_size()
	model.scale = Vector3.ONE * k
	model.position = -box.get_center() * k


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
			var flame := _make_flame(Vector3(cell.x + 0.5, 0.0, cell.y + 0.5))
			flame.set_meta("born", _time)
			_flames[cell] = flame
		var grow := minf((_time - _flames[cell].get_meta("born")) * 12.0, 1.0)
		var flicker := 1.0 + 0.25 * sin(_time * 25.0 + cell.x * 2.0 + cell.y * 3.0)
		_flames[cell].scale = Vector3(grow, grow * flicker, grow)
		_flames[cell].rotation.y = _time * 3.0 + cell.x


# Flamme: großer orangeroter Kegel, darin gelber und weißer Kern, dazu aufsteigende Funken.
func _make_flame(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var layers := [[0.42, 0.95, Color("ff4d00")], [0.3, 0.75, Color("ffa500")], [0.16, 0.5, Color("fff2a8")]]
	for layer in layers:
		var cone := CylinderMesh.new()
		cone.bottom_radius = layer[0]
		cone.top_radius = 0.02
		cone.height = layer[1]
		cone.radial_segments = 8
		_add_mesh(root, cone, _glow_material(layer[2]), Vector3(0, layer[1] / 2.0, 0))
	var sparks := CPUParticles3D.new()
	sparks.amount = 6
	sparks.lifetime = 0.5
	sparks.direction = Vector3.UP
	sparks.spread = 25.0
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 2.0
	sparks.gravity = Vector3.ZERO
	sparks.position = Vector3(0, 0.3, 0)
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3.ONE * 0.07
	spark_mesh.material = _glow_material(Color("ffd24d"))
	sparks.mesh = spark_mesh
	root.add_child(sparks)
	add_child(root)
	return root


func _sync_players() -> void:
	for id: int in _players:
		var player: SimPlayer = world.players[id]
		var node: Node3D = _players[id]
		node.position = _world_pos(Vector2(player.pos))
		if player.is_falling():
			node.position.y = -1.5 * (1.0 - clampf(float(player.fall_ms) / SimConstants.FALL_MS, 0.0, 1.0))
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


func _glow_material(color: Color) -> StandardMaterial3D:
	var key := "glow_%s" % color.to_html(false)
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.5
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
