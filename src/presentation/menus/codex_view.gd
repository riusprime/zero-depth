class_name CodexView
extends Control
## v0.7.5 CX (owner N6: "the journal of codex cards"): the Codex, from the main menu and the pause menu. Ember stone
## (MenuStyle, v0.8.0 MU) over the blurred game or the menu's own ember scene: the title and how much you've found, four
## pages (Cards, Enemies, Bosses, Biomes), the page's entries as tiles in sections (CodexTile; the Cards page by pool:
## Gun, Blade, shared, triggers, legendary, then stat cards, utilities and passives), and beside them the focused entry:
## a card as its stone tablet (StoneCard, as in a pick) with its name and sentence (the game's own keys), or an emblem /
## a landscape with its line, and your counts from the profile (CodexStore). An entry you haven't met is a silhouette,
## "???". Keyboard: arrows move, Q / E change the page, Esc goes back. Pad: d-pad or stick, LB / RB, B. Mouse: hover a
## tile, click a page, Back. It reads the catalog (the content) and the profile's counters; it changes nothing. v0.7.5
## AC: given an AchievementBook, a fifth page, Achievements (AchievementsPage), follows the four. v0.9.0 CL: the last
## page, Collectibles (ArchivePage), is the Rune Archive's shelves (the hub's Archive opens on it: page_of).

signal back_pressed

const TAB_KEYS := {
	&"cards": "UI_CODEX_TAB_CARDS",
	&"enemies": "UI_CODEX_TAB_ENEMIES",
	&"bosses": "UI_CODEX_TAB_BOSSES",
	&"biomes": "UI_CODEX_TAB_BIOMES",
	&"achievements": "UI_ACH_TAB",  # v0.7.5 AC
	&"collectibles": "UI_CODEX_TAB_COLLECTIBLES",  # v0.9.0 CL
}
## v0.7.5 AC: the Achievements page's id (not a CodexStore page: it reads the AchievementBook).
const ACHIEVEMENTS := &"achievements"
## v0.9.0 CL: the Collectibles page's id (not a CodexStore page: the catalog's collectibles and the profile's finds).
const COLLECTIBLES := &"collectibles"
const SECTION_KEYS := {
	&"gun": "UI_CODEX_SECTION_GUN",
	&"blade": "UI_CODEX_SECTION_BLADE",
	&"shared": "UI_CODEX_SECTION_SHARED",
	&"triggers": "UI_CODEX_SECTION_TRIGGERS",
	&"legendary": "UI_CODEX_SECTION_LEGENDARY",
	&"stats": "UI_CODEX_SECTION_STATS",
	&"utilities": "UI_CODEX_SECTION_UTILITIES",
	&"abilities": "UI_CODEX_SECTION_ABILITIES",
	&"passives": "UI_CODEX_SECTION_PASSIVES",
	&"enemies": "UI_CODEX_TAB_ENEMIES",
	&"bosses": "UI_CODEX_TAB_BOSSES",
	&"final": "UI_CODEX_SECTION_FINAL",  # v0.8.0 FB1: the final boss's bodies
	&"biomes": "UI_CODEX_TAB_BIOMES",
}
const COUNTER_KEYS := {
	&"offered": "UI_CODEX_OFFERED",
	&"taken": "UI_CODEX_TAKEN",
	&"level": "UI_CODEX_LEVEL",
	&"kills": "UI_CODEX_KILLS",
	&"deaths": "UI_CODEX_DEATHS",
	&"fights": "UI_CODEX_FIGHTS",
	&"visits": "UI_CODEX_VISITS",
}
const RARITY_KEYS := ["RARITY_COMMON", "RARITY_RARE", "RARITY_EPIC", "RARITY_LEGENDARY"]
## The grid's columns, the tiles' gap and the detail panel's width (px at the 1920 x 1080 base).
const COLUMNS := 7
const GAP := 8
const DETAIL_W := 660.0
const INFO_W := 320.0
const EMBLEM := 220.0

