class_name RuneCipher
extends RefCounted
## v0.9.5 RS1 (RUNIC_STONE.md S4, the hidden cipher): the Runic Stone's lines are English, written one Elder Futhark
## rune per letter. A glyph id is the rune's place in the Futhark (0 = fehu ... 23 = othala); a space is GAP. The
## game never translates a line: a curious player decodes it with a Futhark table. The strokes that draw each glyph
## are the presentation's (RunicGlyphs).
##
## The table (letter -> rune):
##   F fehu 0, U uruz 1, C thurisaz 2 (a spare rune), A ansuz 3, R raido 4, K kaunan 5, G gebo 6, W wunjo 7,
##   H hagalaz 8, N nauthiz 9, I isa 10, J jera 11, Y eihwaz 12 (a spare), P perthro 13, Z algiz 14, S sowilo 15,
##   T tiwaz 16, B berkana 17, E ehwaz 18, M mannaz 19, L laguz 20, V ingwaz 21 (a spare), D dagaz 22, O othala 23.
## Sharing (the Futhark has 24 runes for 26 letters; Q and X have no rune of their own): Q is written with K's kaunan
## and X with Z's algiz, so those two letters decode as K and Z (lossy for them only; no line uses Q or X).

const GAP := -1
const GLYPHS := 24
## A..Z -> glyph id.
const LETTER_GLYPH: Array[int] = [
	3, 17, 2, 22, 18, 0, 6, 8, 10, 11, 5, 20, 19, 9, 23, 13, 5, 4, 15, 16, 1, 21, 7, 14, 12, 14
]


## `text` (capital letters and spaces) as glyph ids; a space is GAP. Anything else is skipped.
static func encode(text: String) -> Array[int]:
	var out: Array[int] = []
	for i in text.length():
		var c := text.unicode_at(i)
		if c == 32:
			out.append(GAP)
		elif c >= 65 and c <= 90:
			out.append(LETTER_GLYPH[c - 65])
	return out


## Glyph ids back to text (the first letter in A..Z order that has the rune: Q reads K, X reads Z).
static func decode(glyphs: Array[int]) -> String:
	var s := ""
	for g in glyphs:
		if g == GAP:
			s += " "
		else:
			var at := LETTER_GLYPH.find(g)
			s += char(65 + at) if at >= 0 else "?"
	return s


## Glyph ids as rows of at most `width` glyphs, broken at gaps (a word longer than a row is cut). The gap that breaks
## a row is dropped; the others stay inside the row.
static func wrap(glyphs: Array[int], width: int = 14) -> Array:
	var rows: Array = []
	var row: Array[int] = []
	var word: Array[int] = []
	var all: Array[int] = glyphs.duplicate()
	all.append(GAP)  # the end closes the last word
	for g in all:
		if g != GAP:
			word.append(g)
			continue
		if row.size() > 0 and row.size() + 1 + word.size() > width:
			rows.append(row)
			row = []
		if row.size() > 0 and not word.is_empty():
			row.append(GAP)
		while word.size() > width:
			rows.append(word.slice(0, width))
			word = word.slice(width)
		row.append_array(word)
		word = []
	if row.size() > 0:
		rows.append(row)
	return rows
