class_name MineLayerModel
extends RefCounted
## The Mine Layer on the owner's model (EnemyModels &"mine_layer", cut by scripts/assets/mine_layer_prep.py into the
## body, the head, the hopper with its front mine, the hatch, the rear mine and six two-part legs), animated on
## HordeAvatar's batched path: the avatar keeps its state (the drop's windup and strike, the rise-in, the death, the
## walk) and this poses the parts from five drives, the same numbers the native avatar (native/src/zd_avatar.cpp)
## works out for a batched one. The owner asked for the enemies to be "animated as good as you can"; the horde rig's
## stance grid could not carry walking legs, a drop and an idle at once, so this kind declares its own rig (three
## grids, five drives: one more drive than the other horde kinds, sent in the crowd's per-instance drive texture).
## The drives (each 0..1, the bake's grid units):
## - 0 the stride's phase (a loop), 1 and 2 the stride's velocity along +X and +Z in the facing's frame (within the
##   unit disc of FULL_MPS, mapped to 0..1; faster, a knock, slides): the legs scuttle in a tripod gait, posed by reach
##   so a foot on the ground stays still while the body passes over it, in whichever way it goes (it keeps its
##   distance facing the hero: backing off and sidestepping too); the body bobs and rocks with each tripod's landing;
## - 3 the drop clip: 0..0.5 the windup (the hopper tips back, the hatch eases open, the rear mine rolls to it), 0.5
##   the drop (the hatch flung open, the mine gone through it), the hatch slamming shut, a new mine growing in its
##   seat, back to rest at 1 (= 0);
## - 4 the idle loop (the frame clock): the body heaving with its breath (a stretch about the ground: the feet stay
##   down) and the head looking round.
## The rise-in, the hit's flinch and the death are the body's whole move (the instance transform): it climbs out of the
## ground; dying it rolls onto its back with its legs flailing, the hatch flung open. Reduced motion: the idle at half
## its pace, no flailing. Presentation only (EI-07).

const MODEL := &"mine_layer"
## The stride: a full stride at FULL_MPS (the sim's 2.4 m/s), up to WALK_MAX of it; STEP_HZ strides a second; a foot
## is down DUTY of a stride and sweeps SWEEP either side (so a planted foot keeps still), lifting LIFT.
const FULL_MPS := 2.4
const WALK_MAX := 1.0
const STEP_HZ := 10.0
const DUTY := 0.5
const SWEEP := FULL_MPS * DUTY / (2.0 * STEP_HZ)
const LIFT := 0.035
## The legs flail this fast as it dies; the idle loop's pace (Hz); the body's roll and lift as it dies.
const FLAIL_HZ := 5.0
const IDLE_HZ := 0.3
const DEATH_ROLL := 2.6
const HALF_WIDTH := 0.31
const TOP := 0.39
## The legs (fr / fl the front pair, m the middle, b the back; r is +Z) and each one's place in the stride: two tripods.
const LEGS: Array[StringName] = [&"fr", &"fl", &"mr", &"ml", &"br", &"bl"]
const STRIDE_AT := [0.0, 0.5, 0.5, 0.0, 0.0, 0.5]
## Each claw's tip in the model (model units: metres at the model's own size, the prep's fitted points), and where
## each foot stands at rest: the front pair a little further out than the model has them (their short legs keep the
## stride's sweep within reach and never under the hip).
const TIPS := [
	Vector3(0.317, 0.0, 0.193),
	Vector3(0.303, 0.0, -0.208),
	Vector3(0.141, 0.0, 0.289),
	Vector3(0.076, 0.0, -0.291),
	Vector3(-0.106, 0.0, 0.301),
	Vector3(-0.139, 0.0, -0.303),
]
const FEET := [
	Vector3(0.331, 0.0, 0.204),
	Vector3(0.315, 0.0, -0.222),
	Vector3(0.141, 0.0, 0.289),
	Vector3(0.076, 0.0, -0.291),
	Vector3(-0.106, 0.0, 0.301),
	Vector3(-0.139, 0.0, -0.303),
]
## The body's pivot (it rocks about it), the hopper's rear hinge (it tips back about it, its front lifting), the point
## the dropping mine shrinks toward (the hatch's lip, below and behind it).
const BODY_AT := Vector3(0.0, 0.15, 0.0)
const HOPPER_REAR := Vector3(-0.37, 0.19, -0.03)
const MINE_OUT := Vector3(-0.42, 0.22, -0.06)
## The breath's stretch and the bob (m) at a full stride.
const BREATH := 0.025
const BOB := 0.006
## The drop clip's beats (each one a sample of the bake's 129: the mine's scale is linear between them).
const C_DROP := 0.5
const C_GONE := 0.5625
const C_BACK := 0.8125
const C_FULL := 0.9375
## The rig's samples: the stride's phase, velocity x and z; the clip; the idle loop.
const SAMPLES := [32, 15, 15, 129, 32]


