class_name ColossusAvatar
extends FinalBodyAvatar
## The final boss's first body, a floating stone giant with two free fists. The owner's model
## (assets/models/bosses/final_boss_colossus.glb) is one mesh skinned to a full skeleton and carries its own
## animations: its hover ("idle"), its glide ("walk"), its reactions ("flinch", "stagger", "roar"), its "rise" and
## its "break" replace the clips of those names, and OWNER_PLAYS says which animation each move plays.
## The combo plays one animation per strike: the right hook on even strikes, the left on odd ones and the two-fisted
## slam as the last (the strike's index and count are read from its telegraph). Each new strike restarts the attack
## layer, and the strike's own progress runs its animation up to the strike pose.
## What the code adds over the animations (_pose_final, _after_bones): the halo turns slowly round its crown, faster
## while a clip flares it, and each of the five crystals held in the air under it turns about its own length, once in
## SPIKE_TURN_SECONDS, each its own way from its own start, never reset by a clip. Reduced motion holds both still.
## Its rise is the fight's entrance: it lasts as long as the intro, so all of it plays over the intro and the body
## stands as the intro ends. Without the model file a code-made stand-in (a rock body and two rock fists) keeps the
## fight readable.

const HEIGHT := 3.2
const WALK_SPEED := 4.2
## It floats, so no foot has to match the floor: the metres one loop of the file's glide covers are set so that a
## loop takes its 3 s at the walk speed.
const STRIDE := WALK_SPEED * 3.0
## Seconds of the file's idle loop, played at the speed it was made at.
const IDLE_SECONDS := 4.0
## The file's animations by the clip that plays them, with the seconds of each one's strike pose and of the end of
## its active part. The three combo clips are one strike each (_action_clip picks).
const OWNER_PLAYS := {
	&"combo":
	{
		"anim": &"hook_r",
		"strike": ColossusClips.HOOK["strike"],
		"recover": ColossusClips.HOOK["recover"]
	},
	&"combo_l":
	{
		"anim": &"hook_l",
		"strike": ColossusClips.HOOK["strike"],
		"recover": ColossusClips.HOOK["recover"]
	},
	&"combo_slam":
	{
		"anim": &"slam",
		"strike": ColossusClips.SLAM["strike"],
		"recover": ColossusClips.SLAM["recover"]
	},
	&"leap": {"anim": &"leap", "strike": 0.53, "recover": 1.0},
	&"marks": {"anim": &"hurl", "strike": 0.77, "recover": 0.9},
	&"spike_chase": {"anim": &"ground_punch", "strike": 0.9, "recover": 1.5},
	&"spike_burst": {"anim": &"burst", "strike": 0.9, "recover": 1.53},
	FinalBodyAvatar.SHATTER_CLIP: {"anim": &"break"},
}
## Points on the owner's model at rest (metres, model frame): the chest gem (the weak point), each fist's palm and
## the halo's centre. Each rides a bone.
const MODEL_CHEST := Vector3(0.36, 1.95, 0.05)
const MODEL_FISTS := [Vector3(0.1, 1.52, -1.38), Vector3(0.27, 1.5, 1.33)]
const MODEL_HALO := Vector3(-0.14, 3.07, -0.06)
## The halo's slow turn (radians a second), and how much faster it spins at a full flare (a leap's landing, a burst).
const HALO_SPIN := 0.7
const HALO_FLARE_SPIN := 9.0
## Seconds a crystal takes to turn once about its own length, and each crystal's bone, its way round and the share
## of a turn it starts at.
const SPIKE_TURN_SECONDS := 10.0
const SPIKES := [
	[&"spike_front", 1.0, 0.0],
	[&"spike_low_L", -1.0, 0.2],
	[&"spike_low_R", 1.0, 0.4],
	[&"spike_side_L", 1.0, 0.6],
	[&"spike_side_R", -1.0, 0.8],
]

const STONE := Color("#3E3550")
const STONE_DARK := Color("#2A2338")
const CRYSTAL := Color("#E03050")

## The code-made stand-in's nodes (freed when the owner's model is used).
var stand_in := Node3D.new()
var _fists: Array[Node3D] = []
## The combo's strike in progress, how many it has, and how far the strike's own time has run (from its telegraph);
## the strike the attack layer last started.
var _strike := 0
var _strikes := 0
var _strike_progress := 0.0
var _played_strike := 0
## The halo's angle (frame time; a fixed tilt with reduced motion), and the crystals' shared turn (turns).
var _halo := 0.0
var _spin := 0.0


func sync(reader: WorldReader, i: int) -> void:
	var tg := reader.telegraph(i)
	_read_strike(
		int(tg.get("strike", 0)), int(tg.get("strikes", 0)), float(tg.get("progress", 0)) / 1000.0
	)
	super(reader, i)


## Plain values (tests, renders): "strike", "strikes" and "strike_progress" (0..1) are the combo's telegraph.
func apply_state(s: Dictionary) -> void:
	if s.has("strikes"):
		_read_strike(
			int(s.get("strike", 0)), int(s["strikes"]), float(s.get("strike_progress", 0.0))
		)
	var serial := _attack_serial
	super(s)
	# A new strike of the same combo is a new clip: the attack layer restarts, crossfaded from the strike before.
	if (
		_attack_serial == serial
		and _clip_move == WorldReader.MOVE_COMBO
		and _strike != _played_strike
	):
		_attack_serial += 1
	_played_strike = _strike


