class_name AchievementsPage
extends ScrollContainer
## v0.7.5 AC (owner N7): the Codex's Achievements page: every achievement (AchievementBook) in its group, two rows
## to a line (AchievementRow). Unlocked ones are lit in gold; locked ones are dimmed and keep their sentence and how
## far along they are, so you know what to aim for; a hidden one (`hidden` in its data, today the Ascension pair)
## stays "???" until it unlocks. Reads the book only; it changes nothing.

const GROUP_KEYS := {
	&"run": "UI_ACH_GROUP_RUN",
	&"bosses": "UI_ACH_GROUP_BOSSES",
	&"biomes": "UI_ACH_GROUP_BIOMES",
	&"build": "UI_ACH_GROUP_BUILD",
	&"combat": "UI_ACH_GROUP_COMBAT",
	&"risk": "UI_ACH_GROUP_RISK",
	&"codex": "UI_ACH_GROUP_CODEX",
	&"ascension": "UI_ACH_GROUP_ASCENSION",
}
const COLUMNS := 2
const GAP := 12

var book: AchievementBook
var rows: Array[AchievementRow] = []
## Where "up" goes from the first line of rows (the page's tab).
var top_neighbor: Control
var _list := VBoxContainer.new()


func _init(p_book: AchievementBook) -> void:
	name = "AchievementsPage"
	book = p_book
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = true
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(COLUMNS * AchievementRow.SIZE.x + (COLUMNS - 1) * GAP + 24, 0)
	_list.name = "List"
	_list.add_theme_constant_override("separation", 10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)


## An achievement's name: its key, with the Codex entry's name for one per boss or biome.
static func title_of(ci: Object, a: Dictionary) -> String:
	return _with_arg(ci, a["name_key"], a)


static func desc_of(ci: Object, a: Dictionary) -> String:
	return _with_arg(ci, a["desc_key"], a)


static func _with_arg(ci: Object, key: StringName, a: Dictionary) -> String:
	var t: String = ci.tr(key)
	var arg: StringName = a.get("arg_key", &"")
	if arg != &"" and t.contains("%s"):
		return t % ci.tr(arg)
	return t


## The page's progress line ("Unlocked 4 / 37").
func progress_text() -> String:
	return tr("UI_ACH_PROGRESS") % [book.unlocked_count(), book.size()]


## Builds the rows from the book (call again after the profile changed).
func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	rows.clear()
	scroll_vertical = 0
	var first_line := true
	for g: StringName in book.groups():
		var list := book.in_group(g)
		var have := 0
		for a in list:
			have += 1 if book.is_unlocked(a["id"]) else 0
		var head := Label.new()
		head.name = "Head_%s" % g
		head.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		head.text = "%s   %d / %d" % [tr(GROUP_KEYS.get(g, "UI_ACH_TAB")), have, list.size()]
		head.add_theme_font_override("font", HudStyle.font(true))
		head.add_theme_font_size_override("font_size", 18)
		head.add_theme_color_override("font_color", MenuStyle.GLASS.lerp(Color.WHITE, 0.3))
		_list.add_child(head)
		var grid := GridContainer.new()
		grid.name = "Grid_%s" % g
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", GAP)
		grid.add_theme_constant_override("v_separation", GAP)
		_list.add_child(grid)
		for k in list.size():
			var r := AchievementRow.new()
			r.show_entry(list[k], book)
			grid.add_child(r)
			if k < COLUMNS:
				r.focus_entered.connect(_show_head.bind(head))
			if first_line and k < COLUMNS and top_neighbor != null:
				r.focus_neighbor_top = r.get_path_to(top_neighbor)
			rows.append(r)
		first_line = false


func _show_head(head: Label) -> void:
	ensure_control_visible.call_deferred(head)


func focus_first() -> void:
	if not rows.is_empty():
		rows[0].grab_focus()


## The row of achievement `id` (null when there's none).
func row(id: StringName) -> AchievementRow:
	for r in rows:
		if r.entry["id"] == id:
			return r
	return null
