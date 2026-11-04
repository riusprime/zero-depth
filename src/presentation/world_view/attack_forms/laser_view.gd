class_name LaserView
extends Node3D
## v0.9.0 LZ (owner C §6.2; PLAN C48, C49): the Laser's beams while it fires. Each beam (WorldReader.beams: the sim's
## own trace, so the drawn beam ends where the hits are) is a camera-facing ribbon at the shot's height with the
## look's scrolling strip (BeamLooks: core and edge colour, the owner's beam_core_<look> PNG or the code strip), a
## muzzle glow at the hero, and an impact where it ends (on an enemy or a wall): a flickering star in the look's
## colours and spikes. With the effects layer (VfxLayer) the element adds its accent along the beam (Fire's layered
## flames, Lightning's arcs, Frost's motes, Venom's and Bleed's drips: VfxLayer.line) and sparks and a light at the
## impact. Presentation only (EI-07): it reads the reader, never writes; the scroll and flicker use the shader clock.

## v0.9.5 FC1: the Laser cards' extra paths (LaserMods.plan: a bent beam's legs, Halo's fan, Backfire, Split's forks)
## are ribbons of the same shader, the pool grows to as many as the sim traces (thinner or wider by the beam's `wmul`);
## Echo's strike to come is a paler ghost ribbon, Ring's circle and the mines are flat rings at the tip and on the
## floor.
const POOL_START := 3
const GHOSTS_MAX := 16
const RING_COLOUR_MUL := 1.6
const HEIGHT := SimPlane.CORE_HEIGHT
const IMPACT_SIZE := 0.9
const MUZZLE_SIZE := 0.55
## The strip tiles this many times a metre along the beam.
const TILES_PER_M := 0.6
## v0.9.0 VX V8: the impact's element extra plays every EXTRA_EVERY ticks (twice a second) for EXTRA_TICKS.
const EXTRA_EVERY := 30.0
const EXTRA_TICKS := 18.0
## v0.10.0 VX2 (VFX_PACK R4): each beam is the pack's laser scene (beam_vfx) laid from its start to its end every
## frame (false: the ribbons, for before/after shots). The scene's core radius per metre of the ribbon's width.
## v0.10.0 FX (owner, 2026-10-31: a bent beam was "7-8 overlapping straight laser segments", each pack scene with its
## own flare at its start): off; the ribbons are back, and a bent beam is one ribbon (_join).
const PACK_LASER := false
const BEAM_RADIUS_PER_W := 0.12
const BEAM_RADIUS_MIN := 0.04
## v0.10.0 FX: a bent beam's corners are rounded (Chaikin cuts, CURVE_CUTS passes) where it turns less than
## CURVE_MAX_TURN_DEG (a Ricochet bounce keeps its corner); the legs join when the next starts within JOIN_M.
const CURVE_CUTS := 2
const CURVE_MAX_TURN_DEG := 40.0
const JOIN_M := 0.08

const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D strip : source_color, repeat_enable, filter_linear;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.1, 0.3, 0.8, 1.0);
uniform float length_m = 1.0;
uniform float tiles = 0.6;
uniform float scroll = 2.0;
uniform float energy = 1.7;
uniform float core_frac = 1.0;
uniform float glow = 0.0;
void fragment() {
	// v0.10.5 W3-O8: the strip draws in the ribbon's middle core_frac (the core), a soft halo fills the rest.
	float y = (UV.y - 0.5) / core_frac + 0.5;
	float inside = step(0.0, y) * step(y, 1.0);
	vec2 uv = vec2(UV.x * length_m * tiles - TIME * scroll, clamp(y, 0.0, 1.0));
	vec4 t = texture(strip, uv) * inside;
	float ends = smoothstep(0.0, 0.04, UV.x) * smoothstep(1.0, 0.97, UV.x);
	// v0.9.0 VX: three tones, the outer glow in the element's deep tone, the body its colour, the centre white-hot.
	vec3 body = mix(deep.rgb, edge.rgb, smoothstep(0.0, 0.35, t.r));
	vec3 col = mix(body, core.rgb, smoothstep(0.35, 1.0, t.r)) * t.a * energy * ends;
	float halo = exp(-pow((UV.y - 0.5) * 2.0, 2.0) * 3.0) * glow;
	ALBEDO = col + mix(deep.rgb, edge.rgb, 0.6) * halo * energy * ends;
}
"""
const IMPACT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float spikes = 4.0;
uniform float soft = 0.5;
uniform float flicker = 9.0;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s,
		INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float a = atan(d.y, d.x) + TIME * 1.3;
	if (r >= 1.0) {
		discard;
	}
	float edge_mask = 1.0 - smoothstep(0.8, 1.0, r);
	float star = spikes > 0.5 ? pow(abs(cos(a * spikes * 0.5)), 6.0) * max(0.0, 1.0 - r) : 0.0;
	float pulse = 0.8 + 0.2 * sin(TIME * flicker * 6.2832);
	float glow = exp(-r * r * (3.0 + 6.0 * (1.0 - soft)));
	float hot = exp(-r * r * 22.0);
	ALBEDO = (edge.rgb * (glow + star * 1.4) + core.rgb * hot * 1.6) * pulse * 1.5 * edge_mask;
}
"""

