class_name CurseLook
extends RefCounted
## How a curse reads on screen (v0.5.0 EV): one colour (a sick magenta, apart from every rarity and the shards'
## gold) and one line, its name and its sentence with the number, translated through the caller. v0.6.0 CU: a
## trade-off curse's line adds its upside after a dot ("Rooted: You can't dash · 25 % chance to dodge a hit"); the
## cursed chest card shows the upside on its face and the drawback (down_line) under it.

const COLOR := Color("#E0457B")


## "Swift Foes: Enemies move 15 % faster" (a trade-off: "Name: drawback · upside").
static func line(ci: Object, reader: WorldReader, c: int) -> String:
	var out := down_line(ci, reader, c)
	if reader.curse_is_trade_off(c):
		out += " · " + up_sentence(ci, reader, c)
	return out


## "Name: drawback" (the cursed chest card's line under the card).
static func down_line(ci: Object, reader: WorldReader, c: int) -> String:
	return "%s: %s" % [ci.tr(reader.curse_name_key(c)), sentence(ci, reader, c)]


static func sentence(ci: Object, reader: WorldReader, c: int) -> String:
	return fill(ci.tr(reader.curse_desc_key(c)), reader.curse_value_text(c))


## A trade-off curse's upside sentence ("" for a plain curse).
static func up_sentence(ci: Object, reader: WorldReader, c: int) -> String:
	if not reader.curse_is_trade_off(c):
		return ""
	return fill(ci.tr(reader.curse_up_desc_key(c)), reader.curse_up_value_text(c))


## `text` with its one %s filled by `value` (an on/off sentence has none and stays as it is).
static func fill(text: String, value: String) -> String:
	return text % value if text.contains("%s") else text