var catalog: CodexCatalog
var store: CodexStore
var page := &"cards"
## The pages shown, in order: CodexStore.PAGES, then Achievements when there is a book (v0.7.5 AC).
var pages: Array[StringName] = []
## v0.7.5 AC: the achievements (null: no Achievements page) and their page.
var achievements: AchievementBook
var achievements_page: AchievementsPage
## v0.9.0 CL: the Collectibles page (null when the content has no collectible).
var archive_page: ArchivePage
var tabs := {}
var tiles: Array[CodexTile] = []
var progress := Label.new()
var card := StoneCard.new(1.0)
var emblem := CodexIcon.new()
var name_label := Label.new()
var section_label := Label.new()
var desc_label := Label.new()
var counts_label := Label.new()
var back := Button.new()
var _scroll := ScrollContainer.new()
var _list := VBoxContainer.new()
var _body: HBoxContainer
var _visual := Control.new()
var _emblem_box := PanelContainer.new()
var _shown := {}


func _init(
	p_catalog: CodexCatalog, p_store: CodexStore, p_achievements: AchievementBook = null
) -> void:
	name = "CodexView"
	catalog = p_catalog
	store = p_store
	achievements = p_achievements
	pages = CodexStore.PAGES.duplicate()
	if achievements != null:
		pages.append(ACHIEVEMENTS)
	if not catalog.collectibles.is_empty():  # v0.9.0 CL
		pages.append(COLLECTIBLES)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuStyle.apply(self)
	add_child(MenuBackdrop.new())
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(MenuStyle.LIST_LEFT))
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 44)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var col := VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)
	col.add_child(_header())
	col.add_child(_tab_row())
	var body := HBoxContainer.new()
	_body = body
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 40)
	col.add_child(body)
	if achievements != null:  # v0.7.5 AC: shown in the body's place on its own page
		achievements_page = AchievementsPage.new(achievements)
		achievements_page.visible = false
		col.add_child(achievements_page)
	if pages.has(COLLECTIBLES):  # v0.9.0 CL: shown in the body's place on its own page
		archive_page = ArchivePage.new(
			catalog.collectibles, CollectibleBook.found_flags(store.profile, catalog.collectibles)
		)
		archive_page.visible = false
		col.add_child(archive_page)
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.custom_minimum_size = Vector2(COLUMNS * CodexTile.SIZE.x + (COLUMNS - 1) * GAP + 24, 0)
	body.add_child(_scroll)
	_list.name = "List"
	_list.add_theme_constant_override("separation", 10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	body.add_child(_detail())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 28)
	col.add_child(foot)
	back.name = "Back"
	back.text = "UI_BACK"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.custom_minimum_size = Vector2(200, 48)
	back.add_theme_font_size_override("font_size", MenuStyle.BUTTON_SIZE)
	back.pressed.connect(func() -> void: back_pressed.emit())
	foot.add_child(back)
	var hint := MenuStyle.hint("UI_CODEX_HINT")
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hint)
	_build_page()


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	var title := Label.new()
	title.name = "Title"
	title.text = "UI_CODEX_TITLE"
	title.add_theme_font_override("font", HudStyle.font(true))
	title.add_theme_font_size_override("font_size", MenuStyle.TITLE_SIZE)
	title.add_theme_constant_override("outline_size", 6)
	row.add_child(title)
	progress.name = "Progress"
	progress.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	progress.size_flags_vertical = Control.SIZE_SHRINK_END
	progress.add_theme_font_size_override("font_size", MenuStyle.NOTE_SIZE + 3)
	progress.add_theme_color_override("font_color", MenuStyle.DIM)
	row.add_child(progress)
	return row


func _tab_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "Tabs"
	row.add_theme_constant_override("separation", 6)
	for p: StringName in pages:
		var b := Button.new()
		b.name = "Tab%s" % String(p).capitalize()
		b.text = TAB_KEYS[p]
		b.custom_minimum_size = Vector2(0, 48)
		b.add_theme_font_size_override("font_size", MenuStyle.BUTTON_SIZE - 2)
		b.focus_entered.connect(_set_page.bind(p))
		b.pressed.connect(func() -> void: focus_first())
		row.add_child(b)
		tabs[p] = b
	return row


