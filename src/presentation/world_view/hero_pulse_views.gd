class_name HeroPulseViews
extends Node3D
## v0.8.0 GF1 (owner O19: "transform the square that comes out into a pulse, like a fireball, but it will be blue"):
## the hero's plain shots (team 0, no fireball look, not a kill shard: the Gun's bolts, their splits, echoes and the
## other bolt cards) drawn as a lit 3D pulse, the way FireballViews draws the bosses' orbs: a bright pale core that
## falls off to the shot's own colour at the rim (FireballShaders.core: noise swirl and flicker inside), a soft additive
## glow round it that swells and settles (the pulse; no dark edge: a dark rim is the hostile shots' mark), and a short
## tapered trail (FireballShaders.trail). Hundreds at once, so each look is three MultiMeshes (one draw each), and
## positions are blended between the last two ticks each frame (MultiMesh instances aren't nodes).
## - Colour: the hero's attack family only. A shot takes the bolt colour of the moment it is fired
##   (ActorViews.bolt_color: the player's core cyan, a card's tint such as Cinder Shot's orange or Splinter's green,
##   the heat tier's orange or red from Hot up) and keeps it while it flies, as the darts did. Never a hostile colour
##   (a test pins the distance to every hostile look's core and trail).
## - Size: what you see is what hits (owner O18). The core's radius is the shot's own hit radius (WorldReader.
##   projectile_radius: Big Shot, Rapid Fire, Charge and the splits all scale it) times CORE_SCALE; the glow reaches
##   GLOW_SCALE of it and fades out. A faster-firing look (ActorViews.bolt_look "size": Rapid Coil's long dart) is
##   drawn a little drawn-out along the flight and with a longer trail.
## - Effects density Low thins the trails (every other shot, narrower), as for the hostile fireballs; the shots stay.
## - Reduced motion stills the swirl and the glow's swell (the shots and their trails stay).
## AttackFormView still adds the element and card layers (element darts, particles, cues) over these.
## Presentation only (EI-07): it reads WorldReader and never writes.

## The core's radius over the shot's hit radius, and the glow's.
const CORE_SCALE := 0.9
const GLOW_SCALE := 1.6
## The core is a little longer than wide along the flight (a pulse, not a bead).
const TIP := 1.2
## The trail behind (metres at the plain dart's look) and its strip's width over the core's.
const TRAIL_M := 0.55
const TRAIL_WIDTH_SCALE := 1.5
const HEIGHT := SimPlane.CORE_HEIGHT
## How far the look's core is pulled toward white (the pale centre), and the glow's strength.
const CORE_WHITE := 0.5
const GLOW_STRENGTH := 0.5
const ENERGY := 1.7
## The plain shot's body leans this far from the hero's cyan toward BLUE (owner O19: "it will be blue"; the normal
## colour mode only: the colour-blind modes keep their own core colour). Never as far as the Arc Caster's periwinkle
## plasma (#6E9CFF): a test pins the distance.
const BLUE := Color("#2F6BFF")
const BLUE_LEAN := 0.35
## The plain dart's length (AttackView.PLAIN_BOLT_SIZE.x): a look's "size" over it stretches the pulse.
const PLAIN_LENGTH := 0.38
const TRAIL_SCALE := {"low": 0.45, "medium": 0.75, "high": 1.0}
const TRAIL_WIDTH := {"low": 0.55, "medium": 0.8, "high": 1.0}

## The soft glow round the core: additive, brightest where it faces the camera, its size swelling and settling on
## each shot's own seed (the pulse). `motion` 0 (reduced motion) holds it still.
const GLOW := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(0.2, 0.8, 0.9, 1.0);
uniform float strength = 0.85;
uniform float swell = 0.16;
uniform float rate = 11.0;
uniform float motion = 1.0;

