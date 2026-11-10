class_name AchievementRow
extends Button
## v0.7.5 AC: one achievement on the Codex's Achievements page; v0.8.0 MU: a carved stone row (Ember stone),
## ember-lit when focused, an unlocked one with a gold rim inlay and groove: its glyph, its name and
## sentence, and on the right "Unlocked" or how far along it is ("37 / 100"). A locked one is dimmed with its
## sentence; a hidden locked one is "???" with the hidden line. A Button, so keys, the pad and the mouse reach it
## through the focus.

const SIZE := Vector2(792, 92)
const ICON := 56.0
const NAME_SIZE := 21
const DESC_SIZE := 17
const STATE_W := 150.0
## v0.10.5 W3-O19: Astral's legendary pale gold (was a warm gold).
const UNLOCKED := Color("#E2CB8E")

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
	AstralUi.caps(name_label, NAME_SIZE - 2, AstralCardArt.TEXT)  # v0.10.5 W3-O19: Cinzel
	desc_label.name = "Desc"
	AstralUi.body(desc_label, DESC_SIZE)
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
	name_label.add_theme_color_override(
		"font_color", AstralCardArt.TEXT if unlocked else AstralCardArt.DIM
	)
	desc_label.add_theme_color_override(
		"font_color", AstralCardArt.TEXT.lerp(AstralCardArt.DIM, 0.3) if unlocked else AstralUi.HINT
	)
	state_label.add_theme_color_override("font_color", UNLOCKED if unlocked else AstralUi.HINT)
	_style()


## v0.10.5 W3-O19: an Astral frame (AstralChrome.FrameBox), an unlocked one's in the pale gold, a locked one fainter.
func _style() -> void:
	var quiet := 1.0 if unlocked else 0.6
	var normal := AstralChrome.FrameBox.new(0.0, quiet)
	var lit := AstralChrome.FrameBox.new(1.0, quiet)
	var hover := AstralChrome.FrameBox.new(0.0, minf(1.0, quiet + 0.25))
	hover.rim = AstralCardArt.ACCENT
	if unlocked:
		normal.rim = Color(UNLOCKED, 0.7)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", lit)
	add_theme_stylebox_override("hover_pressed", lit)
	add_theme_stylebox_override("focus", lit)
