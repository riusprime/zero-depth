class_name CurseLook
extends RefCounted
## How a curse reads on screen (v0.5.0 EV): one colour (a sick magenta, apart from every rarity and the shards'
## gold) and one line, its name and its sentence with the number, translated through the caller.

const COLOR := Color("#E0457B")


## "Swift Foes: Enemies move 15 % faster".
static func line(ci: Object, reader: WorldReader, c: int) -> String:
	return "%s: %s" % [ci.tr(reader.curse_name_key(c)), sentence(ci, reader, c)]


static func sentence(ci: Object, reader: WorldReader, c: int) -> String:
	return ci.tr(reader.curse_desc_key(c)) % str(reader.curse_value(c))
