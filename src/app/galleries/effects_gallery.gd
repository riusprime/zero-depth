class_name EffectsGallery
extends Control
## v0.10.5 W3-O12 (owner, 2026-11-04; docs/roadmap/v0.10.5/W3_O12_VFX_GALLERY.md): the Effects gallery, a dev tool
## (debug builds: the master dev panel's Effects button, next to Galleries). Every effect in the game and every unused
## pack effect (EffectsCatalog), each playing live in its own stage (EffectStage), labelled with its name, its source
## and where the game uses it.
## - One entry: Left / Right (keys, the pad's d-pad) the previous / next entry; Up / Down the previous / next group;
##   G (pad Y) a grid of the group, a page at a time (Left / Right the pages; a click opens a cell); Esc (pad B) back.
##   The buttons at the bottom do the same with the mouse.
## - Sheets (`sheets`): scripts/shots/vfx_gallery.gd shows each group's grid pages in turn and saves each page.

signal back_pressed

## Cells per grid page: [columns, rows] for the sim groups (a game view each) and the pack groups.
const GRID_SIM := Vector2i(3, 3)
const GRID_PACK := Vector2i(4, 3)

var catalog: EffectsCatalog
var group := 0
var index := 0
var grid := false
var page := 0
var stages: Array[EffectStage] = []
var _area := Control.new()
var _head := Label.new()
var _title := Label.new()
var _info := Label.new()
var _seen := Label.new()
var _hint := Label.new()
var _seen_wait := 0.0


func _init(p_catalog: EffectsCatalog = null) -> void:
	name = "EffectsGallery"
	catalog = p_catalog
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12
	col.offset_top = 8
	col.offset_right = -12
	col.offset_bottom = -8
	add_child(col)
	for l: Label in [_head, _title, _info, _seen]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.clip_text = true
		col.add_child(l)
	_head.add_theme_color_override("font_color", Color(0.75, 0.8, 1.0))
	_title.add_theme_font_size_override("font_size", 22)
	_info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_seen.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_area.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_area)
	var bar := HBoxContainer.new()
	col.add_child(bar)
	for spec: Array in [
		["PrevGroup", "UI_FXG_PREV_GROUP", prev_group],
		["Prev", "UI_FXG_PREV", prev],
		["Next", "UI_FXG_NEXT", next],
		["NextGroup", "UI_FXG_NEXT_GROUP", next_group],
		["Grid", "UI_FXG_GRID", toggle_grid],
		["Back", "UI_FXG_BACK", func() -> void: back_pressed.emit()],
	]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.focus_mode = Control.FOCUS_NONE  # (the arrows page the gallery, not the buttons' focus)
		b.pressed.connect(spec[2])
		bar.add_child(b)
	_hint.text = "UI_FXG_HINT"
	_hint.modulate = Color(1, 1, 1, 0.6)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_hint)


## The master dev panel's Effects button (Main): the run, the hub and the panel close, the gallery opens as the
## menu; Back returns to the main menu.
static func open(main: Main) -> void:
	main._close_master_panel()
	main._end_stage()
	main._end_hub()
	var g := EffectsGallery.new()
	g.back_pressed.connect(main.show_main_menu)
	main._set_menu(g)


func _ready() -> void:
	if catalog == null:
		catalog = EffectsCatalog.build()
	show_current()


func entries() -> Array[Dictionary]:
	return catalog.in_group(EffectsCatalog.GROUPS[group])


func group_id() -> StringName:
	return EffectsCatalog.GROUPS[group]


func page_size() -> int:
	var g := grid_shape()
	return g.x * g.y


func grid_shape() -> Vector2i:
	return GRID_PACK if group_id() in [&"pack_used", &"pack_unused"] else GRID_SIM


func pages() -> int:
	return maxi(1, ceili(float(entries().size()) / page_size()))


func next() -> void:
	if grid:
		page = (page + 1) % pages()
	else:
		index = (index + 1) % maxi(1, entries().size())
	show_current()


func prev() -> void:
	if grid:
		page = (page + pages() - 1) % pages()
	else:
		index = (index + maxi(1, entries().size()) - 1) % maxi(1, entries().size())
	show_current()


