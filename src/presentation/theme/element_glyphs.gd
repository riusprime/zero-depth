class_name ElementGlyphs
extends RefCounted
## v0.8.0 TX3: the owner's element glyphs (docs/art/requests/v0.8.0_textures.md, `ui_element_glyphs` and
## `ui_element_glyphs_2`; scripts/assets/tx3_prep.py): eight glyphs carved in stone and glowing, four to a 2 x 2 sheet.
## A card whose modifier names an element (ModifierOpDefinition.ELEMENTS: an ELEMENT op) wears its element's glyph
## set into its socket's inlay ring (InlaySocket), so the element reads by shape as well as by the ring's colour.
## ELEMENT_OF is the card → element table (as CardFrames.FAMILY_OF; an ELEMENT op inside a HOOK op's hook_ops
## counts); tests/unit/presentation/test_element_glyphs.gd fails when a content card's ELEMENT op is missing here or
## disagrees, so a new elemental card gets its glyph on purpose. v0.8.0 N1 (owner O54, D42 "(a)"): the two spare
## glyphs got their meanings: the star burst on a Legendary card (LEGENDARY: the items of rarity LEGENDARY; the reward
## pick's legendary tier too, StoneCard), over its element; the crossed blades on a Blade card with no element
## (BLADE_PLAIN: the items that require the Blade and name no element). glyph_of picks the one a card wears; the
## same test keeps both lists in step with the content. Without the sheets nothing is drawn (the ring's colour
## alone, the look before TX3).
## Presentation only (EI-07).

const SHEETS := [
	"res://assets/textures/ui/ui_element_glyphs.png",
	"res://assets/textures/ui/ui_element_glyphs_2.png",
]
## Glyph → [sheet, cell (column, row)]. The sheets' quarters as the owner painted them.
const CELLS := {
	&"ember": [0, Vector2i(0, 0)],  # a flame
	&"frost": [0, Vector2i(1, 0)],  # a snowflake
	&"storm": [0, Vector2i(0, 1)],  # a lightning bolt
	&"venom": [0, Vector2i(1, 1)],  # a venom drop
	&"void": [1, Vector2i(0, 0)],  # a void spiral
	&"bleed": [1, Vector2i(1, 0)],  # a blood drop
	&"blades": [1, Vector2i(0, 1)],  # crossed blades: a Blade card with no element (N1, D42)
	&"star": [1, Vector2i(1, 1)],  # a star burst: a Legendary card (N1, D42)
}
## Every card whose modifier names an element → that element (the first ELEMENT op's).
const ELEMENT_OF := {
	&"barbed_bolts": &"bleed",
	&"chain_blast": &"ember",
	&"cinder_shot": &"ember",
	&"conductor": &"storm",
	&"ember_core": &"ember",
	&"ember_edge": &"ember",
	&"ember_trail": &"ember",
	&"frost_core": &"frost",
	&"frost_nova": &"frost",
	&"glacial_edge": &"frost",
	&"gravity_well": &"void",
	&"gun_ring": &"storm",
	&"inferno_core": &"ember",
	&"phase_dash": &"void",
	&"razor_orbit": &"bleed",
	&"serrated_edge": &"bleed",
	&"shared_bleed": &"bleed",
	&"shared_explosive": &"ember",
	&"shock_circles": &"storm",
	&"static_chain": &"storm",
	&"storm_core": &"storm",
	&"tempest_core": &"storm",
	&"venom_core": &"venom",
}

## v0.8.0 N1 (D42): the Legendary cards (ItemDefinition.Rarity.LEGENDARY); they wear the star burst.
const LEGENDARY := {
	&"chain_blast": true,
	&"echo_storm": true,
	&"inferno_core": true,
	&"tempest_core": true,
	&"trigger_on_end_twice": true,
	&"trigger_on_hit_twice": true,
	&"trigger_on_kill_twice": true,
}
## v0.8.0 N1 (D42): the Blade cards (requires_weapon blade) that name no element and aren't Legendary; they wear the
## crossed blades.
const BLADE_PLAIN := {
	&"blade_orbit": true,
	&"blade_storm": true,
	&"bulwark": true,
	&"chain_cut": true,
	&"counter": true,
	&"double_slash": true,
	&"echo_slash": true,
	&"finisher_plus": true,
	&"fissure": true,
	&"flurry": true,
	&"heavy": true,
	&"long_edge": true,
	&"long_shadow": true,
	&"lunge_step": true,
	&"momentum": true,
	&"overcharge": true,
	&"parry_edge": true,
	&"rearguard": true,
	&"riposte_chain": true,
	&"seeker": true,
	&"split_wave": true,
	&"thrust": true,
	&"twin_arc": true,
	&"twin_cast": true,
	&"whirl": true,
	&"wide_arc": true,
}

static var _sheets: Array = []


## The element card `id` wears (&"" for none).
static func element_of(id: StringName) -> StringName:
	return ELEMENT_OF.get(id, &"")


## v0.8.0 N1 (D42): the glyph card `id` wears: the star burst on a Legendary card, else its element's, else the
## crossed blades on a plain Blade card (&"" for none).
static func glyph_of(id: StringName) -> StringName:
	if LEGENDARY.has(id):
		return &"star"
	var e := element_of(id)
	if e != &"":
		return e
	return &"blades" if BLADE_PLAIN.has(id) else &""


## A glyph's sheet and its region on it ([Texture2D, Rect2]); [] when the glyph or its sheet is missing.
static func region(glyph: StringName) -> Array:
	if not CELLS.has(glyph):
		return []
	if _sheets.is_empty():
		for path: String in SHEETS:
			_sheets.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
	var cell: Array = CELLS[glyph]
	var tex: Texture2D = _sheets[int(cell[0])]
	if tex == null:
		return []
	var half := tex.get_size() * 0.5
	var at: Vector2i = cell[1]
	return [tex, Rect2(Vector2(at) * half, half)]


## Draws `glyph` into `rect` on `ci` (a CanvasItem's draw); false when it is not installed.
static func draw(ci: CanvasItem, glyph: StringName, rect: Rect2, modulate := Color.WHITE) -> bool:
	var r := region(glyph)
	if r.is_empty():
		return false
	ci.draw_texture_rect_region(r[0], rect, r[1], modulate)
	return true
