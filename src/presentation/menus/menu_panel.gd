class_name MenuPanel
extends Control
## A column of buttons; labels are translation keys (Controls auto-translate their text).
## v0.5.5 A5 (owner pick C "Cold glass", MenuStyle): the column sits on the left, vertically centred, over the
## blurred and dimmed game (`add_backdrop`); a left-aligned title, plain-type rows, the focused row lit by the glass
## highlight with a small glass diamond beside it (GlassMarker), and small notes and key hints under the list.
## Keyboard, mouse and pad all work through the focus, as before.

var box := VBoxContainer.new()
## The notes and key hints under the list (not buttons, so `box` keeps the title and the rows only).
var footer := VBoxContainer.new()
var marker := GlassMarker.new()
var _column := VBoxContainer.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuStyle.apply(self)
	_column.name = "Column"
	_column.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_column.offset_left = MenuStyle.LIST_LEFT
	_column.grow_vertical = Control.GROW_DIRECTION_BOTH
	_column.custom_minimum_size = Vector2(MenuStyle.LIST_W, 0)
	_column.add_theme_constant_override("separation", 26)
	add_child(_column)
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(MenuStyle.LIST_W, 0)
	_column.add_child(box)
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 6)
	_column.add_child(footer)
	add_child(marker)


## The blurred, dimmed game behind the menu (pause, the run recap); drawn under everything else.
func add_backdrop() -> MenuBackdrop:
	var b := MenuBackdrop.new()
	add_child(b)
	move_child(b, 0)
	return b


func add_title(key: String) -> Label:
	var l := Label.new()
	l.text = key
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_font_override("font", HudStyle.font(true))
	l.add_theme_font_size_override("font_size", MenuStyle.TITLE_SIZE)
	l.add_theme_constant_override("outline_size", 6)
	box.add_child(l)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)
	return l


func add_button(key: String, on_press: Callable) -> Button:
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
	footer.add_child(l)
	return l


## The small key hint at the bottom of the list (a translation key).
func add_hint(key: String) -> Label:
	var l := MenuStyle.hint(key)
	footer.add_child(l)
	return l


func focus_first() -> void:
	for c in box.get_children():
		if c is Button:
			(c as Button).grab_focus()
			return


func _process(_delta: float) -> void:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	marker.follow(f as Button if f is Button and box.is_ancestor_of(f) else null)


## The small glass diamond to the left of the focused row (decoration; it takes no input).
class GlassMarker:
	extends Control
	const SIZE := Vector2(12, 20)
	var target: Button

	func _init() -> void:
		name = "GlassMarker"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = SIZE
		visible = false

	func follow(b: Button) -> void:
		target = b
		visible = b != null and b.is_visible_in_tree()
		if visible:
			var r := b.get_global_rect()
			global_position = Vector2(r.position.x - SIZE.x - 10, r.get_center().y - SIZE.y * 0.5)

	func _draw() -> void:
		var c := SIZE * 0.5
		var pts := PackedVector2Array(
			[Vector2(c.x, 0), Vector2(SIZE.x, c.y), Vector2(c.x, SIZE.y), Vector2(0, c.y)]
		)
		draw_colored_polygon(pts, Color(MenuStyle.GLASS, 0.9))
		var lit := PackedVector2Array([Vector2(c.x, 0), Vector2(SIZE.x, c.y), Vector2(c.x, c.y)])
		draw_colored_polygon(lit, Color(1, 1, 1, 0.55))
