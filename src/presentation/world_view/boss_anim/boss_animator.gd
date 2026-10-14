class_name BossAnimator
extends RefCounted
## v0.8.0 BA (owner O6, Q4): plays a boss model's keyframed clips (BossClip) in layers and writes the sum onto its
## bones (through the avatar's BonePoser) and its pivot. Every layer is additive over the rest pose:
## - the base: idle (a loop in seconds) and walk (a loop whose time is the gait's phase, so the steps match its
##   speed), weighted by how fast it walks;
## - the action: the clip of the sim's attack in progress, its time driven by the attack's phase (BossAvatar
##   .clip_time), crossfaded from the previous action (FADE_IN) and faded out when it ends or is cut off (FADE_OUT);
## - the reactions: the shielded hold, a hit's flinch, the stagger, the phase gate's roar, the rise-in and the death.
## The owner's clips (Q4, "yours replace"): when the model's own scene ships an AnimationPlayer with an animation of
## the same name as one of these clips ("idle", "walk", "marks", "death" …), that animation is played instead of
## the code clip, at the same time and weight. An attack animation may carry the markers "strike" (the pose on the
## active tick) and "recover" (the end of the active part); without them its length stands for 0..1 of the clip.
## Presentation only (EI-07): it writes the avatar's own skeleton and pivot; per frame it allocates nothing.

## Layer slots, applied in this order.
const IDLE := 0
const WALK := 1
const ACTION := 2
const PREV := 3
const SHIELD := 4
const FLINCH := 5
const STAGGER := 6
const ROAR := 7
const RISE := 8
const DEATH := 9
const SLOTS := 10
## Seconds to crossfade into an attack's clip, and to fade one out when it ends or is cut off.
const FADE_IN := 0.1
const FADE_OUT := 0.22
## The clip each sim move plays: the attack's own `move` name in data/bosses (`move = &"marks"` plays "marks").
const MOVE_CLIPS := {
	WorldReader.MOVE_SLAM_RING: &"slam_ring",
	WorldReader.MOVE_LANES: &"lanes",
	WorldReader.MOVE_SWEEP: &"sweep",
	WorldReader.MOVE_CHARGE: &"charge",
	WorldReader.MOVE_LEAP: &"leap",
	WorldReader.MOVE_BURROW: &"burrow",
	WorldReader.MOVE_BROOD: &"brood",
	WorldReader.MOVE_BARRAGE: &"barrage",
	WorldReader.MOVE_RAIL: &"rail",
	WorldReader.MOVE_BOLT_FAN: &"bolt_fan",
	WorldReader.MOVE_DEPLOY: &"deploy",
	WorldReader.MOVE_PULL: &"pull",
	WorldReader.MOVE_FLOOD: &"flood",
	WorldReader.MOVE_PATTERN: &"pattern",
	WorldReader.MOVE_MARKS: &"marks",
	WorldReader.MOVE_ROW_LANES: &"row_lanes",
	WorldReader.MOVE_GRID: &"grid",
	WorldReader.MOVE_ROW_FLOOD: &"row_flood",
	WorldReader.MOVE_GAZE: &"gaze",  # v0.8.0 BS2
	WorldReader.MOVE_MELT: &"melt",
	WorldReader.MOVE_COMBO: &"combo",  # v0.8.0 FB1: the Colossus
	WorldReader.MOVE_SPIKE_CHASE: &"spike_chase",
	WorldReader.MOVE_SPIKE_BURST: &"spike_burst",
	WorldReader.MOVE_CROSS: &"cross",  # v0.8.0 FB2: the Prism
	WorldReader.MOVE_MIMIC_COMBO: &"mimic_combo",  # v0.8.0 FB3: the Nemesis (a slash, a shot, a cast)
	WorldReader.MOVE_MIMIC_SHOTS: &"mimic_shots",
	WorldReader.MOVE_CARD_CAST: &"card_cast",
}
## The clips every boss has besides its moves'.
const COMMON: Array[StringName] = [
	&"idle", &"walk", &"shielded", &"flinch", &"stagger", &"roar", &"rise", &"death"
]
## A shielded attack plays "<move>_shielded" when the boss has one (then the shielded layer stays off), else its
## move's clip with the "shielded" hold layered over it.
const SHIELDED_SUFFIX := "_shielded"

