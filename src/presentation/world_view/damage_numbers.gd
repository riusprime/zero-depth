class_name DamageNumbers
extends Node3D
## Damage numbers (v0.4.0 BS, owner F9): every direct hit the player lands on an enemy shows its damage from where it
## landed: a small white number, or for a crit (TAG_CRIT) a bigger yellow one. Read from the event log (DAMAGE events
## the player owns; damage over time stays quiet). Pooled Label3Ds, the oldest reused once POOL are in the air, so a
## crowd never allocates per hit (that is the rule for rapid hits: no merging, the oldest gives way). Nothing here
## changes an outcome.
## v0.8.0 GF2 (owner O21: "a little bit bigger, just a bit, and they should come out like they are thrown from the
## enemy in a curve that goes up and out. And the crit should be a number that spawns bigger, it has a little shake,
## and then it vanishes"): numbers are 15 % bigger; each is thrown up and out to one side of the screen (sides
## alternate, the reach and height spread a little by a cosmetic RNG: presentation only, never the sim's streams,
## EI-05), peaking ARC_PEAK of the way and falling as it fades. A crit spawns big (CRIT_POP), shakes for CRIT_SHAKE_S,
## drifts up a little and vanishes, shrinking, over its last CRIT_VANISH. Colours unchanged (readability). Reduced
## motion: no shake and no arc, a short straight rise. Starting values.

const POOL := 40
const LIFE_S := 0.75
const CRIT_LIFE_S := 0.8
## Reduced motion's rise (m); a crit's drift up (m).
const RISE_M := 0.6
const CRIT_RISE_M := 0.35
const SIZE := 37
const CRIT_SIZE := 69
const COLOR := Color(1, 1, 1, 0.92)
const CRIT_COLOR := Color("#FFD23A")
## v0.9.5 SM: a hit that struck a Stress Mark's weak side.
const WEAK_COLOR := Color("#FF8A2A")
## The throw: how far out to the side (m, along the screen), how high its peak (m) and where in its life it peaks;
## the cosmetic spread on both (0.2: 80-120 %).
const THROW_OUT_M := 0.9
const THROW_UP_M := 0.75
const ARC_PEAK := 0.45
const SPREAD := 0.2
## A crit: its pop at spawn (scale over 1), the shake's time and amplitude (m), the vanish's share of its life.
const CRIT_POP := 0.6
const CRIT_SHAKE_S := 0.22
const CRIT_SHAKE_M := 0.05
const CRIT_VANISH := 0.3

var _labels: Array[Label3D] = []
## Per label: seconds left, start position, crit, the throw (sideways in metres along the screen, peak height).
var _left := PackedFloat32Array()
var _from: Array[Vector3] = []
var _crit: Array[bool] = []
var _throw: Array[Vector2] = []
var _next := 0
var _last_seq := 0
## v0.9.5 SM: the enemies whose weak side broke this tick (id -> tick), so their hit's number shows orange.
var _weak := {}
var _side := 1.0
## The cosmetic stream (presentation only, EI-05): the throw's spread and the crit's shake.
var _rng := RandomNumberGenerator.new()
## The screen's right on the floor plane (the iso camera's yaw is fixed: IsoRig.YAW_DEG).
var _right := Vector3(cos(deg_to_rad(IsoRig.YAW_DEG)), 0.0, -sin(deg_to_rad(IsoRig.YAW_DEG)))


func _init() -> void:
	name = "DamageNumbers"
	_rng.seed = 21


func sync(reader: WorldReader) -> void:
	var player_id := reader.actor_id(0)
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.STRESS_BREAK:
			_weak[e.target_id] = e.tick
			continue
		if e.kind != SimEvent.Kind.DAMAGE or e.owner_id != player_id or e.target_id == player_id:
			continue
		if e.tags & SimEvent.TAG_DOT or e.amount <= 0:
			continue
		var weak := int(_weak.get(e.target_id, -1)) == e.tick
		show_number(
			e.pos,
			e.amount,
			(e.tags & SimEvent.TAG_CRIT) != 0,
			WEAK_COLOR if weak else Color(0, 0, 0, 0)
		)
		_weak.erase(e.target_id)