static var _shaders := {}

## What the last sync showed (tests read them): the beams drawn, their look, and the impacts.
var shown := 0
var look := &"default"
var impacts := 0
## v0.10.0 FX: the points of the drawn beams' centre lines (more than 2 a beam: a curve).
var points_shown := 0
## v0.10.5 W3-O8 (LaserWeight): the start flash now (0..1), the ribbons' width factor now and the impact's sparks
## drawn in the last effects frame (the tests read them).
var flash_now := 0.0
var width_now := 1.0
var sparks_drawn := 0
## What the last sync showed of the cards' extras (tests read them): ghost ribbons, rings, mines.
var ghosts_shown := 0
var rings_shown := 0
var mines_shown := 0
## The effects layer for the element accents (WorldViewRoot hands it in; null: the ribbons and impacts alone).
var vfx: VfxLayer = null
## v0.10.0 VX2: the pack the beams draw with (WorldViewRoot hands it in) and the beams it holds, by beam index.
var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v if PACK_LASER else null
var hold := FormPackHold.new()

var _ribbons: Array[MeshInstance3D] = []
var _ghost_ribbons: Array[MeshInstance3D] = []
var _ghost_mat: Array[ShaderMaterial] = []
var _ghosts: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _mines: Array[Dictionary] = []
var _quad: QuadMesh
var _impacts: Array[MeshInstance3D] = []
var _muzzle: MeshInstance3D
var _beam_mat: Array[ShaderMaterial] = []
var _impact_mat: Array[ShaderMaterial] = []
var _beams: Array[Dictionary] = []
var _look_set := &""
var _form := FormLook.new()
var _tick := 0.0
var _fire_start := 0.0


func _init() -> void:
	name = "LaserView"
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	_grow(POOL_START)
	_muzzle = MeshInstance3D.new()
	_muzzle.mesh = _quad
	_muzzle.material_override = _impact_mat[0].duplicate()
	_muzzle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle.visible = false
	add_child(_muzzle)


## The pool holds at least `n` ribbons with their impacts (new ones take the look at once).
func _grow(n: int) -> void:
	while _ribbons.size() < n:
		var bm := ShaderMaterial.new()
		bm.shader = _shader(BEAM_SHADER)
		var r := MeshInstance3D.new()
		r.mesh = ImmediateMesh.new()  # v0.10.0 FX: a strip along the beam's (maybe bent) centre line
		r.material_override = bm
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.visible = false
		add_child(r)
		_ribbons.append(r)
		_beam_mat.append(bm)
		var im := ShaderMaterial.new()
		im.shader = _shader(IMPACT_SHADER)
		var i := MeshInstance3D.new()
		i.mesh = _quad
		i.material_override = im
		i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		i.visible = false
		add_child(i)
		_impacts.append(i)
		_impact_mat.append(im)
		if _look_set != &"":
			_style(_ribbons.size() - 1)


