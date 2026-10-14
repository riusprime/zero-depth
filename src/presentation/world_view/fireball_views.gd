class_name FireballViews
extends Node3D
## v0.7.5 BF1 (owner N15; BOSS_FIGHTS.md "Readable"): the hostile fireballs (WorldReader.projectile_look not empty;
## the plain shots stay ActorViews'). Hundreds at once, so each look is three MultiMeshes (one draw each): the core,
## a dark edge behind it (a bigger copy drawn from the inside, so it rings the core) and a trail stretched back along
## the shot's way. Positions are blended between the last two ticks each frame (physics interpolation by hand:
## MultiMesh instances aren't nodes). Looks only: nothing here decides an outcome (EI-07).
## - Each boss and enemy has its own look (LOOKS, by the pattern's look key; an unknown key gets DEFAULT_LOOK, so a
##   new pattern draws before its look is made): colour, size, a spear tip (a longer core) and a trail.
## - Hostile fireballs never use the hero's attack colours (the cyan core, the heat tiers; a test pins the distance).
## - Effects density (ViewPrefs.effects_density): Low thins the trails (every other ball, narrower); the balls stay.
## - v0.7.5 EF (owner N16): the enemies' looks (Arc Caster, Lens Drone, Bomb Drone), and the Bomb Drone's lobbed
##   fireball in the air (its telegraph's "lob", drawn as a bigger ball of its look on an arc; no ground circle).
## - v0.7.5 BF3: a look with "smoke" draws its trail as unlit smoke (no glow; the Siege Engine's cannon embers), and
##   a raining pattern's drops in the air (WorldReader.boss_rain: the Foundry's Slag Fountain) are drawn in their
##   pattern's look on an arc up from the boss and down to where they land (they hurt only once landed).
## - v0.8.0 AV (owner O8: "the orbs that they throw, they're 2D shit looking … actual 3D objects in the game"): every
##   look is a lit 3D body from ProjectileMeshes (stone chunks, spear heads, gems, plasma orbs, wobbling globs, molten
##   drops) with FireballShaders' noise swirl, veins, fresnel rim to the dark edge and its own turn; the trail is a
##   tapered strip facing the camera (glowing, smoke, or drips). The big ones (a lobbed fireball, a raining drop, a
##   boss's signature shots) ask VfxCore for a small light within its budget (draw_lights, a VfxCore drawer).
##   Reduced motion stills the swirl, the turning and the wobble.

