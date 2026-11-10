class_name VoidView
extends Node3D
## v0.9.0 VP (owner C §6.4: "The visual should communicate a moving gravitational anomaly, not a stationary vortex";
## PLAN C56): the Void form. Each Void shot in flight (WorldReader.void_shots) is a travelling lensing sphere:
## - a dark core (an unlit black sphere at the shot's height);
## - a camera-facing lens around it that bends the picture behind (the screen texture pulled toward the core, strongest
##   at the rim), with a bright violet bent-light ring at its edge; with the owner's `void_lens` PNG
##   (assets/textures/vfx/, white on transparent) installed the ring is that picture, tinted;
## - swirling dust: a camera-facing disc of violet arms winding in and turning, and a short trail of fading dust puffs
##   behind it along its flight (so it reads as moving), plus a faint flat ring on the ground at its aura's reach.
## The enemies it pulls lean into it (ActorViews._lean, from WorldReader.void_leans). Pooled (VOIDS_MAX shots drawn,
## the rest skipped). Presentation only (EI-07): the sim decides where, how big and which way; the swirl's clock is the
## shader's.

const VOIDS_MAX := 16
## Ring's lightning rings drawn at once, and the ring shader's phase that puts its band at ARC_FRONT of the
## quad's half-width (0.25 + 0.72 u), so a ring of radius r is drawn at r / ARC_FRONT.
const ARCS_MAX := 6
const ARC_U := 0.7
const ARC_FRONT := 0.754
const TRAIL := 3
## The trail's puffs this far apart behind the shot (m).
const TRAIL_GAP_M := 0.38
const HEIGHT := SimPlane.CORE_HEIGHT
const CORE_SIZE := 0.42
const LENS_SIZE := 1.5
const VIOLET := Color("#8B55FF")
const RIM := Color("#D9C2FF")
## VFX_AUDIT.md V12, V14, V15, V47: the lens grows from a point over GROW_TICKS; a shot that ends collapses
## to a point with a violet flash over COLLAPSE_TICKS (COLLAPSE_MAX at once); the element tints the rim and the trail
## this much (the body stays violet) and adds its accent to the trail from ACCENT_DENSITY (Medium) up.
const GROW_TICKS := 6.0
const COLLAPSE_TICKS := 8.0
const COLLAPSE_MAX := 6
const RIM_TINT := 0.6
const TRAIL_TINT := 0.55
const ACCENT_DENSITY := 0.5
## VFX_PACK R7: the shot's body (the dark core, the dust disc and the trail puffs) is the pack's huge orb
## in the Void violet, and its collapse the pack's orb flash (the screen-distortion lens and the ground ring stay).
## False: the old body, for before/after shots. The orbs' scales per metre of the lens (LENS_SIZE).
## Off, with PACK_SPARKS below
## and GapPack.PACK_RIFT; the Void is its v0.9.5 self again (its lens, dark body, dust trail, collapse and ring).
const PACK_VOID := false
const BODY_PER_LENS := 0.35
const COLLAPSE_PER_LENS := 0.5
## VFX_PACK N5: violet sparks (the pack's orb flash, small) now and then along the dust trail, one every
## SPARK_EVERY ticks a shot (Effects density Medium and High: with the dust), SPARK_PER_LENS of the lens' size.
const PACK_SPARKS := false
const SPARK_ID := &"vx7_void_spark"
const SPARK_EVERY := 9
const SPARK_PER_LENS := 0.15
const SPARK_SIDE_M := 0.3
## - the body (core, lens, dust, trail) is sized by the shot's own aura against the plain Void's BASE_AURA_M (clamped
##   to SIZE_MIN..SIZE_MAX), so Split's minis (0.6 m) draw smaller than the void they came from;
## - a void that stands still (Split's minis, a held Mine: the sim reports no flight, its way reads as +x) draws no
##   dust trail and no trail accent: only a shot that moved since the last tick does;
## - the lens and the dust disc are drawn TO_CAMERA_M nearer the camera than the shot, so the enemies it pulls into
##   its middle (a held Mine's catch) no longer bury it;
## - a void collapses from the size it was drawn at (a mini that opened against a wall and ended a tick later: a
##   small pop, not a full-size black ball).
const BASE_AURA_M := 1.0
const SIZE_MIN := 0.5
const SIZE_MAX := 1.6
const TO_CAMERA_M := 1.2

