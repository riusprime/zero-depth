class_name SkillVisuals
extends Node3D
## The build skills in the world (v0.3.5 K, owner F18). Reads WorldReader.skill_state() only (EI-07):
## - Lunge Cleave: while the lunge runs, the cleave's fan rides with the hero (the forecast: the same half arc and
##   reach the hit uses, PlayerSkill.cleave_touches); a streak from where the lunge started; when it lands, the fan
##   flashes white-hot.
## - Scatter Blast: a tracer from the muzzle to each pellet's end (the sim's own end points: a wall, an enemy or full
##   range) and a quick flash of the cone (half_cone, range_m).
## v0.5.5 LK (owner A1: "The ability for gun and blade should match the animation"):
## - the cleave is drawn as a wide blade sweep across the real hit shape: a ribbon over the fan (the hero's edge out
##   to edge + reach, -half_arc..+half_arc round the lunge's angle; 180 degrees with the starting values) led by a
##   bright blade edge. It crosses the arc over the lunge's last CLEAVE_SWEEP_TICKS ticks and reaches the far edge on
##   the tick the cleave hits (cleave_progress, which PlayerAvatar's cleave pose also reads), holds through the
##   hit-stop and fades;
## - the blast adds a muzzle flash at the hero's edge; the cone flash is the real cone (2 x half_cone, range_m).
## Every effect ages in sim ticks (sync), not frames, so it lines up with the skill's ticks.
## v0.5.5 LK (owner A2): every skill effect takes the heat tier's colour (HeatLooks.attack_color): its own cyan below
## Hot, orange at Hot, red at Overclock.
## Nothing here changes an outcome.

## Effect lives in sim ticks.
const FX_TICKS := 16
const TRACER_TICKS := 9
const STREAK_TICKS := 14
const MUZZLE_TICKS := 6
## The cleave's sweep crosses the arc over the lunge's last this many ticks, landing on the hit tick.
const CLEAVE_SWEEP_TICKS := 4
## After the hit the sweep holds this many ticks (about the cleave's hit-stop), then fades over CLEAVE_FADE_TICKS.
const CLEAVE_HOLD_TICKS := 6
const CLEAVE_FADE_TICKS := 10
## Ribbon segments across the full arc, and the blade edge's height and thickness.
const CLEAVE_SEGMENTS := 28
const EDGE_HEIGHT := 0.45
const EDGE_THICK := 0.06
const COLOR := Color("#7FE9FF")
const HOT := Color("#FFFFFF")

## Live effects: [node, material, ticks left, ticks, kind, base alpha].
var _fx: Array = []
var _fx_template := _make_template()
## v0.5.5 LK (A3 VFX audit): the cleave's and the blast's flashes are light, added to the floor (HeatVisuals' glow
## template); mixed, their pale unshaded fans read as flat sheets over a dark lit floor.
var _glow_template := HeatVisuals.make_glow_template()
var _forecast := MeshInstance3D.new()
var _forecast_mat: StandardMaterial3D
var _forecast_shape := Vector2.ZERO
var _box := BoxMesh.new()
var _disc := CylinderMesh.new()
var _last_hit := -1
var _last_tick := -1
var _tier := HeatLooks.TIER_COOL
## The cleave sweep: a ribbon (rebuilt each tick) and its leading blade edge.
var _sweep := MeshInstance3D.new()
var _sweep_mesh := ImmediateMesh.new()
var _sweep_mat := StandardMaterial3D.new()
var _edge := MeshInstance3D.new()
var _edge_mat: StandardMaterial3D
## The sweep as of the last sync: [progress 0..1, strength 0..1, half arc (1/4096 turns), outer radius m].
var _sweep_state: Array = [0.0, 0.0, 0, 0.0]


