class_name HeroArms
extends Node3D
## The hooded wanderer's arms and gauntlets, and the Blade in their hands. Two blocky charcoal arms hang from
## shoulders hidden under the poncho; each ends in a chunky segmented gauntlet (a cuff, a plate, a fist block) in
## the boots' lighter grey. Matte and lit like the legs, and they flash with the body on a hit.
## The Blade decides where the hands go, never the other way round: while SummonedBlade shows the sword (a combo
## step, the finisher's spin, the Lunge Cleave) both hands sit on its grip, the right nearer the cross-guard, and each
## arm is solved to its hand (a two-bone reach from the shoulder, the elbow kept low and out). The sword is the
## one the slash is drawn with, so its tip stays on the slash's tip and it is never stretched. The shoulders turn to
## the sword under the poncho (no torso shows), so both hands reach it all the way round an arc.
## Between swings, two ways (ViewPrefs.blade_held, the dev panel's "Blade held" switch):
## - summoned (the default): the sword is gone, and the arms ease back under the poncho and are hidden;
## - held: a second copy of the sword stays in the hands in a guard across the body (its tip up and to the left),
##   turning with the body; a swing takes it from there to the arc's start at once.
## The poncho drapes over the arms: its hem lifts on the side the hands leave it (lifted()).
## With the Gun, dead, or with no Blade view (the hub), the arms stay at rest, hidden. Without the Blade's model
## nothing here shows (KitView's laser blade needs no hands). Presentation only (EI-07): it reads the Blade's view and
## the body's pose in frame time and decides nothing.

## Shoulders, in the body's frame (+X the front, +Z the right, the origin at the hips): right, then left.
const SHOULDERS: Array[Vector3] = [Vector3(0.02, 0.2, 0.15), Vector3(0.02, 0.2, -0.15)]
## The hands at rest, tucked in front of the belly under the poncho.
const REST: Array[Vector3] = [Vector3(0.12, 0.02, 0.1), Vector3(0.12, 0.02, -0.1)]
## Upper arm and forearm lengths (the forearm ends at the fist's centre), and their thickness.
const UPPER_M := 0.31
const FORE_M := 0.38
## How far a hand is asked to reach from its shoulder (a little short of a straight arm).
const REACH_M := UPPER_M + FORE_M - 0.02
const UPPER_W := 0.08
const FORE_W := 0.085
## The gauntlet: the cuff and the plate (width, length, how far along the forearm their centre sits) and the fist.
const CUFF := Vector3(0.13, 0.07, 0.5)
const PLATE := Vector3(0.115, 0.11, 0.76)
const FIST := Vector3(0.105, 0.11, 0.105)
## Which way the elbows point, in the shoulders' frame (Z mirrored for the left arm): down, out and a little back.
const ELBOW_POLE := Vector3(-0.35, -1.0, 0.55)
## During a swing the right hand grips this far from the hero's axis (m) and the left HAND_GAP_M nearer the pommel;
## neither leaves the grip: between GRIP_LOW and GRIP_HIGH of the sword's drawn length from the pommel (the cross-guard
## sits at 0.34 of it).
const HAND_R_M := 0.54
const HAND_GAP_M := 0.14
const GRIP_LOW := 0.03
const GRIP_HIGH := 0.3
## The guard the sword is held in between swings (held mode), in the body's frame: where the left hand is, the
## way the sword points (its tip up, forward and to the left), and how far up the grip the right hand is (m).
const GUARD_HAND := Vector3(0.4, 0.04, 0.08)
const GUARD_DIR := Vector3(0.4, 0.68, -0.62)
const GUARD_LOW_M := 0.1
## How fast the sword settles into the guard after a swing and the arms drop to rest (per second).
const GUARD_RATE := 7.0
const REST_RATE := 6.0
## The poncho's hem lifts this much (m) straight over the hands, and stands this much further out.
const HEM_LIFT_M := 0.13
const HEM_OUT_M := 0.04
const ARM_COLOR := PlayerAvatar.LEG_COLOR
const GAUNTLET_COLOR := PlayerAvatar.BOOT_COLOR
const CUFF_COLOR := Color("#666A73")

## The Blade's view (found on the world view when this enters the tree; null: no Blade, the arms rest).
var blade: SummonedBlade
## Reads the Blade as drawn this frame (between two ticks). Tests step ticks faster than frames and turn it off.
var interpolated := true

