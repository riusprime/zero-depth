class_name CodexIcon
extends Control
## v0.7.5 CX: one Codex entry's picture: a card's icon (ItemIcons, which falls through to the abilities' and the stat
## cards' symbols) in its colour, an enemy's or boss's emblem (CodexGlyphs), or a biome's landscape in its palette.
## A locked entry is the same shape as a dark silhouette. Draws only (EI-07).
## v0.10.5 W3-O19 (every UI element in Astral): a card with a painted icon (AstralCardArt, the cards' own) shows it,
## a dark silhouette while locked; the hostile and the lore colours are Astral's (no red, orange or ember).

## A locked entry's silhouette colour.
const SILHOUETTE := Color(0.17, 0.19, 0.24)

var entry := {}
var locked := true
## Shapes drawn the last time (tests).
var drawn := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_entry(p_entry: Dictionary, p_locked: bool) -> void:
	entry = p_entry
	locked = p_locked
	queue_redraw()


## The entry's colour when unlocked (a card's own colour, the hostile reds).
static func color_of(e: Dictionary) -> Color:
	var page: StringName = e.get("page", &"")
	if page == &"lore":  # v0.10.5 O18: not a hostile red (W3-O19: Astral's accent)
		return AstralCardArt.ACCENT
	if page == &"enemies":  # v0.10.5 W3-O19: Astral's muted rose
		return AstralCardArt.POOR
	if page == &"bosses":  # v0.10.5 W3-O19: the legendary pale gold
		return AstralCardArt.rarity(4)
	if page != &"cards":
		return CodexGlyphs.color(page)
	var id: StringName = e["id"]
	if int(e["type"]) != WorldReader.CARD_MOD:
		return AbilityIcons.color(id)
	var c := ItemLooks.color_of_id(id)
	if c == ItemLooks.FALLBACK:  # a card without its own colour wears its frame's (the wand cards' gems)
		c = CardFrames.tint(CardFrames.frame_of(CardFrames.family(id, int(e["type"]))))
	return c


func _draw() -> void:
	drawn = 0
	if entry.is_empty():
		return
	var r := Rect2(Vector2.ZERO, size)
	var page: StringName = entry["page"]
	var c := SILHOUETTE if locked else color_of(entry)
	match page:
		&"cards":
			if AstralCardArt.has_icon(entry["id"]):  # v0.10.5 W3-O19: the card's painted icon
				var s := minf(r.size.x, r.size.y) * 1.25
				var at := Rect2(r.get_center() - Vector2(s, s) * 0.5, Vector2(s, s))
				var tint := Color(SILHOUETTE, 1.0) if locked else Color.WHITE
				draw_texture_rect(AstralCardArt.icon(entry["id"]), at, false, tint)
				drawn = 1
			else:
				drawn = ItemIcons.draw(self, entry["id"], r, c)
		&"enemies":
			var shapes := CodexGlyphs.shapes(page, entry.get("behaviour", &""))
			drawn = CodexGlyphs.draw(self, shapes, r, c)
		&"bosses":
			drawn = CodexGlyphs.draw(self, CodexGlyphs.shapes(page, entry["id"]), r, c)
		&"lore":  # v0.10.5 O18: a carved rune diamond
			var m := r.get_center()
			var h := minf(r.size.x, r.size.y) * 0.42
			var w := h * 0.7
			var pts := PackedVector2Array(
				[m + Vector2(0, -h), m + Vector2(w, 0), m + Vector2(0, h), m + Vector2(-w, 0)]
			)
			pts.append(pts[0])
			draw_polyline(pts, c, 2.0, true)
			draw_line(m + Vector2(0, -h * 0.55), m + Vector2(0, h * 0.55), c, 2.0, true)
			draw_line(m + Vector2(-w * 0.5, -h * 0.1), m + Vector2(w * 0.5, h * 0.2), c, 2.0, true)
			drawn = 1
		&"biomes":
			CodexGlyphs.draw_biome(self, entry.get("palette", [] as Array[Color]), r, locked)
			drawn = 1
