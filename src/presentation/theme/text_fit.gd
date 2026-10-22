class_name TextFit
extends RefCounted
## Text that steps down in size until it fits its box (P-11; moved out of the retired crystal card, v0.8.0 MU): the
## cards, plaques, tiles and slots pick their type sizes here, so long Spanish lines stay inside.

## v0.8.0 N18 (owner O76: "Shrink long words to fit"): a card name laid out in a fixed tile wraps by word; a word
## wider than the tile ("Electromagnetismo") steps the name's size down a pixel at a time until its widest word fits,
## never below this share of the size it would have had (a floor, so a name stays legible).
const WORD_FLOOR := 0.75


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


## v0.8.0 N18: the largest size from `s` down to WORD_FLOOR x `s` at which every word of `text` fits `width` on its
## own line (so word wrapping never has to break or overflow a word); the floor when none does.
static func word_fit_size(font: Font, text: String, width: float, s: int) -> int:
	var lowest := maxi(1, ceili(s * WORD_FLOOR))
	var size := s
	while size > lowest and widest_word(font, text, size) > width:
		size -= 1
	return size


## The width (px) of the widest word of `text` at size `s` (words split on spaces).
static func widest_word(font: Font, text: String, s: int) -> float:
	var most := 0.0
	for word in text.split(" ", false):
		most = maxf(most, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x)
	return most


## v0.8.0 N18: sizes label `l` (its own font) for its text in a tile `width` wide: `s`, or smaller when a word would
## not fit (word_fit_size). Returns the size set.
static func fit_label_words(l: Label, width: float, s: int) -> int:
	var size := word_fit_size(l.get_theme_font("font"), l.text, width, s)
	l.add_theme_font_size_override("font_size", size)
	return size


## The height of `text` wrapped to `width` at size `s` (word breaks, as a Label with AUTOWRAP_WORD_SMART).
static func text_height(font: Font, text: String, width: float, s: int) -> float:
	if text.is_empty():
		return 0.0
	var flags := (
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	)
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, s, -1, flags).y