static func takes(a: HordeAvatar) -> bool:
	return a.kind == WorldReader.KIND_MINE_LAYER and a.has_model()


# --- The state the drives come from -------------------------------------------------------------------------------
## The walk (HordeAvatar.advance, the owner's model): the stride's velocity in the facing's frame (`at` the avatar's
## place now, `yaw` the facing's turn) and its phase; dying, the legs flail. The native avatar's h_advance does the
## same arithmetic.
static func step(a: HordeAvatar, at: Vector3, yaw: float, dt: float) -> void:
	var vx := 0.0
	var vz := 0.0
	if a._last_at != Vector3.INF:
		var dx := at.x - a._last_at.x
		var dz := at.z - a._last_at.z
		var c := cos(yaw)
		var s := sin(yaw)
		vx = (dx * c - dz * s) / dt / FULL_MPS
		vz = (dx * s + dz * c) / dt / FULL_MPS
	a._walk = move_toward(a._walk, clampf(vx, -WALK_MAX, WALK_MAX), dt * 6.0)
	a._walk_z = move_toward(a._walk_z, clampf(vz, -WALK_MAX, WALK_MAX), dt * 6.0)
	var speed := sqrt(a._walk * a._walk + a._walk_z * a._walk_z)
	if speed > WALK_MAX:  # Kept in the disc (the stride's reach)
		a._walk = a._walk / speed * WALK_MAX
		a._walk_z = a._walk_z / speed * WALK_MAX
		speed = WALK_MAX
	var hz := STEP_HZ * minf(1.0, speed * 20.0)
	if a._die_t >= 0.0:
		hz = 0.0 if ViewPrefs.reduced_motion else FLAIL_HZ
	a._walk_t += dt * hz


## The body's place under the avatar (the rise-in's climb; dying, lifted as it rolls so it rolls over the ground), its
## roll (radians about +X) at death fraction `d`.
static func body_at(a: HordeAvatar, d: float) -> Vector3:
	var y := -(1.0 - a._rise) * a.height
	if d > 0.0:
		var r := death_roll(d)
		y += (HALF_WIDTH * sin(r) + TOP * maxf(0.0, -cos(r))) * (1.0 - 0.35 * d)
	return Vector3(0.0, y, 0.0)


static func death_roll(d: float) -> float:
	return DEATH_ROLL * d * d * (3.0 - 2.0 * d)


## The first four drives (grid units) at death fraction `d`: the stride's phase, its velocity (dying: a full stride
## along +X, the legs flailing), the clip.
static func drives(a: HordeAvatar, d: float) -> Vector4:
	var vx := lerpf(a._walk, 1.0, d)
	var vz := a._walk_z * (1.0 - d)
	var c := 1.0 - 0.5 * a._strike if a._strike > 0.0 else 0.5 * a._wind
	return Vector4(
		fposmod(a._walk_t, 1.0),
		(clampf(vx, -WALK_MAX, WALK_MAX) / WALK_MAX + 1.0) * 0.5,
		(clampf(vz, -WALK_MAX, WALK_MAX) / WALK_MAX + 1.0) * 0.5,
		c
	)


## The fifth drive: the idle loop's phase at clock `t`.
static func idle_phase(t: float) -> float:
	return fposmod(t * IDLE_HZ * (0.5 if ViewPrefs.reduced_motion else 1.0), 1.0)


