class_name RunicGlyphs
extends RefCounted
## v0.9.5 RS1 (RUNIC_STONE.md S4): the 24 Elder Futhark runes as line strokes (no font), in the Futhark's order (glyph
## id 0 = fehu ... 23 = othala; RuneCipher maps letters onto them). Each glyph is a list of polylines on a box 2 wide
## and 4 tall (x right, y down); the stem of a rune is x = 1 (or the box's sides). Reads nothing, draws nothing.

const W := 2.0
const H := 4.0
const NAMES: Array[String] = [
	"fehu",
	"uruz",
	"thurisaz",
	"ansuz",
	"raido",
	"kaunan",
	"gebo",
	"wunjo",
	"hagalaz",
	"nauthiz",
	"isa",
	"jera",
	"eihwaz",
	"perthro",
	"algiz",
	"sowilo",
	"tiwaz",
	"berkana",
	"ehwaz",
	"mannaz",
	"laguz",
	"ingwaz",
	"dagaz",
	"othala",
]

const _STEM := [Vector2(1, 0), Vector2(1, 4)]


static func strokes(glyph: int) -> Array:
	if glyph < 0 or glyph >= RuneCipher.GLYPHS:
		return []
	return _table()[glyph]


static func _p(pts: Array) -> PackedVector2Array:
	return PackedVector2Array(pts)


static func _table() -> Array:
	var stem := _p(_STEM)
	return [
		# 0 fehu
		[stem, _p([Vector2(1, 2), Vector2(2, 1)]), _p([Vector2(1, 1), Vector2(2, 0)])],
		# 1 uruz
		[_p([Vector2(0, 4), Vector2(0, 0), Vector2(1.8, 1.4), Vector2(1.8, 4)])],
		# 2 thurisaz
		[stem, _p([Vector2(1, 1), Vector2(2, 2), Vector2(1, 3)])],
		# 3 ansuz
		[stem, _p([Vector2(1, 0), Vector2(2, 1)]), _p([Vector2(1, 1.2), Vector2(2, 2.2)])],
		# 4 raido
		[stem, _p([Vector2(1, 0), Vector2(2, 1), Vector2(1, 2.2), Vector2(2, 4)])],
		# 5 kaunan
		[_p([Vector2(2, 1), Vector2(1, 2), Vector2(2, 3)])],
		# 6 gebo
		[_p([Vector2(0, 0), Vector2(2, 4)]), _p([Vector2(2, 0), Vector2(0, 4)])],
		# 7 wunjo
		[stem, _p([Vector2(1, 0), Vector2(2, 1), Vector2(1, 2)])],
		# 8 hagalaz
		[
			_p([Vector2(0, 0), Vector2(0, 4)]),
			_p([Vector2(2, 0), Vector2(2, 4)]),
			_p([Vector2(0, 1.2), Vector2(2, 2.8)])
		],
		# 9 nauthiz
		[stem, _p([Vector2(0, 1.2), Vector2(2, 2.8)])],
		# 10 isa
		[stem],
		# 11 jera
		[_p([Vector2(1, 0), Vector2(0, 1.4), Vector2(1, 2.4), Vector2(2, 3.2), Vector2(1, 4)])],
		# 12 eihwaz
		[stem, _p([Vector2(0, 1), Vector2(1, 0)]), _p([Vector2(1, 4), Vector2(2, 3)])],
		# 13 perthro
		[_p([Vector2(0, 4), Vector2(0, 0), Vector2(2, 1), Vector2(0, 2.4)])],
		# 14 algiz
		[stem, _p([Vector2(1, 2), Vector2(0, 0)]), _p([Vector2(1, 2), Vector2(2, 0)])],
		# 15 sowilo
		[_p([Vector2(2, 0), Vector2(0, 1.6), Vector2(2, 2.4), Vector2(0, 4)])],
		# 16 tiwaz
		[stem, _p([Vector2(0, 1.4), Vector2(1, 0), Vector2(2, 1.4)])],
		# 17 berkana
		[
			stem,
			_p([Vector2(1, 0), Vector2(2, 0.9), Vector2(1, 2)]),
			_p([Vector2(1, 2), Vector2(2, 3.1), Vector2(1, 4)])
		],
		# 18 ehwaz
		[
			_p([Vector2(0, 0), Vector2(0, 4)]),
			_p([Vector2(2, 0), Vector2(2, 4)]),
			_p([Vector2(0, 0), Vector2(1, 1.2), Vector2(2, 0)])
		],
		# 19 mannaz
		[
			_p([Vector2(0, 0), Vector2(0, 4)]),
			_p([Vector2(2, 0), Vector2(2, 4)]),
			_p([Vector2(0, 0), Vector2(1, 2), Vector2(2, 0)]),
			_p([Vector2(0, 4), Vector2(1, 2), Vector2(2, 4)])
		],
		# 20 laguz
		[stem, _p([Vector2(1, 0), Vector2(2, 1.4)])],
		# 21 ingwaz
		[_p([Vector2(1, 0), Vector2(2, 2), Vector2(1, 4), Vector2(0, 2), Vector2(1, 0)])],
		# 22 dagaz
		[_p([Vector2(0, 0), Vector2(2, 4), Vector2(2, 0), Vector2(0, 4), Vector2(0, 0)])],
		# 23 othala
		[
			_p([Vector2(1, 0), Vector2(2, 1.4), Vector2(1, 2.4), Vector2(0, 1.4), Vector2(1, 0)]),
			_p([Vector2(1, 2.4), Vector2(0, 4)]),
			_p([Vector2(1, 2.4), Vector2(2, 4)])
		],
	]