## Throws `amount` from `at` (crit: bigger, yellow, a shake and a vanish).
func show_number(at: Vector2, amount: int, crit: bool, tint := Color(0, 0, 0, 0)) -> void:
	var l: Label3D
	if _labels.size() < POOL:
		l = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.005
		l.outline_size = 10
		l.outline_modulate = Color(0, 0, 0, 0.85)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(l)
		_labels.append(l)
		_left.append(0.0)
		_from.append(Vector3.ZERO)
		_crit.append(false)
		_throw.append(Vector2.ZERO)
		_next = _labels.size() - 1
	else:
		_next = (_next + 1) % POOL
	var k := _next
	l = _labels[k]
	l.text = str(amount)
	l.font_size = CRIT_SIZE if crit else SIZE
	l.modulate = tint if tint.a > 0.0 else (CRIT_COLOR if crit else COLOR)
	_from[k] = SimPlane.to_3d(at, 1.3 if crit else 1.1)
	_crit[k] = crit
	_left[k] = CRIT_LIFE_S if crit else LIFE_S
	_side = -_side
	_throw[k] = Vector2(
		_side * THROW_OUT_M * _rng.randf_range(1.0 - SPREAD, 1.0 + SPREAD),
		THROW_UP_M * _rng.randf_range(1.0 - SPREAD, 1.0 + SPREAD)
	)
	l.position = _from[k]
	l.scale = Vector3.ONE * (1.0 + CRIT_POP if crit else 1.0)
	l.visible = true


# --- Reads (tests) ------------------------------------------------------------------------------------------
func showing() -> int:
	var n := 0
	for k in _labels.size():
		n += 1 if _labels[k].visible else 0
	return n


## The visible labels' texts and whether each is a crit, in pool order.
func shown() -> Array:
	var out := []
	for k in _labels.size():
		if _labels[k].visible:
			out.append([_labels[k].text, _crit[k], _labels[k].font_size])
	return out


func _process(delta: float) -> void:
	for k in _labels.size():
		var l := _labels[k]
		if not l.visible:
			continue
		_left[k] -= delta
		if _left[k] <= 0.0:
			l.visible = false
			continue
		var life := CRIT_LIFE_S if _crit[k] else LIFE_S
		var t := 1.0 - _left[k] / life
		var o := offset(t, _crit[k], _throw[k], ViewPrefs.reduced_motion)
		var shake := Vector3.ZERO
		if _crit[k] and not ViewPrefs.reduced_motion and t * life < CRIT_SHAKE_S:
			var fall := 1.0 - t * life / CRIT_SHAKE_S
			shake = (
				(_right * _rng.randf_range(-1.0, 1.0) + Vector3(0, _rng.randf_range(-1.0, 1.0), 0))
				* CRIT_SHAKE_M
				* fall
			)
		l.position = _from[k] + _right * o.x + Vector3(0, o.y, 0) + shake
		l.scale = Vector3.ONE * size_at(t, _crit[k])
		l.modulate.a = alpha_at(t, _crit[k]) * (1.0 if _crit[k] else 0.92)


## Where a number is at t (0..1) through its life, from where it spawned: x along the screen's right, y up (m).
## A plain number flies the throw (x out, y up to `arc.y` at ARC_PEAK and back down past where it started); a
## crit drifts straight up; with reduced motion both rise straight a little.
static func offset(t: float, crit: bool, arc: Vector2, calm: bool) -> Vector2:
	var u := clampf(t, 0.0, 1.0)
	if calm:
		return Vector2(0, RISE_M * (1.0 - (1.0 - u) * (1.0 - u)))
	if crit:
		return Vector2(0, CRIT_RISE_M * (1.0 - (1.0 - u) * (1.0 - u)))
	# A parabola through 0 at the start with its top (throw.y) at ARC_PEAK.
	var a := u / ARC_PEAK
	return Vector2(arc.x * u, arc.y * (2.0 * a - a * a))


## A number's scale at t: a crit spawns CRIT_POP bigger and settles fast, then shrinks away over its vanish.
static func size_at(t: float, crit: bool) -> float:
	if not crit:
		return 1.0
	var pop := 1.0 + CRIT_POP * maxf(0.0, 1.0 - t * 5.0)
	var gone := clampf((t - (1.0 - CRIT_VANISH)) / CRIT_VANISH, 0.0, 1.0)
	return pop * (1.0 - 0.7 * gone * gone)


## A number's opacity at t: a plain one fades as it falls (from its peak on), a crit over its vanish.
static func alpha_at(t: float, crit: bool) -> float:
	if crit:
		return clampf((1.0 - t) / CRIT_VANISH, 0.0, 1.0)
	return clampf((1.0 - t) / (1.0 - ARC_PEAK), 0.0, 1.0)


## A label's offset from where it spawned now (tests): [the label, its start].
func label_at(k: int) -> Array:
	return [_labels[k], _from[k]]