## Echo's ghost ribbons: the beam's shader with a paler colour and less energy.
func _grow_ghosts(n: int) -> void:
	while _ghost_ribbons.size() < mini(n, GHOSTS_MAX):
		var bm := ShaderMaterial.new()
		bm.shader = _shader(BEAM_SHADER)
		var r := MeshInstance3D.new()
		r.mesh = _quad
		r.material_override = bm
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.visible = false
		add_child(r)
		_ghost_ribbons.append(r)
		_ghost_mat.append(bm)
		if _look_set != &"":
			_style_ghost(_ghost_ribbons.size() - 1)


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var s := Shader.new()
		s.code = code
		_shaders[code] = s
	return _shaders[code]


## Each tick: the beams now and their look (v0.9.0 VX V48: read again only when the build changes).
func sync(reader: WorldReader) -> void:
	_beams = []
	_rings = []
	for b in reader.beams():
		if b.has("circle"):
			_rings.append(b)
		else:
			_beams.append(b)
	_beams = _join(_beams)
	_tick = float(reader.tick())
	if _beams.size() > 0 and shown == 0:
		_fire_start = _tick  # W3-O8: a firing starts (the flash)
	_ghosts = reader.laser_ghosts()
	_mines = reader.laser_mines()
	ghosts_shown = mini(_ghosts.size(), GHOSTS_MAX)
	rings_shown = _rings.size()
	mines_shown = _mines.size()
	var d := reader.attack_digest() + String(ElementLooks.energy_style)
	if not _form.read_once or d != _form.digest:
		_form.read_once = true
		_form.digest = d
		_form.set_elements(reader.beam_elements())
		look = _form.look
		_set_look(look)
	shown = _beams.size()
	points_shown = 0
	for b in _beams:
		points_shown += (b["pts"] as PackedVector2Array).size()
	_grow(shown)
	_grow_ghosts(ghosts_shown)
	impacts = 0
	for k in _ribbons.size():
		_ribbons[k].visible = k < shown
		_impacts[k].visible = false
	for k in _ghost_ribbons.size():
		_ghost_ribbons[k].visible = k < ghosts_shown
	_muzzle.visible = shown > 0
	flash_now = LaserWeight.flash(_tick - _fire_start) if shown > 0 else 0.0
	width_now = LaserWeight.width_mul(_tick, flash_now)
	if shown == 0:
		hold.clear()  # v0.10.0 VX2: the pack's beams end with the fire
		return
	var glow := LaserWeight.glow(ViewPrefs.effects_density)
	for k in shown:
		_beam_mat[k].set_shader_parameter(&"glow", glow)
	var grow := 1.0 + LaserWeight.FLASH_GROW * flash_now
	_muzzle.position = SimPlane.to_3d(_beams[0]["from"], HEIGHT)
	_muzzle.scale = Vector3.ONE * MUZZLE_SIZE * (1.0 + 0.4 * (shown - 1)) * grow
	for k in shown:
		var b: Dictionary = _beams[k]
		var hits: PackedInt32Array = b["hits"]
		if bool(b.get("impact", hits.size() > 0 or bool(b["wall"]))):
			_impacts[k].visible = true
			_impacts[k].position = SimPlane.to_3d(b["to"], HEIGHT)
			_impacts[k].scale = (
				Vector3.ONE
				* IMPACT_SIZE
				* LaserWeight.IMPACT_MUL
				* LaserWeight.width_mul(_tick, 0.0)
				* grow
			)
			impacts += 1
	_place_ribbons()


func _process(_delta: float) -> void:
	if shown > 0 or ghosts_shown > 0:
		_place_ribbons()


## The ribbons face the camera along their beams (each frame: the camera moves between ticks).
func _place_ribbons() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var view := Vector3(0, 1, 1).normalized() if cam == null else cam.global_transform.basis.z
	var w := BeamLooks.width(look)
	var wide := w * LaserWeight.GLOW_WIDTH * width_now  # W3-O8: the core in the middle, the halo around it
	hold.begin()
	for k in shown:
		var b: Dictionary = _beams[k]
		var bw := w * int(b.get("wmul", 1000)) / 1000.0
		if _pack_beam(k, b, bw):
			_ribbons[k].visible = false
			continue
		_ribbons[k].visible = true
		_lay_path(
			_ribbons[k], _beam_mat[k], b["pts"], wide * int(b.get("wmul", 1000)) / 1000.0, view
		)
	hold.end()
	for k in ghosts_shown:
		var g: Dictionary = _ghosts[k]
		_lay(_ghost_ribbons[k], _ghost_mat[k], g["from"], g["to"], w * 0.8, view)
		_ghost_mat[k].set_shader_parameter(
			&"energy", 1.2 * float(g["left"]) / maxf(1.0, float(g["total"]))
		)


