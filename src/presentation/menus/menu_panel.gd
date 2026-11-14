class_name MenuPanel
extends Control
## A column of buttons; labels are translation keys (Controls auto-translate their text).
## v0.10.5 W3-O18 (owner: "the rest of the UI ... should match the new style"), in Astral (AstralMenu): the column on
## the left, vertically centred, no slab; the title in letter-spaced Cinzel after the sigil over a fading hairline, the
## rows AstralButtons (a star and a tapered streak mark the focused one), notes and hints in Atkinson under a second
## hairline, the game under Astral's cool ink (`add_backdrop`). Keyboard, mouse and pad all work through the focus.
## v0.11.1 Step 13 (owner 2026-11-10: "Astral current one live should be the only HUD style for all elements
## throughout the game"): every menu is drawn so; the Ember stone look (its theme, the slab, the ember marker) is gone.

var box := VBoxContainer.new()
## The notes and key hints under the list (not buttons, so `box` keeps the title and the rows only).
var footer := VBoxContainer.new()
## The open panel the list sits in (no box drawn: Astral's lists are unboxed).
var slab := PanelContainer.new()
var _column := VBoxContainer.new()


## The Astral list: no slab, rows on a 56 px pitch, a hairline between the list and its notes.
func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AstralMenu.apply(self)
	slab.name = "Slab"
	slab.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	var open := StyleBoxEmpty.new()
	open.content_margin_top = 32
	open.content_margin_bottom = 32
	slab.add_theme_stylebox_override("panel", open)
	slab.offset_left = AstralMenu.LEFT
	slab.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(slab)
	_column.name = "Column"
	_column.custom_minimum_size = Vector2(AstralMenu.LIST_W, 0)
	_column.add_theme_constant_override("separation", 16)
	slab.add_child(_column)
	box.add_theme_constant_override("separation", 0)
	box.custom_minimum_size = Vector2(AstralMenu.LIST_W, 0)
	_column.add_child(box)
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 8)
	footer.add_child(AstralMenu.LeftRule.new(24.0, 0.35))
	_column.add_child(footer)


## The backdrop behind the menu (MenuBackdrop: the blurred game under Astral's cool ink, or with nothing behind
## Astral's own night); drawn under everything else.
func add_backdrop() -> MenuBackdrop:
	var b := MenuBackdrop.new()
	b.astral = true
	add_child(b)
	move_child(b, 0)
	return b


## The sigil, the title in Cinzel, a fading hairline under it.
func add_title(key: String) -> Label:
	var head := AstralMenu.Title.new(AstralMenu.TITLE_SIZE, true)
	head.label.text = key
	box.add_child(head)
	box.add_child(AstralMenu.LeftRule.new(40.0))
	return head.label


func add_button(key: String, on_press: Callable) -> Button:
	var r := AstralButton.new(AstralButton.Kind.ROW, AstralMenu.LIST_W)
	r.text = key
	r.pressed.connect(on_press)
	box.add_child(r)
	return r


## A small line under the list (a run summary); `text` is shown as given (callers pass tr()).
func add_note(text: String) -> Label:
	var l := Label.new()
	l.name = "Note"
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	AstralMenu.body(l, AstralMenu.NOTE_SIZE, AstralCardArt.DIM)
	footer.add_child(l)
	return l


## The small key hint at the bottom of the list (a translation key).
func add_hint(key: String) -> Label:
	var l := Label.new()
	l.name = "Hint"
	l.text = key
	AstralMenu.body(l, AstralMenu.NOTE_SIZE, Color(AstralCardArt.DIM, 0.75))
	footer.add_child(l)
	return l


func focus_first() -> void:
	for c in box.get_children():
		if c is Button:
			(c as Button).grab_focus()
			return
