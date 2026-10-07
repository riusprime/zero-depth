class_name BossAvatar
extends Node3D
## The base of the three boss models (v0.3.0 C; docs/art/first-three-bosses-concept.png). It turns the sim state
## read through WorldReader into smoothed animation inputs (walk speed and phase, the windup of the attack in
## progress and its move, the hit of its active frame, a stagger, a leap's arc, burrowing, the rise-in) and each
## model poses itself from them in _pose(). Presentation only (EI-07): sync() reads once per tick, advance() animates
## in frame time, and nothing here feeds back into the sim. +X is the front and +Z the right; the node sits at the
## actor's feet under ActorViews' facing node.
## The owner's models (v0.3.0 L13): when assets/models/bosses/<model_id()>.glb exists (BossModels), it replaces the
## code-built body. It is one mesh, so it moves as a whole: breathing, a walk bob and sway, a lean and crouch with a
## red glow for the windup, a lunge and squash (a recoil for a turret) for the attack, a sag in recovery, a wobble
## when staggered, and a steady glow in the last phase. The glow is a material_overlay whose alpha changes, and the
## body's material is flashable (emission on at energy 0), so no shader ever changes at run time.
## The weak point (v0.3.0 BX, L17): a glowing core on the boss's chest while it is open (WorldReader
## .boss_weak_point_permille), a kept material with emission on from the start, so only its energy changes, and a
## small light; hidden while shut.

## Faster than this between two ticks is a teleport, not motion.
const TELEPORT_SPEED := 40.0
## Seconds to rise out of the ground once the intro ends; seconds to sink when burrowing.
const RISE_SECONDS := 0.8
const SINK_SECONDS := 0.3
## A leap's peak height (metres).
const LEAP_HEIGHT := 2.6
## Where the owner's boss models go (PLAN v0.3.0 L10): assets/models/bosses/<model_id()>.glb.
const MODEL_DIR := "res://assets/models/bosses/"
## The weak point's core (BX): its colour and its glow at full.
const WEAK_COLOR := Color("#FFD36A")
const WEAK_ENERGY := 5.0
const WEAK_LIGHT := 2.2

## Parts and materials, read by tests and by ActorViews (the hit flash).
var body_materials: Array[StandardMaterial3D] = []
var parts: BossParts
## The model's root (moved for the rise, a leap, a burrow and a stagger's slump).
var model := Node3D.new()
## The owner's model, when it is used (null with the code-built body), its pivot, and its glow overlay.
var imported: MeshInstance3D
var pivot: Node3D
var glow_overlay: StandardMaterial3D
## The owner's model's skeleton (v0.3.0 L13: rigged in code, BossRig) and its rig.
var skeleton: Skeleton3D
var rig: BossRig
## The weak point (BX): its core, its halo, their kept material and the light.
var weak_core := MeshInstance3D.new()
var weak_material := StandardMaterial3D.new()
var weak_light := OmniLight3D.new()
var _weak := 0.0
var _weak_shown := 0.0

# Sim state from the last sync.
var _fresh := true
var _last_tick := -1
var _last_pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _state := WorldReader.STATE_MOVE
var _move := -1
var _state_ticks := 0
var _windup := 0.0
var _leap := 0.0
var _airborne := false
var _hidden := false
var _boss_phase := 0
# Smoothed animation state.
var _t := 0.0
var _speed := 0.0
var _walk := 0.0
var _phase := 0.0
var _wind := 0.0
var _hit := 0.0
var _rise := 1.0
var _stagger := 0.0
var _sink := 0.0
var _late := 0.0


## Builds the model. technique "xray" adds a team-coloured silhouette twin to every body piece.
func setup(outline_color: Color, technique: StringName = &"xray") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parts = BossParts.new(outline_color, technique)
	model.name = "Model"
	add_child(model)
	_build_body()
	body_materials = parts.body_materials
	_build_weak_point()
	_pose_any(0.0)


