class_name AchievementRow
extends Button
## v0.7.5 AC: one achievement on the Codex's Achievements page; v0.8.0 MU: a carved stone row (Ember stone, MenuStyle),
## ember-lit when focused, an unlocked one with a gold rim inlay and groove: its glyph, its name and
## sentence, and on the right "Unlocked" or how far along it is ("37 / 100"). A locked one is dimmed with its
## sentence; a hidden locked one is "???" with the hidden line. A Button, so keys, the pad and the mouse reach it
## through the focus.

const SIZE := Vector2(792, 92)
const ICON := 56.0
const NAME_SIZE := 21
const DESC_SIZE := 17
const STATE_W := 150.0
const UNLOCKED := Color("#F2C46A")

var entry := {}
var unlocked := false
var hidden_locked := false
var picture := AchievementIcon.new()
var name_label := Label.new()
var desc_label := Label.new()
var state_label := Label.new()


func _init() -> void:
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_top = 8
	row.offset_bottom = -8
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	picture.custom_minimum_size = Vector2(ICON, ICON)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(picture)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	name_label.name = "Name"
	name_label.add_theme_font_override("font", HudStyle.font(true))
	name_label.add_theme_font_size_override("font_size", NAME_SIZE)
	desc_label.name = "Desc"
	desc_label.add_theme_font_size_override("font_size", DESC_SIZE)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.max_lines_visible = 2
	for l: Label in [name_label, desc_label]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size = Vector2(text_width(), 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(l)
	state_label.name = "State"
	state_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.custom_minimum_size = Vector2(STATE_W, 0)
	state_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.add_theme_font_size_override("font_size", DESC_SIZE)
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(state_label)
	mouse_entered.connect(func() -> void: grab_focus())


## The width the name and the sentence have (the row less the picture, the state and the gaps).
static func text_width() -> float:
	return SIZE.x - 28.0 - ICON - STATE_W - 28.0


## Shows achievement `a` (AchievementBook) of `book`.
func show_entry(a: Dictionary, book: AchievementBook) -> void:
	entry = a
	name = "Ach_%s" % a["id"]
	unlocked = book.is_unlocked(a["id"])
	hidden_locked = bool(a["hidden"]) and not unlocked
	picture.show_glyph(a["glyph"], unlocked, hidden_locked)
	name_label.text = "???" if hidden_locked else AchievementsPage.title_of(self, a)
	desc_label.text = tr("UI_ACH_HIDDEN") if hidden_locked else AchievementsPage.desc_of(self, a)
	if unlocked:
		state_label.text = tr("UI_ACH_UNLOCKED")
	elif hidden_locked or book.goal(a) <= 1:
		state_label.text = tr("UI_ACH_LOCKED")
	else:
		state_label.text = "%d / %d" % [book.progress(a), book.goal(a)]
	name_label.add_theme_color_override("font_color", MenuStyle.TEXT if unlocked else MenuStyle.DIM)
	desc_label.add_theme_color_override(
		"font_color", MenuStyle.TEXT.lerp(MenuStyle.DIM, 0.3) if unlocked else MenuStyle.HINT
	)
	state_label.add_theme_color_override("font_color", UNLOCKED if unlocked else MenuStyle.HINT)
	_style()


func _style() -> void:
	var tint := UNLOCKED if unlocked else Color(MenuStyle.DIM, 0.5)
	var pattern := hash(entry.get("id", &"")) % 83
	var normal := MenuStyle.tile_slab(tint, false, not unlocked, pattern)
	var lit := MenuStyle.tile_slab(tint, true, not unlocked, pattern)
	var hover := MenuStyle.tile_slab(tint, false, not unlocked, pattern)
	hover.focus = 0.45
	hover.dim = 1.0
	for b: StoneBox in [normal, lit, hover]:
		b.cut = 12.0
		b.rim = Color(EmberStone.GOLD, 0.7) if unlocked else Color(0, 0, 0, 0)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", lit)
	add_theme_stylebox_override("hover_pressed", lit)
	add_theme_stylebox_override("focus", lit)
