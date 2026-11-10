class_name AbilityVisuals
extends Node3D
## The abilities in the world. Reads WorldReader.ability_fx() only (EI-07); nothing here changes an
## outcome. Every shape is the sim's own number (bomb radius, blade points, shock radius).
## - Bombs: each bomb in flight arcs from where it left to where it lands, and its landing circle shows on the
##   ground from the throw (a ring with a fill that grows until it lands: the readable telegraph); a landing flashes
##   an orange disc.
## - Blink's landing shock and Combo Sword's finisher wave: a ring that flashes out to the shock's radius.
## Drone Buddy's bots and Orbit Blades' steel went with those abilities.

const BOMB_COLOR := Color("#FF8A3A")
const BLINK_COLOR := Color("#B48CFF")
const FX_FRAMES := 18
const RING_Y := 0.03
const BOMB_ARC_M := 2.4

## AttackFormView draws the bombs that name a spec (the LOB form) and every landing (WorldViewRoot sets
## it); this view keeps the drones, the orbit blades' steel and the rest.
var forms_drawn := false
var _bombs: Array[Node3D] = []
var _fx := FxFade.new()
var _fx_template := SkillVisuals._make_template()
var _ring_mat := _fx_template.duplicate() as StandardMaterial3D
var _fill_mat := _fx_template.duplicate() as StandardMaterial3D
var _bomb_mat := StandardMaterial3D.new()
var _last_blast := -1
var _bomb_keys := PackedStringArray()
var _last_shock := -1
var _last_echo_at := -1
var _last_echo := -1


func _init() -> void:
	name = "AbilityVisuals"
	_ring_mat.albedo_color = Color(BOMB_COLOR, 0.85)
	_fill_mat.albedo_color = Color(BOMB_COLOR, 0.22)
	_bomb_mat.albedo_color = Color("#2A2D33")


func sync(reader: WorldReader) -> void:
	var fx := reader.ability_fx()
	_bomb_keys = reader.bomb_spec_keys() if forms_drawn else PackedStringArray()
	_sync_bombs(fx, reader.tick())
	var bt: PackedInt32Array = fx["blast_tick"]
	var bp: PackedVector2Array = fx["blast_pos"]
	var br: PackedFloat32Array = fx["blast_r"]
	for k in bt.size():
		if bt[k] > _last_blast and not forms_drawn:
			_flash_disc(bp[k], br[k], BOMB_COLOR, &"blast")
	if not bt.is_empty():
		_last_blast = maxi(_last_blast, bt[bt.size() - 1])
	if int(fx["shock_tick"]) != _last_shock:
		_last_shock = int(fx["shock_tick"])
		if _last_shock >= 0:
			_flash_ring(fx["shock_pos"], float(fx["shock_r"]))
	_sync_echo(fx)


## v0.5.0 CP, Afterimage: a small ring where the echo waits, then a disc as it bursts (the sim's radius).
func _sync_echo(fx: Dictionary) -> void:
	if int(fx.get("echo_at", -1)) != _last_echo_at:
		_last_echo_at = int(fx["echo_at"])
		if _last_echo_at >= 0:
			_flash_ring(fx["echo_pos"], 0.45)
	if int(fx.get("echo_tick", -1)) != _last_echo:
		_last_echo = int(fx["echo_tick"])
		if _last_echo >= 0:
			_flash_disc(fx["echo_burst_pos"], float(fx["echo_r"]), BLINK_COLOR, &"afterimage")


# --- Reads (tests) ------------------------------------------------------------------------------------------


func fx_count_of(kind: StringName) -> int:
	return _fx.count_of(kind)


# --- Bombs --------------------------------------------------------------------------------------------------
func _sync_bombs(fx: Dictionary, tick: int) -> void:
	var at: PackedVector2Array = fx["bomb_pos"]
	var from: PackedVector2Array = fx["bomb_from"]
	var thrown: PackedInt32Array = fx["bomb_throw"]
	var land: PackedInt32Array = fx["bomb_land"]
	var radius: PackedFloat32Array = fx["bomb_r"]
	while _bombs.size() < at.size():
		var b := _make_bomb()
		add_child(b)
		_bombs.append(b)
	for k in _bombs.size():
		var b := _bombs[k]
		b.visible = k < at.size() and (k >= _bomb_keys.size() or _bomb_keys[k] == "")
		if not b.visible:
			continue
		var p := clampf(float(tick - thrown[k]) / maxf(1.0, float(land[k] - thrown[k])), 0.0, 1.0)
		b.position = SimPlane.to_3d(at[k], RING_Y)
		var ring: MeshInstance3D = b.get_node("Ring")
		var torus: TorusMesh = ring.mesh
		if not is_equal_approx(torus.outer_radius, radius[k]):
			torus.outer_radius = radius[k]
			torus.inner_radius = radius[k] - 0.07
		var fill: Node3D = b.get_node("Fill")
		var fr := maxf(radius[k] * p, 0.01)
		fill.scale = Vector3(fr, 1, fr)
		var ball: Node3D = b.get_node("Ball")
		var flat := from[k].lerp(at[k], p) - at[k]
		ball.position = Vector3(flat.x, 0.3 + BOMB_ARC_M * 4.0 * p * (1.0 - p), -flat.y)


func _make_bomb() -> Node3D:
	var root := Node3D.new()
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.rings = 40
	ring.mesh = torus
	ring.scale = Vector3(1, 0.05, 1)
	ring.material_override = _ring_mat
	root.add_child(ring)
	var fill := MeshInstance3D.new()
	fill.name = "Fill"
	var cyl := CylinderMesh.new()
	cyl.height = 0.005
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.radial_segments = 40
	fill.mesh = cyl
	fill.material_override = _fill_mat
	root.add_child(fill)
	var ball := MeshInstance3D.new()
	ball.name = "Ball"
	var s := SphereMesh.new()
	s.radius = 0.16
	s.height = 0.32
	s.radial_segments = 8
	s.rings = 4
	ball.mesh = s
	ball.material_override = _bomb_mat
	root.add_child(ball)
	var fuse := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.06, 0.06, 0.06)
	fuse.mesh = fb
	fuse.position = Vector3(0, 0.17, 0)
	var fm := _fx_template.duplicate() as StandardMaterial3D
	fm.albedo_color = BOMB_COLOR
	fuse.material_override = fm
	ball.add_child(fuse)
	for c in root.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


# --- Flashes ------------------------------------------------------------------------------------------------
func _flash_disc(at: Vector2, r: float, c: Color, kind: StringName, y: float = RING_Y) -> void:
	var n := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = 0.01
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.radial_segments = 32
	n.mesh = cyl
	n.position = SimPlane.to_3d(at, y)
	_add(n, c, 0.6, kind)


func _flash_ring(at: Vector2, r: float) -> void:
	var n := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.01, r - 0.12)
	torus.outer_radius = r
	torus.rings = 40
	n.mesh = torus
	n.scale = Vector3(1, 0.08, 1)
	n.position = SimPlane.to_3d(at, RING_Y + 0.02)
	_add(n, BLINK_COLOR, 0.9, &"shock")


func _add(n: MeshInstance3D, c: Color, alpha: float, kind: StringName) -> void:
	_fx.add(self, n, _fx_template, c, alpha, kind, FX_FRAMES)


func _process(_delta: float) -> void:
	_fx.step(1)