func _detail() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Detail"
	panel.add_theme_stylebox_override("panel", MenuStyle.stone_panel(Vector2(22, 22)))
	panel.custom_minimum_size = Vector2(DETAIL_W, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	_visual.custom_minimum_size = StoneCard.SIZE
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_visual)
	_visual.add_child(card)
	_emblem_box.name = "Emblem"
	_emblem_box.add_theme_stylebox_override("panel", MenuStyle.stone_panel(Vector2(14, 14)))
	_emblem_box.position = Vector2((StoneCard.SIZE.x - EMBLEM - 28) * 0.5, 0)
	_emblem_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.custom_minimum_size = Vector2(EMBLEM, EMBLEM)
	_emblem_box.add_child(emblem)
	_visual.add_child(_emblem_box)
	var info := VBoxContainer.new()
	info.name = "Info"
	info.custom_minimum_size = Vector2(INFO_W, 0)
	info.add_theme_constant_override("separation", 10)
	row.add_child(info)
	name_label.name = "EntryName"
	name_label.add_theme_font_override("font", HudStyle.font(true))
	name_label.add_theme_font_size_override("font_size", 30)
	section_label.name = "Section"
	section_label.add_theme_font_size_override("font_size", MenuStyle.NOTE_SIZE)
	section_label.add_theme_color_override("font_color", MenuStyle.DIM)
	desc_label.name = "Desc"
	desc_label.add_theme_font_size_override("font_size", 20)
	counts_label.name = "Counts"
	counts_label.add_theme_font_size_override("font_size", 20)
	counts_label.add_theme_color_override("font_color", MenuStyle.EMBER.lerp(Color.WHITE, 0.45))
	for l: Label in [name_label, section_label, desc_label, counts_label]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(INFO_W, 0)
		info.add_child(l)
		if l == desc_label:
			info.add_child(HSeparator.new())
	return panel


## Shows page `p` (CodexStore.PAGES) with its first tile focused.
func open(p: StringName) -> void:
	_set_page(p)
	focus_first()


## v0.9.0 HB: shows page `p` before the view is in the tree (the hub's Trophy Area opens on the Achievements); its
## first focus comes with focus_first, so no scroll of the page it replaced is left waiting.
func start_on(p: StringName) -> void:
	if pages.has(p):
		_set_page(p)


## v0.9.0 CL: the page a hub station's panel opens on: the Trophy Area's Achievements, the Rune Archive's Collectibles
## (&"" for any other: the first page).
static func page_of(panel: StringName) -> StringName:
	match panel:
		&"achievements":
			return ACHIEVEMENTS
		&"codex":
			return COLLECTIBLES
	return &""


func focus_first() -> void:
	if page == ACHIEVEMENTS and achievements_page != null and not achievements_page.rows.is_empty():
		achievements_page.focus_first()
	elif page == COLLECTIBLES and archive_page != null and not archive_page.tiles.is_empty():
		archive_page.focus_first()
	elif not tiles.is_empty():
		tiles[0].grab_focus()
	else:
		back.grab_focus()


## The tile of entry `id` on the page shown (null when it isn't there).
func tile(id: StringName) -> CodexTile:
	for t in tiles:
		if t.entry["id"] == id:
			return t
	return null


## The entry the detail panel shows now.
func shown_entry() -> Dictionary:
	return _shown


## The page's content on screen (tests: it fits the 1920 x 1080 base).
func content_rect() -> Rect2:
	var col := get_node_or_null("Margin/Column") as Control
	return col.get_global_rect() if col != null else Rect2()


func _set_page(p: StringName) -> void:
	if p == page and not tiles.is_empty():
		return
	if p == page and p == ACHIEVEMENTS and not achievements_page.rows.is_empty():
		return  # v0.7.5 AC: the Achievements page is already built
	if p == page and p == COLLECTIBLES and not archive_page.tiles.is_empty():
		return  # v0.9.0 CL: so is the Collectibles page
	page = p
	_build_page()