## name -> BossClip (the boss type's library; a copy once the owner's clips are bound).
var clips: Dictionary
var slot_clip: Array[BossClip] = []
var slot_t := PackedFloat32Array()
var slot_w := PackedFloat32Array()
## This frame's named parameters (PARAM tracks summed over the layers) and the pivot's pose.
var params := {}
var body_turn := Quaternion.IDENTITY
var body_shift := Vector3.ZERO
var body_squash := 0.0
var _serial := -1
## The owner's animations by clip name: [Animation, track indices, bone indices, track types].
var _owner := {}


func _init(library: Dictionary) -> void:
	clips = library
	slot_clip.resize(SLOTS)
	slot_t.resize(SLOTS)
	slot_w.resize(SLOTS)
	for c: BossClip in library.values():
		for k in c.targets.size():
			if c.channels[k] == BossClip.PARAM:
				params[c.targets[k]] = 0.0


## The clip a sim move plays (shielded: its shielded variant when the library has one), or &"" for none.
static func clip_name_for(move: int, shielded: bool, library: Dictionary) -> StringName:
	var base: StringName = MOVE_CLIPS.get(move, &"")
	if base == &"":
		return &""
	if shielded:
		var v := StringName(String(base) + SHIELDED_SUFFIX)
		if library.has(v):
			return v
	return base


func has_clip(clip_name: StringName) -> bool:
	return clips.has(clip_name)


## True when the owner's animation of this name replaces the code clip.
func owner_has(clip_name: StringName) -> bool:
	return _owner.has(clip_name)


## Sets a layer: `clip_name` at time t (0..1) and weight w; an unknown name clears it.
func set_layer(slot: int, clip_name: StringName, t: float, w: float) -> void:
	slot_clip[slot] = clips.get(clip_name) as BossClip
	slot_t[slot] = t
	slot_w[slot] = w if slot_clip[slot] != null else 0.0


## The action layer: a new `serial` is a new attack (the previous clip fades out in PREV while this one fades in);
## while `running` the clip plays at `t`, after it the clip holds its last time and fades out.
func drive_action(clip_name: StringName, serial: int, t: float, running: bool, dt: float) -> void:
	var c := clips.get(clip_name) as BossClip
	if serial != _serial:
		_serial = serial
		if slot_clip[ACTION] != null and slot_w[ACTION] > 0.001:
			slot_clip[PREV] = slot_clip[ACTION]
			slot_t[PREV] = slot_t[ACTION]
			slot_w[PREV] = slot_w[ACTION]
		slot_clip[ACTION] = c
		slot_w[ACTION] = 0.0
	if running and c != null:
		slot_clip[ACTION] = c
		slot_t[ACTION] = t
		slot_w[ACTION] = move_toward(slot_w[ACTION], 1.0, dt / FADE_IN)
	else:
		slot_w[ACTION] = move_toward(slot_w[ACTION], 0.0, dt / FADE_OUT)
	slot_w[PREV] = move_toward(slot_w[PREV], 0.0, dt / FADE_IN)
	if slot_w[PREV] <= 0.0:
		slot_clip[PREV] = null


## The action clip now (null with none), its time and weight.
func action_clip() -> BossClip:
	return slot_clip[ACTION]


func action_time() -> float:
	return slot_t[ACTION]


func action_weight() -> float:
	return slot_w[ACTION]


## A parameter's value this frame (0 when no layer moves it).
func param(param_name: StringName) -> float:
	return params.get(param_name, 0.0)


## Samples every layer and writes the sum: bone turns, shifts and stretches through `poser`, the BODY channels onto
## `pivot` (its transform is set from scratch), PARAM tracks into params.
func apply(poser: BonePoser, pivot: Node3D, reduced: bool) -> void:
	body_turn = Quaternion.IDENTITY
	body_shift = Vector3.ZERO
	body_squash = 0.0
	for key: StringName in params:
		params[key] = 0.0
	for s in SLOTS:
		var c := slot_clip[s]
		var w := slot_w[s]
		if c == null or w <= 0.0001 or _owner.has(c.name):
			continue
		var t := slot_t[s]
		for k in c.targets.size():
			var v := c.value(k, t, reduced) * w
			if v == 0.0:
				continue
			var target := c.targets[k]
			match c.channels[k]:
				BossClip.TURN:
					if target == BossClip.BODY:
						body_turn = Quaternion(c.axes[k], v) * body_turn
					elif poser != null:
						poser.turn(target, c.axes[k], v)
				BossClip.SHIFT:
					if target == BossClip.BODY:
						body_shift += c.axes[k] * v
					elif poser != null:
						poser.shift(target, c.axes[k] * v)
				BossClip.STRETCH:
					if target == BossClip.BODY:
						body_squash += v
					elif poser != null:
						poser.stretch(target, 1.0 + v)
				BossClip.PARAM:
					params[target] = float(params.get(target, 0.0)) + v
	if pivot != null:
		var tall := maxf(0.3, 1.0 + body_squash)
		var wide := 1.0 / sqrt(tall)
		pivot.transform = Transform3D(
			Basis(body_turn) * Basis.from_scale(Vector3(wide, tall, wide)), body_shift
		)