# --- The parts ----------------------------------------------------------------------------------------------------
## Rebuilds the model's parts (HordeAvatar._build_model hangs each from the model) into the rig's chain: a breath node
## over everything; the head and the hopper on the body; the hatch and the mine on the hopper; each leg's lower half
## on its upper half.
static func rig_nodes(a: HordeAvatar) -> void:
	var breath := Node3D.new()
	breath.name = "Breath"
	a.model.add_child(breath)
	for pname: String in a.parts.keys():
		(a.parts[pname] as Node3D).reparent(breath, false)
	a.parts["breath"] = breath
	_hang(a, "head", "body")
	_hang(a, "hopper", "body")
	_hang(a, "hatch", "hopper")
	_hang(a, "mine", "hopper")
	for leg: StringName in LEGS:
		_hang(a, "leg_%s_l" % leg, "leg_%s_u" % leg)


static func _hang(a: HordeAvatar, child: String, parent: String) -> void:
	var c := a.parts[child] as Node3D
	c.reparent(a.parts[parent], false)
	c.position = pivot(child) - pivot(parent)


## A part's pivot (model units, the model's frame).
static func pivot(pname: String) -> Vector3:
	var parts: Dictionary = EnemyModels.get_model(MODEL).get("parts", {})
	if parts.has(StringName(pname)):
		return (parts[StringName(pname)] as Dictionary)["pivot"]
	return Vector3.ZERO


## Poses the parts at drives `d` (grid units; [phase, vx, vz, clip, idle]). The live pose and the bake both pose here.
static func pose(a: HordeAvatar, d: PackedFloat64Array) -> void:
	var p := a.parts
	(p["breath"] as Node3D).transform = breath_xf(d[4])
	var body := body_xf(d[0], d[1], d[2])
	(p["body"] as Node3D).transform = body
	(p["head"] as Node3D).transform = head_xf(d[4])
	(p["hopper"] as Node3D).transform = hopper_xf(d[3])
	(p["hatch"] as Node3D).transform = hatch_xf(d[3])
	(p["mine"] as Node3D).transform = mine_xf(d[3])
	var vx := (d[1] * 2.0 - 1.0) * WALK_MAX
	var vz := (d[2] * 2.0 - 1.0) * WALK_MAX
	var amp := vx * vx + vz * vz
	for k in LEGS.size():
		var c := leg_cycle(fposmod(d[0] - float(STRIDE_AT[k]), 1.0))
		var foot: Vector3 = (
			FEET[k] + Vector3(vx, 0.0, vz) * (SWEEP * c.x) + Vector3(0, LIFT * amp * c.y, 0)
		)
		_reach(a, k, body, foot)


## The breath: a stretch up about the ground (the feet stay down) on the idle loop.
static func breath_xf(w: float) -> Transform3D:
	return Transform3D(
		Basis.from_scale(Vector3(1.0, 1.0 + BREATH * sin(TAU * w), 1.0)), Vector3.ZERO
	)


## The body over the stride (phase `ph`, velocity grid `gx`, `gz`): it bobs as each tripod lands and rocks with them.
static func body_xf(ph: float, gx: float, gz: float) -> Transform3D:
	var vx := (gx * 2.0 - 1.0) * WALK_MAX
	var vz := (gz * 2.0 - 1.0) * WALK_MAX
	var g := vx * vx + vz * vz
	var bob := -BOB * g * (1.0 - cos(2.0 * TAU * ph))
	var roll := 0.05 * g * sin(TAU * ph)
	var pitch := 0.02 * g * sin(2.0 * TAU * ph + 0.5)
	var yaw := 0.04 * g * sin(TAU * ph + 0.3)
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, pitch) * Basis(Vector3.RIGHT, roll)
	return Transform3D(b, BODY_AT + Vector3(0, bob, 0) - b * BODY_AT)


## The head (at the neck, under the body) on the idle loop: looking round, nodding.
static func head_xf(w: float) -> Transform3D:
	var yaw := 0.3 * sin(TAU * w) + 0.12 * sin(3.0 * TAU * w + 1.0)
	var nod := 0.08 * sin(2.0 * TAU * w + 0.7)
	return Transform3D(
		Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, nod), pivot("head") - pivot("body")
	)


