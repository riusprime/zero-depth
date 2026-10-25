extends SceneTree
## v0.9.0 AS (G2, docs/process/OWNER_GATES.md §3; owner Q5 "Marked, old one burns", Q14 "Short line + slot tag"): three
## mockups of the reward card's slot tag + "Replaces <card>" and of the Build page by slot, in English and Spanish, at
## 1920 × 1080. Real data from a fixed seed: a Gun run (CardPoolSurvey.world, seed 5) on floor 3 holding Twin, Pierce,
## Homing, Ember Core and On Hit (taken through BuildSlots.take under the shipped slot rules); the altar shows Halo (a
## Pattern: it replaces Twin), Ricochet (a Secondary: the slot is full, it replaces Pierce) and Storm Core (an Element
## with room); every face is the game's own (PickPanel.card_face on the live WorldReader).
## - A (built): the slot line under the card (its mark, its tag, "· [icon] Replaces Twin" in ember); the Build page's
##   tiles add the tag to the level line and its note counts the slots.
## - B: a ribbon across the card's top ("REPLACES TWIN") and the tag in the rarity line; the Build page shows a pip row
##   per slot above the wand.
## - C: the tag as a large corner badge and the replaced card as a crossed-out mini tile beside "→"; the Build page
##   adds a column per slot under the wand (the cards of each).
## A tool, not a test; it quits on every path. Needs a renderer (not --headless):
##   godot --path . --resolution 1920x1080 -s scripts/shots/mock_attack_slots.gd
## Writes build/shots/v0.9.0/as/<a|b|c>_<pick|build>_<en|es>.png. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.9.0/as/"
const SEED := 5
const HELD: Array[StringName] = [
	&"gun_twin", &"gun_pierce", &"gun_homing", &"ember_core", &"trigger_on_hit"
]
const OFFER: Array[StringName] = [&"halo_shot", &"gun_ricochet", &"storm_core"]
const DIRS := ["a", "b", "c"]
const NOTES := {
	"a": "A (built): a slot line under the card; tiles say their slot; the page counts the slots",
	"b": "B: a ribbon across the card and the tag in the rarity line; pips per slot over the wand",
	"c":
	"C: a corner badge and a crossed-out mini tile of the old card; a column per slot under the wand",
}
const LANGS := ["en", "es"]
const SETTLE := 8

var _w: World
var _reader: WorldReader
var _frame := 0
var _shots: Array = []
var _at := -1
var _wait := 0
var _overlay: Control


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("as: renderer=%s" % RenderingServer.get_current_rendering_method())
	var repo := ContentRepository.load_all()
	_w = CardPoolSurvey.world(repo, SEED, &"gun", [])
	_w.wand_table = WandCompiler.from_repo(repo)
	_w.slot_table = WandCompiler.slots(repo, _w.item_tables)
	_w.floor_index = 3
	_w.run_floor = 3
	for id in HELD:
		BuildSlots.take(_w, _code(id))
	_reader = WorldReader.new(_w)
	print("as: wand %s" % str(_ids()))
	for d in DIRS:
		for screen in ["pick", "build"]:
			for lang in LANGS:
				_shots.append([d, screen, lang])


func _code(id: StringName) -> int:
	return AttackScenario.item_index(_w.item_tables, id)


func _ids() -> Array:
	var out := []
	for c in _w.mod_slots:
		out.append(_w.item_tables[c].id)
	return out


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 3000:
		print("as: gave up")
		quit(1)
		return true
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			_grab()
		return false
	_at += 1
	if _at >= _shots.size():
		print("as: done")
		quit(0)
		return true
	_show(_shots[_at])
	_wait = SETTLE
	return false


func _show(shot: Array) -> void:
	TranslationServer.set_locale(shot[2])
	if _overlay != null:
		_overlay.queue_free()
	_overlay = _pick(shot[0]) if shot[1] == "pick" else _build(shot[0])
	var cap := Label.new()
	cap.text = NOTES[shot[0]]
	cap.position = Vector2(24, 18)
	cap.add_theme_font_size_override("font_size", 22)
	cap.add_theme_color_override("font_color", Color(1, 0.85, 0.6))
	cap.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_overlay.add_child(cap)
	root.add_child(_overlay)


func _grab() -> void:
	var shot: Array = _shots[_at]
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%s_%s_%s.png" % shot
	img.save_png(path)
	print("as: ", path, " ", img.get_size())


# --- The reward cards ----------------------------------------------------------------------------------------
func _pick(dir: String) -> Control:
	var top := Control.new()
	top.size = Vector2(1920, 1080)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.07)
	bg.size = top.size
	top.add_child(bg)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.size = top.size
	top.add_child(col)
	var title := Label.new()
	title.text = tr("PICK_TITLE_ALTAR")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HudStyle.style_label(title, 28, true)
	col.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	col.add_child(row)
	for k in OFFER.size():
		var face := PickPanel.card_face(self, _reader, _code(OFFER[k]))
		var holder := VBoxContainer.new()
		holder.add_theme_constant_override("separation", 8)
		row.add_child(holder)
		var s := PickSlot.new(k)
		match dir:
			"b":
				face = _face_b(face)
			"c":
				face = _face_c(face)
		s.show_card(face)
		s.set_focused(k == 0)
		holder.add_child(s)
		if dir == "b" and face.has("ribbon"):
			_ribbon(s, String(face["ribbon"]))
		if dir == "c":
			_badge(s, face)
			holder.add_child(_mini_swap(face))
	return top


