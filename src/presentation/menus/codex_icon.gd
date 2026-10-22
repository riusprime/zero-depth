class_name CodexIcon
extends Control
## v0.7.5 CX: one Codex entry's picture: a card's icon (ItemIcons, which falls through to the abilities' and the stat
## cards' symbols) in its colour, an enemy's or boss's emblem (CodexGlyphs), or a biome's landscape in its palette.
## A locked entry is the same shape as a dark silhouette. Draws only (EI-07).

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
			drawn = ItemIcons.draw(self, entry["id"], r, c)
		&"enemies":
			var shapes := CodexGlyphs.shapes(page, entry.get("behaviour", &""))
			drawn = CodexGlyphs.draw(self, shapes, r, c)
		&"bosses":
			drawn = CodexGlyphs.draw(self, CodexGlyphs.shapes(page, entry["id"]), r, c)
		&"biomes":
			CodexGlyphs.draw_biome(self, entry.get("palette", [] as Array[Color]), r, locked)
			drawn = 1