# --- The owner's clips (Q4) -------------------------------------------------------------------------------------


## Binds the owner's animations: every animation of `player` with bone tracks on `skeleton` (rotation, position,
## scale; matched by bone name) replaces the code clip of the same name. Stops the player (we sample it ourselves).
## Returns how many were bound.
func bind_owner(player: AnimationPlayer, skeleton: Skeleton3D) -> int:
	player.active = false
	clips = clips.duplicate()
	var n := 0
	for full: StringName in player.get_animation_list():
		var anim := player.get_animation(full)
		var tracks := PackedInt32Array()
		var bones := PackedInt32Array()
		var types := PackedInt32Array()
		for tr in anim.get_track_count():
			var ty := anim.track_get_type(tr)
			if (
				ty != Animation.TYPE_ROTATION_3D
				and ty != Animation.TYPE_POSITION_3D
				and ty != Animation.TYPE_SCALE_3D
			):
				continue
			var b := skeleton.find_bone(String(anim.track_get_path(tr).get_concatenated_subnames()))
			if b < 0:
				continue
			tracks.append(tr)
			bones.append(b)
			types.append(ty)
		if tracks.is_empty():
			continue
		var key := StringName(String(full).get_slice("/", String(full).get_slice_count("/") - 1))
		_owner[key] = [anim, tracks, bones, types]
		if not clips.has(key):
			clips[key] = BossClip.new(key, key == &"idle" or key == &"walk")
		n += 1
	return n


## The owner's animation time for a code clip's time t: a loop wraps over its length; an attack maps its windup to
## 0..the "strike" marker, its active part to "strike".."recover" and its recovery to the end.
static func owner_time(anim: Animation, c: BossClip, t: float) -> float:
	var length := anim.length
	if c.loop:
		return fposmod(t, 1.0) * length
	t = clampf(t, 0.0, 1.0)
	if not anim.has_marker(&"strike"):
		return t * length
	var ts := anim.get_marker_time(&"strike")
	var th := anim.get_marker_time(&"recover") if anim.has_marker(&"recover") else ts
	if t < c.strike:
		return t / c.strike * ts
	if t < c.hold:
		return lerpf(ts, th, (t - c.strike) / (c.hold - c.strike))
	return lerpf(th, length, (t - c.hold) / (1.0 - c.hold))


## After the code pose is written: each bound owner animation in a live layer sets its bones' poses, blended in by
## the layer's weight.
func apply_owner(skeleton: Skeleton3D) -> void:
	if _owner.is_empty() or skeleton == null:
		return
	for s in SLOTS:
		var c := slot_clip[s]
		var w := slot_w[s]
		if c == null or w <= 0.0001 or not _owner.has(c.name):
			continue
		var entry: Array = _owner[c.name]
		var anim: Animation = entry[0]
		var tracks: PackedInt32Array = entry[1]
		var bones: PackedInt32Array = entry[2]
		var types: PackedInt32Array = entry[3]
		var time := owner_time(anim, c, slot_t[s])
		for j in tracks.size():
			var b := bones[j]
			match types[j]:
				Animation.TYPE_ROTATION_3D:
					var q := anim.rotation_track_interpolate(tracks[j], time)
					skeleton.set_bone_pose_rotation(
						b, skeleton.get_bone_pose_rotation(b).slerp(q, minf(w, 1.0))
					)
				Animation.TYPE_POSITION_3D:
					var p := anim.position_track_interpolate(tracks[j], time)
					skeleton.set_bone_pose_position(
						b, skeleton.get_bone_pose_position(b).lerp(p, minf(w, 1.0))
					)
				Animation.TYPE_SCALE_3D:
					var sc := anim.scale_track_interpolate(tracks[j], time)
					skeleton.set_bone_pose_scale(
						b, skeleton.get_bone_pose_scale(b).lerp(sc, minf(w, 1.0))
					)