func _cycle(step: int) -> void:
	var k := pages.find(page)
	open(pages[(k + step + pages.size()) % pages.size()])


func _build_page() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	tiles.clear()
	_scroll.scroll_vertical = 0
	if archive_page != null:
		archive_page.visible = false
	if page == ACHIEVEMENTS:
		_build_achievements()
		return
	if page == COLLECTIBLES:
		_build_archive()
		return
	_body.visible = true
	if achievements_page != null:
		achievements_page.visible = false
	var found := 0
	var above: Array[CodexTile] = []  # the section before's tiles (_link_short_rows)
	for s: StringName in catalog.sections(page):
		var rows: Array = catalog.section_entries(page, s)
		var have := 0
		for e: Dictionary in rows:
			have += 1 if store.is_unlocked(page, e["id"]) else 0
		found += have
		var head := Label.new()
		head.name = "Head_%s" % s
		head.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		head.text = "%s   %d / %d" % [tr(SECTION_KEYS[s]), have, rows.size()]
		head.add_theme_font_override("font", HudStyle.font(true))
		head.add_theme_font_size_override("font_size", 18)
		head.add_theme_color_override("font_color", MenuStyle.EMBER.lerp(Color.WHITE, 0.3))
		_list.add_child(head)
		var grid := GridContainer.new()
		grid.name = "Grid_%s" % s
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", GAP)
		grid.add_theme_constant_override("v_separation", GAP)
		_list.add_child(grid)
		var here: Array[CodexTile] = []
		for k in rows.size():
			var e: Dictionary = rows[k]
			var t := CodexTile.new()
			t.show_entry(e, title_of(self, e), not store.is_unlocked(page, e["id"]))
			t.focus_entered.connect(_on_tile_focus.bind(t, head if k < COLUMNS else null))
			grid.add_child(t)
			if tiles.is_empty() or (k < COLUMNS and s == catalog.sections(page)[0]):
				t.focus_neighbor_top = t.get_path_to(tabs[page])  # up goes to this page's tab, not another
			tiles.append(t)
			here.append(t)
		_link_short_rows(above, here)
		_stop_at_row_ends(here)
		above = here
	progress.text = tr("UI_CODEX_FOUND") % [found, catalog.size(page)]
	for p: StringName in tabs:
		var b: Button = tabs[p]
		b.focus_neighbor_bottom = b.get_path_to(tiles[0]) if not tiles.is_empty() else NodePath()
		var lit := MenuStyle.EMBER.lerp(Color.WHITE, 0.35)
		b.add_theme_color_override("font_color", lit if p == page else MenuStyle.DIM)
	if not tiles.is_empty():
		_show(tiles[0].entry)


## v0.8.0 RM: left and right stop at a row's ends instead of jumping to the nearest tile of another section (with the
## two mutations the legendary section takes two rows, and right from its first row's end landed on a stat card,
## skipping the rest of that section).
func _stop_at_row_ends(here: Array[CodexTile]) -> void:
	for k in here.size():
		var t := here[k]
		if k % COLUMNS == 0:
			t.focus_neighbor_left = t.get_path_to(t)
		if k % COLUMNS == COLUMNS - 1 or k == here.size() - 1:
			t.focus_neighbor_right = t.get_path_to(t)


## v0.8.0: a short row is never skipped. Down from a column the next row (or the next section's only row) doesn't
## reach lands on that row's last tile, and up from a column the row above doesn't reach lands on its last tile. Godot's
## own focus search otherwise jumps over the short row to the next full one, so its cards (Gun Twin and Halo Shot,
## after AO's two Gun cards) can't be reached by the arrows from that side.
func _link_short_rows(above: Array[CodexTile], here: Array[CodexTile]) -> void:
	var n := here.size()
	if n == 0:
		return
	var last_len := (n - 1) % COLUMNS + 1
	if n > COLUMNS and last_len < COLUMNS:
		for k in range(n - COLUMNS, n - last_len):  # the full row's columns past the short row's end
			here[k].focus_neighbor_bottom = here[k].get_path_to(here[n - 1])
	if above.is_empty():
		return
	var first_len := mini(n, COLUMNS)
	var a_n := above.size()
	var a_len := (a_n - 1) % COLUMNS + 1
	for k in range(a_n - a_len, a_n):
		if k - (a_n - a_len) >= first_len:
			above[k].focus_neighbor_bottom = above[k].get_path_to(here[first_len - 1])
	if a_len < COLUMNS:
		for k in range(a_len, first_len):
			here[k].focus_neighbor_top = here[k].get_path_to(above[a_n - 1])