## The combo's telegraph; one with no strikes (the recovery after the slam) keeps the last strike read.
func _read_strike(strike: int, strikes: int, progress: float) -> void:
	if strikes <= 0:
		return
	_strike = strike
	_strikes = strikes
	_strike_progress = clampf(progress, 0.0, 1.0)


## The combo's strike in progress and how many it has (tests).
func combo_strike() -> Vector2i:
	return Vector2i(_strike, _strikes)


func model_id() -> StringName:
	return &"final_boss_colossus"


func _code_nodes() -> Array[Node]:
	return [stand_in]


func _clip_library() -> Dictionary:
	return ColossusClips.library()


func _owner_plays() -> Dictionary:
	return OWNER_PLAYS


func _walk_speed() -> float:
	return WALK_SPEED


func _stride() -> float:
	return STRIDE


func _idle_seconds() -> float:
	return IDLE_SECONDS


func _rise_intro_share() -> float:
	return 1.0


func _weak_point_at() -> Vector3:
	return MODEL_CHEST if imported != null else Vector3(0.7, 1.6, 0)


func _weak_bone() -> StringName:
	return &"chest"


func anchor_names() -> Array[StringName]:
	return [&"weak", &"fist_l", &"fist_r", &"halo"]


func _anchor(point: StringName) -> Vector3:
	if imported == null:
		var k := 0 if point == &"fist_l" else 1
		return _fists[k].position if point in [&"fist_l", &"fist_r"] else weak_core.position
	match point:
		&"fist_l":
			return _on_bone(ColossusClips.FIST_L, MODEL_FISTS[0])
		&"fist_r":
			return _on_bone(ColossusClips.FIST_R, MODEL_FISTS[1])
		&"halo":
			return _on_bone(&"halo", MODEL_HALO)
	return weak_core.position


## The combo's clip for the strike in progress: the slam last, before it the right hook on even strikes and the left
## on odd ones.
func _action_clip(by_move: StringName) -> StringName:
	if by_move != &"combo" or _strikes <= 0:
		return by_move
	if _strike >= _strikes - 1:
		return &"combo_slam"
	return &"combo" if _strike % 2 == 0 else &"combo_l"


## A combo strike's clip runs up to its strike pose over the strike's own time (the windup for the first, the gap
## from the strike before for the others) and lands on it the tick the strike lands; the recovery after the slam
## plays the rest of its clip.
func clip_time(c: BossClip) -> float:
	if _clip_move != WorldReader.MOVE_COMBO or _strikes <= 0:
		return super(c)
	var sub := clampf(_since_sync * 60.0, 0.0, 0.999)
	if _state == WorldReader.STATE_RECOVER:
		var r := _attack_ticks.z if _attack_ticks.z > 0 else DEFAULT_RECOVER_TICKS
		return lerpf(c.strike, 1.0, clampf((float(_state_ticks) + sub) / float(r), 0.0, 1.0))
	var span := _attack_ticks.x if _strike == 0 else _attack_ticks.w
	var p := _strike_progress
	if span > 0 and p < 1.0:
		p = minf(1.0, p + sub / float(span))
	return p * c.strike


## The stand-in: a hunched block of violet stone with a crystal crown, and two big rock fists beside it.
func _build() -> void:
	var p := parts
	stand_in.name = "StandIn"
	model.add_child(stand_in)
	p.piece(stand_in, BossParts.rock(Vector3(1.4, 2.2, 1.5), 3), Vector3(0, 1.2, 0), STONE)
	p.piece(stand_in, BossParts.rock(Vector3(0.8, 0.7, 0.8), 5), Vector3(0.2, 2.5, 0), STONE_DARK)
	p.piece(stand_in, BossParts.crystal(0.8, 0.3, 7), Vector3(0.0, 3.0, 0), CRYSTAL)
	for side in [-1.0, 1.0]:
		var f := Node3D.new()
		f.position = Vector3(0.3, 1.3, side * 1.3)
		stand_in.add_child(f)
		p.piece(f, BossParts.rock(Vector3(0.9, 0.9, 0.9), 11 + int(side)), Vector3.ZERO, STONE_DARK)
		_fists.append(f)


## The stand-in poses its fists from the same inputs (a raise in the windup, a strike forward).
func _pose(_dt: float) -> void:
	for k in _fists.size():
		var side := -1.0 if k == 0 else 1.0
		_fists[k].position = Vector3(0.3 + 0.9 * _hit, 1.3 + 0.9 * _wind, side * 1.3)


func _pose_final(dt: float) -> void:
	if not ViewPrefs.reduced_motion:
		var flare := maxf(0.0, animator.param(&"halo_flare"))
		_halo = fmod(_halo + dt * (HALO_SPIN + HALO_FLARE_SPIN * flare), TAU)
		_spin = fposmod(_spin + dt / SPIKE_TURN_SECONDS, 1.0)
	poser.turn(&"halo", Vector3.UP, _halo)


## The crystals' turn, once this frame's bones are written: each about its own bone's Y, the crystal's length (its
## point sits on that axis, so it stays where the animation put it), on top of the pose the animation gave it.
func _after_bones() -> void:
	var animated := animator.owner_bones()
	for row: Array in SPIKES:
		var k := poser.index_of(row[0])
		if k < 0:
			continue
		var from := (
			skeleton.get_bone_pose_rotation(k)
			if animated.has(k)
			else skeleton.get_bone_rest(k).basis.get_rotation_quaternion()
		)
		var angle := TAU * (float(row[1]) * _spin + float(row[2]))
		skeleton.set_bone_pose_rotation(k, from * Quaternion(Vector3.UP, angle))