## v0.8.0 AV (owner O8): each look is a real 3D body (FireballShaders, ProjectileMeshes): "mesh" its shape, "body"
## its lit surface, "energy" its glow, "crack" how much of it glows only in veins (stone, crust) rather than all
## over (plasma), "swirl" the noise speed inside, "spin" / "tumble" its own turn, "wobble" (a glob), "facets" (a gem's
## glints), "opacity" (< 1: translucent), and its trail: "trail_style" &"glow" (additive), &"smoke" (unlit, mixed,
## widening) or &"drips" (broken into drops), "tail" the strip's width at its end.
const LOOKS := {
	## Gatekeeper: rocky glowing chunks of stone, ember veins, tumbling.
	&"ember_stone":
	{
		"core": Color("#FFBE85"),
		"edge": Color("#2A211C"),
		"trail": Color("#C0703A"),
		"size": 1.0,
		"tip": 1.0,
		"trail_m": 0.55,
		"mesh": &"rock",
		"body": Color("#54483F"),
		"energy": 2.4,
		"crack": 1.0,
		"swirl": 0.6,
		"spin": 2.2,
		"tumble": 1.6,
		"trail_style": &"glow",
		"tail": 0.3,
	},
	## Warlord: red spear-tipped embers, long four-sided heads turning about their flight.
	&"spear_ember":
	{
		"core": Color("#FF7A6B"),
		"edge": Color("#3A0A10"),
		"trail": Color("#C2283A"),
		"size": 0.9,
		"tip": 1.9,
		"trail_m": 0.7,
		"mesh": &"spear",
		"body": Color("#5A1A20"),
		"energy": 2.8,
		"crack": 0.35,
		"swirl": 1.2,
		"spin": 5.0,
		"trail_style": &"glow",
		"tail": 0.15,
	},
	## v0.7.5 EF. Arc Caster: blue-white plasma balls, a long cold trail.
	&"arc_plasma":
	{
		"core": Color("#C8DCFF"),
		"edge": Color("#0C1830"),
		"trail": Color("#6E9CFF"),
		"size": 1.0,
		"tip": 1.15,
		"trail_m": 0.65,
		"mesh": &"orb",
		"energy": 3.6,
		"swirl": 3.0,
		"trail_style": &"glow",
		"tail": 0.2,
	},
	## v0.7.5 EF. Lens Drone: small red orbs, a rose-white core and a short crimson trail.
	&"lens_orb":
	{
		"core": Color("#FFA0A8"),
		"edge": Color("#2A0008"),
		"trail": Color("#D0102A"),
		"size": 0.8,
		"tip": 1.0,
		"trail_m": 0.3,
		"mesh": &"orb",
		"energy": 3.0,
		"swirl": 1.2,
		"trail_style": &"glow",
		"tail": 0.35,
	},
	## v0.7.5 EF. Bomb Drone: violet fuse-fire cinders (and the lobbed fireball they burst from).
	&"bomb_cinder":
	{
		"core": Color("#E9B8FF"),
		"edge": Color("#1E0A2A"),
		"trail": Color("#9A4AE0"),
		"size": 1.05,
		"tip": 1.0,
		"trail_m": 0.45,
		"mesh": &"orb",
		"body": Color("#3A1A4A"),
		"energy": 3.0,
		"crack": 0.3,
		"swirl": 2.2,
		"trail_style": &"glow",
		"tail": 0.3,
	},
	## v0.7.5 BF2: Brood Mother: sickly green acid globs (fat, wobbly, see-through; dripping).
	&"acid_glob":
	{
		"core": Color("#C8FF6A"),
		"edge": Color("#142A08"),
		"trail": Color("#6FA02A"),
		"size": 1.1,
		"tip": 1.0,
		"trail_m": 0.4,
		"mesh": &"glob",
		"body": Color("#3A6A12"),
		"energy": 1.7,
		"swirl": 0.8,
		"wobble": 0.12,
		"opacity": 0.72,
		"trail_style": &"drips",
		"tail": 0.6,
	},
	## v0.7.5 BF2: Hive Lens: magenta-red prism orbs (faceted gems with glints; a long bright trail).
	&"prism_orb":
	{
		"core": Color("#FF78D0"),
		"edge": Color("#3A0626"),
		"trail": Color("#C02A78"),
		"size": 0.9,
		"tip": 1.0,
		"trail_m": 0.75,
		"mesh": &"gem",
		"body": Color("#6A1048"),
		"energy": 2.6,
		"crack": 0.2,
		"swirl": 0.8,
		"spin": 3.5,
		"facets": 0.6,
		"trail_style": &"glow",
		"tail": 0.1,
	},
	## v0.8.0 FB2: the Prism (the final boss's second body): her shards' orbs, deep red crystal gems turning as they
	## drift, a crimson trail (redder and darker than the Hive Lens's magenta prism orbs).
	&"crown_orb":
	{
		"core": Color("#F02848"),
		"edge": Color("#2A0610"),
		"trail": Color("#B81C38"),
		"size": 1.0,
		"tip": 1.0,
		"trail_m": 0.6,
		"mesh": &"gem",
		"body": Color("#6A0E22"),
		"energy": 2.8,
		"crack": 0.2,
		"swirl": 0.7,
		"spin": 2.6,
		"facets": 0.8,
		"trail_style": &"glow",
		"tail": 0.15,
	},
	## v0.8.0 FB2: the Prism's fast bolts: long white-hot crystal spears with a long red streak behind.
	&"crown_bolt":
	{
		"core": Color("#FFD6DC"),
		"edge": Color("#3A0814"),
		"trail": Color("#FF3A58"),
		"size": 0.95,
		"tip": 2.4,
		"trail_m": 1.6,
		"mesh": &"spear",
		"body": Color("#7A1A2A"),
		"energy": 3.6,
		"crack": 0.3,
		"swirl": 1.6,
		"spin": 6.0,
		"trail_style": &"glow",
		"tail": 0.1,
	},
	## v0.8.0 FB3: the Nemesis's copies of the hero's shots: the hero's bolt as a pale violet spear on a black body (never
	## the hero's cyan), and the hero's flying slash as a black crescent with a hot magenta-violet core.
	&"nemesis_bolt":
	{
		"core": Color("#B4A0FF"),
		"edge": Color("#12061E"),
		"trail": Color("#5A1AB0"),
		"size": 0.9,
		"tip": 1.8,
		"trail_m": 0.9,
		"mesh": &"spear",
		"body": Color("#22102E"),
		"energy": 3.0,
		"crack": 0.3,
		"swirl": 1.2,
		"spin": 4.0,
		"trail_style": &"glow",
		"tail": 0.1,
	},
	&"nemesis_crescent":
	{
		"core": Color("#E07CFF"),
		"edge": Color("#0E0414"),
		"trail": Color("#7A0AA0"),
		"size": 1.6,
		"tip": 1.0,
		"trail_m": 0.6,
		"mesh": &"crescent",
		"body": Color("#1A0A24"),
		"energy": 2.6,
		"crack": 0.6,
		"swirl": 0.9,
		"spin": 0.0,
		"trail_style": &"glow",
		"tail": 0.4,
	},
	## v0.7.5 BF3: Siege Engine: orange cannon embers with a smoke trail.
	&"cannon_ember":
	{
		"core": Color("#D79000"),
		"edge": Color("#2E1A0E"),
		"trail": Color("#5A524C"),
		"size": 1.2,
		"tip": 1.15,
		"trail_m": 0.9,
		"smoke": true,
		"mesh": &"rock",
		"body": Color("#5A4C40"),
		"energy": 3.0,
		"crack": 0.6,
		"swirl": 1.4,
		"spin": 1.2,
		"tumble": 0.8,
		"trail_style": &"smoke",
		"tail": 1.8,
	},
	## v0.7.5 BF3: Foundry: white-yellow molten drops, a crust over the glow, drips behind.
	&"molten_drop":
	{
		"core": Color("#FFF07A"),
		"edge": Color("#2A1C06"),
		"trail": Color("#FFB830"),
		"size": 1.05,
		"tip": 1.3,
		"trail_m": 0.45,
		"mesh": &"drop",
		"body": Color("#5A3A10"),
		"energy": 3.4,
		"crack": 0.4,
		"swirl": 1.0,
		"trail_style": &"drips",
		"tail": 0.5,
	},
}
const DEFAULT_LOOK := {
	"core": Color("#F0A890"),
	"edge": Color("#2A1416"),
	"trail": Color("#A04048"),
	"size": 1.0,
	"tip": 1.0,
	"trail_m": 0.5,
	"mesh": &"orb",
	"energy": 2.6,
	"trail_style": &"glow",
	"tail": 0.3,
}
## Trail length and share by Effects density (low: every other ball, shorter).
const TRAIL_SCALE := {"low": 0.45, "medium": 0.75, "high": 1.0}
## v0.8.0 AV: the trail strip's width by Effects density (low: thin; the balls stay).
const TRAIL_WIDTH := {"low": 0.55, "medium": 0.8, "high": 1.0}
## v0.8.0 AV: the lights the big ones ask VfxCore for (its budget; the brightest requests win): a lobbed fireball or a
## raining drop each (merged within LIGHT_MERGE m), and a boss's signature shots (merged clusters, at most
## SIGNATURE_LIGHTS of them).
const LIGHT_ENERGY := 1.6
const LIGHT_RANGE := 3.5
const LIGHT_MERGE := 2.5
const SIGNATURE_LIGHTS := 3
const SIGNATURE_ENERGY := 0.9
## v0.8.0 AV: the dark shell's size over the core's.
const EDGE_SCALE := 1.15
const HEIGHT := 0.55
## v0.7.5 EF: a lobbed fireball's radius (metres) and how high its arc rises over HEIGHT at the middle of its flight.
const LOB_RADIUS := 0.3
const LOB_RISE := 1.4