func _init() -> void:
	name = "SkillVisuals"
	_box.size = Vector3.ONE
	_disc.top_radius = 1.0
	_disc.bottom_radius = 1.0
	_disc.height = 0.02
	_disc.radial_segments = 20
	_forecast_mat = _fx_template.duplicate() as StandardMaterial3D
	_forecast_mat.albedo_color = Color(COLOR, 0.22)
	_forecast.material_override = _forecast_mat
	_forecast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_forecast.visible = false
	add_child(_forecast)
	_sweep_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sweep_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sweep_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sweep_mat.vertex_color_use_as_albedo = true
	_sweep_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_sweep.name = "CleaveSweep"
	_sweep.mesh = _sweep_mesh
	_sweep.material_override = _sweep_mat
	_sweep.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sweep.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_sweep.extra_cull_margin = 8.0
	add_child(_sweep)
	_edge_mat = _fx_template.duplicate() as StandardMaterial3D
	_edge.name = "CleaveEdge"
	_edge.mesh = _box
	_edge.material_override = _edge_mat
	_edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_edge.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_edge.visible = false
	add_child(_edge)


## How far the cleave's sweep has crossed its arc (0..1) and how strongly it is drawn (0..1), from the skill's
## ticks: `running` (the lunge's tick, 0 when not lunging), `move_ticks` (the lunge's length) and `since_hit` (ticks
## since the cleave hit, -1 if it hasn't). The sweep starts CLEAVE_SWEEP_TICKS before the lunge ends and reaches 1 on
## the hit tick; then it holds and fades. PlayerAvatar's cleave pose reads the same function.
static func cleave_progress(running: int, move_ticks: int, since_hit: int) -> Vector2:
	if running > 0:
		var start := move_ticks - CLEAVE_SWEEP_TICKS
		var p := clampf(float(running - start) / float(CLEAVE_SWEEP_TICKS + 1), 0.0, 1.0)
		return Vector2(p, 1.0 if p > 0.0 else 0.0)
	if since_hit < 0 or since_hit >= CLEAVE_HOLD_TICKS + CLEAVE_FADE_TICKS:
		return Vector2.ZERO
	var fade := clampf(float(since_hit - CLEAVE_HOLD_TICKS) / CLEAVE_FADE_TICKS, 0.0, 1.0)
	return Vector2(1.0, 1.0 - fade)


func sync(reader: WorldReader) -> void:
	_tier = HeatLooks.tier_of(reader.heat_state())
	var tick := reader.tick()
	if _last_tick >= 0 and tick > _last_tick:
		_age(tick - _last_tick)
	_last_tick = tick
	var s := reader.skill_state()
	if s.is_empty():
		_forecast.visible = false
		_hide_sweep()
		return
	var cleave: bool = int(s["kind"]) == WorldReader.SKILL_LUNGE_CLEAVE
	var running: bool = int(s["running"]) > 0
	_forecast.visible = cleave and running
	if _forecast.visible:
		_show_forecast(s, reader)
	var hit := int(s["hit_tick"])
	if hit != _last_hit:
		if hit >= 0:
			if cleave:
				_streak(s["from"], s["hit_pos"], STREAK_TICKS)
				_fan(s["hit_pos"], int(s["angle"]), int(s["half_arc"]), float(s["reach_m"]), reader)
			else:
				_blast(s, reader)
		_last_hit = hit
	if cleave:
		_show_sweep(s, reader, tick)
	else:
		_hide_sweep()


# --- Reads (tests) ------------------------------------------------------------------------------------------
func forecast_visible() -> bool:
	return _forecast.visible


## The forecast fan's (half arc in 1/4096 turns, reach in metres), as drawn.
func forecast_shape() -> Vector2:
	return _forecast_shape


func fx_count_of(kind: StringName) -> int:
	return _fx.filter(func(f: Array) -> bool: return f[4] == kind).size()


## The colour the skill's effects take now (HeatLooks.attack_color of the heat tier).
func fx_color() -> Color:
	return AttackView.edge_color(COLOR, _tier)  # v0.6.0 MX1: the attacks' one edge rule


