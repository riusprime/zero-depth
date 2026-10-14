class_name TextFit
extends RefCounted
## Text that steps down in size until it fits its box (P-11; moved out of the retired crystal card, v0.8.0 MU): the
## cards, plaques, tiles and slots pick their type sizes here, so long Spanish lines stay inside.


## The largest size in `sizes` at which `text` wrapped to `width` is at most `max_h` tall and `max_lines` lines
## (0: any), or the smallest size when none fits.
static func fit_size(
	font: Font, text: String, width: float, max_h: float, sizes: Array, max_lines: int = 0
) -> int:
	for s: int in sizes:
		var h := text_height(font, text, width, s)
		var lines := roundi(h / font.get_height(s)) if not text.is_empty() else 0
		if h <= max_h and (max_lines <= 0 or lines <= max_lines):
			return s
	return sizes[sizes.size() - 1]


## True when `text` fits `width` x `max_h` at size `s` (and at most `max_lines` lines; 0: any).
static func fits(
	font: Font, text: String, width: float, max_h: float, s: int, max_lines: int = 0
) -> bool:
	var h := text_height(font, text, width, s)
	var lines := roundi(h / font.get_height(s)) if not text.is_empty() else 0
	return h <= max_h + 0.5 and (max_lines <= 0 or lines <= max_lines)


## The largest size in `sizes` (largest first) at which `text` fits one line `width` wide, or the smallest when none
## fits.
static func fit_width(font: Font, text: String, width: float, sizes: Array) -> int:
	for s: int in sizes:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= width:
			return s
	return sizes[sizes.size() - 1]


## The height of `text` wrapped to `width` at size `s` (word breaks, as a Label with AUTOWRAP_WORD_SMART).
static func text_height(font: Font, text: String, width: float, s: int) -> float:
	if text.is_empty():
		return 0.0
	var flags := (
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	)
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, s, -1, flags).y