## The weak point's core: a bright gem on the chest with a halo ring, unshaded, emission on from the start.
func _build_weak_point() -> void:
	weak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	weak_material.albedo_color = WEAK_COLOR
	weak_material.emission_enabled = true
	weak_material.emission = WEAK_COLOR
	weak_material.emission_energy_multiplier = 0.0
	weak_material.no_depth_test = true  # seen through the body's own front
	weak_core.name = "WeakPoint"
	var gem := SphereMesh.new()
	gem.radius = 0.24
	gem.height = 0.48
	gem.radial_segments = 12
	gem.rings = 6
	weak_core.mesh = gem
	weak_core.material_override = weak_material
	weak_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weak_core.position = _weak_point_at()
	weak_core.visible = false
	model.add_child(weak_core)
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.36
	torus.outer_radius = 0.44
	halo.mesh = torus
	halo.material_override = weak_material
	halo.rotation = Vector3(0, 0, PI * 0.5)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weak_core.add_child(halo)
	weak_light.name = "WeakLight"
	weak_light.light_color = WEAK_COLOR
	weak_light.light_energy = 0.0
	weak_light.omni_range = 3.0
	weak_light.shadow_enabled = false
	weak_core.add_child(weak_light)


## Where the weak point sits on the model (+X front, Y up); bodies override it.
func _weak_point_at() -> Vector3:
	return Vector3(0.75, 1.55, 0)


## 0..1: how open the weak point shows (tests).
func weak_amount() -> float:
	return _weak_shown


## Reads boss i's state after a sim tick.
func sync(reader: WorldReader, i: int) -> void:
	var tg := reader.telegraph(i)
	var leap := reader.boss_leap(i)
	apply_state(
		{
			"tick": reader.tick(),
			"pos": reader.actor_pos(i),
			"state": reader.actor_state(i),
			"move": reader.boss_move(i),
			"windup": float(tg.get("progress", 0)) / 1000.0,
			"state_ticks": reader.actor_state_ticks(i),
			"airborne": leap[0],
			"leap": leap[1],
			"hidden": reader.boss_hidden(i),
			"phase": reader.boss_phase(i),
			"weak": reader.boss_weak_point_permille(i) / 1000.0,
		}
	)


## The same as sync(), from plain values (tests and the render scripts drive the model with this): tick, pos,
## state (a WorldReader STATE_*), and optionally move (MOVE_*, -1 none), windup (0..1), state_ticks, airborne, leap
## (0..1), hidden.
func apply_state(s: Dictionary) -> void:
	var tick: int = s["tick"]
	var pos: Vector2 = s["pos"]
	var state: int = s["state"]
	var dt_ticks := tick - _last_tick
	if not _fresh and dt_ticks > 0:
		var v := (pos - _last_pos) * (60.0 / float(dt_ticks))
		_vel = v if v.length() <= TELEPORT_SPEED and dt_ticks <= 30 else Vector2.ZERO
	elif dt_ticks < 0:
		_vel = Vector2.ZERO
	_last_tick = tick
	_last_pos = pos
	if state == WorldReader.STATE_ACTIVE and _state != WorldReader.STATE_ACTIVE:
		_hit = 1.0
	_state = state
	_move = s.get("move", -1)
	_state_ticks = s.get("state_ticks", 0)
	_windup = clampf(s.get("windup", 0.0), 0.0, 1.0)
	_airborne = s.get("airborne", false)
	_leap = s.get("leap", 0.0)
	_hidden = s.get("hidden", false)
	_boss_phase = s.get("phase", 0)
	_weak = s.get("weak", 0.0)
	if _fresh:
		_fresh = false
		_rise = 0.0 if state == WorldReader.STATE_SPAWN else 1.0
		_pose_any(0.0)


func _process(delta: float) -> void:
	advance(delta)


## Advances the animation by `delta` seconds of frame time.
func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or parts == null:
		return
	_t += dt
	var moving := _state == WorldReader.STATE_MOVE
	_speed = lerpf(_speed, _vel.length() if moving or _airborne else 0.0, _rate(8.0, dt))
	_rise = move_toward(_rise, 0.0 if _state == WorldReader.STATE_SPAWN else 1.0, dt / RISE_SECONDS)
	_sink = move_toward(_sink, 1.0 if _hidden else 0.0, dt / SINK_SECONDS)
	var wind_target := 0.0
	if _state == WorldReader.STATE_WINDUP:
		wind_target = smoothstep(0.0, 0.8, _windup)
	_wind = lerpf(_wind, wind_target, _rate(10.0 if wind_target > _wind else 6.0, dt))
	_hit = move_toward(_hit, 0.0, dt * 2.2)
	var stag := 1.0 if _state == WorldReader.STATE_STAGGERED else 0.0
	_stagger = lerpf(_stagger, stag, _rate(7.0, dt))
	_late = move_toward(_late, 1.0 if _boss_phase > 0 else 0.0, dt)
	_pose_weak_point(dt)
	_pose_any(dt)
	# The rise from the ground, a leap's arc, the burrow's sink, the stagger's slump.
	var rise := 1.0 - _rise
	rise = rise * rise * (3.0 - 2.0 * rise)
	var lift := 0.0
	if _airborne:
		lift = 4.0 * _leap * (1.0 - _leap) * LEAP_HEIGHT
	model.position = Vector3(0, -3.2 * rise - 3.0 * _sink * _sink + lift - 0.12 * _stagger, 0)
	model.visible = _sink < 0.98


