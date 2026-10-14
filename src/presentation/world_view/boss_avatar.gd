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
## v0.7.5 BM: the owner's rigged models (the Warlord, the Hive Lens; BossModels "skinned") keep their own skeleton
## and skin, and the Foundry is cut in code (BossRig). Their bodies pose bone by bone through a BonePoser in the
## model frame, one function per pose layer (idle, walk, attack, guard, flinch, stagger, death, and a "shielded"
## hook a later step drives). More read state: the HP (a drop flinches), the player's bearing from the facing (the
## Hive Lens's eye turns to it) and the facing (the local velocity that trails the cables). The weak point's core
## follows its bone. All of it reads the sim and writes only this node's own children (EI-07).
## v0.8.0 BA (owner O6: "the animations they do are a shit … like we did with the actual attacks of the player"; Q4:
## code clips now, the owner's replace them): the owner's models are animated by keyframed clips (BossClip) played
## in layers by a BossAnimator: idle and walk (matched to its speed), one clip per attack move (its time driven by
## the sim's attack phase: anticipation fills the windup, the strike pose lands on the first active tick, the
## follow-through and recovery follow; clip_time), and the shielded hold, a hit's flinch, the stagger, the phase
## gate's roar, the rise-in (with the boss bar: WorldReader.boss_intro_permille) and the death collapse, which every
## model now plays after the sim removes it. Each body's library is its <Boss>Clips; its _pose_rig only adds what
## follows the clips (the Hive Lens's trailing tails, a spider's leg groups). Reduced motion: no tremble or daze
## sway and no overshoot (BossClip SETTLE keys), the same poses.

## Faster than this between two ticks is a teleport, not motion.
const TELEPORT_SPEED := 40.0
## v0.7.5 BM: seconds a boss that falls when it dies (has_death_pose) keeps drawing after the sim removed it.
const DEATH_SECONDS := 1.6
## Seconds to rise out of the ground once the intro ends; seconds to sink when burrowing.
const RISE_SECONDS := 0.8
const SINK_SECONDS := 0.3
## A leap's peak height (metres).
const LEAP_HEIGHT := 2.6
## v0.8.0 BA: seconds of the rise clip's flourish after the intro ends; the defaults of an attack's active and
## recover ticks when apply_state isn't told them (tests, shots); seconds the stagger clip's reel takes; the
## shielded hold's brace.
const RISE_FLOURISH_SECONDS := 1.0
const DEFAULT_ACTIVE_TICKS := 6
const DEFAULT_RECOVER_TICKS := 60
const STAGGER_CLIP_SECONDS := 1.2
const SHIELD_CLIP_SECONDS := 0.4
## v0.8.0 BS1 (S2): the clip a boss plays while its javelins stand in the floor (WarlordClips), timed 0..1 by the
## recall (WorldReader.boss_recall_permille).
const RECALL_CLIP := &"recall"
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
## v0.7.5 BM: poses the model's bones in the model frame (the skinned models and the Foundry).
var poser: BonePoser
## v0.8.0 BA: plays the model's clips (null with the code-built body).
var animator: BossAnimator
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
# v0.7.5 BM: more read state and its smoothed animation inputs.
var _last_hp := -1
var _aim := 0.0
var _facing_yaw := 0.0
var _shielded := false
var _flinch := 0.0
var _aim_shown := 0.0
var _shield_hold := 0.0
var _death := 0.0
var _dying := false
var _local_vel := Vector3.ZERO
# The weak point's rest position in the skeleton's space (it follows _weak_bone()).
var _weak_rest_skel := Vector3.ZERO
# The attack in progress as the sim has it (the avatars remap _move for the code bodies), its timing
# (BossAnimator: windup, active, recover, strike gap), a serial that changes with each new attack, whether it is
# shielded, the frame time since the last sync (the clip runs between ticks), the gate's and the intro's progress,
# when a burrow came back up, and the reaction clips' clocks.
var _clip_move := -1
var _attack_ticks := Vector4i.ZERO
var _attack_serial := 0
var _attack_shielded := false
var _since_sync := 0.0
var _just_synced := false
var _gate := -1.0
var _gate_w := 0.0
var _gate_t := 0.0
var _intro := -1.0
var _rise_t := 1.0
var _unhide_tick := -1
var _was_hidden := false
var _stagger_secs := 0.0
var _shield_t := 0.0
## v0.8.0 BS1 (S2): the recall's progress 0..1 while the boss's javelins stand in the floor (held at 1 while they fly
## back, through the rest of the attack), -1 with none; its "recall" clip then plays instead of the attack's.
var _recall := -1.0


