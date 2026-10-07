class_name SkillVisuals
extends Node3D
## The build skills in the world (v0.3.5 K, owner F18). Reads WorldReader.skill_state() only (EI-07):
## - Lunge Cleave: while the lunge runs, the cleave's fan rides with the hero (the forecast: the same half arc and
##   reach the hit uses, PlayerSkill.cleave_touches); a streak from where the lunge started; when it lands, the fan
##   flashes white-hot.
## - Scatter Blast: a tracer from the muzzle to each pellet's end (the sim's own end points: a wall, an enemy or full
##   range) and a quick flash of the cone (half_cone, range_m).
## Nothing here changes an outcome.

const FX_FRAMES := 16
const TRACER_FRAMES := 9
const STREAK_FRAMES := 14
const COLOR := Color("#7FE9FF")
const HOT := Color("#FFFFFF")

## Live effects: [node, material, frames left, frames, kind, base alpha].
var _fx: Array = []
var _fx_template := _make_template()
var _forecast := MeshInstance3D.new()
var _forecast_mat: StandardMaterial3D
var _forecast_shape := Vector2.ZERO
var _box := BoxMesh.new()
var _last_hit := -1


func _init() -> void:
	name = "SkillVisuals"
	_box.size = Vector3.ONE
	_forecast_mat = _fx_template.duplicate() as StandardMaterial3D
	_forecast_mat.albedo_color = Color(COLOR, 0.22)
	_forecast.material_override = _forecast_mat
	_forecast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_forecast.visible = false
	add_child(_forecast)


func sync(reader: WorldReader) -> void:
	var s := reader.skill_state()
	if s.is_empty():
		_forecast.visible = false
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
				_streak(s["from"], s["hit_pos"], STREAK_FRAMES)
				_fan(s["hit_pos"], int(s["angle"]), int(s["half_arc"]), float(s["reach_m"]), reader)
			else:
				_blast(s, reader)
		_last_hit = hit


# --- Reads (tests) ------------------------------------------------------------------------------------------
func forecast_visible() -> bool:
	return _forecast.visible


## The forecast fan's (half arc in 1/4096 turns, reach in metres), as drawn.
func forecast_shape() -> Vector2:
	return _forecast_shape


func fx_count_of(kind: StringName) -> int:
	return _fx.filter(func(f: Array) -> bool: return f[4] == kind).size()


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
	_forecast_mat.albedo_color = Color(COLOR, 0.12 + 0.25 * t)


func _fan(at: Vector2, angle: int, half: int, reach: float, reader: WorldReader) -> void:
	var n := MeshInstance3D.new()
	n.mesh = KitView.fan_mesh(half, reader.player_radius(), reach)
	n.position = SimPlane.to_3d(at, 0.06)
	n.rotation = Vector3(0, SimPlane.yaw_of(angle), 0)
	_add(n, COLOR.lerp(HOT, 0.5), 0.75, &"cleave", FX_FRAMES)


func _streak(from: Vector2, to: Vector2, frames: int) -> void:
	var d := to - from
	var len := d.length()
	if len < 0.05:
		return
	var n := MeshInstance3D.new()
	n.mesh = _box
	n.position = SimPlane.to_3d((from + to) * 0.5, 0.45)
	n.rotation = Vector3(0, atan2(d.y, d.x), 0)
	n.scale = Vector3(len, 0.08, 0.5)
	_add(n, COLOR, 0.55, &"streak", frames)


func _blast(s: Dictionary, reader: WorldReader) -> void:
	var origin: Vector2 = s["hit_pos"]
	var angle := int(s["angle"])
	var n := MeshInstance3D.new()
	n.mesh = KitView.fan_mesh(int(s["half_cone"]), reader.player_radius(), float(s["range_m"]))
	n.position = SimPlane.to_3d(origin, 0.05)
	n.rotation = Vector3(0, SimPlane.yaw_of(angle), 0)
	_add(n, COLOR, 0.3, &"cone", TRACER_FRAMES)
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
		_add(t, HOT.lerp(COLOR, 0.3), 0.95, &"tracer", TRACER_FRAMES)


func _add(n: MeshInstance3D, c: Color, alpha: float, kind: StringName, frames: int) -> void:
	var m := _fx_template.duplicate() as StandardMaterial3D
	m.albedo_color = Color(c, alpha)
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(n)
	_fx.append([n, m, frames, frames, kind, alpha])


func _process(_delta: float) -> void:
	for k in range(_fx.size() - 1, -1, -1):
		var fx: Array = _fx[k]
		fx[2] -= 1
		(fx[1] as StandardMaterial3D).albedo_color.a = fx[5] * float(fx[2]) / fx[3]
		if fx[2] <= 0:
			(fx[0] as Node).queue_free()
			_fx.remove_at(k)


static func _make_template() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
