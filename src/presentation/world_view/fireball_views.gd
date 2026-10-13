class_name FireballViews
extends Node3D
## v0.7.5 BF1 (owner N15; BOSS_FIGHTS.md "Readable"): the hostile fireballs (WorldReader.projectile_look not empty;
## the plain shots stay ActorViews'). Hundreds at once, so each look is three MultiMeshes (one draw each): a bright
## unshaded core, a dark edge behind it (a bigger sphere drawn from the inside, so it rings the core) and a trail
## stretched back along the shot's way. Positions are blended between the last two ticks each frame (physics
## interpolation by hand: MultiMesh instances aren't nodes). Looks only: nothing here decides an outcome (EI-07).
## - Each boss and enemy has its own look (LOOKS, by the pattern's look key; an unknown key gets DEFAULT_LOOK, so a
##   new pattern draws before its look is made): colour, size, a spear tip (a longer core) and a trail.
## - Hostile fireballs never use the hero's attack colours (the cyan core, the heat tiers; a test pins the distance).
## - Effects density (ViewPrefs.effects_density): Low thins the trails (every other ball, shorter); the balls stay.

const LOOKS := {
	## Gatekeeper: grey-orange ember stones.
	&"ember_stone":
	{
		"core": Color("#FFBE85"),
		"edge": Color("#2A211C"),
		"trail": Color("#C0703A"),
		"size": 1.0,
		"tip": 1.0,
		"trail_m": 0.55,
	},
	## Warlord: red spear-tipped embers.
	&"spear_ember":
	{
		"core": Color("#FF7A6B"),
		"edge": Color("#3A0A10"),
		"trail": Color("#C2283A"),
		"size": 0.9,
		"tip": 1.9,
		"trail_m": 0.7,
	},
	## v0.7.5 BF2: Brood Mother: sickly green acid globs (fat, a short dripping trail).
	&"acid_glob":
	{
		"core": Color("#C8FF6A"),
		"edge": Color("#142A08"),
		"trail": Color("#6FA02A"),
		"size": 1.1,
		"tip": 1.0,
		"trail_m": 0.4,
	},
	## v0.7.5 BF2: Hive Lens: magenta-red prism orbs (small, a long bright trail).
	&"prism_orb":
	{
		"core": Color("#FF78D0"),
		"edge": Color("#3A0626"),
		"trail": Color("#C02A78"),
		"size": 0.9,
		"tip": 1.0,
		"trail_m": 0.75,
	},
}
const DEFAULT_LOOK := {
	"core": Color("#F0A890"),
	"edge": Color("#2A1416"),
	"trail": Color("#A04048"),
	"size": 1.0,
	"tip": 1.0,
	"trail_m": 0.5,
}
## Trail length and share by Effects density (low: every other ball, shorter).
const TRAIL_SCALE := {"low": 0.45, "medium": 0.75, "high": 1.0}
const HEIGHT := 0.55

## Per look: {"core", "edge", "trail": MultiMeshInstance3D}.
var _sets := {}
## This tick's and the last tick's positions by projectile id, and the order drawn this tick (per look).
var _now := {}
var _before := {}
var _drawn := {}
var _radius := {}
var _vel := {}
## Balls and trails drawn per look in the last draw (kept here: a headless renderer keeps no MultiMesh state).
var _balls := {}
var _trails := {}


func sync(reader: WorldReader) -> void:
	_before = _now
	_now = {}
	_drawn = {}
	for i in reader.projectile_count():
		var key := StringName(reader.projectile_look(i))
		if key == &"":
			continue
		var id := reader.projectile_id(i)
		var p := reader.projectile_pos(i)
		_now[id] = p
		_vel[id] = reader.projectile_vel(i)
		_radius[id] = reader.projectile_radius(i)
		if not _before.has(id):
			_before[id] = p  # a new ball appears where it spawned
		var list: PackedInt32Array = _drawn.get(key, PackedInt32Array())
		list.append(id)  # a packed array is a value: written back
		_drawn[key] = list
	for id in _vel.keys():
		if not _now.has(id):
			_vel.erase(id)
			_radius.erase(id)
	for key in _sets.keys():
		if not _drawn.has(key):
			_drawn[key] = PackedInt32Array()
	for key in _drawn:
		if not _sets.has(key):
			_sets[key] = _make_set(key)
	_draw(1.0)


func _process(_delta: float) -> void:
	if not _now.is_empty():
		_draw(Engine.get_physics_interpolation_fraction())


## How many fireballs are drawn now (tests and the tour).
func count() -> int:
	return _now.size()


