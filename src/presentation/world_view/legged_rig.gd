class_name LeggedRig
extends RefCounted
## The leg and joint arithmetic the Needle and the Sniper share (NeedleAvatar, SniperAvatar: the owner's models cut
## into a body, a shell, a barrel and two-part legs): the legs posed by reach (each foot where its clip asks, under
## the body's transform now), a foot's stride cycle, the nodes written from the raw drives through the joint table,
## and the small pseudo-random motions (held glances, twitches) idle clips are made of. Presentation only (EI-07).


## A leg's heading: the turn about the vertical from +X to its rest foot's direction from its hip (its plane at rest
## holds its hip and its foot).
static func heading(hip: Vector3, tip: Vector3) -> float:
	return atan2(-(tip.z - hip.z), tip.x - hip.x)


## The axis a leg bends about (its hip and its knee): level, across its plane at rest.
static func bend_axis(hip: Vector3, tip: Vector3) -> Vector3:
	return Basis(Vector3.UP, heading(hip, tip)) * Vector3.BACK


## The legs reach for their feet: for each leg j, `hips[j]`, `knees[j]` and `tips[j]` its rest joints (m, the model's
## frame), `want[j]` where its tip should be (the facing's frame); under the body transform `body` each leg's yaw turns
## its plane (the vertical one through its hip and its rest foot) toward the foot, then its hip and knee bend in that
## plane so the tip lands there (two bones; past the leg's reach the foot stops short). Writes d[leg0 + 3 j + 0 / 1 /
## 2] (yaw, hip turn, knee turn).
static func reach(
	d: PackedFloat32Array,
	leg0: int,
	body: Transform3D,
	hips: Array[Vector3],
	knees: Array[Vector3],
	tips: Array[Vector3],
	want: Array[Vector3]
) -> void:
	var inv := body.affine_inverse()
	for j in hips.size():
		var hip := hips[j]
		var to_leg := Basis(Vector3.UP, -heading(hip, tips[j]))
		var w := to_leg * (inv * want[j] - hip)
		var yaw := atan2(-w.z, w.x)
		var t := w.rotated(Vector3.UP, -yaw)
		var aim := Vector2(t.x, t.y)
		var k3 := to_leg * (knees[j] - hip)
		var f3 := to_leg * (tips[j] - knees[j])
		var u0 := Vector2(k3.x, k3.y)
		var l0 := Vector2(f3.x, f3.y)
		var a := u0.length()
		var b := l0.length()
		var r := clampf(aim.length(), absf(a - b) + 0.002, (a + b) * 0.998)
		var bend := signf((u0 + l0).cross(u0))
		var off := acos(clampf((a * a + r * r - b * b) / (2.0 * a * r), -1.0, 1.0))
		var hip_turn := wrapf(aim.angle() + bend * off - u0.angle(), -PI, PI)
		var l1 := aim.normalized() * r - u0.rotated(hip_turn)
		d[leg0 + 3 * j] = yaw
		d[leg0 + 3 * j + 1] = hip_turn
		d[leg0 + 3 * j + 2] = wrapf(l1.angle() - l0.angle() - hip_turn, -PI, PI)


## Where leg j's tip is under the drives `d` (the facing's frame): the body, the leg's yaw at its hip, its hip turn,
## then its knee turn.
static func tip_at(
	d: PackedFloat32Array,
	leg0: int,
	j: int,
	body: Transform3D,
	hip: Vector3,
	knee: Vector3,
	tip: Vector3
) -> Vector3:
	var n := bend_axis(hip, tip)
	return (
		knee_xf(d, leg0, j, body, hip, knee, tip) * (Basis(n, d[leg0 + 3 * j + 2]) * (tip - knee))
	)


## Leg j's knee frame (its origin the knee) in the facing's frame.
static func knee_xf(
	d: PackedFloat32Array,
	leg0: int,
	j: int,
	body: Transform3D,
	hip: Vector3,
	knee: Vector3,
	tip: Vector3
) -> Transform3D:
	var n := bend_axis(hip, tip)
	var yaw := Transform3D(Basis(Vector3.UP, d[leg0 + 3 * j]), hip)
	var up := Transform3D(Basis(n, d[leg0 + 3 * j + 1]), Vector3.ZERO)
	return body * yaw * up * SoloVat.at(knee - hip)