## v0.7.5 BF3: a raining drop leaves the boss this high and peaks this much above its straight path.
const RAIN_FROM_Y := 2.6
const RAIN_ARC_Y := 2.2

## v0.8.0 AV: the effects layer the big ones ask for light from (WorldViewRoot sets it with the new look; null: none).
var vfx: VfxCore
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
## v0.7.5 EF: the lobbed fireballs in the air this tick, per look (3D positions).
var _lobs := {}

## v0.7.5 BF3: the raining drops this tick, per look: [from, to, progress, progress a tick, radius] each.
var _rain := {}
## v0.8.0 AV: the light requests of the last draw: [position, colour, energy, range, merge] each.
var _light_wants: Array = []
## v0.8.0 AV: the look of the boss's signature pattern while it fires (its shots get lights), else &"".
var _signature := &""
var _motion := -1.0
## v0.8.0 AV: the trail strips' width factor in the last draw (tests: Low narrows them).
var _trail_width := 1.0


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
	_sync_lobs(reader)
	_rain = {}
	var b := reader.boss_index()
	if b >= 0:
		var pat := reader.boss_pattern(b)
		var drops := reader.boss_rain(b)
		if not drops.is_empty():
			var rkey := StringName(pat.get("look", &""))
			_rain[rkey] = drops
			if not _drawn.has(rkey):
				_drawn[rkey] = PackedInt32Array()
		if pat.get("shielded", false) and not pat.get("winding", true):
			_signature = StringName(pat.get("look", &""))
	if _signature != &"" and not _drawn.has(_signature):
		_signature = &""  # its shots are gone
	for key in _sets.keys():
		if not _drawn.has(key):
			_drawn[key] = PackedInt32Array()
	for key in _drawn:
		if not _sets.has(key):
			_sets[key] = _make_set(key)
	_draw(1.0)


