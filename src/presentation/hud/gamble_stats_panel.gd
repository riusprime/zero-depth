class_name GambleStatsPanel
extends PanelContainer
## The stats won at the gamble shrine this run (v0.3.0 L19): one row per stat with its icon, the total it adds and
## its wins / cap. On the HUD it shows while you stand at the shrine; the pause menu shows it too.
## v0.6.0 UP: on the HUD it is an Ember stone slab (HudStyle) with the shrine's colour along its top; inside a menu
## (the pause screen) it takes the menu's Ember stone look (MenuStyle), so the pause screen reads as one style.
## v0.10.5 W3-O20 (UI style Astral): in HudStyle.ASTRAL the HUD's Astral side panel in both places, the title in
## letter-spaced Cinzel, the lines in Astral's silver-white, the counts and the empty line dim; each stat keeps its
## icon's colour (GambleIconView draws its Astral tile).

const ICON := 28.0
const MARGIN := Vector2(14, 9)
const LIT_S := 0.6

## Whether it wears the menus' Ember stone (set when it is added to a MenuPanel).
var in_menu := false
## The reader last shown (read only), to word the panel again on a language switch.
var _reader: WorldReader
var _rows := VBoxContainer.new()
var _title := Label.new()
var _none := Label.new()
## The state last shown (stacks per stat), so rows are rebuilt only on a change.
var _shown := PackedInt32Array()
## The language the rows were worded in.
var _locale := ""
## v0.11.0 F13: wins the view has not shown yet, per stat (the sim applied them at once; their symbol is still on its
## way to the panel), so the rows say the value before them until release().
var _held := {}
## The row last lit and how long it still glows (s).
var _lit_stat := -1
var _lit_left := 0.0
var _row_of := {}


func _init() -> void:
	name = "GambleStats"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	_title.add_theme_font_size_override("font_size", 16)
	_none.add_theme_font_size_override("font_size", 15)
	_apply_look()
	for l: Label in [_title, _none]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)
	col.add_child(_none)
	_rows.add_theme_constant_override("separation", 4)
	col.add_child(_rows)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED and get_parent() is MenuPanel and not in_menu:
		in_menu = true
		_apply_look()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and _reader != null:
		sync(_reader)  # the pause menu syncs it once: a language switch from its Options words it again


## The panel's box and title colours for where it is: Ember stone in a menu, the HUD's slab otherwise.
func _apply_look() -> void:
	if HudStyle.current == HudStyle.Style.ASTRAL:  # v0.10.5 W3-O20: one Astral panel on the HUD and in the pause
		add_theme_stylebox_override(
			"panel", HudStyle.side_panel_box(MARGIN + Vector2(4, 4), GambleIcons.CORE)
		)
		HudStyle.serif_label(_title, 18, 4, HudStyle.A_TEXT)
		HudStyle.style_label(_none, 16)
		_none.add_theme_color_override("font_color", HudStyle.A_DIM)
	elif in_menu:
		add_theme_stylebox_override("panel", MenuStyle.stone_panel(MARGIN))
		_title.add_theme_color_override("font_color", MenuStyle.EMBER.lerp(Color.WHITE, 0.25))
		_none.add_theme_color_override("font_color", MenuStyle.DIM)
	else:
		add_theme_stylebox_override("panel", HudStyle.side_panel_box(MARGIN, GambleIcons.CORE))
		_title.add_theme_color_override("font_color", GambleIcons.CORE.lerp(Color.WHITE, 0.4))
		_none.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	queue_redraw()


func _draw() -> void:
	if not in_menu or HudStyle.current == HudStyle.Style.ASTRAL:
		HudStyle.draw_side_panel(self, GambleIcons.CORE)


## Anchors the panel to the top-right corner, `top` px down.
func place_top_right(top: float) -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_left = -28
	offset_right = -28
	offset_top = top


