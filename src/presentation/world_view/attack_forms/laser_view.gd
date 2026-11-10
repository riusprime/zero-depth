class_name LaserView
extends Node3D
## The Laser's beams while it fires. Each beam (WorldReader.beams: the sim's
## own trace, so the drawn beam ends where the hits are) is a camera-facing ribbon at the shot's height with the
## look's scrolling strip (BeamLooks: core and edge colour, the owner's beam_core_<look> PNG or the code strip), a
## muzzle glow at the hero, and an impact where it ends (on an enemy or a wall): a flickering star in the look's
## colours and spikes. Presentation only (EI-07): it reads the reader, never writes; the scroll and flicker use the
## shader clock.
## v0.11.0 O1d (owner, 2026-11-08: "maybe to save resources element just changes the color but does not spawn the
## fire/frost etc particles that surround the laser"): the element is the lance's colour only. No accent along the ray,
## no burst, no sparks and no light at the hit (draw_fx draws Ring's circle and the mines only); the pack tube's own end
## ball marks the hit.

## The Laser cards' extra paths (LaserMods.plan: a bent beam's legs, Halo's fan, Backfire, Split's forks)
## are ribbons of the same shader, the pool grows to as many as the sim traces (thinner or wider by the beam's `wmul`);
## Echo's strike to come is a paler ghost ribbon, Ring's circle and the mines are flat rings at the tip and on the
## floor.
## The Laser is a lance, one instant shot every 3 s. WorldReader.beams gives the
## last shot's paths (as the sim hit them) for half a second: each lane's legs join into one strip (_join; with Homing
## the sim's one smooth curve), drawn out from the hero over LaserWeight.DRAW_TICKS (0.15 s, cut()) and its glow fading
## by the end (lance_fade). A minimal look: the final one waits for the owner's sketch (PLAN X2).
## With the pack (the game), each lance is the pack's laser of its element laid on one tube
## through the sim's points (LaserPackTube: laser_vfx_0N's BeamCore, BeamOuter and its start and end balls), drawn out
## and faded the same way; the outer glow's width follows Effects density. The ribbons stay for a bare view (tests).
const PACK_TUBE := true
## The tube's core radius per metre of the look's width, and its outer glow's radius over the core's at a glow of 1.
const TUBE_CORE_PER_W := 0.22
const TUBE_OUTER_PER_GLOW := 2.5
## The start and end balls' scale per unit of the muzzle's and the impact's.
const TUBE_START_PER_MUZZLE := 1.4
const TUBE_END_PER_IMPACT := 1.2
const POOL_START := 3
const GHOSTS_MAX := 16
const RING_COLOUR_MUL := 1.6
const HEIGHT := SimPlane.CORE_HEIGHT
const IMPACT_SIZE := 0.9
const MUZZLE_SIZE := 0.55
## The strip tiles this many times a metre along the beam.
const TILES_PER_M := 0.6
## VFX_PACK R4: each beam is the pack's laser scene (beam_vfx) laid from its start to its end every
## frame (false: the ribbons, for before/after shots). The scene's core radius per metre of the ribbon's width.
## v0.10.0 FX (owner, 2026-10-31: a bent beam was "7-8 overlapping straight laser segments", each pack scene with its
## own flare at its start): off; the ribbons are back, and a bent beam is one ribbon (_join).
const PACK_LASER := false
const BEAM_RADIUS_PER_W := 0.12
const BEAM_RADIUS_MIN := 0.04
## The legs of a path join into one beam when the next starts within JOIN_M. (the sim's legs
## turn
## at most 6 degrees, so the view draws them as they are; rounding them more only made points to rebuild.)
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
## The points of the drawn beams' centre lines (more than 2 a beam: a curve).
var points_shown := 0
## LaserWeight: the start flash now (0..1) and the ribbons' width factor now (the tests read them).
var flash_now := 0.0
var width_now := 1.0
## The share of the lance drawn out now and its glow (LaserWeight.lance_drawn, lance_fade).
var drawn_now := 1.0
var fade_now := 1.0
## The pack tubes (one a lance path) and how many the last draw laid.
var tubes: Array[LaserPackTube] = []
var tubes_shown := 0
## What the last sync showed of the cards' extras (tests read them): ghost ribbons, rings, mines.
var ghosts_shown := 0
var rings_shown := 0
var mines_shown := 0
## The effects layer for the element accents (WorldViewRoot hands it in; null: the ribbons and impacts alone).
var vfx: VfxLayer = null
## The pack the beams draw with (WorldViewRoot hands it in) and the beams it holds, by beam index.
var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v if PACK_LASER else null
		_prewarm_tube()
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
## The lance's age at the last sync (ticks since its shot), its glow ticks, and the seconds since.
var _age := 0.0
var _glow_ticks := 30.0
var _since := 0.0
## The look the pack tubes were set up for.
var _tube_key := ""
## The frame the lances were last placed in (sync and _process both land in a frame; once is enough).
var _placed_frame := -1


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