## The leg joints of the table for leg j: its yaw about the vertical at the hip, its hip turn about its bend axis
## (turning with the yaw) on frame `upper`, its knee turn at the knee on frame `lower`; `parent` the body's last joint,
## `at` the table's size so far.
static func leg_joints(
	leg0: int, j: int, parent: int, at: int, bones: Array[Vector3], upper: Node3D, lower: Node3D
) -> Array:
	var hip := bones[0]
	var n := bend_axis(hip, bones[2])
	return [
		[leg0 + 3 * j, parent, null, SoloVat.turn(Vector3.UP, 1.0, SoloVat.at(hip))],
		[leg0 + 3 * j + 1, at, upper, SoloVat.turn(n)],
		[leg0 + 3 * j + 2, at + 1, lower, SoloVat.turn(n, 1.0, SoloVat.at(bones[1] - hip))],
	]


## The nodes from the drives `vd`: each frame node's transform is its joints' makes composed since its parent frame
## (the rig's with the lift under it), as the VAT rig chains them.
static func apply(joints: Array, vd: PackedFloat32Array, lift: float, rig: Node3D) -> void:
	var acc: Array[Transform3D] = []
	acc.resize(joints.size())
	for j in joints.size():
		var jt: Array = joints[j]
		var parent: int = jt[1]
		var base := Transform3D.IDENTITY
		if parent >= 0 and (joints[parent] as Array)[2] == null:
			base = acc[parent]
		acc[j] = base * (jt[3] as Callable).call([vd[jt[0]]])
		var frame: Node3D = jt[2]
		if frame == null:
			continue
		frame.transform = (
			Transform3D(Basis.IDENTITY, Vector3(0, lift, 0)) * acc[j] if frame == rig else acc[j]
		)


## One foot through its stride at q (0 its touchdown), `duty` of it on the ground: (the sweep: 1 ahead .. -1 behind;
## the lift 0..1). On the ground the foot keeps still while the body passes over it; in the air it lifts and comes
## forward eased.
static func leg_cycle(q: float, duty: float) -> Vector2:
	if q < duty:
		return Vector2(1.0 - 2.0 * q / duty, 0.0)
	var w := (q - duty) / (1.0 - duty)
	var up := sin(PI * w)
	return Vector2(-1.0 + 2.0 * smoothstep(0.0, 1.0, w), up * up * (3.0 - 2.0 * up))


## A clip's clock: -1 (not playing) stays; else on by dt, back to -1 at its end.
static func clip(t: float, dt: float, length: float) -> float:
	if t < 0.0:
		return t
	t += dt
	return t if t < length else -1.0


## A held glance: a pseudo-random value in -1..1 per `every` s that holds, then moves quickly to the next.
static func scan(t: float, every: float, seed_off: float) -> float:
	var u := t / every + seed_off
	var seg := floorf(u)
	var a := hash01(seg) * 2.0 - 1.0
	var b := hash01(seg + 1.0) * 2.0 - 1.0
	return lerpf(a, b, smoothstep(0.55, 0.85, u - seg))


## A quick twitch now and then (-1..1, mostly 0).
static func twitch(t: float, every: float, seed_off: float) -> float:
	var u := t / every + seed_off
	var seg := floorf(u)
	if hash01(seg + 31.0) < 0.55:
		return 0.0
	var s := 1.0 if hash01(seg + 17.0) > 0.5 else -1.0
	return s * sin(PI * clampf((u - seg - 0.4) / 0.05, 0.0, 1.0))


## A foot re-planted now and then while idle: [the leg (or -1), how far up its step is 0..1] at time t.
static func replant(t: float, every: float, legs: int) -> Array:
	var u := t / every
	var seg := floorf(u)
	if hash01(seg + 7.0) <= 0.4:
		return [-1, 0.0]
	var j := int(hash01(seg + 3.0) * legs) % legs
	return [j, sin(PI * clampf((u - seg - 0.2) / 0.2, 0.0, 1.0))]


static func hash01(x: float) -> float:
	var v := sin(x * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)


## The facing's turn rate (rad/s, + toward -Z: Godot's yaw), smoothed by `rate`, from `fy` (the facing node's yaw now)
## and `last` (its yaw a frame ago; `have` false on the first frame).
static func turning(
	omega: float, fy: float, last: float, have: bool, dt: float, rate: float
) -> float:
	var w := 0.0
	if have:
		w = clampf(wrapf(fy - last, -PI, PI) / dt, -6.0, 6.0)
	return lerpf(omega, w, rate)