## Builds the model. technique "xray" adds a team-coloured silhouette twin to every body piece.
func setup(outline_color: Color, technique: StringName = &"xray") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parts = BossParts.new(outline_color, technique)
	model.name = "Model"
	model.scale = Vector3.ONE * BossModels.SIZE_SCALE  # v0.7.5 BM (owner N18): every boss 1.3x
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
			"hp": reader.actor_hp(i),
			"facing": SimPlane.yaw_of(reader.actor_facing(i)),
			"aim": bearing(reader.actor_pos(i), reader.actor_facing(i), reader.player_pos()),
			"shielded": reader.boss_shielded(i),  # v0.7.5 BF1: its signature pattern (the shell and the pose)
			"attack_ticks": reader.boss_attack_ticks(i),  # v0.8.0 BA: the clip's timing
			"recall": reader.boss_recall_permille(i) / 1000.0,  # v0.8.0 BS1: the javelins' pull
			"gate": reader.boss_gate_permille(i) / 1000.0,
			"intro": reader.boss_intro_permille(i) / 1000.0,
		}
	)


## The player's bearing from a boss at `pos` facing `facing` (1/4096 turns): radians, + toward the boss's left
## (counter-clockwise seen from above, like the facing's yaw), in -PI..PI.
static func bearing(pos: Vector2, facing: int, target: Vector2) -> float:
	var d := target - pos
	if d.length_squared() < 0.0001:
		return 0.0
	return wrapf(atan2(d.y, d.x) - SimPlane.yaw_of(facing), -PI, PI)


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
	# v0.8.0 BA: a windup entered (or a new move winding up) is a new attack for the clips.
	var raw_move: int = s.get("move", -1)
	var shielded: bool = s.get("shielded", false)
	if (
		state == WorldReader.STATE_WINDUP
		and (_state != WorldReader.STATE_WINDUP or raw_move != _clip_move)
	):
		_attack_serial += 1
		_attack_shielded = shielded
		_unhide_tick = -1
	elif shielded:
		_attack_shielded = true
	_clip_move = raw_move
	_attack_ticks = s.get("attack_ticks", Vector4i.ZERO)
	# v0.8.0 BS1 (S2): the recall starts a new clip (crossfaded); it holds its pull while the javelins fly back.
	var recall: float = s.get("recall", -1.0)
	if recall >= 0.0:
		if _recall < 0.0:
			_attack_serial += 1
		_recall = recall
	elif _recall >= 0.0 and state != WorldReader.STATE_ACTIVE:
		_recall = -1.0
	elif _recall >= 0.0:
		_recall = 1.0
	_gate = s.get("gate", -1.0)
	_intro = s.get("intro", -1.0)
	_since_sync = 0.0
	_just_synced = true
	var hidden: bool = s.get("hidden", false)
	if _was_hidden and not hidden:
		_unhide_tick = tick
	_was_hidden = hidden
	_state = state
	_move = s.get("move", -1)
	_state_ticks = s.get("state_ticks", 0)
	_windup = clampf(s.get("windup", 0.0), 0.0, 1.0)
	_airborne = s.get("airborne", false)
	_leap = s.get("leap", 0.0)
	_hidden = s.get("hidden", false)
	_boss_phase = s.get("phase", 0)
	_weak = s.get("weak", 0.0)
	# v0.7.5 BM: a drop in HP flinches; the bearing to the player, the facing, and "shielded" (BF1's
	# WorldReader.boss_shielded: the boss is firing its shielded signature).
	var hp: int = s.get("hp", -1)
	if hp >= 0 and _last_hp >= 0 and hp < _last_hp:
		_flinch = 1.0
	_last_hp = hp
	_aim = s.get("aim", 0.0)
	_facing_yaw = s.get("facing", 0.0)
	_shielded = s.get("shielded", false)
	_local_vel = Basis(Vector3.UP, _facing_yaw).inverse() * SimPlane.to_3d(_vel)
	if _fresh:
		_fresh = false
		_rise = 0.0 if state == WorldReader.STATE_SPAWN else 1.0
		_rise_t = 0.0 if state == WorldReader.STATE_SPAWN else 1.0
		_pose_any(0.0)


