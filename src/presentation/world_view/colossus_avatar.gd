class_name ColossusAvatar
extends FinalBodyAvatar
## v0.8.0 FB1 (owner O17: "big stone hands … a fast moving pace fight"; FINAL_BOSS.md F4): the final boss's first body,
## the owner's model assets/models/bosses/final_boss_colossus.glb (split from the owner's file; one mesh), its fists
## cut in code as the separate pieces they are (BossRig: body, chest, halo, fist_l, fist_r) and animated by
## ColossusClips. Its own layer after the clips (_pose_final): the halo turns slowly round its crown (still with reduced
## motion, a fixed tilt), and the combo's swing (the `hook` parameter) lands on the right fist, then the left, in turn
## (the strike's index, read from its telegraph), and on both fists as the closing slam. Without the model file a
## code-made stand-in (a rock body and two rock fists) keeps the fight readable.

const HEIGHT := 3.2
const WALK_SPEED := 4.2
const STRIDE := 2.4
## Points on the owner's model at rest (metres, model frame; its pieces' centres from the split's analysis, scaled
## to HEIGHT): the chest's front (the weak point), each fist and the halo.
const MODEL_CHEST := Vector3(0.55, 1.85, 0.0)
const MODEL_FISTS := [Vector3(0.16, 1.4, -1.35), Vector3(0.32, 1.4, 1.29)]
const MODEL_HALO := Vector3(-0.14, 3.07, -0.06)
## The halo's slow turn (radians a second), and how much faster it spins at a full flare (a leap's landing, a burst).
const HALO_SPIN := 0.7
const HALO_FLARE_SPIN := 9.0

const STONE := Color("#3E3550")
const STONE_DARK := Color("#2A2338")
const CRYSTAL := Color("#E03050")

## The code-made stand-in's nodes (freed when the owner's model is used).
var stand_in := Node3D.new()
var _fists: Array[Node3D] = []
## The combo's strike in progress and how many it has (from its telegraph).
var _strike := 0
var _strikes := 0
## The halo's angle (frame time; a fixed tilt with reduced motion).
var _halo := 0.0


func sync(reader: WorldReader, i: int) -> void:
	var tg := reader.telegraph(i)
	_strike = int(tg.get("strike", 0))
	_strikes = int(tg.get("strikes", 0))
	super(reader, i)


func model_id() -> StringName:
	return &"final_boss_colossus"


func _code_nodes() -> Array[Node]:
	return [stand_in]


func _clip_library() -> Dictionary:
	return ColossusClips.library()


func _walk_speed() -> float:
	return WALK_SPEED


func _stride() -> float:
	return STRIDE


func _idle_seconds() -> float:
	return 2.4


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
			return _on_bone(&"fist_l", MODEL_FISTS[0])
		&"fist_r":
			return _on_bone(&"fist_r", MODEL_FISTS[1])
		&"halo":
			return _on_bone(&"halo", MODEL_HALO)
	return weak_core.position


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
	var an := animator
	var p := poser
	if not ViewPrefs.reduced_motion:
		var flare := maxf(0.0, an.param(&"halo_flare"))
		_halo = fmod(_halo + dt * (HALO_SPIN + HALO_FLARE_SPIN * flare), TAU)
	p.turn(&"halo", Vector3.UP, _halo)
	_pose_combo(p, an.param(&"hook"))


## The combo's swing on the fist whose turn it is (right on even strikes, left on odd), both on the closing slam.
func _pose_combo(p: BonePoser, hook: float) -> void:
	if absf(hook) < 0.0001 or _clip_move != WorldReader.MOVE_COMBO:
		return
	var wind := maxf(0.0, -hook)
	var hit := maxf(0.0, hook)
	if _strikes > 0 and _strike >= _strikes - 1:
		for f: StringName in [&"fist_l", &"fist_r"]:
			p.turn(f, Vector3.BACK, 2.4 * wind + 0.9 * hit)
			p.shift(f, Vector3(0.5 * hit, -1.0 * hit, 0.0))
		return
	var right := _strike % 2 == 0
	var side := 1.0 if right else -1.0
	var fist := &"fist_r" if right else &"fist_l"
	p.turn(fist, Vector3.RIGHT, -side * 1.1 * (wind + 0.6 * hit))
	p.turn(fist, Vector3.UP, side * (-0.7 * wind + 1.3 * hit))
	p.shift(fist, Vector3(0.3 * hit, 0.2 * wind, 0.0))
