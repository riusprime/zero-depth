class_name AbilityVisuals
extends Node3D
## The abilities in the world (v0.4.0 BS). Reads WorldReader.ability_fx() only (EI-07); nothing here changes an
## outcome. Every shape is the sim's own number (bomb radius, blade points, shock radius).
## - Bomb Lobber: each bomb in flight arcs from where it left to where it lands, and its landing circle shows on the
##   ground from the throw (a ring with a fill that grows until it lands: the readable telegraph); a landing flashes
##   an orange disc.
## - Drone Buddy: a small low-poly hovering bot in the hero's palette (white shell, cyan visor and rotor) at each
##   drone's sim position, bobbing; a cyan flash at its muzzle when it fires, a cyan line when a bolt chains.
## - Orbit Blades: a flat steel blade at each blade point, edge-on along the ring.
## - Blink's landing shock and Combo Sword's finisher wave: a ring that flashes out to the shock's radius.

const BOMB_COLOR := Color("#FF8A3A")
const BLINK_COLOR := Color("#B48CFF")
const FX_FRAMES := 18
const RING_Y := 0.03
const DRONE_Y := 1.35
const BOMB_ARC_M := 2.4

var _drones: Array[Node3D] = []
var _blades: Array[MeshInstance3D] = []
var _bombs: Array[Node3D] = []
var _fx: Array = []
var _fx_template := SkillVisuals._make_template()
var _blade_mesh := PrismMesh.new()
var _blade_mat := StandardMaterial3D.new()
var _ring_mat := _fx_template.duplicate() as StandardMaterial3D
var _fill_mat := _fx_template.duplicate() as StandardMaterial3D
var _bomb_mat := StandardMaterial3D.new()
var _shell_mat := StandardMaterial3D.new()
var _core_mat := StandardMaterial3D.new()
var _last_blast := -1
var _last_shock := -1
var _last_chain := -1
var _drone_fire := PackedInt32Array()
var _t := 0.0


func _init() -> void:
	name = "AbilityVisuals"
	_blade_mesh.size = Vector3(0.62, 0.05, 0.16)
	_blade_mat.albedo_color = Color("#D6E4F0")
	_blade_mat.metallic = 0.6
	_blade_mat.roughness = 0.3
	_ring_mat.albedo_color = Color(BOMB_COLOR, 0.85)
	_fill_mat.albedo_color = Color(BOMB_COLOR, 0.22)
	_bomb_mat.albedo_color = Color("#2A2D33")
	_shell_mat.albedo_color = ThemePalette.color(&"player_body")
	_shell_mat.roughness = 0.8
	_core_mat.albedo_color = ThemePalette.color(&"player_core")
	_core_mat.emission_enabled = true
	_core_mat.emission = ThemePalette.color(&"player_core")
	_core_mat.emission_energy_multiplier = 1.4


func sync(reader: WorldReader) -> void:
	var fx := reader.ability_fx()
	_sync_drones(fx)
	_sync_blades(fx)
	_sync_bombs(fx, reader.tick())
	var bt: PackedInt32Array = fx["blast_tick"]
	var bp: PackedVector2Array = fx["blast_pos"]
	var br: PackedFloat32Array = fx["blast_r"]
	for k in bt.size():
		if bt[k] > _last_blast:
			_flash_disc(bp[k], br[k], BOMB_COLOR, &"blast")
	if not bt.is_empty():
		_last_blast = maxi(_last_blast, bt[bt.size() - 1])
	if int(fx["shock_tick"]) != _last_shock:
		_last_shock = int(fx["shock_tick"])
		if _last_shock >= 0:
			_flash_ring(fx["shock_pos"], float(fx["shock_r"]))
	if int(fx["chain_tick"]) != _last_chain:
		_last_chain = int(fx["chain_tick"])
		if _last_chain >= 0:
			_line(fx["chain_from"], fx["chain_to"])


# --- Reads (tests) ------------------------------------------------------------------------------------------
func drone_count() -> int:
	return _drones.filter(func(d: Node3D) -> bool: return d.visible).size()


func blade_count() -> int:
	return _blades.filter(func(b: MeshInstance3D) -> bool: return b.visible).size()


func bomb_count() -> int:
	return _bombs.filter(func(b: Node3D) -> bool: return b.visible).size()


## The ground circle's radius of bomb k as drawn (the sim's bomb radius).
func bomb_ring_radius(k: int) -> float:
	return ((_bombs[k].get_node("Ring") as MeshInstance3D).mesh as TorusMesh).outer_radius


func fx_count_of(kind: StringName) -> int:
	return _fx.filter(func(f: Array) -> bool: return f[4] == kind).size()