func _process(delta: float) -> void:
	advance(delta)


## Advances the animation by `delta` seconds of frame time.
func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or parts == null:
		return
	_t += dt
	# The first frame after a sync shows that tick exactly; later frames (a fast display) run on toward the next.
	if _just_synced:
		_just_synced = false
	else:
		_since_sync += dt
	var moving := _state == WorldReader.STATE_MOVE
	_speed = lerpf(_speed, _vel.length() if moving or _airborne else 0.0, _rate(8.0, dt))
	var spawning := _state == WorldReader.STATE_SPAWN
	if spawning and _intro >= 0.0:
		# v0.8.0 BA: it rises with the boss bar (the sim's intro, L22), not after it.
		_rise = move_toward(_rise, _intro, dt * 4.0)
	else:
		_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt / RISE_SECONDS)
	_sink = move_toward(_sink, 1.0 if _hidden else 0.0, dt / SINK_SECONDS)
	var wind_target := 0.0
	if _state == WorldReader.STATE_WINDUP:
		wind_target = smoothstep(0.0, 0.8, _windup)
	_wind = lerpf(_wind, wind_target, _rate(10.0 if wind_target > _wind else 6.0, dt))
	_hit = move_toward(_hit, 0.0, dt * 2.2)
	var stag := 1.0 if _state == WorldReader.STATE_STAGGERED else 0.0
	_stagger = lerpf(_stagger, stag, _rate(7.0, dt))
	_late = move_toward(_late, 1.0 if _boss_phase > 0 else 0.0, dt)
	_flinch = move_toward(_flinch, 0.0, dt * 3.5)
	_aim_shown = lerpf(_aim_shown, _aim, _rate(3.0, dt))
	_shield_hold = lerpf(_shield_hold, 1.0 if _shielded else 0.0, _rate(8.0, dt))
	if _dying:
		_death = move_toward(_death, 1.0, dt / (DEATH_SECONDS * 0.75))
	_advance_clips(dt, spawning)
	_pose_weak_point(dt)
	_pose_any(dt)
	_follow_weak_bone()
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
	weak_core.visible = _weak_shown > 0.01 and not _hidden and not _dying
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


## 0..1: the flinch of the last hit taken (v0.7.5 BM).
func flinch_amount() -> float:
	return _flinch


## 0..1: the "shielded" pose (v0.7.5 BM; apply_state's "shielded", read from the sim by sync()).
func shielded_amount() -> float:
	return _shield_hold


## 0..1: how far the death fall has played.
func death_amount() -> float:
	return _death


## True when this boss's body plays a fall after the sim removes it (v0.8.0 BA: every owner's model collapses).
func has_death_pose() -> bool:
	return imported != null


## The sim removed this boss: start the death fall. False when the body has none (ActorViews frees it at once).
func die() -> bool:
	if not has_death_pose():
		return false
	_dying = true
	return true


## Where a named point on the body is now (v0.7.5 BM: for telegraphs and fireballs to start from), in this node's
## space: &"weak" is the weak point's core; bodies add their own (anchor_names()). Unknown names give the core.
func anchor(point: StringName) -> Vector3:
	return model.transform * _anchor(point)


## The points anchor() knows on this body.
func anchor_names() -> Array[StringName]:
	return [&"weak"]


## A body's own anchors, in the model's space (+X front, Y up); the weak point's core otherwise.
func _anchor(_point: StringName) -> Vector3:
	return weak_core.position


## The bone the weak point's core rides on (the owner's rigged models), or &"" to keep it still.
func _weak_bone() -> StringName:
	return &""