## v0.10.0 VX2 (R4): beam `k` as the pack's laser: the scene stands at the beam's start, turned to its end
## (-z along it), its length set to the trace and its core radius to the look's width (vfx_beam_controller). False:
## the ribbon draws (no pack, no room, or too short to show).
func _pack_beam(k: int, b: Dictionary, w: float) -> bool:
	if not hold.active():
		return false
	var a := SimPlane.to_3d(b["from"], HEIGHT)
	var along := SimPlane.to_3d(b["to"], HEIGHT) - a
	var len := along.length()
	if len < 0.01:
		return false
	var xf := Transform3D(Basis.looking_at(along / len, Vector3.UP), a)
	var cols := {} if hold.has(k) else PackLooks.colors(_form.elements)
	var n := hold.put(k, PackLooks.laser_id(_form.element), &"beam", xf, cols)
	if n == null:
		return false
	n.set(&"beam_length", len)
	var radius := maxf(BEAM_RADIUS_MIN, w * BEAM_RADIUS_PER_W)
	if not is_equal_approx(float(n.get_meta(&"vx2_radius", -1.0)), radius):
		n.set_meta(&"vx2_radius", radius)  # (the setter rebuilds the scene's shared meshes: only when it changes)
		n.set(&"beam_radius", radius)
	return true