func _process(_delta: float) -> void:
	if not _now.is_empty() or not _lobs.is_empty() or not _rain.is_empty():
		_draw(Engine.get_physics_interpolation_fraction())


## How many fireballs are drawn now (tests and the tour).
func count() -> int:
	return _now.size()


## v0.7.5 EF: how many lobbed fireballs are in the air now (tests).
func lob_count() -> int:
	var n := 0
	for key in _lobs:
		n += (_lobs[key] as Array).size()
	return n


## v0.7.5 EF: the Bomb Drones' fireballs in the air (their telegraph's "lob": from the drone to where it lands, on an
## arc), each a bigger ball of its look.
func _sync_lobs(reader: WorldReader) -> void:
	_lobs = {}
	for i in reader.actor_count():
		if reader.actor_kind(i) != WorldReader.KIND_BOMB_DRONE:
			continue
		var tg := reader.telegraph(i)
		if tg.get("shape", &"") != &"lob":
			continue
		var key := StringName(tg.get("look", &""))
		var p := float(tg["progress"]) / 1000.0
		var at := (tg["from"] as Vector2).lerp(tg["to"], p)
		var list: Array = _lobs.get(key, [])
		list.append(SimPlane.to_3d(at, HEIGHT + LOB_RISE * 4.0 * p * (1.0 - p)))
		_lobs[key] = list
		if not _drawn.has(key):
			_drawn[key] = PackedInt32Array()


## The look a key draws with (tests): LOOKS[key] or DEFAULT_LOOK.
static func look_of(key: StringName) -> Dictionary:
	return LOOKS.get(key, DEFAULT_LOOK)