const LENS_SHADER := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D lens_tex : source_color, filter_linear;
uniform float has_tex = 0.0;
uniform vec4 rim : source_color = vec4(0.85, 0.76, 1.0, 1.0);
uniform vec4 glow : source_color = vec4(0.55, 0.33, 1.0, 1.0);
uniform float core = 0.3;
uniform float to_cam = 0.0;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[3].z += to_cam;
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	if (r > 1.0) {
		discard;
	}
	vec2 n = d / max(r, 0.001);
	float bend = core * core / max(r * r, core * core) * 0.035 * (1.0 - smoothstep(0.6, 1.0, r));
	vec3 bg = textureLod(screen_tex, SCREEN_UV + vec2(n.x, -n.y) * bend, 0.0).rgb;
	float ring = exp(-pow((r - core * 1.35) * 12.0, 2.0));
	float halo = exp(-pow((r - core * 1.35) * 4.0, 2.0)) * 0.35;
	if (has_tex > 0.5) {
		vec4 t = texture(lens_tex, UV);
		ring = t.a * dot(t.rgb, vec3(0.333));
	}
	float dark = 1.0 - smoothstep(core * 0.95, core * 1.12, r);
	vec3 col = mix(bg * (0.75 + 0.25 * r), vec3(0.0), dark) + rim.rgb * ring * 1.9 + glow.rgb * halo;
	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(0.82, 1.0, r);
}
"""
const DUST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 arm_color : source_color = vec4(0.55, 0.33, 1.0, 1.0);
uniform float strength = 1.0;
uniform float turn = 0.0;
uniform float billboard = 1.0;
uniform float motion = 1.0;
uniform float to_cam = 0.0;
void vertex() {
	if (billboard > 0.5) {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
			INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
		MODELVIEW_MATRIX[3].z += to_cam;
	}
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = TIME * motion;
	float arms = 0.5 + 0.5 * sin(3.0 * a + 6.0 * log(max(r, 0.03)) + t * 5.0 + turn);
	float grains = 0.5 + 0.5 * sin(a * 23.0 - t * 7.0 + r * 31.0 + turn * 3.0);
	float band = smoothstep(0.45, 1.0, arms) * (0.6 + 0.4 * grains);
	float fade = (1.0 - smoothstep(0.55, 1.0, r)) * smoothstep(0.12, 0.3, r);
	ALBEDO = arm_color.rgb * strength * band * fade * 1.4;
}
"""

static var _shaders := {}

## What the last sync drew (tests read them): the shots and the dust puffs behind them; the collapses
## playing, the shots' lens growth (0..1, the newest shot's) and whether the dust disc shows (Effects density Low: no).
var voids := 0
## The pack's sparks spawned since the view began (the tests read it).
var sparks := 0
var arcs := 0
var puffs := 0
var collapses := 0
var growth := 1.0
var dust_on := true
## The body size of each shot drawn (its aura's), whether it moved (its trail shows), the trail puffs
## of the still ones (always 0) and each collapse's start size, in sync order (the tests read them).
var sizes: PackedFloat32Array = PackedFloat32Array()
var moving: Array[bool] = []
var collapse_sizes: PackedFloat32Array = PackedFloat32Array()
## v0.9.0 VX V15: the element tint of the bent-light rim and the dust trail (the body stays violet).
var rim_color := RIM
var trail_color := VIOLET
## The pack the shots draw with (WorldViewRoot hands it in) and the orbs it holds, by shot id.
var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v if PACK_VOID else null
var hold := FormPackHold.new()

var _cores: Array[MeshInstance3D] = []
var _lenses: Array[MeshInstance3D] = []
var _dust: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
var _arcs: Array[MeshInstance3D] = []
var _trail: Array[MeshInstance3D] = []
var _trail_mat: Array[ShaderMaterial] = []
var _dust_mats: Array[ShaderMaterial] = []
var _lens_mat: ShaderMaterial
var _ring_mat: ShaderMaterial
## v0.9.0 VX V14: the collapse's own small pool (a core and a lens each, shrinking to a point).
var _gone_cores: Array[MeshInstance3D] = []
var _gone_lenses: Array[MeshInstance3D] = []
## Each shot's first tick (V12's growth), the shots drawn this sync (the effects layer's accents) and the
## collapses playing ([pos (Vector2), tick (float)]). Kept and reused, not rebuilt.
var _born := {}
var _seen := {}
var _at: Array[Vector2] = []
var _dir: Array[Vector2] = []
var _ids: PackedInt32Array = PackedInt32Array()
var _gone: Array = []
var _last_at := {}
## Each shot's place and tick at the last sync and whether it moved then; its last drawn size.
var _prev := {}
var _drawn := {}
var _tick := 0.0
var _form := FormLook.new()
var _motion := -1.0