## B: no slot line; the tag goes into the rarity line and "Replaces <card>" onto a ribbon.
func _face_b(face: Dictionary) -> Dictionary:
	var out := face.duplicate()
	if face.has("slot_text"):
		out["tier_text"] = "%s · %s" % [face["slot_text"], face["tier_text"]]
	if face.has("replaces_text"):
		out["ribbon"] = String(face["replaces_text"]).to_upper()
	out.erase("slot")
	return out


## C: no slot line (a corner badge and a mini tile say it).
func _face_c(face: Dictionary) -> Dictionary:
	var out := face.duplicate()
	out.erase("slot")
	out["c_slot"] = int(face.get("slot", 0))
	return out


func _ribbon(s: PickSlot, text: String) -> void:
	var band := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#B8471E")
	box.set_corner_radius_all(4)
	band.add_theme_stylebox_override("panel", box)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 18)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	band.add_child(l)
	band.position = Vector2(-16, 64)
	band.size = Vector2(StoneCard.SIZE.x * PickSlot.PICK_SCALE + 32, 34)
	band.rotation = -0.06
	s.card.add_child(band)


func _badge(s: PickSlot, face: Dictionary) -> void:
	var slot := int(face.get("c_slot", 0))
	if slot == 0:
		return
	var b := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.08, 0.07, 0.92)
	box.border_color = MenuStyle.EMBER
	box.set_border_width_all(2)
	box.set_corner_radius_all(22)
	b.add_theme_stylebox_override("panel", box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var g := SlotGlyph.new(24.0)
	g.slot = slot
	g.color = MenuStyle.EMBER
	h.add_child(g)
	var l := Label.new()
	l.text = String(face.get("slot_text", ""))
	l.add_theme_font_size_override("font_size", 17)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	h.add_child(l)
	b.add_child(h)
	b.position = Vector2(StoneCard.SIZE.x * PickSlot.PICK_SCALE - 120, -14)
	s.card.add_child(b)


func _mini_swap(face: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	if not face.has("replaces_id"):
		var l := Label.new()
		l.text = " "
		h.add_child(l)
		return h
	var old := _mini_tile(face["replaces_id"], true)
	h.add_child(old)
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 26)
	arrow.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	h.add_child(arrow)
	h.add_child(_mini_tile(face["id"], false))
	return h


func _mini_tile(id: StringName, crossed: bool) -> Control:
	var sock := InlaySocket.new()
	sock.custom_minimum_size = Vector2(48, 48)
	var c := ItemLooks.color_of_id(id)
	sock.show_item(id, c, c)
	if crossed:
		sock.modulate = Color(0.75, 0.6, 0.55, 0.75)
		var x := Label.new()
		x.text = "✕"
		x.add_theme_font_size_override("font_size", 40)
		x.add_theme_color_override("font_color", Color("#FF6A3D"))
		x.position = Vector2(10, -4)
		x.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		sock.add_child(x)
	return sock


# --- The Build page ------------------------------------------------------------------------------------------
func _build(dir: String) -> Control:
	var page := BuildPage.new()  # full screen, as the pause menu shows it
	var wand := _reader.wand()
	page.open(wand, Wand.slots(_w))
	match dir:
		"b":
			var col := page.row.get_parent() as VBoxContainer
			col.add_child(_pips(wand))
			col.move_child(col.get_child(col.get_child_count() - 1), page.row.get_index())
		"c":
			var col := page.row.get_parent() as VBoxContainer
			col.add_child(_columns(wand))
			col.move_child(col.get_child(col.get_child_count() - 1), page.row.get_index() + 1)
	return page


func _pips(wand: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 34)
	var form := Label.new()
	form.text = tr("UI_BUILD_FORM") % tr("UI_FORM_" + String(wand["form"]).to_upper())
	form.add_theme_font_size_override("font_size", 20)
	h.add_child(form)
	for e: Array in wand["slot_counts"]:
		if int(e[0]) == WorldReader.SLOT_FORM:
			continue
		var g := SlotGlyph.new(18.0)
		g.slot = int(e[0])
		g.color = MenuStyle.EMBER
		h.add_child(g)
		var l := Label.new()
		l.text = (
			"%s %s"
			% [
				tr(WorldReader.SLOT_TAG_KEYS[int(e[0])]),
				"●".repeat(int(e[1])) + "○".repeat(int(e[2]) - int(e[1]))
			]
		)
		l.add_theme_font_size_override("font_size", 20)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		h.add_child(l)
	return h


func _columns(wand: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 48)
	var groups := {}
	for c: Dictionary in wand["cards"]:
		var s := int(c.get("slot", 0))
		if not groups.has(s):
			groups[s] = []
		(groups[s] as Array).append(tr(c["name_key"]))
	for slot in [
		WorldReader.SLOT_FORM,
		WorldReader.SLOT_PATTERN,
		WorldReader.SLOT_SECONDARY,
		WorldReader.SLOT_ELEMENT,
		0
	]:
		var v := VBoxContainer.new()
		var head := Label.new()
		head.text = tr(WorldReader.SLOT_TAG_KEYS[slot]) if slot != 0 else "—"
		head.add_theme_font_size_override("font_size", 20)
		head.add_theme_color_override("font_color", MenuStyle.EMBER)
		head.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		v.add_child(head)
		var names: Array = groups.get(slot, [])
		if slot == WorldReader.SLOT_FORM:
			names = [tr("UI_FORM_" + String(wand["form"]).to_upper())]
		for n: String in names:
			var l := Label.new()
			l.text = n
			l.add_theme_font_size_override("font_size", 18)
			l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			v.add_child(l)
		h.add_child(v)
	return h