## The instances the trails of a look draw now (tests: Effects density Low thins them).
func trail_count(key: StringName) -> int:
	return _trails.get(key, 0)


func ball_count(key: StringName) -> int:
	return _balls.get(key, 0)


## v0.7.5 BF3: raining drops drawn in the air now (tests and the tour).
func rain_count() -> int:
	var n := 0
	for key in _rain:
		n += (_rain[key] as Array).size()
	return n


## v0.8.0 AV: the trail strips' width factor in the last draw (TRAIL_WIDTH by density; tests).
func trail_width() -> float:
	return _trail_width


## v0.8.0 AV: the lights the big ones asked for in the last draw (tests).
func light_requests() -> int:
	return _light_wants.size()


## v0.8.0 AV: a VfxCore drawer (WorldViewRoot adds it): the big ones' lights, into the layer's light budget.
func draw_lights(layer: VfxCore) -> void:
	for w: Array in _light_wants:
		layer.light_merged(w[0], w[1], w[2], w[3], w[4])


## v0.7.5 BF3: where a raining drop is drawn at progress f (0 leaving the boss, 1 landing): along the ground from
## `from` to `to`, from RAIN_FROM_Y down to the fireballs' height, on an arc RAIN_ARC_Y high.
static func rain_point(from: Vector2, to: Vector2, f: float) -> Vector3:
	var g := clampf(f, 0.0, 1.0)
	var y := lerpf(RAIN_FROM_Y, HEIGHT, g) + 4.0 * RAIN_ARC_Y * g * (1.0 - g)
	return SimPlane.to_3d(from.lerp(to, g), y)


func _draw(f: float) -> void:
	var trail_scale: float = TRAIL_SCALE.get(ViewPrefs.effects_density, 1.0)
	var width: float = TRAIL_WIDTH.get(ViewPrefs.effects_density, 1.0)
	var thin := ViewPrefs.effects_density == "low"
	_trail_width = width
	_update_motion()
	_light_wants.clear()
	for key in _drawn:
		var ids: PackedInt32Array = _drawn[key]
		var look := look_of(key)
		var cores := PackedFloat32Array()
		var edges := PackedFloat32Array()
		var trails := PackedFloat32Array()
		var size: float = look["size"]
		var glow: Color = look["core"]
		var signature: bool = key == _signature
		var lit := 0
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
			edges.append_array(
				_row(
					Transform3D(
						_scaled(basis, Vector3(r * float(look["tip"]), r, r) * EDGE_SCALE), at
					)
				)
			)
			if signature and lit < SIGNATURE_LIGHTS and n % 6 == 0:
				lit += 1
				_light_wants.append([at, glow, SIGNATURE_ENERGY, LIGHT_RANGE, LIGHT_MERGE * 1.6])
			if thin and n % 2 == 1:
				continue
			var len: float = look["trail_m"] * trail_scale
			var back := SimPlane.to_3d(p - dir * (len * 0.5 + r * 0.6), HEIGHT)
			trails.append_array(
				_row(
					Transform3D(
						_scaled(basis, Vector3(len, r * 1.7 * width, r * 1.7 * width)), back
					)
				)
			)
		for at: Vector3 in _lobs.get(key, []):
			var lr := LOB_RADIUS * size
			cores.append_array(_row(Transform3D(Basis().scaled(Vector3.ONE * lr), at)))
			edges.append_array(_row(Transform3D(Basis().scaled(Vector3.ONE * lr * EDGE_SCALE), at)))
			_light_wants.append([at, glow, LIGHT_ENERGY, LIGHT_RANGE, LIGHT_MERGE])
		for d: Array in _rain.get(key, []):  # v0.7.5 BF3: the drops in the air, on their arc
			var r: float = 0.22 * size
			var at := rain_point(d[0], d[1], d[2] + d[3] * f)
			cores.append_array(_row(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r), at)))
			edges.append_array(
				_row(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r * EDGE_SCALE), at))
			)
			_light_wants.append([at, glow, LIGHT_ENERGY, LIGHT_RANGE, LIGHT_MERGE])
		_balls[key] = cores.size() / 12
		_trails[key] = trails.size() / 12
		_fill(_sets[key]["core"], cores)
		_fill(_sets[key]["edge"], edges)
		_fill(_sets[key]["trail"], trails)