func _init() -> void:
	name = "VoidView"
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.0, 0.0, 0.01)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var flat := PlaneMesh.new()
	flat.size = Vector2(2.0, 2.0)
	var tex := FxTextures.get_tex("void_lens")
	_lens_mat = ShaderMaterial.new()
	_lens_mat.shader = _shader(LENS_SHADER)
	_lens_mat.set_shader_parameter(&"has_tex", 1.0 if tex != null else 0.0)
	if tex != null:
		_lens_mat.set_shader_parameter(&"lens_tex", tex)
	_lens_mat.set_shader_parameter(&"rim", RIM)
	_lens_mat.set_shader_parameter(&"glow", VIOLET)
	_lens_mat.set_shader_parameter(&"to_cam", TO_CAMERA_M)
	_lens_mat.render_priority = 1
	_ring_mat = _dust_mat(0.45, false)
	_ring_mat.set_shader_parameter(&"arm_color", AttackFormLooks.ground_safe(VIOLET))  # V49
	for k in VOIDS_MAX:
		_cores.append(_node(ball, black))
		_lenses.append(_node(quad, _lens_mat))
		var dm := _dust_mat(1.0, true)
		_dust_mats.append(dm)
		_dust.append(_node(quad, dm))
		_rings.append(_node(flat, _ring_mat))
		for t in TRAIL:
			var m := _dust_mat(1.0, true)
			_trail.append(_node(quad, m))
			_trail_mat.append(m)
	var arc_mat := ShaderMaterial.new()  # Ring's lightning ring (the Bomb's ring look)
	arc_mat.shader = _shader(BombView.RING_SHADER)
	arc_mat.set_shader_parameter(&"has_tex", 0.0)
	arc_mat.set_shader_parameter(&"u", ARC_U)
	arc_mat.set_shader_parameter(&"core", AttackFormLooks.ground_safe(BeamLooks.core(&"lightning")))
	arc_mat.set_shader_parameter(&"edge", AttackFormLooks.ground_safe(BeamLooks.edge(&"lightning")))
	for k in ARCS_MAX:
		_arcs.append(_node(flat, arc_mat))
	for k in COLLAPSE_MAX:
		_gone_cores.append(_node(ball, black))
		_gone_lenses.append(_node(quad, _lens_mat))


