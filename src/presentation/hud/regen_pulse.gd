class_name RegenPulse
extends ColorRect
## The HP bar's subtle green pulse while out-of-combat regen heals (v0.3.0 L25). It lies over the bar's fill and
## breathes while the sim regenerates (WorldReader.player_build); it reads the sim and decides nothing.

const COLOR := Color("#5BE38A")
const PERIOD_S := 1.0
const PEAK_ALPHA := 0.45

var _t := 0.0
var _on := false


func _init() -> void:
	name = "RegenPulse"
	color = COLOR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0


## Follows the fill's size; pulses while the sim regenerates.
func sync(reader: WorldReader, fill_size: Vector2) -> void:
	size = fill_size
	_on = reader.player_build()["regenerating"]


func is_pulsing() -> bool:
	return _on


func _process(delta: float) -> void:
	if not _on:
		_t = 0.0
		modulate.a = move_toward(modulate.a, 0.0, delta * 3.0)
		return
	_t = fmod(_t + delta, PERIOD_S)
	modulate.a = PEAK_ALPHA * (0.5 - 0.5 * cos(TAU * _t / PERIOD_S))
