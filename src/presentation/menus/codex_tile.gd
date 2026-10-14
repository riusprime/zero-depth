class_name CodexTile
extends Button
## v0.7.5 CX: one Codex entry in the page's grid; v0.8.0 MU (Ember stone, MenuStyle): a small carved stone tablet,
## its picture (CodexIcon) in a round socket with a glowing inlay ring and its name, the glowing groove at its foot,
## both in the card's colour (CardFrames) or the page's colour; the focused tile is ember-lit. A locked entry is a dark,
## unlit tablet with a silhouette named "???". It is a Button, so the keyboard, the mouse and the pad reach it through
## the focus.

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
var _tint := MenuStyle.EMBER


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
	name_label.add_theme_font_override("font", HudStyle.font(true))
	name_label.add_theme_font_size_override("font_size", NAME_SIZE)
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
	name_label.add_theme_color_override("font_color", MenuStyle.DIM if p_locked else MenuStyle.TEXT)
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
		return palette[3] if palette.size() > 3 else MenuStyle.EMBER  # its accent
	return CodexIcon.color_of(e)


func _style() -> void:
	var pattern := hash(entry.get("id", &"")) % 89
	var normal := MenuStyle.tile_slab(_tint, false, locked, pattern)
	var lit := MenuStyle.tile_slab(_tint, true, locked, pattern)
	var hover := MenuStyle.tile_slab(_tint, false, locked, pattern)
	hover.focus = 0.45
	hover.dim = 1.0
	var ring := Rect2(Vector2((SIZE.x - SOCKET) * 0.5, SOCKET_TOP), Vector2(SOCKET, SOCKET))
	for b: StoneBox in [normal, lit, hover]:
		b.ring = ring
		b.ring_color = Color(_tint, 0.35) if locked else _tint
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", lit)
	add_theme_stylebox_override("hover_pressed", lit)
	add_theme_stylebox_override("focus", lit)