## Measured: the first shot's frame: a tube of the plain laser, made now and hidden: the build's
## ShaderWarmup
## draws it once behind the loading cover, so the tube's pipelines compile there and not on the first shot. Every laser
## scene of the pack shares the shaders; only its colours differ.
func _prewarm_tube() -> void:
	if pack_fx == null or not PACK_TUBE or not tubes.is_empty():
		return
	var nt := LaserPackTube.new()
	add_child(nt)
	tubes.append(nt)
	var path := PackFx.scene_path_of(PackLooks.laser_id(&""))
	nt.setup(path, PackFx.scene_at(path), {})
	if nt.ok:
		nt.lay([Vector3.ZERO, Vector3(0.0, 0.0, 0.1)] as Array[Vector3], 0.05, 0.12, 1.0, 1.0, 1.0)
	nt.off()


## The pool holds at least `n` ribbons with their impacts (new ones take the look at once).
func _grow(n: int) -> void:
	while _ribbons.size() < n:
		var bm := ShaderMaterial.new()
		bm.shader = _shader(BEAM_SHADER)
		var r := MeshInstance3D.new()
		r.mesh = ImmediateMesh.new()  # A strip along the beam's (maybe bent) centre line
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
	_since = 0.0
	if not _beams.is_empty():
		_age = float(_beams[0].get("age", 0))
		_glow_ticks = float(_beams[0].get("glow", 30))
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
		hold.clear()  # The pack's beams end with the fire
		for t in tubes:  # And the pack tubes
			t.off()
		tubes_shown = 0
		return
	var glow := LaserWeight.glow(ViewPrefs.effects_density)
	for k in shown:
		_beam_mat[k].set_shader_parameter(&"glow", glow)
	var grow := 1.0 + LaserWeight.FLASH_GROW * flash_now
	_muzzle.position = SimPlane.to_3d(_beams[0]["from"], HEIGHT)
	_muzzle.scale = Vector3.ONE * MUZZLE_SIZE * (1.0 + 0.4 * (shown - 1)) * grow
	for k in shown:
		var b: Dictionary = _beams[k]
		if _hit(b):
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


func _process(delta: float) -> void:
	_since += delta
	if (shown > 0 or ghosts_shown > 0) and _placed_frame != Engine.get_process_frames():
		_place_ribbons()


## The ribbons face the camera along their beams (each frame: the camera moves between ticks).
func _place_ribbons() -> void:
	_placed_frame = Engine.get_process_frames()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var view := Vector3(0, 1, 1).normalized() if cam == null else cam.global_transform.basis.z
	var w := BeamLooks.width(look)
	var wide := w * LaserWeight.GLOW_WIDTH * width_now  # W3-O8: the core in the middle, the halo around it
	var age := _age + _since * 60.0  # Drawn out fast, then the glow fades
	drawn_now = LaserWeight.lance_drawn(age)
	fade_now = LaserWeight.lance_fade(age, _glow_ticks)
	hold.begin()
	tubes_shown = 0
	for k in shown:
		var b: Dictionary = _beams[k]
		var bw := w * int(b.get("wmul", 1000)) / 1000.0
		if _pack_beam(k, b, bw) or _tube_beam(k, b, bw):
			_ribbons[k].visible = false
			continue
		_ribbons[k].visible = true
		_beam_mat[k].set_shader_parameter(&"energy", LaserWeight.LANCE_ENERGY * fade_now)
		_lay_path(
			_ribbons[k],
			_beam_mat[k],
			cut(b["pts"], drawn_now),
			wide * int(b.get("wmul", 1000)) / 1000.0,
			view
		)
	hold.end()
	for k in range(shown, tubes.size()):
		tubes[k].off()
	for k in ghosts_shown:
		var g: Dictionary = _ghosts[k]
		_lay(_ghost_ribbons[k], _ghost_mat[k], g["from"], g["to"], w * 0.8, view)
		_ghost_mat[k].set_shader_parameter(
			&"energy", 1.2 * float(g["left"]) / maxf(1.0, float(g["total"]))
		)