var _upper: Array[Node3D] = []
var _fore: Array[Node3D] = []
var _hands: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _grips: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _reached: Array[bool] = [false, false]
## The sword's pose in this node's frame (the pommel at the origin, +X to the tip, scaled) as last gripped.
var _sword := Transform3D.IDENTITY
## How far the hands are out of rest (0..1), and how far the sword has settled into the guard since a swing (0..1).
var _out := 0.0
var _settle := 1.0
var _swinging := false
## The copy of the sword carried in held mode (made the first time it is needed), and the model's length.
var _carried: Node3D
var _carried_len := 0.0
## Where the hands leave the poncho (a unit direction on the ground plane; zero: nowhere).
var _lift_dir := Vector3.ZERO


func _enter_tree() -> void:
	var n := get_parent()
	while n != null and blade == null:
		var kit: Variant = n.get(&"kit")
		if kit is KitView:
			blade = (kit as KitView).summoned
		n = n.get_parent()


## Builds the two arms; `avatar` takes their materials for its hit flash.
func build(avatar: AvatarBase) -> void:
	name = "Arms"
	var mats: Array[StandardMaterial3D] = []
	for c: Color in [ARM_COLOR, GAUNTLET_COLOR, CUFF_COLOR]:
		var m := ActorViews.flashable(AvatarBase.plain_material(c))
		avatar.body_materials.append(m)
		mats.append(m)
	for k in 2:
		var upper := Node3D.new()
		add_child(upper)
		_box(upper, Vector3(UPPER_W, UPPER_M, UPPER_W), UPPER_M * 0.5, mats[0])
		_upper.append(upper)
		var fore := Node3D.new()
		add_child(fore)
		_box(fore, Vector3(FORE_W, FORE_M, FORE_W), FORE_M * 0.5, mats[0])
		_box(fore, Vector3(CUFF.x, CUFF.y, CUFF.x), FORE_M * CUFF.z, mats[2])
		_box(fore, Vector3(PLATE.x, PLATE.y, PLATE.x), FORE_M * PLATE.z, mats[1])
		_box(fore, FIST, FORE_M, mats[2])
		_fore.append(fore)
	visible = false


