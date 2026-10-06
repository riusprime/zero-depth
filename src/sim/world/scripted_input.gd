class_name ScriptedInput
extends RefCounted
## A seeded, replayable input source for tests, goldens, smoke runs and the bench: it changes direction every
## 30 ticks, sweeps its aim, and taps dash now and then.

var _rng: RngStream
var _move := Vector2i.ZERO
var _aim := 0


func _init(seed_value: int) -> void:
	_rng = RngStream.derive(seed_value, "scripted_input")


func frame(tick: int) -> InputFrame:
	if tick % 30 == 0:
		_move = Vector2i(_rng.range_int(-127, 127), _rng.range_int(-127, 127))
		_aim = _rng.range_int(0, 4095)
	var pressed := InputFrame.DASH if _rng.chance_permille(20) else 0
	_aim = (_aim + 7) & 4095
	return InputFrame.make(_move, _aim, 800, 0, pressed)