## The colour of the newest live effect of a kind (its material's albedo, alpha 1), or transparent black.
func fx_color_of(kind: StringName) -> Color:
	for k in range(_fx.size() - 1, -1, -1):
		if _fx[k][4] == kind:
			return Color((_fx[k][1] as StandardMaterial3D).albedo_color, 1.0)
	return Color(0, 0, 0, 0)


## The cleave sweep as drawn at the last sync: progress across the arc (0..1), strength (0 hidden), the arc's half
## width (1/4096 turns) and its outer radius (m, from the hero's centre).
func cleave_sweep() -> Array:
	return _sweep_state.duplicate()


## The blade edge leading the sweep is drawn.
func cleave_edge_visible() -> bool:
	return _edge.visible


# --- Drawing ------------------------------------------------------------------------------------------------
func _show_forecast(s: Dictionary, reader: WorldReader) -> void:
	var half := int(s["half_arc"])
	var reach := float(s["reach_m"])
	if _forecast_shape != Vector2(half, reach):
		_forecast_shape = Vector2(half, reach)
		_forecast.mesh = KitView.fan_mesh(half, reader.player_radius(), reach)
	_forecast.position = SimPlane.to_3d(reader.player_pos(), 0.04)
	_forecast.rotation = Vector3(0, SimPlane.yaw_of(int(s["angle"])), 0)
	var t := float(s["running"]) / maxf(1.0, float(s["move_ticks"]))
	_forecast_mat.albedo_color = Color(fx_color(), 0.12 + 0.25 * t)


func _hide_sweep() -> void:
	_sweep_state = [0.0, 0.0, 0, 0.0]
	_sweep_mesh.clear_surfaces()
	_edge.visible = false


## The cleave sweep: a ribbon over the hit's fan from its starting edge to the blade edge, brightest at the edge.
func _show_sweep(s: Dictionary, reader: WorldReader, tick: int) -> void:
	var running := int(s["running"])
	var hit := int(s["hit_tick"])
	var since_hit := tick - hit if hit >= 0 and running == 0 else -1
	var ps := cleave_progress(running, int(s["move_ticks"]), since_hit)
	var p := ps.x
	var strength := ps.y
	var half_arc := int(s["half_arc"])
	var r_in := reader.player_radius()
	var r_out := r_in + float(s["reach_m"])
	_sweep_state = [p, strength, half_arc, r_out]
	_sweep_mesh.clear_surfaces()
	if p <= 0.0 or strength <= 0.0:
		_edge.visible = false
		return
	var centre: Vector2 = reader.player_pos() if running > 0 else s["hit_pos"]
	var at := SimPlane.to_3d(centre, 0.07)
	var aim := SimPlane.yaw_of(int(s["angle"]))
	var half := TAU * float(half_arc) / 4096.0
	var start := aim - half
	var now := start + 2.0 * half * p
	var c := fx_color()
	var n := maxi(2, ceili(CLEAVE_SEGMENTS * p))
	_sweep_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for k in n + 1:
		var f := float(k) / n  # 0 at the starting edge, 1 at the blade
		var yaw := lerpf(start, now, f)
		var out := Vector3(cos(yaw), 0, -sin(yaw))
		_sweep_mesh.surface_set_color(Color(c, 0.08 * strength * f))
		_sweep_mesh.surface_add_vertex(at + out * r_in)
		_sweep_mesh.surface_set_color(
			Color(c.lightened(0.15), strength * (0.12 + 0.75 * pow(f, 1.6)))
		)
		_sweep_mesh.surface_add_vertex(at + out * r_out)
	_sweep_mesh.surface_end()
	_edge.visible = true
	var mid := (r_in + r_out) * 0.5
	_edge.position = SimPlane.to_3d(centre, EDGE_HEIGHT) + Vector3(cos(now), 0, -sin(now)) * mid
	_edge.rotation = Vector3(0, now, 0)
	_edge.scale = Vector3(r_out - r_in, EDGE_THICK, EDGE_THICK)
	_edge_mat.albedo_color = Color(c.lightened(0.45), strength)


