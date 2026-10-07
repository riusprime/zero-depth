class_name DamageNumbers
extends Node3D
## Damage numbers (v0.4.0 BS, owner F9): every direct hit the player lands on an enemy floats its damage up from
## where it landed: a small white number, or for a crit (TAG_CRIT) a bigger yellow one that pops. Read from the
## event log (DAMAGE events the player owns; damage over time stays quiet). Pooled Label3Ds, the oldest reused once
## POOL are in the air, so a crowd never allocates per hit. Nothing here changes an outcome.

const POOL := 40
const LIFE_S := 0.7
const RISE_M := 0.9
const SIZE := 32
const CRIT_SIZE := 60
const COLOR := Color(1, 1, 1, 0.92)
const CRIT_COLOR := Color("#FFD23A")

var _labels: Array[Label3D] = []
## Per label: seconds left, start position, crit.
var _left := PackedFloat32Array()
var _from: Array[Vector3] = []
var _crit: Array[bool] = []
var _next := 0
var _last_seq := 0


func _init() -> void:
	name = "DamageNumbers"


func sync(reader: WorldReader) -> void:
	var player_id := reader.actor_id(0)
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.DAMAGE or e.owner_id != player_id or e.target_id == player_id:
			continue
		if e.tags & SimEvent.TAG_DOT or e.amount <= 0:
			continue
		show_number(e.pos, e.amount, (e.tags & SimEvent.TAG_CRIT) != 0)


## Floats `amount` up from `at` (crit: bigger, yellow).
func show_number(at: Vector2, amount: int, crit: bool) -> void:
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
		_next = _labels.size() - 1
	else:
		_next = (_next + 1) % POOL
	var k := _next
	l = _labels[k]
	l.text = str(amount)
	l.font_size = CRIT_SIZE if crit else SIZE
	l.modulate = CRIT_COLOR if crit else COLOR
	_from[k] = SimPlane.to_3d(at, 1.3 if crit else 1.1)
	_crit[k] = crit
	_left[k] = LIFE_S
	l.position = _from[k]
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
		var t := 1.0 - _left[k] / LIFE_S
		l.position = _from[k] + Vector3(0, RISE_M * t, 0)
		var pop := 1.0 + (0.5 * maxf(0.0, 1.0 - t * 5.0) if _crit[k] else 0.0)
		l.scale = Vector3.ONE * pop
		l.modulate.a = clampf(_left[k] / (LIFE_S * 0.4), 0.0, 1.0) * (1.0 if _crit[k] else 0.92)