## v0.7.5 AC: the Achievements page in the body's place; up from its first line goes to its tab.
func _build_achievements() -> void:
	_body.visible = false
	achievements_page.visible = true
	achievements_page.top_neighbor = tabs[ACHIEVEMENTS]
	achievements_page.refresh()
	progress.text = achievements_page.progress_text()
	var first: Control = (
		achievements_page.rows[0] if not achievements_page.rows.is_empty() else back
	)
	for p: StringName in tabs:
		var b: Button = tabs[p]
		b.focus_neighbor_bottom = b.get_path_to(first)
		var lit := MenuStyle.EMBER.lerp(Color.WHITE, 0.35)
		b.add_theme_color_override("font_color", lit if p == page else MenuStyle.DIM)


## v0.9.0 CL: the Collectibles page in the body's place; up from its first shelf goes to its tab.
func _build_archive() -> void:
	_body.visible = false
	if achievements_page != null:
		achievements_page.visible = false
	archive_page.visible = true
	archive_page.top_neighbor = tabs[COLLECTIBLES]
	archive_page.refresh()
	progress.text = archive_page.progress_text()
	var first: Control = archive_page.tiles[0] if not archive_page.tiles.is_empty() else back
	for p: StringName in tabs:
		var b: Button = tabs[p]
		b.focus_neighbor_bottom = b.get_path_to(first)
		var lit := MenuStyle.EMBER.lerp(Color.WHITE, 0.35)
		b.add_theme_color_override("font_color", lit if p == page else MenuStyle.DIM)


## An entry's name: its own key, and a card with a Gun face shows both ("On Finisher / On Crit").
static func title_of(ci: Object, e: Dictionary) -> String:
	var t: String = ci.tr(e["name_key"])
	var alt: StringName = e.get("alt_name_key", &"")
	return t if alt == &"" else "%s / %s" % [t, ci.tr(alt)]


## An entry's sentence: the game's own key (a stat card's numbers at common rarity).
static func desc_of(ci: Object, e: Dictionary) -> String:
	var key: StringName = e.get("desc_key", &"")
	if key == &"":
		return ""
	var nums: PackedInt32Array = e.get("desc_permille", PackedInt32Array())
	if nums.is_empty():
		return ci.tr(key)
	var args := [GambleIcons.percent(nums[0])]
	if nums.size() > 1 and nums[1] > 0:
		args.append(GambleIcons.percent(nums[1]))
	return ci.tr(key) % args


## An entry's counts as lines ("Taken: 3"), the counters of its page; the highest level only on a card that levels.
func counts_text(e: Dictionary) -> String:
	var lines := PackedStringArray()
	for c: StringName in CodexStore.COUNTERS[page]:
		if c == &"level" and not bool(e.get("leveled", false)):
			continue
		var n := store.count(page, e["id"], c)
		lines.append("%s: %s" % [tr(COUNTER_KEYS[c]), str(n) if n > 0 or c != &"level" else "—"])
	return "\n".join(lines)


## A tile took the focus: show its entry; a tile in a section's first row also brings the section's title into view
## (the scroll follows the focus to the tile itself).
func _on_tile_focus(t: CodexTile, head: Label) -> void:
	_show(t.entry)
	if head != null:
		_scroll.ensure_control_visible.call_deferred(head)