## The look a key draws with (tests): LOOKS[key] or DEFAULT_LOOK.
static func look_of(key: StringName) -> Dictionary:
	return LOOKS.get(key, DEFAULT_LOOK)


## The instances the trails of a look draw now (tests: Effects density Low thins them).
func trail_count(key: StringName) -> int:
	return _trails.get(key, 0)


func ball_count(key: StringName) -> int:
	return _balls.get(key, 0)


func _draw(f: float) -> void:
	var trail_scale: float = TRAIL_SCALE.get(ViewPrefs.effects_density, 1.0)
	var thin := ViewPrefs.effects_density == "low"
	for key in _drawn:
		var ids: PackedInt32Array = _drawn[key]
		var look := look_of(key)
		var cores := PackedFloat32Array()
		var edges := PackedFloat32Array()
		var trails := PackedFloat32Array()
		var size: float = look["size"]
		for n in ids.size():
			var id := ids[n]
			var p: Vector2 = (_before.get(id, _now[id]) as Vector2).lerp(_now[id], f)
			var r: float = _radius.get(id, 0.18) * size
			var v: Vector2 = _vel.get(id, Vector2.RIGHT)
			var dir := v.normalized() if v.length() > 0.00001 else Vector2.RIGHT
			var at := SimPlane.to_3d(p, HEIGHT)
			var basis := _along(dir)
			cores.append_array(
				_row(Transform3D(_scaled(basis, Vector3(r * float(look["tip"]), r, r)), at))
			)
			edges.append_array(_row(Transform3D(_scaled(basis, Vector3.ONE * r * 1.3), at)))
			if thin and n % 2 == 1:
				continue
			var len: float = look["trail_m"] * trail_scale
			var back := SimPlane.to_3d(p - dir * (len * 0.5 + r * 0.6), HEIGHT)
			trails.append_array(
				_row(Transform3D(_scaled(basis, Vector3(len, r * 0.9, r * 0.9)), back))
			)
		_balls[key] = cores.size() / 12
		_trails[key] = trails.size() / 12
		_fill(_sets[key]["core"], cores)
		_fill(_sets[key]["edge"], edges)
		_fill(_sets[key]["trail"], trails)


## A basis whose x axis runs along the sim-plane direction `d`.
static func _along(d: Vector2) -> Basis:
	var x := SimPlane.to_3d(d) - SimPlane.to_3d(Vector2.ZERO)
	x = x.normalized()
	var y := Vector3.UP
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## The basis with its own axes scaled (x along the shot).
static func _scaled(b: Basis, s: Vector3) -> Basis:
	return Basis(b.x * s.x, b.y * s.y, b.z * s.z)


static func _row(t: Transform3D) -> PackedFloat32Array:
	var b := t.basis
	return PackedFloat32Array(
		[
			b.x.x,
			b.y.x,
			b.z.x,
			t.origin.x,
			b.x.y,
			b.y.y,
			b.z.y,
			t.origin.y,
			b.x.z,
			b.y.z,
			b.z.z,
			t.origin.z
		]
	)


static func _fill(mi: MultiMeshInstance3D, buf: PackedFloat32Array) -> void:
	var mm := mi.multimesh
	var n := buf.size() / 12
	if mm.instance_count < n:
		mm.instance_count = maxi(maxi(n, mm.instance_count * 2), 32)
	if n > 0:
		buf.resize(mm.instance_count * 12)  # the hidden tail is zeros
		mm.buffer = buf
	mm.visible_instance_count = n


func _make_set(key: StringName) -> Dictionary:
	var look := look_of(key)
	var out := {}
	var core := SphereMesh.new()
	core.radius = 1.0
	core.height = 2.0
	core.radial_segments = 10
	core.rings = 5
	var edge := SphereMesh.new()
	edge.radius = 1.0
	edge.height = 2.0
	edge.radial_segments = 10
	edge.rings = 5
	var trail := BoxMesh.new()
	trail.size = Vector3(1, 1, 1)
	var specs := [
		["core", core, _mat(look["core"], 2.4, false)],
		["edge", edge, _mat(look["edge"], 0.0, true)],
		["trail", trail, _mat(Color(look["trail"], 0.55), 1.2, false, true)],
	]
	for s: Array in specs:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = s[1]
		mm.instance_count = 32
		mm.visible_instance_count = 0
		var mi := MultiMeshInstance3D.new()
		mi.name = "%s_%s" % [key, s[0]]
		mi.multimesh = mm
		mi.material_override = s[2]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(mi)
		out[s[0]] = mi
	return out


func _mat(c: Color, energy: float, inside: bool, alpha: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
	if inside:
		m.cull_mode = BaseMaterial3D.CULL_FRONT  # only the far side: a dark ring round the core
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
