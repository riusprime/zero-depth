class_name EchoLabel
extends Label
## A HUD label in the HudStyle look (v0.3.0 UI, L21): ghost copies of its text sit behind it (a chromatic split,
## trailing holo echoes or a stencil shadow, by style) and, when the text changes, they spread out, jitter and
## settle back over HudStyle.ECHO_S: an echo/glitch on every new value. It reads nothing; it shows what it is
## given.

var style: HudStyle.Style
var _ghosts: Array[Label] = []
var _base: Array = []
var _shown := ""
var _echo := 0.0
var _t := 0.0


func _init(font_size: int = 20, bold: bool = false, s: HudStyle.Style = HudStyle.current) -> void:
	style = s
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudStyle.style_label(self, font_size, bold, s)
	for g: Array in HudStyle.ghosts(s):
		var l := Label.new()
		l.show_behind_parent = true
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		HudStyle.style_label(l, font_size, bold, s)
		l.add_theme_color_override("font_color", g[1])
		l.add_theme_constant_override("outline_size", 0)
		add_child(l)
		_ghosts.append(l)
		_base.append(g)


## How much of the current echo is left, 1 (just changed) .. 0 (settled) (tests).
func echo_level() -> float:
	return _echo


func _process(delta: float) -> void:
	_t += delta
	if text != _shown:
		_shown = text
		_echo = 1.0
		for l in _ghosts:
			l.text = text
			l.horizontal_alignment = horizontal_alignment
			l.vertical_alignment = vertical_alignment
	if _echo > 0.0:
		_echo = maxf(0.0, _echo - delta / HudStyle.ECHO_S)
	var calm := HudStyle.reduced_motion
	var e := 0.0 if calm else _echo
	var flip := 1.0 if int(_t * 40.0) % 2 == 0 else -1.0
	for k in _ghosts.size():
		var g: Array = _base[k]
		var off: Vector2 = g[0]
		var c: Color = g[1]
		match style:
			HudStyle.Style.TERMINAL:
				off = off * (1.0 + 5.0 * e) + Vector2(0, flip * 2.0 * e)
			HudStyle.Style.INDUSTRIAL:
				off += Vector2(flip * 9.0 * e, 0)
			_:
				off = off * (1.0 + 3.0 * e)
				c.a = minf(1.0, c.a * (1.0 + 1.2 * e))
		_ghosts[k].position = off
		_ghosts[k].size = size
		_ghosts[k].add_theme_color_override("font_color", c)
	modulate.a = 0.7 if e > 0.2 and int(_t * 24.0) % 3 == 0 else 1.0