## 0..1 how far into the windup clip `c` is (0 after it).
static func windup_of(c: float) -> float:
	return smoothstep(0.0, C_DROP, c) if c <= C_DROP else 0.0


## The hopper at clip `c`: tipping back about its rear hinge through the windup (its front lifting, the mines rolling
## back), kicking at the drop, settling with a bounce.
static func hopper_xf(c: float) -> Transform3D:
	var tilt := 0.26 * windup_of(c)
	if c > C_DROP:
		var u := (c - C_DROP) / (1.0 - C_DROP)
		var kick := sin(PI * clampf(u / 0.3, 0.0, 1.0))
		tilt = 0.26 * (1.0 - smoothstep(0.0, 0.55, u)) + 0.08 * kick
		tilt -= 0.04 * sin(PI * clampf((u - 0.45) / 0.35, 0.0, 1.0))
	var at := pivot("hopper")
	var b := Basis(Vector3.BACK, tilt)
	var q := HOPPER_REAR - at
	return Transform3D(b, at - pivot("body") + q - b * q)


## The hatch at clip `c` (about its foot, + swings its top back and out): easing open through the windup, flung open
## at the drop, slammed shut with a rebound.
static func hatch_xf(c: float) -> Transform3D:
	var open := 0.55 * windup_of(c) * windup_of(c)
	if c > C_DROP:
		var u := (c - C_DROP) / (1.0 - C_DROP)
		open = lerpf(0.55, 1.4, smoothstep(0.0, 0.16, u)) * (1.0 - smoothstep(0.32, 0.56, u))
		open -= 0.1 * sin(PI * clampf((u - 0.56) / 0.2, 0.0, 1.0))
	return Transform3D(Basis(Vector3.BACK, open), pivot("hatch") - pivot("hopper"))


## The rear mine at clip `c`: rolling back to the hatch through the windup, shrinking out through it at the drop (to the
## hatch's lip), gone, then a new one growing back from the lip into its seat. (Its place and its size are each linear
## between the clip's beats, which are samples of the bake: the baked mine is the live one.)
static func mine_xf(c: float) -> Transform3D:
	var at := pivot("mine") - pivot("hopper")
	var w := windup_of(c)
	if c <= C_DROP:
		return Transform3D(Basis(Vector3.BACK, 0.9 * w), at + Vector3(-0.035 * w, 0, 0))
	var lip := MINE_OUT - pivot("hopper")
	if c < C_GONE:  # Out through the hatch: toward the lip, at the windup's end pose
		var s := 1.0 - (c - C_DROP) / (C_GONE - C_DROP)
		var seat := at + Vector3(-0.035, 0, 0)
		return Transform3D(Basis(Vector3.BACK, 0.9) * s, lip + (seat - lip) * s)
	var g := clampf((c - C_BACK) / (C_FULL - C_BACK), 0.0, 1.0)
	return Transform3D(Basis.IDENTITY * g, lip + (at - lip) * g)


## One foot through its stride at q (0 its touchdown): (the sweep: 1 ahead .. -1 behind; the lift 0..1).
static func leg_cycle(q: float) -> Vector2:
	if q < DUTY:
		return Vector2(1.0 - 2.0 * q / DUTY, 0.0)
	var w := (q - DUTY) / (1.0 - DUTY)
	var up := sin(PI * w)
	return Vector2(-1.0 + 2.0 * smoothstep(0.0, 1.0, w), up * up * (3.0 - 2.0 * up))