func next_group() -> void:
	set_group((group + 1) % EffectsCatalog.GROUPS.size())


func prev_group() -> void:
	set_group((group + EffectsCatalog.GROUPS.size() - 1) % EffectsCatalog.GROUPS.size())


func set_group(g: int) -> void:
	group = g
	index = 0
	page = 0
	show_current()


func toggle_grid() -> void:
	grid = not grid
	page = index / page_size()
	show_current()


## Opens grid cell `n` of the page as the one entry.
func open_cell(n: int) -> void:
	index = clampi(page * page_size() + n, 0, maxi(0, entries().size() - 1))
	grid = false
	show_current()


## Rebuilds the stages for what is chosen now (one entry, or a grid page) and the labels.
func show_current() -> void:
	for s in stages:
		s.queue_free()
	stages.clear()
	for c in _area.get_children():
		c.queue_free()
	var list := entries()
	var gname := tr(EffectsCatalog.GROUP_KEYS[group_id()])
	_seen.text = ""
	for l: Label in [_title, _info, _seen]:  # (a grid's cells carry their own labels)
		l.visible = not grid or list.is_empty()
	if list.is_empty():
		_head.text = gname
		_title.text = tr(&"UI_FXG_EMPTY")
		_info.text = ""
		return
	if grid:
		_head.text = (
			tr(&"UI_FXG_HEAD_GRID")
			% [group + 1, EffectsCatalog.GROUPS.size(), gname, page + 1, pages(), list.size()]
		)
		_title.text = ""
		_info.text = ""
		var shape := grid_shape()
		var g := GridContainer.new()
		g.columns = shape.x
		g.set_anchors_preset(Control.PRESET_FULL_RECT)
		g.add_theme_constant_override("h_separation", 4)
		g.add_theme_constant_override("v_separation", 4)
		_area.add_child(g)
		var first := page * page_size()
		for n in range(first, mini(first + page_size(), list.size())):
			var s := EffectStage.new(list[n], catalog, true)
			s.gui_input.connect(_on_cell_input.bind(n - first))
			stages.append(s)
			g.add_child(s)
		return
	var e := list[index]
	_head.text = (
		tr(&"UI_FXG_HEAD")
		% [group + 1, EffectsCatalog.GROUPS.size(), gname, index + 1, list.size()]
	)
	_title.text = e["title"]
	_info.text = "%s: %s\n%s: %s" % [tr(&"UI_FXG_SOURCE"), e["source"], tr(&"UI_FXG_USE"), e["use"]]
	var s := EffectStage.new(e, catalog)
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	stages.append(s)
	_area.add_child(s)


func _process(delta: float) -> void:
	if grid or stages.is_empty() or stages[0].entry["kind"] != &"sim":
		return
	_seen_wait -= delta
	if _seen_wait > 0.0:
		return
	_seen_wait = 0.5
	var ids := stages[0].pack_ids_seen()
	_seen.text = (
		tr(&"UI_FXG_SEEN") % (", ".join(ids) if not ids.is_empty() else tr(&"UI_FXG_SEEN_NONE"))
	)


func _on_cell_input(ev: InputEvent, n: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		open_cell(n)


func _unhandled_input(ev: InputEvent) -> void:
	var done := true
	if ev.is_action_pressed(&"ui_right"):
		next()
	elif ev.is_action_pressed(&"ui_left"):
		prev()
	elif ev.is_action_pressed(&"ui_down") or _joy(ev, JOY_BUTTON_RIGHT_SHOULDER):
		next_group()
	elif ev.is_action_pressed(&"ui_up") or _joy(ev, JOY_BUTTON_LEFT_SHOULDER):
		prev_group()
	elif _key(ev, KEY_G) or _joy(ev, JOY_BUTTON_Y):
		toggle_grid()
	elif ev.is_action_pressed(&"ui_cancel"):
		if grid:
			toggle_grid()
		else:
			back_pressed.emit()
	else:
		done = false
	if done:
		get_viewport().set_input_as_handled()


static func _key(ev: InputEvent, k: Key) -> bool:
	return ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == k


static func _joy(ev: InputEvent, b: JoyButton) -> bool:
	return ev is InputEventJoypadButton and ev.pressed and ev.button_index == b