## The core rides on its bone: the rest position moved by how far the bone has turned and shifted from its rest.
func _follow_weak_bone() -> void:
	var bone := _weak_bone()
	if poser == null or bone == &"" or not poser.has_bone(bone):
		return
	var k := poser.index_of(bone)
	var delta := (
		skeleton.get_bone_global_pose(k) * skeleton.get_bone_global_rest(k).affine_inverse()
	)
	weak_core.position = _skel_to_model() * (delta * _weak_rest_skel)


## The skeleton node's space in the model's space now (the pivot's breath and lean included).
func _skel_to_model() -> Transform3D:
	return pivot.transform * BossModels.relative_transform(pivot, skeleton)


## A point in the skeleton's space moved with `bone` from its rest, in the model's space (the anchors).
func _on_bone(bone: StringName, rest_model: Vector3) -> Vector3:
	if poser == null or not poser.has_bone(bone):
		return rest_model
	var k := poser.index_of(bone)
	var rest_skel := BossModels.relative_transform(pivot, skeleton).affine_inverse() * rest_model
	var delta := (
		skeleton.get_bone_global_pose(k) * skeleton.get_bone_global_rest(k).affine_inverse()
	)
	return _skel_to_model() * (delta * rest_skel)


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
	if m.get("skinned", false):
		_build_skinned(m)
	else:
		_build_imported(m)
	_weak_rest_skel = (
		BossModels.relative_transform(pivot, skeleton).affine_inverse() * _weak_point_at()
	)
	animator = BossAnimator.new(_clip_library())
	var players := pivot.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		animator.bind_owner(players[0] as AnimationPlayer, skeleton)  # Q4: the owner's clips replace ours
	for n in _code_nodes():
		if n.get_parent() == null:
			n.free()


## v0.7.5 BM: the owner's rigged model as delivered, its own skeleton and skin, under a node that turns, scales and
## lifts it into our frame; dressed like the others (flashable, outlined, the glow overlay, the X-ray twin).
func _build_skinned(m: Dictionary) -> void:
	pivot = Node3D.new()
	pivot.name = "Body"
	model.add_child(pivot)
	var holder := Node3D.new()
	holder.name = "Normalise"
	holder.transform = m["transform"]
	pivot.add_child(holder)
	var inst: Node3D = (m["scene"] as PackedScene).instantiate()
	holder.add_child(inst)
	skeleton = inst.find_children("*", "Skeleton3D", true, false)[0]
	for n: Node in inst.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).skin != null:
			imported = n
			break
	imported.name = "Imported"
	# Poses move parts past the rest pose's bounds (a raised shield, a thrown spear, a folded head): never cull early.
	imported.extra_cull_margin = 2.0
	_dress(imported, m["material"], m["scale"])
	poser = BonePoser.new(skeleton, m["frame"], m["scale"])


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
	skeleton.add_child(imported)
	imported.skeleton = NodePath("..")
	_dress(imported, m["material"])
	poser = BonePoser.new(skeleton)


## Dresses the owner's skinned mesh: its own material kept (texture and all), duplicated, made flashable (no drawn
## outline since v0.7.5), the glow overlay, shadows on, and with the X-ray technique a twin on the same skeleton.
## `units` is the mesh's metres per unit (the twin shrinks by 4 cm along its normals in metres).
func _dress(mi: MeshInstance3D, material: StandardMaterial3D, units: float = 1.0) -> void:
	var mat: StandardMaterial3D = (
		material.duplicate() as StandardMaterial3D if material != null else StandardMaterial3D.new()
	)
	# v0.7.5 (owner: "remove the stroke outline around the bosses model, it is ugly"): no drawn outline on the
	# owner's models. The outline stencil mode stays, at zero thickness, so the X-ray twin's stencil is unchanged.
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_OUTLINE
	mat.stencil_color = parts.outline_color()
	mat.stencil_outline_thickness = 0.0
	mi.material_override = ActorViews.flashable(mat)
	glow_overlay = StandardMaterial3D.new()
	glow_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	glow_overlay.albedo_color = Color(1.0, 0.06, 0.03, 0.0)
	mi.material_overlay = glow_overlay
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parts.body_materials.append(mat)
	if parts.technique() == &"xray":
		var ghost := MeshInstance3D.new()
		ghost.name = "XrayTwin"
		ghost.mesh = mi.mesh
		ghost.skin = mi.skin
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color("#6B5F5B")
		gm.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		# Shrunk along its normals (the skinned twin shares the body's surface, so it would z-fight with it).
		gm.grow = true
		gm.grow_amount = -0.04 / maxf(units, 0.0001)
		gm.stencil_color = Color(ThemePalette.color(&"enemy_body"), 0.85)
		ghost.material_override = gm
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.extra_cull_margin = mi.extra_cull_margin
		mi.get_parent().add_child(ghost)
		ghost.transform = mi.transform
		ghost.skeleton = mi.skeleton  # a sibling: the same path reaches the skeleton


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