func sync(reader: WorldReader) -> void:
	_reader = reader
	var now := PackedInt32Array()
	for s in reader.gamble_stat_count():
		now.append(_shown_stacks(s))
	if now == _shown and TranslationServer.get_locale() == _locale:  # v0.6.0 UP: worded again on a switch
		return
	_title.text = tr("UI_GAMBLE_STATS")  # P-7: after the early return (unchanged words then)
	_none.text = tr("UI_GAMBLE_STATS_NONE")
	_shown = now
	_locale = TranslationServer.get_locale()
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	_row_of.clear()
	for s in reader.gamble_stat_count():
		if _shown_stacks(s) <= 0:
			continue
		var id := reader.gamble_stat_id(s)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(GambleIconView.new(id, ICON))
		var text := Label.new()
		text.text = GambleIcons.line(self, id, _shown_bonus(s))
		text.add_theme_font_size_override("font_size", 17)
		var tone := GambleIcons.color(id).lerp(Color.WHITE, 0.45)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var count := Label.new()
		count.text = "%d / %d" % [_shown_stacks(s), reader.gamble_cap(s)]
		count.add_theme_font_size_override("font_size", 14)
		if HudStyle.current == HudStyle.Style.ASTRAL:  # v0.10.5 W3-O20: the HUD's type in the pause too
			HudStyle.style_label(text, 17)
			HudStyle.style_label(count, 16)
		text.add_theme_color_override("font_color", HudStyle.pick(HudStyle.A_TEXT, tone))
		count.add_theme_color_override(
			"font_color", HudStyle.pick(HudStyle.A_DIM, Color(1, 1, 1, 0.55))
		)
		row.add_child(count)
		for l: Label in [text, count]:
			l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(row)
		_row_of[s] = row
	_none.visible = _rows.get_child_count() == 0


func _shown_stacks(stat: int) -> int:
	return maxi(0, _reader.gamble_stacks(stat) - int(_held.get(stat, 0)))


func _shown_bonus(stat: int) -> int:
	return maxi(
		0, _reader.gamble_bonus(stat) - int(_held.get(stat, 0)) * _reader.gamble_amount(stat)
	)


## v0.11.0 F13: a win of `stat` is on its way here; its row keeps the value before it until release(stat).
func hold(stat: int) -> void:
	_held[stat] = int(_held.get(stat, 0)) + 1
	_shown = PackedInt32Array()  # reworded on the next sync


## One held win's symbol arrived (or was dropped): the row shows it, and glows briefly when `glow`.
func release(stat: int, glow := true) -> void:
	var n := int(_held.get(stat, 0)) - 1
	if n <= 0:
		_held.erase(stat)
	else:
		_held[stat] = n
	_shown = PackedInt32Array()
	if _reader != null:
		sync(_reader)
	if glow:
		_lit_stat = stat
		_lit_left = LIT_S


## Drops every held win (no shrine any more: a new floor).
func release_all() -> void:
	if not _held.is_empty():
		_held.clear()
		_shown = PackedInt32Array()


## Held wins of `stat` (tests).
func held(stat: int) -> int:
	return int(_held.get(stat, 0))


## Where a symbol of `stat` lands (global px): its row's icon, or where its row will appear.
func landing_point(stat: int) -> Vector2:
	var row := _row_of.get(stat) as Control
	if row != null and is_instance_valid(row):
		return row.get_global_rect().position + Vector2(ICON, ICON) * 0.5
	var before := 0
	for s in stat:
		if _row_of.has(s):
			before += 1
	var step := ICON + 4.0
	if _rows.get_child_count() > 0:
		step = maxf(step, (_rows.get_child(0) as Control).size.y + 4.0)
	return _rows.get_global_rect().position + Vector2(ICON * 0.5, step * before + ICON * 0.5)


func _process(delta: float) -> void:
	if _lit_left > 0.0:
		_lit_left = maxf(0.0, _lit_left - delta)
		var row := _row_of.get(_lit_stat) as Control
		if row != null and is_instance_valid(row):
			row.modulate = Color.WHITE.lerp(Color(2.0, 2.0, 1.6), _lit_left / LIT_S)


## A row is glowing from an arrival (tests).
func lit() -> bool:
	return _lit_left > 0.0


## Rows shown (one per stat won), for tests.
func row_count() -> int:
	var n := 0
	for c in _rows.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n


## Row k's line ("+12 % melee damage"), for tests.
func row_text(k: int) -> String:
	return (_rows.get_child(k).get_child(1) as Label).text