func _box(parent: Node3D, size: Vector3, along: float, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(0, along, 0)
	mi.material_override = mat
	parent.add_child(mi)


## Poses the arms for this frame. `body` is the body's frame in the avatar's (the hips' place, the lean, the
## poncho's yaw), `lean` the hips' lean alone, and `armed` whether the hero may hold the Blade (alive, not the Gun).
func pose(dt: float, body: Transform3D, lean: Basis, armed: bool) -> void:
	var has_blade := armed and blade != null and blade.has_model()
	var calm := ViewPrefs.reduced_motion
	_swinging = has_blade and blade.blade_visible()
	var carry := has_blade and not _swinging and ViewPrefs.blade_held
	var guard_at := 1.0
	if _swinging:
		_sword = _to_local(blade.drawn_transform() if interpolated else blade.tick_transform())
		_out = 1.0
		_settle = 0.0
	elif carry:
		_settle = 1.0 if calm or _out <= 0.0 else move_toward(_settle, 1.0, dt * GUARD_RATE)
		_out = 1.0
		var k := smoothstep(0.0, 1.0, _settle)
		_sword = _sword.interpolate_with(_guard(body), k) if k < 1.0 else _guard(body)
		guard_at = k
	else:
		_out = 0.0 if calm or not armed else move_toward(_out, 0.0, dt * REST_RATE)
		_settle = 1.0
	_show_carried(carry)
	visible = _out > 0.0
	if not visible:
		_lift_dir = Vector3.ZERO
		return
	var axis := _sword.basis.x
	var span := axis.length() * blade.length_m()
	axis = axis.normalized()
	# Up the grip: a fixed distance from the hero's axis in a swing, a fixed distance up the grip in the guard.
	var r0 := Vector2(_sword.origin.x, _sword.origin.z).length()
	var high := clampf(HAND_R_M - r0, HAND_GAP_M + GRIP_LOW * span, GRIP_HIGH * span)
	if not _swinging:
		high = lerpf(high, GUARD_LOW_M + HAND_GAP_M, guard_at)
	# The shoulders: square to the sword in a swing, with the body in the guard and at rest.
	var flat := Vector3(axis.x, 0, axis.z)
	var frame := body
	if flat.length() > 0.05 and guard_at < 1.0:
		var to_sword := lean * Basis(Vector3.UP, atan2(-flat.z, flat.x))
		frame.basis = to_sword.slerp(body.basis.orthonormalized(), guard_at)
	# A body leaning away draws the right hand down the grip rather than off it.
	var low := HAND_GAP_M + GRIP_LOW * span
	for _i in 3:
		var short := (frame * SHOULDERS[0]).distance_to(_sword.origin + axis * high) - REACH_M
		if short > 0.0:
			high = maxf(high - short * 1.5, low)
	_grips[0] = _sword.origin + axis * high
	_grips[1] = _sword.origin + axis * maxf(high - HAND_GAP_M, GRIP_LOW * span)
	var mid := (_grips[0] + _grips[1]) * 0.5
	mid.y = 0.0
	_lift_dir = mid.normalized() if mid.length() > 0.05 else Vector3.ZERO
	var ease := smoothstep(0.0, 1.0, _out)
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		var shoulder := frame * SHOULDERS[k]
		var target := (body * REST[k]).lerp(_grips[k], ease)
		var pole := frame.basis * Vector3(ELBOW_POLE.x, ELBOW_POLE.y, ELBOW_POLE.z * side)
		var bones := reach(shoulder, target, UPPER_M, FORE_M, pole)
		_hands[k] = bones[1]
		_reached[k] = bones[1].distance_to(_grips[k]) < 0.005
		_upper[k].transform = Transform3D(_along(shoulder, bones[0], pole), shoulder)
		_fore[k].transform = Transform3D(_along(bones[0], bones[1], pole), bones[0])


## The two-bone reach from `from` toward `to` with bones `a` then `b` long, the joint bent toward `pole`:
## [the joint, the end]. The end is `to` when it is in reach, else as near as the bones allow.
static func reach(from: Vector3, to: Vector3, a: float, b: float, pole: Vector3) -> Array[Vector3]:
	var d := to - from
	var dist := clampf(d.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var along := (a * a - b * b + dist * dist) / (2.0 * dist)
	var off := sqrt(maxf(a * a - along * along, 0.0))
	var bend := pole - dir * pole.dot(dir)
	bend = bend.normalized() if bend.length() > 0.0001 else Vector3.ZERO
	return [from + dir * along + bend * off, from + dir * dist]


## A basis whose +Y runs from `a` to `b`, its faces squared to `pole`.
static func _along(a: Vector3, b: Vector3, pole: Vector3) -> Basis:
	var y := (b - a).normalized() if a.distance_to(b) > 0.0001 else Vector3.UP
	var x := pole.cross(y)
	x = x.normalized() if x.length() > 0.0001 else y.cross(Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


## The guard's sword in this node's frame: the left hand at GUARD_HAND, the flat toward the front.
func _guard(body: Transform3D) -> Transform3D:
	var x := GUARD_DIR.normalized()
	var y := (Vector3.RIGHT - x * x.x).normalized()
	var s := blade.carry_scale()
	var b := body.basis.orthonormalized() * Basis(x, y, x.cross(y))
	var at := body * GUARD_HAND - b.x * GUARD_LOW_M
	return Transform3D(b.scaled_local(Vector3.ONE * s), at)


func _to_local(world: Transform3D) -> Transform3D:
	if not is_inside_tree():
		return world
	var mine := get_global_transform_interpolated() if interpolated else global_transform
	return mine.affine_inverse() * world


func _show_carried(on: bool) -> void:
	if on and _carried == null:
		_carried = Node3D.new()
		_carried.name = "CarriedBlade"
		_carried.set_meta(ShaderWarmup.WARM_META, true)
		add_child(_carried)
		_carried_len = SummonedBlade.build_model(_carried)
	if _carried != null:
		_carried.visible = on and _carried_len > 0.0
		if _carried.visible:
			_carried.transform = _sword


## A poncho hem point (in the avatar's frame), lifted and pushed out where the hands leave the poncho.
func lifted(hem: Vector3) -> Vector3:
	if _lift_dir == Vector3.ZERO or _out <= 0.0:
		return hem
	var flat := Vector3(hem.x, 0, hem.z)
	var toward := maxf(flat.normalized().dot(_lift_dir), 0.0)
	var k := toward * toward * smoothstep(0.0, 1.0, _out)
	return hem + Vector3(0, HEM_LIFT_M * k, 0) + flat.normalized() * (HEM_OUT_M * k)


# --- Reads (tests, the shots) ------------------------------------------------------------------------------------
## Hand `k`'s place (0 the right, 1 the left) and the place on the grip it holds, in the avatar's frame.
func hand_point(k: int) -> Vector3:
	return _hands[k]


func grip_point(k: int) -> Vector3:
	return _grips[k]


## Hand `k` is on the grip (the arm reached it).
func on_grip(k: int) -> bool:
	return visible and _out >= 1.0 and _reached[k]


## The sword as the hands hold it, in the avatar's frame: its pommel and its tip.
func sword_pommel() -> Vector3:
	return _sword.origin


func sword_tip() -> Vector3:
	return _sword.origin + _sword.basis.x * (blade.length_m() if blade != null else 0.0)


## The sword carried between swings shows (held mode).
func carrying() -> bool:
	return _carried != null and _carried.visible
