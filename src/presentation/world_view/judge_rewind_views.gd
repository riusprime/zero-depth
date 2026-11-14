class_name JudgeRewindViews
extends Node3D
## The Clockwork Judge's Rewind, drawn from WorldReader.boss_time (EI-07: it reads; the throw is the sim's).
## - The pale copy: while the Rewind is on, a pale translucent figure of the hero's shape stands where the Bell would
##   throw the hero (`copy`), over a pale ring on the floor, seen through anything in front of it. The sim moves that
##   point a step at a time; the figure glides after it.
## - The Bell's cast (`bell` 0..1000): a pale-gold ring closes on the copy and reaches it at the toll, a line of
##   light from the hero to the copy brightens through the cast, and the copy itself brightens.
## - The throw (the `judge_rewind` event): a ring flashes where the hero was and where it landed, a streak joins
##   them for a moment, and the pack's pulse (cj_pulse) bursts at both ends.
## - The Judge's own return (the `judge_return` event): the same gold rings where it stood and where it stands now.
## Everything that follows the copy hangs under one node (`copy_parts`), so a mark the Bell aims there can be added
## beside the ring. Reduced motion: the copy does not bob and the streak does not show. Nothing here decides an
## outcome.

const GOLD := JudgeViews.GOLD
const PALE := Color(0.82, 0.9, 1.0)
const EFFECT_REWIND := &"judge_rewind"
const EFFECT_RETURN := &"judge_return"
const EFFECT_BELL_VERDICT := &"judge_bell_verdict"
## The bell's ring: its radius at the cast's start and at the toll (m).
const BELL_FROM_M := 4.5
const BELL_TO_M := 0.7
const COPY_ALPHA := 0.42
const COPY_ALPHA_BELL := 0.8
## How fast the figure closes on the copy's point (1/s).
const FOLLOW := 10.0
const FLASHES := 4
const FLASH_S := 0.45
const STREAK_S := 0.3

var pack_fx: PackFx = null
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
## What follows the copy: the figure, its floor ring, the bell's ring.
var copy_parts := Node3D.new()
var _time := {}
var _hero_at := Vector3.ZERO
var _boss_at := Vector3.ZERO
var _last_seq := 0
var _primed := false
var _clock := 0.0
var _shown := false
var _figure := Node3D.new()
var _figure_mat := StandardMaterial3D.new()
var _foot_mat := StandardMaterial3D.new()
var _bell_ring := MeshInstance3D.new()
var _bell_mat := ShaderMaterial.new()
var _link := MeshInstance3D.new()
var _link_mat := StandardMaterial3D.new()
var _streak := MeshInstance3D.new()
var _streak_mat := StandardMaterial3D.new()
var _streak_t := STREAK_S
var _flashes: Array[MeshInstance3D] = []
var _flash_mats: Array[StandardMaterial3D] = []
var _flash_t: Array[float] = []
var _flash_next := 0
## The Bell's Verdict squares, drawn as the Judge's own Verdict square is (TelegraphViews, in the same ground look).
var _squares := TelegraphViews.new()