## v0.10.0 FX: the beams as drawn: each lane's chain of main legs (Homing's curve, a Ricochet bounce) is one beam
## {pts (its centre line, rounded), from, to, hits, wall, impact, wmul}; the other beams stay as they are (pts: their
## two ends). The hits and the impact are the chain's last leg's; every point is a point of the sim's own trace.
static func _join(beams: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in beams:
		var main := StringName(b.get("kind", &"main")) == &"main"
		var last: Dictionary = out.back() if not out.is_empty() else {}
		if (
			main
			and not last.is_empty()
			and bool(last.get("chain", false))
			and int(last.get("lane", 0)) == int(b.get("lane", 0))
			and (last["to"] as Vector2).distance_to(b["from"]) <= JOIN_M
		):
			var pts: PackedVector2Array = last["pts"]  # (a packed array is a copy: written back)
			pts.append(b["to"])
			last["pts"] = pts
			last["to"] = b["to"]
			last["hits"] = b["hits"]
			last["wall"] = b["wall"]
			last["impact"] = b.get(
				"impact", (b["hits"] as PackedInt32Array).size() > 0 or bool(b["wall"])
			)
			continue
		var d := b.duplicate()
		d["pts"] = PackedVector2Array([b["from"], b["to"]])
		d["chain"] = main
		out.append(d)
	for d in out:
		d["pts"] = _round(d["pts"])
	return out


## Chaikin's corner cutting, CURVE_CUTS passes, on the corners that turn less than CURVE_MAX_TURN_DEG; the ends stay.
static func _round(pts: PackedVector2Array) -> PackedVector2Array:
	var cur := pts
	for pass_k in CURVE_CUTS:
		if cur.size() < 3:
			return cur
		var nxt := PackedVector2Array([cur[0]])
		for i in range(1, cur.size() - 1):
			var a := cur[i] - cur[i - 1]
			var b := cur[i + 1] - cur[i]
			if a.length() < 0.001 or b.length() < 0.001:
				nxt.append(cur[i])
				continue
			if rad_to_deg(absf(a.angle_to(b))) >= CURVE_MAX_TURN_DEG:
				nxt.append(cur[i])  # a bounce: a sharp corner
				continue
			nxt.append(cur[i].lerp(cur[i - 1], 0.25))
			nxt.append(cur[i].lerp(cur[i + 1], 0.25))
		nxt.append(cur[cur.size() - 1])
		cur = nxt
	return cur


## v0.10.0 FX: one ribbon along the centre line `pts` (sim plane), `w` wide, facing the camera `view`: a single strip,
## so a bent beam has no joints, overlaps or repeated ends (the shader fades its two real ends only).
func _lay_path(
	r: MeshInstance3D, mat: ShaderMaterial, pts: PackedVector2Array, w: float, view: Vector3
) -> void:
	var p3: Array[Vector3] = []
	for p in pts:
		var q := SimPlane.to_3d(p, HEIGHT)
		p3.append(to_local(q) if is_inside_tree() else q)
	var lens := PackedFloat32Array([0.0])
	for i in range(1, p3.size()):
		lens.append(lens[i - 1] + p3[i].distance_to(p3[i - 1]))
	var total := lens[lens.size() - 1]
	var im := r.mesh as ImmediateMesh
	im.clear_surfaces()
	if total < 0.01:
		r.visible = false
		return
	r.transform = Transform3D.IDENTITY
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in p3.size():
		var t := (p3[mini(i + 1, p3.size() - 1)] - p3[maxi(i - 1, 0)]).normalized()
		var side := t.cross(view).normalized()
		if side.length_squared() < 0.5:
			side = Vector3.UP.cross(t).normalized()
		var u := lens[i] / total
		im.surface_set_uv(Vector2(u, 0.0))
		im.surface_add_vertex(p3[i] - side * w * 0.5)
		im.surface_set_uv(Vector2(u, 1.0))
		im.surface_add_vertex(p3[i] + side * w * 0.5)
	im.surface_end()
	mat.set_shader_parameter(&"length_m", total)


## One ribbon from `p0` to `p1` (sim plane), `w` wide, facing the camera `view`.
func _lay(
	r: MeshInstance3D, mat: ShaderMaterial, p0: Vector2, p1: Vector2, w: float, view: Vector3
) -> void:
	var a := SimPlane.to_3d(p0, HEIGHT)
	var e := SimPlane.to_3d(p1, HEIGHT)
	var along := e - a
	var len := along.length()
	if len < 0.01:
		r.visible = false
		return
	var x := along / len
	var y := x.cross(view).normalized()
	if y.length_squared() < 0.5:
		y = Vector3.UP.cross(x).normalized()
	var n := x.cross(y).normalized()
	r.transform = Transform3D(Basis(x * len, y * w, n), (a + e) * 0.5)
	mat.set_shader_parameter(&"length_m", len)


## The look's strip, scroll and impact shape (its first element), in the V2 colours (the first element's centre, the
## second's edge: FormLook).
func _set_look(l: StringName) -> void:
	_look_set = l
	for k in _ribbons.size():
		_style(k)
	for k in _ghost_ribbons.size():
		_style_ghost(k)
	var imp := BeamLooks.impact(l)
	var m := _muzzle.material_override as ShaderMaterial
	m.set_shader_parameter(&"core", _form.core)
	m.set_shader_parameter(&"edge", _form.edge)
	m.set_shader_parameter(&"spikes", float(imp[0]))
	m.set_shader_parameter(&"soft", float(imp[1]))
	m.set_shader_parameter(&"flicker", float(imp[2]))


## Ribbon `k` and its impact in the current look.
func _style(k: int) -> void:
	var l := _look_set
	var imp := BeamLooks.impact(l)
	var bm := _beam_mat[k]
	bm.set_shader_parameter(&"strip", BeamLooks.texture(l))
	bm.set_shader_parameter(&"core", _form.core)
	bm.set_shader_parameter(&"edge", _form.edge)
	bm.set_shader_parameter(&"deep", _form.glow)
	bm.set_shader_parameter(&"scroll", BeamLooks.scroll(l))
	bm.set_shader_parameter(&"tiles", TILES_PER_M)
	bm.set_shader_parameter(&"core_frac", 1.0 / LaserWeight.GLOW_WIDTH)
	var m := _impact_mat[k]
	m.set_shader_parameter(&"core", _form.core)
	m.set_shader_parameter(&"edge", _form.edge)
	m.set_shader_parameter(&"spikes", float(imp[0]))
	m.set_shader_parameter(&"soft", float(imp[1]))
	m.set_shader_parameter(&"flicker", float(imp[2]))


## Ghost ribbon `k`: the look paler (colours mixed toward white).
func _style_ghost(k: int) -> void:
	var l := _look_set
	var bm := _ghost_mat[k]
	bm.set_shader_parameter(&"strip", BeamLooks.texture(l))
	bm.set_shader_parameter(&"core", Color.WHITE)
	bm.set_shader_parameter(&"edge", _form.edge.lerp(Color.WHITE, 0.55))
	bm.set_shader_parameter(&"deep", _form.glow.lerp(Color.WHITE, 0.4))
	bm.set_shader_parameter(&"scroll", BeamLooks.scroll(l))
	bm.set_shader_parameter(&"tiles", TILES_PER_M)


## VfxLayer's drawer (WorldViewRoot appends it): the element's accent along each beam and the impact's sparks and
## light. The default energy beam adds sparks and its light only.
func draw_fx(layer: VfxCore) -> void:
	_draw_extras(layer)
	sparks_drawn = 0
	if shown == 0:
		return
	var fx := layer as VfxLayer
	var kind: StringName = BeamLooks.VFX_KIND[look]
	var now := layer.now()
	var col := _form.edge
	for k in shown:
		var b: Dictionary = _beams[k]
		var pts: PackedVector2Array = b["pts"]
		var a := SimPlane.to_3d(pts[maxi(0, pts.size() - 2)], HEIGHT)
		var e := SimPlane.to_3d(b["to"], HEIGHT)
		var sd := 7001 + k * 131
		if kind != &"" and fx != null:  # along the centre line, a few points at a time (a curve follows it)
			var i := 0
			while i < pts.size() - 1:
				var j := mini(i + 4, pts.size() - 1)
				fx.line(
					kind,
					SimPlane.to_3d(pts[i], HEIGHT),
					SimPlane.to_3d(pts[j], HEIGHT),
					1.0,
					now,
					sd + i
				)
				i = j
		if not _impacts[k].visible:
			continue
		var n := LaserWeight.sparks(ViewPrefs.effects_density)  # W3-O8: hit sparks thrown from the impact
		for j in n:
			var sp: Array = LaserWeight.spark_offset(j, n, now + k * 5.0)
			var t: float = sp[1]
			var c := Color(col.r * 2.2, col.g * 2.2, col.b * 2.2, 1.0 - t)
			layer.sprite(&"spark", e + sp[0], 0.3 * (1.0 - t) + 0.06, c, j % 4, 0.0)
			sparks_drawn += 1
		layer.light_merged(e + Vector3(0, 0.4, 0), col, 1.6 + 1.2 * flash_now, 3.0, 1.5)
		# v0.9.0 VX V8: the element's extra at the beam's end (HeroFx.impact, V4's), at most twice a second per beam,
		# never on every damage tick: one plays every EXTRA_EVERY ticks and lasts EXTRA_TICKS.
		var u := fposmod(now + k * 7.0, EXTRA_EVERY) / EXTRA_TICKS
		if u < 1.0:
			var dir := (e - a).normalized()
			var cyc := int((now + k * 7.0) / EXTRA_EVERY)
			HeroFx.impact(layer, _form.kind, e, dir, u, sd + cyc * 31, 0.9)


## Ring's circle at the tip (the lightning ring's flat look, pulsing with the tick) and the mines on the floor (the Mine
## look: a flat ring, a spark in it); fog and edge masks are the pools' own.
func _draw_extras(layer: VfxCore) -> void:
	var now := layer.now()
	var col := _form.edge
	for b in _rings:
		var at := SimPlane.to_3d(b["to"], 0.05)
		var pulse := 0.9 + 0.1 * sin(now * 0.5)
		var c := Color(
			col.r * RING_COLOUR_MUL, col.g * RING_COLOUR_MUL, col.b * RING_COLOUR_MUL, 0.9
		)
		layer.flat_sprite(&"ring", at, float(b["circle"]) * 2.0 * pulse, c, 0, 0.0)
	for mn in _mines:
		var at := SimPlane.to_3d(mn["pos"], 0.05)
		var blink := 0.6 + 0.4 * absf(sin(now * 0.12))
		layer.flat_sprite(
			&"ring", at, 0.9, Color(col.r * 1.4, col.g * 1.4, col.b * 1.4, blink), 0, 0.0
		)
		layer.sprite(
			&"spark",
			at + Vector3(0, 0.15, 0),
			0.25,
			Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, blink),
			0,
			0.0
		)
