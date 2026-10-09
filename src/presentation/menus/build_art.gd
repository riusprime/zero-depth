class_name BuildArt
extends RefCounted
## The build picker's art (v0.6.1 R2b): the owner's title plaque, the two build card frames (Blade cyan, Gun amber)
## and the two weapon emblems, cropped by scripts/art/crop_build_art.py into assets/ui/build_picker/ (manifest.json
## lists each with its hash, size and dark panel). **This file is the one table to remap**: which frame and emblem a
## weapon wears, its accent colour, and where the game draws its own text inside the art. Presentation only (EI-07).

const DIR := "res://assets/ui/build_picker/"
## The frames' size in the PNGs (px), both the same.
const FRAME_SIZE := Vector2(695, 980)
const EMBLEM_SIZE := Vector2(812, 788)
const TITLE_SIZE := Vector2(1971, 499)
## The frames and the title plaque are drawn at these scales (art px → screen px at the 1920 x 1080 base).
const CARD_SCALE := 0.6
const TITLE_SCALE := 0.42
## Inside both frames' dark panel (frame px; the manifest's `panel` boxes enclose it): the emblem's square, then the
## text box (the name, a hairline, the description, the damage line).
const EMBLEM_BOX := Rect2(185, 236, 320, 320)
const TEXT_BOX := Rect2(165, 572, 359, 238)
## Inside the title plaque's dark panel (plaque px).
const TITLE_BOX := Rect2(330, 205, 1305, 183)

## BuildDefinition.Weapon → its art and accent (0 Blade, 1 Gun).
const WEAPON := {
	0: {"frame": "frame_blade", "emblem": "emblem_blade", "accent": Color("#8FE3FF")},
	1: {"frame": "frame_gun", "emblem": "emblem_gun", "accent": Color("#FFB85A")},
}
const TITLE := "title_plaque"

static var _cache := {}


static func path(piece: String) -> String:
	return DIR + piece + ".png"


static func texture(piece: String) -> Texture2D:
	if not _cache.has(piece):
		_cache[piece] = load(path(piece))
	return _cache[piece]


static func frame(weapon: int) -> Texture2D:
	return texture(_entry(weapon)["frame"])


static func emblem(weapon: int) -> Texture2D:
	return texture(_entry(weapon)["emblem"])


static func accent(weapon: int) -> Color:
	return _entry(weapon)["accent"]


static func title() -> Texture2D:
	return texture(TITLE)


static func _entry(weapon: int) -> Dictionary:
	return WEAPON.get(weapon, WEAPON[0])