## v0.8.0 RR (owner O33): Cards entry `e`'s frame tier (PickSlot.TIERS): a mod's or a stat card's tier in order
## (a Legendary one the legendary gold), an ability card the ability's.
static func tier_of(e: Dictionary) -> int:
	if int(e["type"]) == WorldReader.CARD_ABILITY:
		return 3
	var r := clampi(int(e["rarity"]), 0, 3)
	return CardFrames.LEGENDARY_TIER if r == 3 else r


## v0.8.0 RR: the tier word a mod card shows in the Codex ("Common", "Rare", "Epic", "Legendary"); "" for an ability
## or a stat card (a stat card's tier is drawn per offer).
static func tier_text(ci: Object, e: Dictionary) -> String:
	if int(e["type"]) != WorldReader.CARD_MOD:
		return ""
	return ci.tr(RARITY_KEYS[clampi(int(e["rarity"]), 0, 3)])


func _show(e: Dictionary) -> void:
	_shown = e
	var locked := not store.is_unlocked(page, e["id"])
	var is_card := page == &"cards"
	card.visible = is_card
	_emblem_box.visible = not is_card
	_visual.custom_minimum_size = (
		StoneCard.SIZE if is_card else Vector2(StoneCard.SIZE.x, EMBLEM + 28.0)
	)
	var section_text: String = tr(SECTION_KEYS.get(e["section"], "UI_CODEX_TITLE"))
	if is_card:
		var fam := CardFrames.family(e["id"], int(e["type"]))
		var tier := tier_of(e)
		var tier_word := tier_text(self, e)  # v0.8.0 RR (owner O33): every card says its tier
		if not locked and tier_word != "":
			section_text = "%s · %s" % [section_text, tier_word]
		if locked:
			card.show_face(&"", "???", tr("UI_CODEX_LOCKED"), fam, 0, PickSlot.COMMON, "")
			card.modulate = Color(0.42, 0.44, 0.5, card.modulate.a)
		else:
			card.show_face(
				e["id"],
				title_of(self, e),
				desc_of(self, e),
				fam,
				tier,
				PickSlot.TIERS[tier],
				tier_word,
				"",
				CodexIcon.color_of(e)
			)
			card.modulate = Color(1, 1, 1, card.modulate.a)
	else:
		emblem.show_entry(e, locked)
	name_label.text = "???" if locked else title_of(self, e)
	section_label.text = section_text
	desc_label.text = tr("UI_CODEX_LOCKED") if locked else desc_of(self, e)
	counts_label.text = "" if locked else counts_text(e)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var jb := event as InputEventJoypadButton
	var k := event as InputEventKey
	var pad := jb.button_index if jb != null and jb.pressed else -1
	var key := k.physical_keycode if k != null and k.pressed and not k.echo else KEY_NONE
	if (
		event.is_action_pressed(&"ui_cancel")
		or event.is_action_pressed(&"pause")
		or pad == JOY_BUTTON_B
	):
		get_viewport().set_input_as_handled()
		back_pressed.emit()
	elif key == KEY_Q or pad == JOY_BUTTON_LEFT_SHOULDER:
		get_viewport().set_input_as_handled()
		_cycle(-1)
	elif key == KEY_E or pad == JOY_BUTTON_RIGHT_SHOULDER:
		get_viewport().set_input_as_handled()
		_cycle(1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and catalog != null and is_inside_tree():
		var at := tiles.find(get_viewport().gui_get_focus_owner() as CodexTile)
		var shelf_at := -1  # v0.9.0 CL
		if archive_page != null:
			shelf_at = archive_page.tiles.find(get_viewport().gui_get_focus_owner() as ArchiveTile)
		var row_at := -1
		if achievements_page != null:
			row_at = achievements_page.rows.find(
				get_viewport().gui_get_focus_owner() as AchievementRow
			)
		_build_page()
		if at >= 0 and at < tiles.size():
			tiles[at].grab_focus()
		elif row_at >= 0 and row_at < achievements_page.rows.size():
			achievements_page.rows[row_at].grab_focus()
		elif shelf_at >= 0 and shelf_at < archive_page.tiles.size():
			archive_page.tiles[shelf_at].grab_focus()