## v0.8.0 AV: reduced motion stills the swirl, the turning and the wobble (set on every look when it changes).
func _update_motion() -> void:
	var m := 0.0 if ViewPrefs.reduced_motion else 1.0
	if m == _motion:
		return
	_motion = m
	for key in _sets:
		for part in ["core", "edge", "trail"]:
			var mat := (_sets[key][part] as MultiMeshInstance3D).material_override as ShaderMaterial
			mat.set_shader_parameter("motion", m)


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
	var mesh := ProjectileMeshes.get_mesh(look.get("mesh", &"orb"))
	var specs := [
		["core", mesh, core_material(look)],
		["edge", mesh, edge_material(look)],
		["trail", ProjectileMeshes.get_mesh(&"ribbon"), trail_material(look)],
	]
	var out := {}
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
		mi.extra_cull_margin = 2.0  # the shaders turn and stretch the pieces past their boxes
		add_child(mi)
		out[s[0]] = mi
	_motion = -1.0  # the new set takes the current motion on the next draw
	return out


## v0.8.0 AV: a look's lit 3D core (FireballShaders.core).
static func core_material(look: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FireballShaders.core(float(look.get("opacity", 1.0)) < 1.0)
	var core: Color = look["core"]
	m.set_shader_parameter("core_color", core)
	m.set_shader_parameter("edge_color", look["edge"])
	m.set_shader_parameter("body_color", look.get("body", core.darkened(0.6)))
	m.set_shader_parameter("energy", look.get("energy", 2.6))
	m.set_shader_parameter("crack", look.get("crack", 0.0))
	m.set_shader_parameter("swirl", look.get("swirl", 1.0))
	m.set_shader_parameter("spin", look.get("spin", 0.0))
	m.set_shader_parameter("tumble", look.get("tumble", 0.0))
	m.set_shader_parameter("wobble", look.get("wobble", 0.0))
	m.set_shader_parameter("facets", look.get("facets", 0.0))
	m.set_shader_parameter("opacity", look.get("opacity", 1.0))
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	return m


## v0.8.0 AV: the dark shell, turning with the core (FireballShaders.edge).
static func edge_material(look: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FireballShaders.edge()
	m.set_shader_parameter("edge_color", look["edge"])
	m.set_shader_parameter("spin", look.get("spin", 0.0))
	m.set_shader_parameter("tumble", look.get("tumble", 0.0))
	m.set_shader_parameter("wobble", look.get("wobble", 0.0))
	return m


## v0.8.0 AV: the trail strip (FireballShaders.trail): glowing and additive, or smoke (mixed, no glow, widening), or
## drips.
static func trail_material(look: Dictionary) -> ShaderMaterial:
	var style: StringName = look.get("trail_style", &"glow")
	var smoke: bool = style == &"smoke" or bool(look.get("smoke", false))
	var translucent := float(look.get("opacity", 1.0)) < 1.0
	var m := ShaderMaterial.new()
	m.shader = FireballShaders.trail(not smoke and not translucent)
	var tint: Color = look["trail"]
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("head", tint if smoke else (look["core"] as Color).lerp(tint, 0.4))
	m.set_shader_parameter("glow", 1.0 if smoke or translucent else 1.6)
	m.set_shader_parameter("tail_width", look.get("tail", 0.3))
	m.set_shader_parameter("drips", 1.0 if style == &"drips" else 0.0)
	m.set_shader_parameter("scroll", 0.8 if smoke else 2.2)
	m.set_shader_parameter("opacity", 0.6 if smoke else 0.85)
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	return m