## Beam `k` as the pack's laser: the scene stands at the beam's start, turned to its end
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


## Whether beam `b` ends on something (an enemy or a wall): it has an impact.
static func _hit(b: Dictionary) -> bool:
	var hits: PackedInt32Array = b["hits"]
	return bool(b.get("impact", hits.size() > 0 or bool(b["wall"])))


## PD-13: beam `k` as the pack's laser on one tube through its (cut) centre line: the lance draws out and
## its glow fades as the ribbon's did (drawn_now, fade_now), its width and the glow's by width_now and Effects density;
## the start ball stands in for the muzzle (beam 0), the end ball for the impact. False: the ribbon draws (no pack, or
## the scene's parts were not found).
func _tube_beam(k: int, b: Dictionary, w: float) -> bool:
	if not PACK_TUBE or pack_fx == null:
		if k < tubes.size():
			tubes[k].off()
		return false
	var key := String(PackLooks.laser_id(_form.element)) + _form.digest
	if key != _tube_key:
		_tube_key = key
		for t in tubes:
			t.set_meta(&"key", "")
	while tubes.size() <= k:
		var nt := LaserPackTube.new()
		add_child(nt)
		tubes.append(nt)
	var t := tubes[k]
	if String(t.get_meta(&"key", "")) != _tube_key:
		t.set_meta(&"key", _tube_key)
		var path := PackFx.scene_path_of(PackLooks.laser_id(_form.element))
		t.setup(path, PackFx.scene_at(path), PackLooks.colors(_form.elements))
	if not t.ok:
		t.off()
		return false
	var p3: Array[Vector3] = []
	for p in cut(b["pts"], drawn_now):
		var q := SimPlane.to_3d(p, HEIGHT)
		p3.append(to_local(q) if is_inside_tree() else q)
	var thin := lerpf(0.35, 1.0, fade_now)  # the lance thins as its glow fades
	var core := maxf(BEAM_RADIUS_MIN, w * TUBE_CORE_PER_W) * width_now * thin
	var outer := core * (1.0 + TUBE_OUTER_PER_GLOW * LaserWeight.glow(ViewPrefs.effects_density))
	var start := 0.0
	if k == 0:
		start = _muzzle.scale.x / MUZZLE_SIZE * TUBE_START_PER_MUZZLE * thin
		_muzzle.visible = false
	var end := 0.0
	if _hit(b):
		end = _impacts[k].scale.x / IMPACT_SIZE * TUBE_END_PER_IMPACT * thin
		_impacts[k].visible = false
	t.lay(p3, core, outer, fade_now, start, end)
	tubes_shown += 1
	return true


## The beams as drawn: each lane's chain of main legs (Homing's curve, a Ricochet bounce) is one beam
## {pts (its centre line), from, to, hits, wall, impact, wmul}; the other beams stay as they are (pts: their
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
	return out


## The first share `f` (0..1) of the centre line `pts` by length (the lance drawing out from the hero).
static func cut(pts: PackedVector2Array, f: float) -> PackedVector2Array:
	if f >= 1.0 or pts.size() < 2:
		return pts
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	var want := total * maxf(0.0, f)
	var out := PackedVector2Array([pts[0]])
	var run := 0.0
	for i in range(1, pts.size()):
		var d := pts[i].distance_to(pts[i - 1])
		if run + d >= want:
			out.append(pts[i - 1].lerp(pts[i], (want - run) / maxf(d, 0.000001)))
			return out
		run += d
		out.append(pts[i])
	return out


## One ribbon along the centre line `pts` (sim plane), `w` wide, facing the camera `view`: a single strip,
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


## VfxLayer's drawer (WorldViewRoot appends it): Ring's circle and the mines. nothing along the lance or at
## its hit; the element is its colour.
func draw_fx(layer: VfxCore) -> void:
	_draw_extras(layer)


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