## The weak point: it pops open, pulses, and fades over its last fifth (energy and scale only).
func _pose_weak_point(dt: float) -> void:
	var target := 1.0 if _weak > 0.0 else 0.0
	_weak_shown = move_toward(_weak_shown, target, dt * (10.0 if target > _weak_shown else 4.0))
	weak_core.visible = _weak_shown > 0.01 and not _hidden
	var fade := clampf(_weak * 5.0, 0.0, 1.0)
	var pulse := 0.75 + 0.25 * sin(_t * 14.0)
	weak_material.emission_energy_multiplier = WEAK_ENERGY * _weak_shown * fade * pulse
	weak_light.light_energy = WEAK_LIGHT * _weak_shown * fade * pulse
	weak_core.scale = Vector3.ONE * (0.6 + 0.4 * _weak_shown) * (0.92 + 0.08 * pulse)
	(weak_core.get_node("Halo") as Node3D).rotation.x = _t * 3.0


## 0..1: the attack's windup pose.
func windup_amount() -> float:
	return _wind


## 0..1: the stagger slump.
func stagger_amount() -> float:
	return _stagger


func _rate(per_second: float, dt: float) -> float:
	return 1.0 - exp(-per_second * dt)


## Walk cycle: phase advanced by speed over the stride; returns the walk blend 0..1.
func _gait(dt: float, walk_speed: float, stride: float) -> float:
	var busy := maxf(_wind, _stagger)
	_walk = lerpf(
		_walk, 0.0 if busy > 0.3 else clampf(_speed / walk_speed, 0.0, 1.0), _rate(6.0, dt)
	)
	_phase += _speed * dt * TAU / stride * (1.0 - busy)
	return _walk


## The id of this boss's imported model (its file name without .glb).
func model_id() -> StringName:
	return &""


## The body, built in one place so an imported model can replace it by model_id() later, with the code-built body
## (_build) as the fallback. Importing isn't wired yet: every body is built in code.
func _build_body() -> void:
	var m := BossModels.get_model(model_id())
	if m.is_empty():
		_build()
		return
	_build_imported(m)
	for n in _code_nodes():
		if n.get_parent() == null:
			n.free()


## The owner's model: its mesh with the model's albedo kept, made flashable and outlined, a glow overlay, and an
## X-ray twin with the X-ray technique.
func _build_imported(m: Dictionary) -> void:
	pivot = Node3D.new()
	pivot.name = "Body"
	model.add_child(pivot)
	rig = m["rig"]
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	for k in rig.bones.size():
		var b: Array = rig.bones[k]
		skeleton.add_bone(String(b[0]))
		var at: Vector3 = b[2]
		if b[1] >= 0:
			skeleton.set_bone_parent(k, b[1])
			at -= rig.bones[b[1]][2]
		skeleton.set_bone_rest(k, Transform3D(Basis(), at))
	skeleton.reset_bone_poses()
	pivot.add_child(skeleton)
	imported = MeshInstance3D.new()
	imported.name = "Imported"
	imported.mesh = m["mesh"]
	imported.skin = m["skin"]
	var mat: StandardMaterial3D = (
		(m["material"] as StandardMaterial3D).duplicate()
		if m["material"] != null
		else StandardMaterial3D.new()
	)
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	mat.stencil_color = parts.outline_color()
	mat.stencil_outline_thickness = 0.03
	imported.material_override = ActorViews.flashable(mat)
	glow_overlay = StandardMaterial3D.new()
	glow_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	glow_overlay.albedo_color = Color(1.0, 0.06, 0.03, 0.0)
	imported.material_overlay = glow_overlay
	imported.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	skeleton.add_child(imported)
	imported.skeleton = NodePath("..")
	parts.body_materials.append(mat)
	if parts.technique() == &"xray":
		var ghost := MeshInstance3D.new()
		ghost.name = "XrayTwin"
		ghost.mesh = m["mesh"]
		ghost.skin = m["skin"]
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color("#6B5F5B")
		gm.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		# Shrunk along its normals (the skinned twin shares the body's surface, so it would z-fight with it).
		gm.grow = true
		gm.grow_amount = -0.04
		gm.stencil_color = Color(ThemePalette.color(&"enemy_body"), 0.85)
		ghost.material_override = gm
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		skeleton.add_child(ghost)
		ghost.skeleton = NodePath("..")