func _init() -> void:
	name = "JudgeRewindViews"
	_squares.name = "BellSquares"
	add_child(_squares)
	copy_parts.visible = false
	copy_parts.set_meta(ShaderWarmup.WARM_META, true)  # drawn once before the fight
	add_child(copy_parts)
	_figure_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_figure_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_figure_mat.albedo_color = Color(PALE, COPY_ALPHA)
	# Drawn over whatever stands in front (a gear, the Judge): where the Bell throws you is never hidden.
	_figure_mat.no_depth_test = true
	_figure_mat.render_priority = 1
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.1
	_piece(_figure, cap, _figure_mat, Vector3(0, 0.75, 0))
	var ball := SphereMesh.new()
	ball.radius = 0.2
	ball.height = 0.4
	_piece(_figure, ball, _figure_mat, Vector3(0, 1.5, 0))
	copy_parts.add_child(_figure)
	var foot := TorusMesh.new()
	foot.inner_radius = 0.42
	foot.outer_radius = 0.5
	foot.rings = 32
	_glow(_foot_mat, PALE, 0.7)
	_piece(copy_parts, foot, _foot_mat, Vector3(0, 0.05, 0))
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0
	_bell_ring.mesh = plane
	var sh := Shader.new()
	sh.code = JudgeTimeViews.WAVE_SHADER
	_bell_mat.shader = sh
	_bell_mat.set_shader_parameter("gold", GOLD.lerp(PALE, 0.5))
	_bell_mat.set_shader_parameter("hot", PALE)
	_bell_mat.set_shader_parameter("noise_tex", ProjectileMeshes.noise())
	_bell_ring.material_override = _bell_mat
	_bell_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bell_ring.visible = false
	copy_parts.add_child(_bell_ring)
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.02, 1.0)
	_glow(_link_mat, PALE, 0.0)
	_glow(_streak_mat, Color.WHITE, 0.0)
	for pair: Array in [[_link, _link_mat], [_streak, _streak_mat]]:
		var mi: MeshInstance3D = pair[0]
		mi.mesh = box
		mi.material_override = pair[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 40
	for k in FLASHES:
		var mat := StandardMaterial3D.new()
		_glow(mat, PALE, 0.0)
		var ring := _piece(self, torus, mat, Vector3.ZERO)
		ring.visible = false
		_flashes.append(ring)
		_flash_mats.append(mat)
		_flash_t.append(FLASH_S)


static func _glow(m: StandardMaterial3D, c: Color, a: float) -> void:
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(c, a)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED


static func _piece(to: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	to.add_child(mi)
	return mi


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	var hero_was := _hero_at
	var boss_was := _boss_at
	_time = reader.boss_time()
	_hero_at = SimPlane.to_3d(reader.actor_pos(0))
	if not _time.is_empty():
		_boss_at = SimPlane.to_3d(reader.actor_pos(int(_time["boss"])))
	_draw_squares()
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # joining a fight under way replays nothing that already happened
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.STATUS_APPLY:
			continue
		if e.effect_id == EFFECT_REWIND:
			_snap(hero_was, SimPlane.to_3d(e.pos), PALE, 1.2)
		elif e.effect_id == EFFECT_RETURN:
			_snap(boss_was, SimPlane.to_3d(e.pos), GOLD, 2.2)


## One square telegraph per Bell's Verdict the reader holds: a dull outline while it follows the copy, the lock's
## flash once it is locked (the sim says which, and where). The square has no fill to grow: the lock is its cue.
func _draw_squares() -> void:
	var tgs := []
	for sq: Dictionary in _time.get("bell_squares", []):
		var half := float(sq["half"])
		var box := Obb.make(sq["center"], Vector2(half, half), 0)
		(
			tgs
			. append(
				{
					"shape": &"lanes",
					"obbs": [box],
					"progress": 1000,
					"move": WorldReader.MOVE_VERDICT,
					"tracked": true,
					"locked": bool(sq["locked"]),
				}
			)
		)
	_squares.draw_extra(tgs, &"cj_verdict")


## A throw from `from` to `to`: a ring at both ends, the streak between them, the pack's pulse on each.
func _snap(from: Vector3, to: Vector3, c: Color, radius: float) -> void:
	for at: Vector3 in [from, to]:
		var k := _flash_next
		_flash_next = (_flash_next + 1) % FLASHES
		_flashes[k].position = at + Vector3(0, 0.08, 0)
		_flashes[k].set_meta(&"radius", radius)
		_flash_mats[k].albedo_color = Color(c * 1.6, 0.0)
		_flash_t[k] = 0.0
		if pack_fx != null and pack_fx.has_id(&"cj_pulse") and pack_fx.has_room(&"impact"):
			var cols := {&"primary": c.lerp(Color.WHITE, 0.5), &"secondary": c}
			pack_fx.spawn(&"cj_pulse", at + Vector3(0, 0.1, 0), radius * 0.45, cols)
	if not ViewPrefs.reduced_motion and from.distance_to(to) > 0.05:
		_stretch(_streak, from + Vector3(0, 0.9, 0), to + Vector3(0, 0.9, 0), 0.22)
		_streak_mat.albedo_color = Color(c.lerp(Color.WHITE, 0.5), 0.9)
		_streak_t = 0.0


## Lays the unit strip `mi` from `a` to `b`, `width` wide.
static func _stretch(mi: MeshInstance3D, a: Vector3, b: Vector3, width: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01:
		mi.visible = false
		return
	mi.visible = true
	mi.transform = Transform3D(
		Basis.looking_at(d / l, Vector3.UP).scaled(Vector3(width, 1, l)), (a + b) * 0.5
	)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	var on := bool(_time.get("rewind", false))
	if not on and _settled():
		if quiet:
			return
		quiet = true
	else:
		quiet = false
	_clock += delta * (0.0 if ViewPrefs.reduced_motion else 1.0)
	_draw_copy(delta, on)
	_draw_flashes(delta)


func _settled() -> bool:
	if _streak_t < STREAK_S:
		return false
	for t in _flash_t:
		if t < FLASH_S:
			return false
	return true


func _draw_copy(delta: float, on: bool) -> void:
	copy_parts.visible = on
	if not on:
		_shown = false
		_link.visible = false
		return
	var target := SimPlane.to_3d(_time["copy"])
	if not _shown:
		copy_parts.position = target  # the first frame stands on the point; later ones glide after it
	else:
		copy_parts.position = copy_parts.position.lerp(target, 1.0 - exp(-FOLLOW * delta))
	_shown = true
	var bell := float(_time.get("bell", -1)) / 1000.0
	var cast := bell >= 0.0
	_figure.position.y = 0.05 * sin(_clock * 2.0)
	_figure_mat.albedo_color.a = lerpf(COPY_ALPHA, COPY_ALPHA_BELL, bell) if cast else COPY_ALPHA
	_foot_mat.albedo_color.a = 0.7 if not cast else 1.0
	_bell_ring.visible = cast
	_link.visible = cast
	if not cast:
		return
	var r := bell_radius()
	_bell_ring.position = Vector3(0, 0.07, 0)
	_bell_ring.scale = Vector3.ONE * r
	_bell_mat.set_shader_parameter("alpha", 0.35 + 0.65 * bell)
	_bell_mat.set_shader_parameter("band", clampf(0.35 / r, 0.03, 0.4))
	_bell_mat.set_shader_parameter("clock", _clock)
	var lift := Vector3(0, 0.9, 0)
	_stretch(_link, _hero_at + lift, copy_parts.position + lift, 0.05 + 0.1 * bell)
	_link_mat.albedo_color.a = 0.12 + 0.78 * bell * bell


func _draw_flashes(delta: float) -> void:
	for k in FLASHES:
		_flash_t[k] = minf(FLASH_S, _flash_t[k] + delta)
		var u := _flash_t[k] / FLASH_S
		_flashes[k].visible = u < 1.0
		if u < 1.0:
			var r := float(_flashes[k].get_meta(&"radius", 1.0)) * lerpf(0.4, 1.8, ease(u, 0.5))
			_flashes[k].scale = Vector3(r, 0.5, r)
			_flash_mats[k].albedo_color.a = 0.9 * (1.0 - u)
	_streak_t = minf(STREAK_S, _streak_t + delta)
	if _streak_t >= STREAK_S:
		_streak.visible = false
	else:
		_streak_mat.albedo_color.a = 0.9 * (1.0 - _streak_t / STREAK_S)


## Tests and the shot scripts: what is drawn now.
func copy_shown() -> bool:
	return copy_parts.visible


## Where the figure stands (sim plane) and the point it follows.
func copy_position() -> Vector2:
	return SimPlane.to_sim(copy_parts.position)


func copy_alpha() -> float:
	return _figure_mat.albedo_color.a


func bell_shown() -> bool:
	return copy_parts.visible and _bell_ring.visible


## The bell ring's radius now: it closes on the copy as the toll nears.
func bell_radius() -> float:
	return lerpf(BELL_FROM_M, BELL_TO_M, clampf(float(_time.get("bell", 0)) / 1000.0, 0.0, 1.0))


func link_alpha() -> float:
	return _link_mat.albedo_color.a if _link.visible else 0.0


func flashes_shown() -> int:
	return _flashes.filter(func(f: MeshInstance3D) -> bool: return f.visible).size()


func streak_shown() -> bool:
	return _streak.visible