# --- Drones -------------------------------------------------------------------------------------------------
func _sync_drones(fx: Dictionary) -> void:
	var pts: PackedVector2Array = fx["drones"]
	var fires: PackedInt32Array = fx["drone_fire"]
	while _drones.size() < pts.size():
		var d := _make_drone()
		add_child(d)
		_drones.append(d)
		_drone_fire.append(-1)
	for k in _drones.size():
		var d := _drones[k]
		d.visible = k < pts.size()
		if not d.visible:
			continue
		var bob := sin(_t * 3.0 + k * 1.7) * 0.08
		var to := SimPlane.to_3d(pts[k], DRONE_Y + bob)
		var step := to - d.position
		d.position = to
		if Vector2(step.x, step.z).length() > 0.002:
			d.rotation.y = atan2(-step.z, step.x)
		d.get_node("Rotor").rotation.y = _t * 22.0
		if k < fires.size() and fires[k] != _drone_fire[k]:
			_drone_fire[k] = fires[k]
			if fires[k] >= 0:
				_flash_disc(pts[k], 0.22, ThemePalette.color(&"player_core"), &"muzzle", DRONE_Y)


## A hovering bot: a faceted white shell, a cyan visor band, a rotor disc on a short mast and two stub legs.
func _make_drone() -> Node3D:
	var root := Node3D.new()
	root.name = "Drone"
	var shell := MeshInstance3D.new()
	var body := SphereMesh.new()
	body.radius = 0.2
	body.height = 0.32
	body.radial_segments = 8
	body.rings = 3
	shell.mesh = body
	shell.material_override = _shell_mat
	root.add_child(shell)
	var visor := MeshInstance3D.new()
	var vb := BoxMesh.new()
	vb.size = Vector3(0.1, 0.07, 0.3)
	visor.mesh = vb
	visor.position = Vector3(0.15, 0.02, 0)
	visor.material_override = _core_mat
	root.add_child(visor)
	var mast := MeshInstance3D.new()
	var mb := CylinderMesh.new()
	mb.top_radius = 0.02
	mb.bottom_radius = 0.02
	mb.height = 0.14
	mast.mesh = mb
	mast.position = Vector3(0, 0.2, 0)
	mast.material_override = _shell_mat
	root.add_child(mast)
	var rotor := MeshInstance3D.new()
	rotor.name = "Rotor"
	var rb := BoxMesh.new()
	rb.size = Vector3(0.46, 0.015, 0.06)
	rotor.mesh = rb
	rotor.position = Vector3(0, 0.27, 0)
	rotor.material_override = _core_mat
	root.add_child(rotor)
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.05, 0.12, 0.05)
		leg.mesh = lb
		leg.position = Vector3(-0.04, -0.18, side * 0.1)
		leg.material_override = _shell_mat
		root.add_child(leg)
	for c in root.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


# --- Orbit Blades -------------------------------------------------------------------------------------------
func _sync_blades(fx: Dictionary) -> void:
	var pts: PackedVector2Array = fx["blades"]
	while _blades.size() < pts.size():
		var b := MeshInstance3D.new()
		b.mesh = _blade_mesh
		b.material_override = _blade_mat
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(b)
		_blades.append(b)
	for k in _blades.size():
		var b := _blades[k]
		b.visible = k < pts.size()
		if b.visible:
			var rv := pts[k] - _centre(pts)  # edge-on along the ring: the tangent's yaw
			b.position = SimPlane.to_3d(pts[k], SimPlane.CORE_HEIGHT)
			b.rotation = Vector3(0, atan2(rv.x, -rv.y), 0)


static func _centre(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / maxf(1.0, pts.size())


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
		b.visible = k < at.size()
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


func _line(from: Vector2, to: Vector2) -> void:
	var d := to - from
	if d.length() < 0.05:
		return
	var n := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	n.mesh = box
	n.position = SimPlane.to_3d((from + to) * 0.5, SimPlane.CORE_HEIGHT)
	n.rotation = Vector3(0, atan2(d.y, d.x), 0)
	n.scale = Vector3(d.length(), 0.05, 0.05)
	_add(n, ThemePalette.color(&"player_core"), 0.95, &"chain")


func _add(n: MeshInstance3D, c: Color, alpha: float, kind: StringName) -> void:
	var m := _fx_template.duplicate() as StandardMaterial3D
	m.albedo_color = Color(c, alpha)
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(n)
	_fx.append([n, m, FX_FRAMES, FX_FRAMES, kind, alpha])


func _process(delta: float) -> void:
	_t += delta
	for k in range(_fx.size() - 1, -1, -1):
		var fx: Array = _fx[k]
		fx[2] -= 1
		(fx[1] as StandardMaterial3D).albedo_color.a = fx[5] * float(fx[2]) / fx[3]
		if fx[2] <= 0:
			(fx[0] as Node).queue_free()
			_fx.remove_at(k)