## Leg `k` reaches for `foot` (the breath's frame) from its hip under `body`: the leg's plane (the vertical through its
## rest reach) turns about the hip to face the foot, then the hip and the knee bend in that plane (two bones; past its
## reach the foot stops short).
static func _reach(a: HordeAvatar, k: int, body: Transform3D, foot: Vector3) -> void:
	var leg: StringName = LEGS[k]
	var up_n := a.parts["leg_%s_u" % leg] as Node3D
	var low_n := a.parts["leg_%s_l" % leg] as Node3D
	var hip0 := pivot("leg_%s_u" % leg)
	var knee := pivot("leg_%s_l" % leg) - hip0
	var tip: Vector3 = TIPS[k] - hip0
	var hip := body * hip0
	var t := foot - hip
	var u0 := Vector3(tip.x, 0.0, tip.z).normalized()
	var n := u0.cross(Vector3.UP).normalized()
	var yaw := wrapf(atan2(-t.z, t.x) - atan2(-u0.z, u0.x), -PI, PI)
	var k2 := Vector2(knee.dot(u0), knee.y)
	var f2 := Vector2(tip.dot(u0), tip.y)
	var aim := Vector2(Vector2(t.x, t.z).length(), t.y)
	var la := k2.length()
	var lb := (f2 - k2).length()
	var reach := clampf(aim.length(), absf(la - lb) + 0.002, (la + lb) * 0.998)
	var bend := signf(f2.cross(k2))
	var off := acos(clampf((la * la + reach * reach - lb * lb) / (2.0 * la * reach), -1.0, 1.0))
	var hip_turn := wrapf(aim.angle() + bend * off - k2.angle(), -PI, PI)
	var l1 := aim.normalized() * reach - k2.rotated(hip_turn)
	var knee_turn := wrapf(l1.angle() - (f2 - k2).angle() - hip_turn, -PI, PI)
	up_n.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(n, hip_turn), hip)
	low_n.transform = Transform3D(Basis(n, knee_turn), knee)


## Where leg `k`'s claw tip is now (the breath's frame; tests): its chain from the nodes.
static func foot_at(a: HordeAvatar, k: int) -> Vector3:
	var leg: StringName = LEGS[k]
	var up_n := a.parts["leg_%s_u" % leg] as Node3D
	var low_n := a.parts["leg_%s_l" % leg] as Node3D
	return up_n.transform * low_n.transform * (TIPS[k] - pivot("leg_%s_l" % leg))


# --- The rig (VatBake) --------------------------------------------------------------------------------------------
## The VatBake rig of `a` (built with its pieces): the body's node the root (its moves are the instance's), then the
## breath and the head on the idle loop (grid 2), the body and the legs on the stride (grid 0: phase, vx, vz), the
## hopper, hatch and mine on the clip (grid 1).
static func rig(a: HordeAvatar) -> Dictionary:
	var p := a.parts
	var spec: Array = [
		[a.body, 0],
		[p["breath"], 2],
		[p["body"], 0],
		[p["head"], 2],
		[p["hopper"], 1],
		[p["hatch"], 1],
		[p["mine"], 1],
	]
	for leg: StringName in LEGS:
		spec.append([p["leg_%s_u" % leg], 0])
		spec.append([p["leg_%s_l" % leg], 0])
	var js: Array = []
	var index := {}
	for e: Array in spec:
		var node: Node3D = e[0]
		var parent := -1
		var up := node.get_parent()
		while up != null and up != a:
			if index.has(up):
				parent = index[up]
				break
			up = up.get_parent()
		index[node] = js.size()
		js.append({"grid": e[1], "parent": parent, "frame": node})
	var out := {
		"key": "mine_layer_model",
		"drives": 5,
		"grids":
		[
			[[0, SAMPLES[0], true], [1, SAMPLES[1], false], [2, SAMPLES[2], false]],
			[[3, SAMPLES[3], false]],
			[[4, SAMPLES[4], true]],
		],
		"joints": js,
		"row": func(g: int, d: PackedFloat64Array) -> Array: return _row(a, js, g, d),
		"scaled": true,
	}
	var tex: Texture2D = EnemyModels.get_model(MODEL).get("texture")
	if tex != null:
		out["albedo_tex"] = tex
	return out


static func _row(a: HordeAvatar, js: Array, g: int, d: PackedFloat64Array) -> Array:
	pose(a, d)
	a.model.transform = Transform3D(Basis.from_scale(Vector3.ONE * a._model_scale), Vector3.ZERO)
	var out: Array = []
	for j: Dictionary in js:
		if j["grid"] != g:
			continue
		out.append(Transform3D.IDENTITY if j["frame"] == a.body else VatBake.local_of(a, js, j))
	return out
