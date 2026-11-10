class_name AstralCardArt
extends RefCounted
## The one
## file that loads the card art. The card icons (assets/ui/card_icons/icon_<card id>.png, cut from his sheets by
## scripts/art/split_sheets.py; a card without one shows icon_unknown), his four carved slate card frames and their
## focused twins (assets/ui/card_frames/frame_<1..4>[_focus].png, cut by scripts/art/cut_card_frames.py: each frame's
## body centred on one 400 x 520 canvas, so a frame and its twin line up), the pick dissolve's noise
## (assets/ui/fx/dissolve_noise.png), Astral's palette and its Cinzel titles. A card's frame is chosen by its id, the
## same every time. Presentation only (EI-07): nothing here changes an outcome.

const ICON_DIR := "res://assets/ui/card_icons/"
const FRAME_DIR := "res://assets/ui/card_frames/"
const BACK_DIR := "res://assets/ui/card_backs/"
const NOISE := "res://assets/ui/fx/dissolve_noise.png"
const UNKNOWN := &"unknown"
const CINZEL := "res://assets/fonts/cinzel/Cinzel-Variable.ttf"
const FRAMES := 4
## The Constellation cards' frame variant and their ids' prefix (Constellations.card_id).
const CONSTELLATION := 101
const CONSTELLATION_PREFIX := "const_"
## A Starbound card (an id starting STARBOUND_PREFIX) wears the owner's gold Starbound frame
## and back (frame_starbound.png, back_starbound.png, on the same canvas) as variant STARBOUND; it has no focused twin,
## so the game's own focus look (the lift, the glow, the light) shows the focus. Its moon-blue (V1, V3, the HUD row).
const STARBOUND := 5
const STARBOUND_PREFIX := "starbound_"
const STARBOUND_BLUE := Color("#8FB8E8")
## The frame canvas (px), the frame body's padding inside it (the focused glow's room) and the body's mean width.
const CANVAS := Vector2(400, 520)
const PAD := Vector2(44, 43)
const BODY_W := 312.0
## The 9-slice margins (canvas px): the padding plus the chamfered corners and their carved ornaments, which never
## stretch; only the plain slate between them does.
const MARGIN_X := 100
const MARGIN_Y := 104

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
static var _backs := {}
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
## A Constellation card (an id `const_<name>`, Constellations.card_id) wears the owner's violet
## Constellation frame and back (CONSTELLATION; one drawing each: its focus is the game's own look, owner).
static func variant_of(id: StringName) -> int:
	var s := String(id)
	if s.begins_with(CONSTELLATION_PREFIX):
		return CONSTELLATION
	if s.begins_with(STARBOUND_PREFIX):
		return STARBOUND
	var h := 0
	for i in s.length():
		h = (h * 31 + s.unicode_at(i)) % 100003
	return 1 + h % FRAMES


## Frame `variant` (1..4, or CONSTELLATION), focused or not.
static func frame(variant: int, focused: bool) -> Texture2D:
	if variant == STARBOUND:  # The gold frame, no focused twin
		if not _frames.has("frame_starbound"):
			_frames["frame_starbound"] = load(FRAME_DIR + "frame_starbound.png")
		return _frames["frame_starbound"]
	var key := "frame_%d%s" % [clampi(variant, 1, FRAMES), "_focus" if focused else ""]
	if variant == CONSTELLATION:
		key = "frame_constellation"
	if not _frames.has(key):
		_frames[key] = load(FRAME_DIR + key + ".png")
	return _frames[key]


## Card back `variant` (1..4, or CONSTELLATION), focused or not: on the frames' canvas, so a back
## and a front line up.
static func back(variant: int, focused: bool) -> Texture2D:
	if variant == STARBOUND:  # The gold back, no focused twin
		if not _backs.has("back_starbound"):
			_backs["back_starbound"] = load(BACK_DIR + "back_starbound.png")
		return _backs["back_starbound"]
	var key := "back_%d%s" % [clampi(variant, 1, FRAMES), "_focus" if focused else ""]
	if variant == CONSTELLATION:
		key = "back_constellation"
	if not _backs.has(key):
		_backs[key] = load(BACK_DIR + key + ".png")
	return _backs[key]


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