## The owner's model (v0.8.0 BA): its clips in layers (BossAnimator), then what each body adds after them
## (_pose_rig), the bones written once (BonePoser.commit), the owner's own clips over them, and the windup glow.
func _pose_imported(dt: float) -> void:
	_gait(dt, _walk_speed(), _stride())
	var reduced := ViewPrefs.reduced_motion
	_animate(dt)
	animator.apply(poser, pivot, reduced)
	if not reduced:
		# A tremble (a roar, a strain) and the stagger's dazed sway: shake, so never with reduced motion.
		var tremble := animator.param(&"tremble")
		var daze := animator.param(&"daze")
		pivot.position += Vector3(sin(_t * 47.0), 0.0, cos(_t * 41.0)) * 0.03 * tremble
		pivot.rotation += Vector3(sin(_t * 5.3) * 0.08, 0.0, sin(_t * 3.7) * 0.06) * daze
	_pose_rig(dt)
	poser.commit()
	animator.apply_owner(skeleton)
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var extra := _extra_glow()  # v0.8.0 FB1: a final boss's body cracking as it shatters
	glow_overlay.albedo_color.a = clampf(
		0.045 * _wind + 0.04 * _hit + _late * (0.02 + 0.01 * pulse) + extra, 0.0, 0.06 + extra
	)


## v0.8.0 FB1: extra glow over the windup's (0 for most bodies; FinalBodyAvatar's shatter).
func _extra_glow() -> float:
	return 0.0


## The clips' clocks that run in frame time: the stagger's, the shielded hold's, the gate's roar, the rise.
func _advance_clips(dt: float, spawning: bool) -> void:
	_stagger_secs = _stagger_secs + dt if _state == WorldReader.STATE_STAGGERED else 0.0
	if _shielded:
		_shield_t = minf(1.0, _shield_t + dt / SHIELD_CLIP_SECONDS)
	elif _shield_hold < 0.01:
		_shield_t = 0.0
	var gating := _state == WorldReader.STATE_GATE
	_gate_w = move_toward(_gate_w, 1.0 if gating else 0.0, dt / BossAnimator.FADE_OUT)
	if gating:
		_gate_t = _gate if _gate >= 0.0 else minf(1.0, _gate_t + dt)
	elif _gate_w <= 0.0:
		_gate_t = 0.0
	if spawning:
		_rise_t = 0.55 * _rise
	elif _rise_t < 1.0:
		_rise_t = minf(1.0, maxf(_rise_t, 0.55 * _rise) + dt / RISE_FLOURISH_SECONDS * 0.45)