func _node(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.visible = false
	add_child(n)
	return n


func _dust_mat(strength: float, billboard: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(DUST_SHADER)
	m.set_shader_parameter(&"arm_color", VIOLET)
	m.set_shader_parameter(&"strength", strength)
	m.set_shader_parameter(&"billboard", 1.0 if billboard else 0.0)
	m.set_shader_parameter(&"to_cam", TO_CAMERA_M if billboard else 0.0)
	return m


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


## Each tick: every Void shot in flight, drawn where the sim has it; a shot that left collapses.
func sync(reader: WorldReader) -> void:
	_tick = float(reader.tick())
	if _form.refresh(reader):
		_tint()
	_update_motion()
	dust_on = ViewPrefs.effects_density != "low"  # Low keeps the core, lens and ring
	var shots := reader.void_shots()
	voids = 0
	puffs = 0
	growth = 1.0
	_at.clear()
	_dir.clear()
	_ids.clear()
	_seen.clear()
	sizes.clear()
	moving.clear()
	hold.begin()
	for v: Dictionary in shots:
		if voids >= VOIDS_MAX:
			break
		var id := int(v["id"])
		_seen[id] = true
		if not _born.has(id):
			_born[id] = _tick
		var p: Vector2 = v["pos"]
		var dir: Vector2 = v["dir"]
		_last_at[id] = p
		_at.append(p)
		_dir.append(dir)
		_ids.append(id)
		# The lens grows from a point to full size over its first GROW_TICKS.
		var g := clampf((_tick - float(_born[id]) + 1.0) / GROW_TICKS, 0.0, 1.0)
		g = 1.0 - (1.0 - g) * (1.0 - g)
		growth = g
		var size := body_size(float(v["aura"]))
		var moved := _moved(id, p)
		sizes.append(size)
		moving.append(moved)
		_drawn[id] = size * g
		_place_shot(voids, p, dir, float(v["aura"]), id, g * size, moved)
		voids += 1
	for k in range(voids, VOIDS_MAX):
		_hide_shot(k)
	hold.end()
	_collapse_gone()
	_place_collapses()
	_place_arcs(reader)  # Ring


## The Ring card's lightning rings growing from where a void ended.
func _place_arcs(reader: WorldReader) -> void:
	arcs = 0
	for row in reader.void_rings():
		if arcs >= ARCS_MAX:
			break
		var g := (
			clampf(float(row["age"]) / float(row["span"]), 0.0, 1.0) * float(row["r"]) / ARC_FRONT
		)
		var arc := _arcs[arcs]
		arc.visible = g > 0.01
		arc.transform = Transform3D(
			Basis.from_scale(Vector3(g, 1.0, g)), SimPlane.to_3d(row["pos"], 0.1)
		)
		arcs += 1
	for k in range(arcs, ARCS_MAX):
		_arcs[k].visible = false


## W3-O8: the body's size factor for a shot of aura `aura` (m): the plain Void's is 1.
static func body_size(aura: float) -> float:
	return clampf(aura / BASE_AURA_M, SIZE_MIN, SIZE_MAX)


## W3-O8: shot `id` moved since the last tick it was seen (a new shot: not yet; the same tick again: as then).
func _moved(id: int, p: Vector2) -> bool:
	var was: Array = _prev.get(id, [])
	if not was.is_empty() and float(was[1]) == _tick:
		return bool(was[2])
	var m := not was.is_empty() and (was[0] as Vector2).distance_squared_to(p) > 1e-6
	_prev[id] = [p, _tick, m]
	return m


## `g`: the growth times the body size; `moved`: the dust trail shows (W3-O8).
func _place_shot(
	k: int, p: Vector2, dir: Vector2, aura: float, id: int, g: float, moved: bool
) -> void:
	var at := SimPlane.to_3d(p, HEIGHT)
	var core := _cores[k]
	core.visible = true
	core.transform = Transform3D(Basis.from_scale(Vector3.ONE * CORE_SIZE * g), at)
	var lens := _lenses[k]
	lens.visible = true
	lens.transform = Transform3D(Basis.from_scale(Vector3.ONE * LENS_SIZE * maxf(g, 0.05)), at)
	var dust := _dust[k]
	dust.visible = dust_on
	dust.transform = Transform3D(Basis.from_scale(Vector3.ONE * LENS_SIZE * 1.35 * g), at)
	var spin := float(id % 97)
	_dust_mats[k].set_shader_parameter(&"turn", spin)
	var ring := _rings[k]
	ring.visible = true
	ring.transform = Transform3D(
		Basis.from_scale(Vector3(aura, 1.0, aura)), SimPlane.to_3d(p, 0.06)
	)
	for t in TRAIL:
		var puff := _trail[k * TRAIL + t]
		puff.visible = dust_on and moved
		if not puff.visible:
			continue
		var back := p - dir * TRAIL_GAP_M * (t + 1)
		var s := LENS_SIZE * (0.9 - 0.2 * t) * g
		puff.transform = Transform3D(
			Basis.from_scale(Vector3.ONE * s), SimPlane.to_3d(back, HEIGHT - 0.05 * t)
		)
		var m := _trail_mat[k * TRAIL + t]
		m.set_shader_parameter(&"strength", 0.55 / (t + 1))
		m.set_shader_parameter(&"turn", spin + t * 1.7)
		puffs += 1
	if hold.active():  # The pack's orb is the body; the lens and the ring stay
		var xf := Transform3D(Basis.from_scale(Vector3.ONE * LENS_SIZE * BODY_PER_LENS * g), at)
		var cols := {} if hold.has(id) else PackLooks.violet_colors()
		if hold.put(id, &"vx2_void_body", &"projectile", xf, cols) != null:
			core.visible = false
			dust.visible = false
			for t in TRAIL:
				_trail[k * TRAIL + t].visible = false
		_spark(id, p, dir)


## A violet spark on the dust trail of shot `id` (every SPARK_EVERY ticks, a place on the trail by turn).
func _spark(id: int, p: Vector2, dir: Vector2) -> void:
	var tick := int(_tick)
	if not PACK_SPARKS or not dust_on or not hold.active() or (tick + id) % SPARK_EVERY != 0:
		return
	if not pack_fx.has_room(&"hit"):
		return
	var turn := tick / SPARK_EVERY + id
	var back := p - dir * TRAIL_GAP_M * (turn % TRAIL + 1)
	back += Vector2(-dir.y, dir.x) * SPARK_SIDE_M * (float((turn * 7) % 5) / 2.0 - 1.0)
	var s := LENS_SIZE * SPARK_PER_LENS
	if pack_fx.spawn(SPARK_ID, SimPlane.to_3d(back, HEIGHT), s, PackLooks.violet_colors()) != null:
		sparks += 1


func _hide_shot(k: int) -> void:
	_cores[k].visible = false
	_lenses[k].visible = false
	_dust[k].visible = false
	_rings[k].visible = false
	for t in TRAIL:
		_trail[k * TRAIL + t].visible = false


## Each shot that left since the last sync collapses where it was last seen (the oldest go past COLLAPSE_MAX).
func _collapse_gone() -> void:
	for id: int in _born.keys():
		if _seen.has(id):
			continue
		var last: Vector2 = _last_at.get(id, Vector2.ZERO)
		var size := float(_drawn.get(id, 1.0))
		# [place, tick, the pack's flash plays, the size it was drawn at (W3-O8)]
		_gone.append([last, _tick, _pack_collapse(last), size])
		_born.erase(id)
		_last_at.erase(id)
		_prev.erase(id)
		_drawn.erase(id)
	while _gone.size() > COLLAPSE_MAX:
		_gone.pop_front()
	var k := 0
	while k < _gone.size():
		if _tick - float(_gone[k][1]) >= COLLAPSE_TICKS:
			_gone.remove_at(k)
		else:
			k += 1
	collapses = _gone.size()
	collapse_sizes.clear()
	for c: Array in _gone:
		collapse_sizes.append(float(c[3]))


## A shot that left collapses in the pack's orb flash (violet); false: no pack or no room (the
## layer's flash draws).
func _pack_collapse(pos: Vector2) -> bool:
	if not hold.active() or not pack_fx.has_room(&"impact"):
		return false
	var s := LENS_SIZE * COLLAPSE_PER_LENS
	return (
		pack_fx.spawn(
			&"vx2_void_collapse", SimPlane.to_3d(pos, HEIGHT), s, PackLooks.violet_colors()
		)
		!= null
	)


func _place_collapses() -> void:
	for k in COLLAPSE_MAX:
		var on := k < _gone.size()
		_gone_cores[k].visible = on
		_gone_lenses[k].visible = on
		if not on:
			continue
		var u := clampf((_tick - float(_gone[k][1])) / COLLAPSE_TICKS, 0.0, 1.0)
		var s := (1.0 - u) * (1.0 - u) * float(_gone[k][3])
		var at := SimPlane.to_3d(_gone[k][0], HEIGHT)
		_gone_cores[k].transform = Transform3D(Basis.from_scale(Vector3.ONE * CORE_SIZE * s), at)
		_gone_lenses[k].transform = Transform3D(
			Basis.from_scale(Vector3.ONE * LENS_SIZE * maxf(s, 0.02)), at
		)


## The element tints the bent-light rim and the dust trail; the body, the dark core and the dust disc stay violet.
func _tint() -> void:
	var c := _form.edge if _form.element != &"" else VIOLET
	rim_color = RIM if _form.element == &"" else RIM.lerp(c, RIM_TINT)
	trail_color = VIOLET if _form.element == &"" else VIOLET.lerp(c, TRAIL_TINT)
	_lens_mat.set_shader_parameter(&"rim", rim_color)
	for m in _trail_mat:
		m.set_shader_parameter(&"arm_color", trail_color)


## Reduced motion stills the dust's swirl (the shots and their lens stay).
func _update_motion() -> void:
	var m := 0.0 if ViewPrefs.reduced_motion else 1.0
	if m == _motion:
		return
	_motion = m
	for d in _dust_mats:
		d.set_shader_parameter(&"motion", m)
	for d in _trail_mat:
		d.set_shader_parameter(&"motion", m)


## The effects layer's drawer (WorldViewRoot appends it): V15's element accent along each shot's trail (Medium and
## High: HeroFx.accent leaves Low out) and V14's collapse flash (a violet core, glow, ring and sparks).
func draw_fx(layer: VfxCore) -> void:
	var now := layer.now()
	if _form.kind != &"" and layer.density >= ACCENT_DENSITY:
		for k in _at.size():
			if not moving[k]:
				continue  # W3-O8: a still void leaves no trail
			var d3 := SimPlane.to_3d(_dir[k], 0.0)
			for t in 2:
				var back := SimPlane.to_3d(_at[k] - _dir[k] * TRAIL_GAP_M * (t + 1), HEIGHT)
				HeroFx.accent(layer, _form.kind, _form.element, back, d3, _ids[k] * 7 + t, 1.2)
	for k in _gone.size():
		if _gone[k][2]:
			continue  # the pack's flash plays
		var u := clampf((now - float(_gone[k][1])) / COLLAPSE_TICKS, 0.0, 1.0)
		var at := SimPlane.to_3d(_gone[k][0], HEIGHT)
		var size := 1.1 * float(_gone[k][3])
		HeroFx.flash(layer, at, RIM, VIOLET.lerp(rim_color, 0.4), u, size, 811 + k * 13, 5)
