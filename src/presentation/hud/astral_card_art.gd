class_name AstralCardArt
extends RefCounted
## v0.10.5 W3-O15 (owner 2026-11-04: UI style Astral, W3_O13_UI_STYLE_G2.md round 2; his painted card art): the one
## file that loads the card art. The card icons (assets/ui/card_icons/icon_<card id>.png, cut from his sheets by
## scripts/art/split_sheets.py; a card without one shows icon_unknown), his four carved slate card frames and their
## focused twins (assets/ui/card_frames/frame_<1..4>[_focus].png, cut by scripts/art/cut_card_frames.py: each frame's
## body centred on one 360 x 480 canvas, so a frame and its twin line up), the pick dissolve's noise
## (assets/ui/fx/dissolve_noise.png), Astral's palette and its Cinzel titles. A card's frame is chosen by its id, the
## same every time. Presentation only (EI-07): nothing here changes an outcome.

const ICON_DIR := "res://assets/ui/card_icons/"
const FRAME_DIR := "res://assets/ui/card_frames/"
const NOISE := "res://assets/ui/fx/dissolve_noise.png"
const UNKNOWN := &"unknown"
const CINZEL := "res://assets/fonts/cinzel/Cinzel-Variable.ttf"
const FRAMES := 4
## The frame canvas (px), the frame body's padding inside it (the focused glow's room) and the body's mean width.
const CANVAS := Vector2(360, 480)
const PAD := Vector2(24, 23)
const BODY_W := 312.0
## The 9-slice margins (canvas px): the padding plus the chamfered corners and their carved ornaments, which never
## stretch; only the plain slate between them does.
const MARGIN_X := 80
const MARGIN_Y := 84

## Astral's tokens (W3_O13_UI_STYLE_G2.md, Astral).
const TEXT := Color("#ECEEFA")
const DIM := Color("#9095B4")
const LINE := Color("#6E76A0")
const LINE_HI := Color("#E4E6FF")
const ACCENT := Color("#B5BDF0")
const METAL := Color("#C9CCE6")
const POOR := Color("#D88A9A")
## The rarity line's colours by tier (PickSlot.TIERS order: common, rare, epic, ability, legendary).
const RARITY: Array[Color] = [
	Color("#8C98A8"), Color("#8FB8E8"), Color("#B4A2E6"), Color("#C9D8EE"), Color("#E2CB8E")
]
## The pick dissolve's glare: a thin moon-blue / silver edge.
const GLARE := Color("#DCE4FF")
const GLARE_BLUE := Color("#9FB4F2")

static var _icons := {}
static var _frames := {}
static var _noise: Texture2D
static var _cinzel: FontFile
static var _serif := {}


## Card `id`'s icon, or the fallback icon_unknown when it has none.
static func icon(id: StringName) -> Texture2D:
	var key := id if id != &"" else UNKNOWN
	if _icons.has(key):
		return _icons[key]
	var path := ICON_DIR + "icon_%s.png" % key
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif key != UNKNOWN:
		tex = icon(UNKNOWN)
	_icons[key] = tex
	return tex


## Whether card `id` has its own icon (not the fallback).
static func has_icon(id: StringName) -> bool:
	return id != &"" and ResourceLoader.exists(ICON_DIR + "icon_%s.png" % id)


## Which of the four frames card `id` wears (1..4): the same for an id every time (a sum of its characters).
static func variant_of(id: StringName) -> int:
	var s := String(id)
	var h := 0
	for i in s.length():
		h = (h * 31 + s.unicode_at(i)) % 100003
	return 1 + h % FRAMES


## Frame `variant` (1..4), focused or not.
static func frame(variant: int, focused: bool) -> Texture2D:
	var key := "frame_%d%s" % [clampi(variant, 1, FRAMES), "_focus" if focused else ""]
	if not _frames.has(key):
		_frames[key] = load(FRAME_DIR + key + ".png")
	return _frames[key]


static func noise() -> Texture2D:
	if _noise == null:
		_noise = load(NOISE)
	return _noise


## Cinzel at weight `wght` with `track` px between letters (Astral's titles).
static func serif(wght: int = 600, track: int = 1) -> FontVariation:
	var key := "%d_%d" % [wght, track]
	if _serif.has(key):
		return _serif[key]
	if _cinzel == null:
		_cinzel = load(CINZEL)
	var v := FontVariation.new()
	v.base_font = _cinzel
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): wght}
	v.spacing_glyph = track
	_serif[key] = v
	return v


static func rarity(tier: int) -> Color:
	return RARITY[clampi(tier, 0, RARITY.size() - 1)]