## Sets every clip layer from the read state: the base (idle, walk), the attack, and the reactions.
func _animate(dt: float) -> void:
	var an := animator
	an.set_layer(BossAnimator.IDLE, &"idle", _t / _idle_seconds(), 1.0 - _walk)
	an.set_layer(BossAnimator.WALK, &"walk", _phase / TAU, _walk)
	var attacking := (
		_clip_move >= 0
		and not _dying
		and (
			_state == WorldReader.STATE_WINDUP
			or _state == WorldReader.STATE_ACTIVE
			or _state == WorldReader.STATE_RECOVER
		)
	)
	var clip_name := BossAnimator.clip_name_for(_clip_move, _attack_shielded, an.clips)
	var c := an.clips.get(clip_name) as BossClip
	var t := clip_time(c) if c != null else 0.0
	if _recall >= 0.0 and an.has_clip(RECALL_CLIP):  # v0.8.0 BS1 (S2): the pull, timed by the recall
		clip_name = RECALL_CLIP
		t = _recall
	an.drive_action(clip_name, _attack_serial, t, attacking, dt)
	var variant := String(clip_name).ends_with(BossAnimator.SHIELDED_SUFFIX)
	an.set_layer(
		BossAnimator.SHIELD, &"shielded", _shield_t, 0.0 if variant or _dying else _shield_hold
	)
	an.set_layer(
		BossAnimator.FLINCH,
		&"flinch",
		1.0 - _flinch,
		(0.6 if ViewPrefs.reduced_motion else 1.0) if _flinch > 0.0 and not _dying else 0.0
	)
	an.set_layer(
		BossAnimator.STAGGER,
		&"stagger",
		minf(1.0, _stagger_secs / STAGGER_CLIP_SECONDS),
		_stagger * (1.0 - _death)
	)
	an.set_layer(BossAnimator.ROAR, &"roar", _gate_t, _gate_w * (1.0 - _death))
	an.set_layer(BossAnimator.RISE, &"rise", _rise_t, 1.0 if _rise_t < 1.0 else 0.0)
	an.set_layer(BossAnimator.DEATH, &"death", _death, 1.0 if _dying else 0.0)


## The attack clip's time now (0..1), from the sim's attack phase: the windup fills 0..strike (the anticipation),
## the first active tick is exactly `strike` (the hit), the active ticks run strike..hold (several strikes cycle it
## once per strike), the recovery hold..1. Between two ticks it runs on by the frame time since the last sync.
func clip_time(c: BossClip) -> float:
	var sub := clampf(_since_sync * 60.0, 0.0, 0.999)
	var tk := _attack_ticks
	var st := float(_state_ticks) + sub
	var t := 1.0
	match _state:
		WorldReader.STATE_WINDUP:
			var p := _windup if tk.x <= 0 else st / float(tk.x)
			t = clampf(p, 0.0, 0.9999) * c.strike
		WorldReader.STATE_ACTIVE:
			var n := tk.y if tk.y > 0 else DEFAULT_ACTIVE_TICKS
			var gap := tk.w
			if _clip_move == WorldReader.MOVE_BURROW:
				t = _burrow_time(c)
			elif gap > 0 and _state_ticks < ((n - 1) / gap) * gap:
				t = c.strike + fposmod(st, float(gap)) / float(gap) * (c.hold - c.strike)
			elif gap > 0:
				var last := float(((n - 1) / gap) * gap)
				t = (
					c.strike
					+ clampf((st - last) / maxf(1.0, n - last), 0.0, 1.0) * (c.hold - c.strike)
				)
			else:
				t = c.strike + clampf(st / float(n), 0.0, 1.0) * (c.hold - c.strike)
		WorldReader.STATE_RECOVER:
			var r := tk.z if tk.z > 0 else DEFAULT_RECOVER_TICKS
			t = c.hold + clampf(st / float(r), 0.0, 1.0) * (1.0 - c.hold)
	return t


## A burrow's active part: it dives (strike → halfway through its active part) while it sinks out of sight, and
## erupts (halfway → hold) over the 18 ticks after it comes back up.
func _burrow_time(c: BossClip) -> float:
	var mid := (c.strike + c.hold) * 0.5
	if _hidden or _unhide_tick < 0:
		return lerpf(c.strike, mid, clampf(float(_state_ticks) / 12.0, 0.0, 1.0))
	var since := float(_last_tick - _unhide_tick) + clampf(_since_sync * 60.0, 0.0, 0.999)
	return lerpf(mid, c.hold, clampf(since / 18.0, 0.0, 1.0))


## Each body's clip library (BossClip by name; its <Boss>Clips).
func _clip_library() -> Dictionary:
	return {}


## Seconds of one idle loop; the walk speed (m/s) and stride (m) its walk clip is timed to.
func _idle_seconds() -> float:
	return 3.0


func _walk_speed() -> float:
	return 2.0


func _stride() -> float:
	return 1.6


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
