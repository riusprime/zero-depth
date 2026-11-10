class_name CodexTile
extends Button
## One Codex entry in the page's grid; Ember stone: a small carved stone tablet,
## its picture (CodexIcon) in a round socket with a glowing inlay ring and its name, the glowing groove at its foot,
## both in the card's colour (CardFrames) or the page's colour; the focused tile is ember-lit. A locked entry is a dark,
## unlit tablet with a silhouette named "???". It is a Button, so the keyboard, the mouse and the pad reach it through
## the focus.
## An Astral tile (AstralUi.TileBox: a 1 px frame,
## an inner frame 6 px in, a medallion ring with a dotted inner ring round the picture; focus: the frame and the ring
## brighten, a second frame 6 px outside, four small stars round the ring); a locked one drawn fainter. Its name in
## Astral's type.

const SIZE := Vector2(116, 128)
const ICON := 46.0
## The picture's socket (its glowing inlay ring in the entry's colour), round the picture.
const SOCKET := 64.0
const SOCKET_TOP := 6.0
const NAME_SIZE := 14

var entry := {}
var locked := true
var picture := CodexIcon.new()
var name_label := Label.new()
var _tint := AstralCardArt.ACCENT


func _init() -> void:
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = SOCKET_TOP + (SOCKET - ICON) * 0.5
	box.offset_left = 6
	box.offset_right = -6
	box.offset_bottom = -6
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	picture.custom_minimum_size = Vector2(ICON, ICON)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(picture)
	name_label.name = "Name"
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.custom_minimum_size = Vector2(SIZE.x - 12, 0)
	AstralUi.body(name_label, NAME_SIZE)  # v0.10.5 W3-O19
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	mouse_entered.connect(func() -> void: grab_focus())


## Shows `p_entry` (CodexCatalog), its name already translated, locked or not.
func show_entry(p_entry: Dictionary, title: String, p_locked: bool) -> void:
	entry = p_entry
	locked = p_locked
	name = "Tile_%s" % p_entry["id"]
	picture.show_entry(p_entry, p_locked)
	name_label.text = "???" if p_locked else title
	TextFit.fit_label_words(name_label, SIZE.x - 12.0, NAME_SIZE)  # A long word shrinks
	name_label.add_theme_color_override(
		"font_color", AstralCardArt.DIM if p_locked else AstralCardArt.TEXT
	)
	_tint = tint_of(p_entry)
	_style()


## The tile's groove colour: a card's colour (CardFrames), else the entry's colour.
static func tint_of(e: Dictionary) -> Color:
	if e.get("page", &"") == &"cards":
		var fam := CardFrames.family(e["id"], int(e["type"]))
		if e.get("section", &"") == &"legendary":
			return CardFrames.LEGENDARY_TINT
		return CardFrames.tint(CardFrames.frame_of(fam))
	if e.get("page", &"") == &"biomes":
		var palette: Array = e.get("palette", [])
		return palette[3] if palette.size() > 3 else AstralCardArt.ACCENT  # its accent
	return CodexIcon.color_of(e)


## Astral tiles; the ring in Astral's line (no family colour: the picture keeps its own).
func _style() -> void:
	var quiet := 0.55 if locked else 1.0
	var normal := AstralUi.TileBox.new(0.0, quiet)
	var lit := AstralUi.TileBox.new(1.0, quiet)
	var hover := AstralUi.TileBox.new(0.0, minf(1.0, quiet + 0.25))
	hover.rim = AstralCardArt.ACCENT
	var ring := Rect2(Vector2((SIZE.x - SOCKET) * 0.5, SOCKET_TOP), Vector2(SOCKET, SOCKET))
	for b: AstralUi.TileBox in [normal, lit, hover]:
		b.ring = ring
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", lit)
	add_theme_stylebox_override("hover_pressed", lit)
	add_theme_stylebox_override("focus", lit)