func _fan(at: Vector2, angle: int, half: int, reach: float, reader: WorldReader) -> void:
	var n := MeshInstance3D.new()
	n.mesh = KitView.fan_mesh(half, reader.player_radius(), reach)
	n.position = SimPlane.to_3d(at, 0.06)
	n.rotation = Vector3(0, SimPlane.yaw_of(angle), 0)
	_add(n, fx_color().lerp(HOT, 0.35), 0.3, &"cleave", FX_TICKS, _glow_template)


func _streak(from: Vector2, to: Vector2, ticks: int) -> void:
	var d := to - from
	var len := d.length()
	if len < 0.05:
		return
	var n := MeshInstance3D.new()
	n.mesh = _box
	n.position = SimPlane.to_3d((from + to) * 0.5, 0.45)
	n.rotation = Vector3(0, atan2(d.y, d.x), 0)
	n.scale = Vector3(len, 0.08, 0.5)
	_add(n, fx_color(), 0.55, &"streak", ticks)


func _blast(s: Dictionary, reader: WorldReader) -> void:
	var origin: Vector2 = s["hit_pos"]
	var angle := int(s["angle"])
	var c := fx_color()
	var n := MeshInstance3D.new()
	n.mesh = KitView.fan_mesh(int(s["half_cone"]), reader.player_radius(), float(s["range_m"]))
	n.position = SimPlane.to_3d(origin, 0.05)
	n.rotation = Vector3(0, SimPlane.yaw_of(angle), 0)
	_add(n, c, 0.22, &"cone", TRACER_TICKS, _glow_template)
	var a0 := TAU * angle / 4096.0
	var flash := MeshInstance3D.new()
	flash.mesh = _disc
	flash.position = SimPlane.to_3d(
		origin + Vector2(cos(a0), sin(a0)) * reader.player_radius(), SimPlane.CORE_HEIGHT
	)
	flash.rotation = Vector3(0, 0, PI * 0.5)
	flash.scale = Vector3(0.32, 1, 0.32)
	_add(flash, c.lerp(HOT, 0.6), 0.9, &"muzzle", MUZZLE_TICKS)
	var angles := reader.skill_pellet_angles(angle)
	var ends: PackedVector2Array = s["pellet_ends"]
	for j in mini(angles.size(), ends.size()):
		var a := TAU * angles[j] / 4096.0
		var muzzle := origin + Vector2(cos(a), sin(a)) * reader.player_radius()
		var t := MeshInstance3D.new()
		var d := ends[j] - muzzle
		t.mesh = _box
		t.position = SimPlane.to_3d((muzzle + ends[j]) * 0.5, SimPlane.CORE_HEIGHT)
		t.rotation = Vector3(0, atan2(d.y, d.x), 0)
		t.scale = Vector3(maxf(0.05, d.length()), 0.04, 0.04)
		_add(t, HOT.lerp(c, 0.3), 0.95, &"tracer", TRACER_TICKS)


func _add(
	n: MeshInstance3D,
	c: Color,
	alpha: float,
	kind: StringName,
	ticks: int,
	template: StandardMaterial3D = null
) -> void:
	var m := (template if template != null else _fx_template).duplicate() as StandardMaterial3D
	m.albedo_color = Color(c, alpha)
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(n)
	_fx.append([n, m, ticks, ticks, kind, alpha])


## Ages every effect by `ticks` sim ticks: it fades with its life and goes when the life is out.
func _age(ticks: int) -> void:
	for k in range(_fx.size() - 1, -1, -1):
		var fx: Array = _fx[k]
		fx[2] -= ticks
		(fx[1] as StandardMaterial3D).albedo_color.a = fx[5] * maxf(0.0, float(fx[2])) / fx[3]
		if fx[2] <= 0:
			(fx[0] as Node).queue_free()
			_fx.remove_at(k)


static func _make_template() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
