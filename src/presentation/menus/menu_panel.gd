class_name MenuPanel
extends Control
## A column of buttons; labels are translation keys (Controls auto-translate their text).
## v0.8.0 MU (owner O14, G2 "menu style B": Ember stone, MenuStyle): the column sits on the left, vertically centred,
## on a carved stone slab, over the blurred, ember-lit game or the menu's own ember scene (`add_backdrop`); a
## left-aligned title over a glowing groove, plain warm rows, the focused row an ember-lit slab with a small ember
## diamond beside it (EmberMarker), and small notes and key hints under the list.
## Keyboard, mouse and pad all work through the focus, as before.
## v0.10.5 W3-O18 (owner: "the rest of the UI ... should match the new style"): `astral` (the main menu, the pause
## menus, the run recap) draws it in Astral (AstralMenu) instead: no slab, the title in letter-spaced Cinzel after the
## sigil over a fading hairline, the rows AstralButtons (a star and a tapered streak mark the focused one), notes and
## hints in Atkinson under a second hairline, the game under Astral's cool ink.

var box := VBoxContainer.new()
## The notes and key hints under the list (not buttons, so `box` keeps the title and the rows only).
var footer := VBoxContainer.new()
var marker := EmberMarker.new()
## The stone slab the list sits on.
var slab := PanelContainer.new()
## v0.10.5 W3-O18: drawn in Astral (AstralMenu).
var astral := false
var _column := VBoxContainer.new()


func _init(p_astral: bool = false) -> void:
	astral = p_astral
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if astral:
		_init_astral()
		return
	MenuStyle.apply(self)
	slab.name = "Slab"
	slab.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	slab.offset_left = MenuStyle.LIST_LEFT - MenuStyle.SLAB_PAD.x
	slab.grow_vertical = Control.GROW_DIRECTION_BOTH
	var stone := MenuStyle.stone_panel(MenuStyle.SLAB_PAD, 21)
	stone.under = 0.5
	stone.cut = 22.0
	slab.add_theme_stylebox_override("panel", stone)
	add_child(slab)
	_column.name = "Column"
	_column.custom_minimum_size = Vector2(MenuStyle.LIST_W, 0)
	_column.add_theme_constant_override("separation", 26)
	slab.add_child(_column)
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(MenuStyle.LIST_W, 0)
	_column.add_child(box)
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 6)
	_column.add_child(footer)
	add_child(marker)


## v0.10.5 W3-O18: the Astral list: no slab, rows on a 56 px pitch, a hairline between the list and its notes.
func _init_astral() -> void:
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
	marker.visible = false
	add_child(marker)


## The backdrop behind the menu (MenuBackdrop: the blurred, ember-lit game, or with nothing behind the menu's own
## ember-lit stone scene); drawn under everything else.
func add_backdrop() -> MenuBackdrop:
	var b := MenuBackdrop.new()
	b.astral = astral  # v0.10.5 W3-O18
	add_child(b)
	move_child(b, 0)
	return b


func add_title(key: String) -> Label:
	if astral:  # v0.10.5 W3-O18: the sigil, the title in Cinzel, a fading hairline under it
		var head := AstralMenu.Title.new(AstralMenu.TITLE_SIZE, true)
		head.label.text = key
		box.add_child(head)
		box.add_child(AstralMenu.LeftRule.new(40.0))
		return head.label
	var l := Label.new()
	l.text = key
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_font_override("font", HudStyle.font(true))
	l.add_theme_font_size_override("font_size", MenuStyle.TITLE_SIZE)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_shadow_color", Color(MenuStyle.EMBER, 0.3))
	l.add_theme_constant_override("shadow_outline_size", 14)
	l.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(l)
	var groove := TitleGroove.new()
	groove.custom_minimum_size = Vector2(0, 20)
	box.add_child(groove)
	return l


func add_button(key: String, on_press: Callable) -> Button:
	if astral:  # v0.10.5 W3-O18
		var r := AstralButton.new(AstralButton.Kind.ROW, AstralMenu.LIST_W)
		r.text = key
		r.pressed.connect(on_press)
		box.add_child(r)
		return r
	var b := Button.new()
	b.text = key
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", MenuStyle.BUTTON_SIZE)
	b.pressed.connect(on_press)
	box.add_child(b)
	return b


## A small line under the list (a run summary); `text` is shown as given (callers pass tr()).
func add_note(text: String) -> Label:
	var l := Label.new()
	l.name = "Note"
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", MenuStyle.NOTE_SIZE)
	l.add_theme_color_override("font_color", MenuStyle.DIM)
	if astral:
		AstralMenu.body(l, AstralMenu.NOTE_SIZE, AstralCardArt.DIM)
	footer.add_child(l)
	return l


## The small key hint at the bottom of the list (a translation key).
func add_hint(key: String) -> Label:
	var l := MenuStyle.hint(key)
	if astral:
		AstralMenu.body(l, AstralMenu.NOTE_SIZE, Color(AstralCardArt.DIM, 0.75))
	footer.add_child(l)
	return l


func focus_first() -> void:
	for c in box.get_children():
		if c is Button:
			(c as Button).grab_focus()
			return


func _process(_delta: float) -> void:
	if astral:  # the rows mark their own focus
		return
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	marker.follow(f as Button if f is Button and box.is_ancestor_of(f) else null)


## The small ember diamond to the left of the focused row (decoration; it takes no input).
class EmberMarker:
	extends Control
	const SIZE := Vector2(14, 22)
	var target: Button

	func _init() -> void:
		name = "EmberMarker"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = SIZE
		visible = false

	func follow(b: Button) -> void:
		target = b
		visible = b != null and b.is_visible_in_tree()
		if visible:
			var r := b.get_global_rect()
			global_position = Vector2(r.position.x - SIZE.x - 8, r.get_center().y - SIZE.y * 0.5)

	func _draw() -> void:
		var c := SIZE * 0.5
		draw_circle(c, SIZE.y * 0.6, Color(MenuStyle.EMBER, 0.12))
		var pts := PackedVector2Array(
			[Vector2(c.x, 0), Vector2(SIZE.x, c.y), Vector2(c.x, SIZE.y), Vector2(0, c.y)]
		)
		draw_colored_polygon(pts, MenuStyle.EMBER)
		var lit := PackedVector2Array([Vector2(c.x, 0), Vector2(SIZE.x, c.y), Vector2(c.x, c.y)])
		draw_colored_polygon(lit, Color(1, 0.93, 0.8, 0.8))


## The glowing ember groove under a menu's title (decoration).
class TitleGroove:
	extends Control
	const W := 300.0
	## Centred under a centred title (the pick), else from the left edge.
	var centred := false

	func _init(p_centred: bool = false) -> void:
		name = "TitleGroove"
		centred = p_centred
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := minf(W, size.x)
		var x := (size.x - w) * 0.5 if centred else 0.0
		var y := size.y * 0.35
		draw_rect(Rect2(x, y - 4, w, 10), Color(MenuStyle.EMBER, 0.13))
		draw_rect(Rect2(x, y, w, 3), Color(MenuStyle.EMBER, 0.92))
		draw_line(Vector2(x, y + 4), Vector2(x + w, y + 4), Color(0, 0, 0, 0.45), 1.0)