void vertex() {
	float seed = fract(float(INSTANCE_ID) * 0.618034);
	float t = (TIME + seed * 40.0) * motion;
	VERTEX *= 1.0 + swell * motion * (0.5 + 0.5 * sin(t * rate));
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = glow_color.rgb;
	ALPHA = clamp(pow(facing, 1.8) * strength, 0.0, 1.0);
}
"""

static var _glow_shader: Shader

## The bolt view the shots' colour and stretch come from (WorldViewRoot sets it).
var actors: ActorViews
## Draw on every sync too (tests and tools that never run a frame); the game view turns it off, since each frame's
## _process draws (blended between ticks) and drawing at the sync as well doubled the cost (the PF probe).
var draw_on_sync := true
## Per look key: {"core", "glow", "trail": MultiMeshInstance3D}.
var _sets := {}
## Per look key: [colour, energy, stretch] it was built from.
var _look_of := {}
## By projectile id: this tick's and the last tick's positions, velocity, radius and the look key it was fired with.
var _now := {}
var _before := {}
var _vel := {}
var _radius := {}
var _key := {}
## The ids drawn per look this tick.
var _drawn := {}
## Shots and trails drawn per look in the last draw (a headless renderer keeps no MultiMesh state).
var _balls := {}
var _trails := {}
var _motion := -1.0
var _trail_width := 1.0
## Shots drawn in the last draw (all looks).
var _shown := 0
## P-6 (as ActorViews): the look a new shot takes is formatted once while it doesn't change.
var _new_key := ""
var _new_of: Array = []


func sync(reader: WorldReader) -> void:
	_before = _now
	_now = {}
	_drawn = {}
	for i in reader.projectile_count():
		if (
			reader.projectile_team(i) != 0
			or reader.projectile_look(i) != ""
			or reader.projectile_is_shard(i)
			or reader.projectile_is_bomb(i)
		):  # v0.9.0 BM: BombView draws the bombs
			continue
		var id := reader.projectile_id(i)
		var p := reader.projectile_pos(i)
		_now[id] = p
		_vel[id] = reader.projectile_vel(i)
		_radius[id] = reader.projectile_radius(i)
		if not _before.has(id):
			_before[id] = p  # a new shot appears where it was fired
		if not _key.has(id):
			_key[id] = _fresh_key()
		var key: String = _key[id]
		var list: PackedInt32Array = _drawn.get(key, PackedInt32Array())
		list.append(id)
		_drawn[key] = list
	for d: Dictionary in [_vel, _radius, _key]:
		for id in d.keys():
			if not _now.has(id):
				d.erase(id)
	for key in _sets.keys():
		if not _drawn.has(key):
			_drawn[key] = PackedInt32Array()
	for key in _drawn:
		if not _sets.has(key):
			_sets[key] = _make_set(key)
	if draw_on_sync:
		_draw(1.0)


func _process(_delta: float) -> void:
	if not _now.is_empty() or _shown > 0:  # the frame after the last shot goes clears them
		_draw(Engine.get_physics_interpolation_fraction())


## How many hero shots are drawn now (tests and the tour).
func count() -> int:
	return _now.size()


## Shots drawn in look `key` in the last draw (tests); the keys in use (looks()).
func ball_count(key: String) -> int:
	return _balls.get(key, 0)


func trail_count(key: String) -> int:
	return _trails.get(key, 0)


func looks() -> Array:
	return _sets.keys()


## The look key shot `id` was fired with ("" when it isn't drawn here), and that look's [colour, energy, stretch].
func key_of(id: int) -> String:
	return _key.get(id, "")


func look(key: String) -> Array:
	return _look_of.get(key, [])


## The MultiMesh instance of look `key`'s `part` (&"core", &"glow" or &"trail"; tests: one draw per look and part).
func part(key: String, p: StringName) -> MultiMeshInstance3D:
	return (_sets[key] as Dictionary)[p] if _sets.has(key) else null


## The core's drawn radius of shot `id`: its hit radius x CORE_SCALE (0 when it isn't drawn here; tests).
func drawn_radius(id: int) -> float:
	return float(_radius.get(id, 0.0)) * CORE_SCALE


func trail_width() -> float:
	return _trail_width


## The colours of the pulse made from bolt colour `c`: [the pale core, the body (the rim the core falls off to), the
## glow, the trail].
static func colors(c: Color) -> Array[Color]:
	var body := c
	if ThemePalette.mode == &"off" and c == ThemePalette.color(&"player_core"):
		body = c.lerp(BLUE, BLUE_LEAN)
	return [c.lerp(Color.WHITE, CORE_WHITE), body, body.lerp(c, 0.5), body]


## The look a shot fired now takes: the bolt's colour and energy (ActorViews), and its stretch along the flight.
func _fresh_key() -> String:
	var c := ThemePalette.color(&"player_core")
	var energy := ENERGY
	var stretch := 1.0
	if actors != null:
		c = actors.bolt_color()
		energy = (
			ENERGY
			* float(actors.bolt_look.get("energy", AttackView.BOLT_ENERGY))
			/ AttackView.BOLT_ENERGY
		)
		var size: Vector3 = actors.bolt_look.get("size", AttackView.PLAIN_BOLT_SIZE)
		stretch = clampf(size.x / PLAIN_LENGTH, 0.6, 2.0)
	var of := [c, energy, stretch]
	if of != _new_of:
		_new_of = of
		_new_key = "%s|%.2f|%.2f" % [c.to_html(), energy, stretch]
		_look_of[_new_key] = of
	return _new_key


## v0.8.0 GF1 (the PF budget): the buffers are written in place, one 12-float row per shot and part, with the basis
## worked out by hand (the flight's x along the plane, y up, z across), so a crowd of shots costs no Transform3D, Basis
## or temporary array each.
func _draw(f: float) -> void:
	var trail_scale: float = TRAIL_SCALE.get(ViewPrefs.effects_density, 1.0)
	var width: float = TRAIL_WIDTH.get(ViewPrefs.effects_density, 1.0)
	var thin := ViewPrefs.effects_density == "low"
	_trail_width = width
	_update_motion()
	var shown := 0
	for key in _drawn:
		var ids: PackedInt32Array = _drawn[key]
		var n := ids.size()
		var stretch: float = (_look_of[key] as Array)[2]
		var tip := TIP * (1.0 + 0.35 * (stretch - 1.0))
		var len := TRAIL_M * stretch * trail_scale
		var parts: Dictionary = _sets[key]
		var cores := _buffer(parts["core"], n)
		var glows := _buffer(parts["glow"], n)
		var trails := _buffer(parts["trail"], n)
		var t := 0
		for k in n:
			var id := ids[k]
			var now: Vector2 = _now[id]
			var p: Vector2 = (_before.get(id, now) as Vector2).lerp(now, f)
			var r: float = float(_radius.get(id, 0.2)) * CORE_SCALE
			var v: Vector2 = _vel.get(id, Vector2.RIGHT)
			var d := v.normalized() if v.length() > 0.00001 else Vector2.RIGHT
			_put(cores, k, d, r * tip, r, p.x, -p.y)
			var g := r * GLOW_SCALE / CORE_SCALE
			_put(glows, k, d, g * tip, g, p.x, -p.y)
			if thin and k % 2 == 1:
				continue
			var back := p - d * (len * 0.5 + r * 0.5)
			_put(trails, t, d, len, r * TRAIL_WIDTH_SCALE * width, back.x, -back.y)
			t += 1
		_balls[key] = n
		_trails[key] = t
		_show(parts["core"], cores, n)
		_show(parts["glow"], glows, n)
		_show(parts["trail"], trails, t)
		shown += n
	_shown = shown


## A buffer for `n` rows of `mi`'s MultiMesh (grown, doubling, when it holds fewer; the hidden tail is zeros).
static func _buffer(mi: MultiMeshInstance3D, n: int) -> PackedFloat32Array:
	var mm := mi.multimesh
	if mm.instance_count < n:
		mm.instance_count = maxi(n, mm.instance_count * 2)
	var buf := PackedFloat32Array()
	buf.resize(mm.instance_count * 12)
	return buf


static func _show(mi: MultiMeshInstance3D, buf: PackedFloat32Array, n: int) -> void:
	if n > 0:
		mi.multimesh.buffer = buf
	mi.multimesh.visible_instance_count = n


## Row `k`: x along the flight `d` (scaled `along`), y up and z across (scaled `side`), at (x, HEIGHT, z) in 3D.
static func _put(
	buf: PackedFloat32Array, k: int, d: Vector2, along: float, side: float, x: float, z: float
) -> void:
	var o := k * 12
	# The flight on the plane is (d.x, 0, -d.y) in 3D; across it (x cross up) is (d.y, 0, d.x).
	buf[o] = d.x * along
	buf[o + 1] = 0.0
	buf[o + 2] = d.y * side
	buf[o + 3] = x
	buf[o + 4] = 0.0
	buf[o + 5] = side
	buf[o + 6] = 0.0
	buf[o + 7] = HEIGHT
	buf[o + 8] = -d.y * along
	buf[o + 9] = 0.0
	buf[o + 10] = d.x * side
	buf[o + 11] = z


## Reduced motion stills the swirl and the swell (set on every look when it changes).
func _update_motion() -> void:
	var m := 0.0 if ViewPrefs.reduced_motion else 1.0
	if m == _motion:
		return
	_motion = m
	for key in _sets:
		for p in ["core", "glow", "trail"]:
			var mat := (_sets[key][p] as MultiMeshInstance3D).material_override as ShaderMaterial
			mat.set_shader_parameter("motion", m)


func _make_set(key: String) -> Dictionary:
	var of: Array = _look_of.get(key, [ThemePalette.color(&"player_core"), ENERGY, 1.0])
	var specs := [
		["core", ProjectileMeshes.get_mesh(&"orb"), core_material(of[0], of[1])],
		["glow", ProjectileMeshes.get_mesh(&"glob"), glow_material(of[0])],
		["trail", ProjectileMeshes.get_mesh(&"ribbon"), trail_material(of[0])],
	]
	var out := {}
	for s: Array in specs:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = s[1]
		mm.instance_count = 32
		mm.visible_instance_count = 0
		var mi := MultiMeshInstance3D.new()
		mi.name = "pulse_%d_%s" % [_sets.size(), s[0]]
		mi.multimesh = mm
		mi.material_override = s[2]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		mi.extra_cull_margin = 2.0
		add_child(mi)
		out[s[0]] = mi
	_motion = -1.0  # the new set takes the current motion on the next draw
	return out


## The lit core (FireballShaders.core): the pale centre falling off to the bolt colour at the rim, no veins, a fast
## swirl and flicker inside.
static func core_material(c: Color, energy: float) -> ShaderMaterial:
	var cols := colors(c)
	var m := ShaderMaterial.new()
	m.shader = FireballShaders.core(false)
	m.set_shader_parameter("core_color", cols[0])
	m.set_shader_parameter("edge_color", cols[1])
	m.set_shader_parameter("body_color", cols[1])
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("crack", 0.0)
	m.set_shader_parameter("swirl", 2.6)
	m.set_shader_parameter("spin", 0.0)
	m.set_shader_parameter("tumble", 0.0)
	m.set_shader_parameter("wobble", 0.05)
	m.set_shader_parameter("facets", 0.0)
	m.set_shader_parameter("opacity", 1.0)
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	return m


static func glow_material(c: Color) -> ShaderMaterial:
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW
	var m := ShaderMaterial.new()
	m.shader = _glow_shader
	m.set_shader_parameter("glow_color", colors(c)[2])
	m.set_shader_parameter("strength", GLOW_STRENGTH)
	return m


## The short tapered trail (FireballShaders.trail, additive): the bolt colour, paler toward the head.
static func trail_material(c: Color) -> ShaderMaterial:
	var cols := colors(c)
	var m := ShaderMaterial.new()
	m.shader = FireballShaders.trail(true)
	m.set_shader_parameter("tint", cols[3])
	m.set_shader_parameter("head", cols[0].lerp(cols[3], 0.4))
	m.set_shader_parameter("glow", 1.6)
	m.set_shader_parameter("tail_width", 0.18)
	m.set_shader_parameter("drips", 0.0)
	m.set_shader_parameter("scroll", 2.6)
	m.set_shader_parameter("opacity", 1.0)
	m.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	return m