## Nodes the code-built body creates up front (freed when the owner's model is used instead).
func _code_nodes() -> Array[Node]:
	return []


## True for a body that kicks back when it fires (the turret) rather than lunging.
func _recoils() -> bool:
	return false


func _pose_any(dt: float) -> void:
	if imported != null:
		_pose_imported(dt)
	else:
		_pose(dt)


## The owner's single-mesh model moves as a whole.
func _pose_imported(dt: float) -> void:
	var walk := _gait(dt, 2.0, 1.6)
	var s := sin(_phase)
	var breath := sin(_t * 1.6) * (1.0 - walk)
	var lean := 0.0
	var crouch := 0.0
	var sag := 0.0
	if _state == WorldReader.STATE_WINDUP:
		lean = _wind
		crouch = _wind
	elif _state == WorldReader.STATE_RECOVER:
		sag = 1.0 - smoothstep(20.0, 60.0, float(_state_ticks))
	var hit := _hit * _hit
	var kick := -hit * 0.35 if _recoils() else hit * 0.45
	var squash := 0.0 if _recoils() else hit * 0.14
	var wob := sin(_t * 9.0) * _stagger
	pivot.position = Vector3(kick, absf(s) * 0.07 * walk, 0)
	pivot.rotation = Vector3(
		s * 0.04 * walk + wob * 0.08,
		0,
		(
			lean * 0.14
			- sag * 0.08
			- hit * (0.0 if _recoils() else 0.12)
			+ wob * 0.06
			+ _stagger * 0.08
		)
	)
	var sy := 1.0 + breath * 0.015 - crouch * 0.07 - squash - sag * 0.03
	var sxz := 1.0 + crouch * 0.03 + squash * 0.5
	pivot.scale = Vector3(sxz, sy, sxz)
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	_pose_rig(dt)
	glow_overlay.albedo_color.a = clampf(
		0.045 * _wind + 0.04 * _hit + _late * (0.02 + 0.01 * pulse), 0.0, 0.06
	)


## Subclasses move the owner's model's bones (BossRig) from the same inputs as the code-built body.
func _pose_rig(_dt: float) -> void:
	pass


## Sets a bone's pose: a rotation about `axis` (in the model frame: +X front, Y up) by `angle`, and an offset from
## its rest position.
func bone(
	bone_name: StringName, axis: Vector3, angle: float, offset: Vector3 = Vector3.ZERO
) -> void:
	var k := skeleton.find_bone(String(bone_name))
	if k < 0:
		return
	skeleton.set_bone_pose_rotation(k, Quaternion(axis.normalized(), angle))
	skeleton.set_bone_pose_position(k, skeleton.get_bone_rest(k).origin + offset)


## Sets a bone's rotation from a full quaternion, its offset and its scale.
func bone_q(
	bone_name: StringName, q: Quaternion, offset: Vector3 = Vector3.ZERO, scl: float = 1.0
) -> void:
	var k := skeleton.find_bone(String(bone_name))
	if k < 0:
		return
	skeleton.set_bone_pose_rotation(k, q)
	skeleton.set_bone_pose_position(k, skeleton.get_bone_rest(k).origin + offset)
	skeleton.set_bone_pose_scale(k, Vector3.ONE * scl)


## The glow overlay's strength now (0..1), for tests.
func glow_amount() -> float:
	return glow_overlay.albedo_color.a if glow_overlay != null else 0.0


## Subclasses build their code-built body with `parts` under `model`.
func _build() -> void:
	pass


## Subclasses pose their parts.
func _pose(_dt: float) -> void:
	pass


## 1 in the active frames of an attack, fading through its recovery (0 otherwise).
func _act_fade() -> float:
	if _state == WorldReader.STATE_ACTIVE:
		return 1.0
	if _state == WorldReader.STATE_RECOVER:
		return 1.0 - smoothstep(20.0, 60.0, float(_state_ticks))
	return 0.0
