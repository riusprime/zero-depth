extends SceneTree
## v0.9.0 AS2 (owner, step AS's G2: "B: ribbon + pips"; "Let me choose"; straight edges): the built look, at
## 1920 × 1080. Real data from a fixed seed: a Gun run (CardPoolSurvey.world, seed 5) on floor 3 holding Twin, Pierce,
## Homing, Ember Core and On Hit (taken through BuildSlots.take). Shots:
## - pick_<en|es>: an altar's Halo (a Pattern: "Replaces Twin"), Ricochet (a full Secondary slot: "Choose one to
##   replace") and Storm Core (an Element with room), the game's own PickSlot faces;
## - build_en: the Build page with the slot pips over the wand;
## - swap_en: the Swap panel choosing which Secondary Ricochet replaces (the others dimmed);
## - menu_en: the pause menu, its slabs' straight edges.
## A tool, not a test; it quits on every path. Needs a renderer (not --headless):
##   godot --path . --resolution 1920x1080 -s scripts/shots/attack_slots_2.gd
## Writes build/shots/v0.9.0/as2/<name>.png. Evidence copies are made by hand.

const OUT := "res://build/shots/v0.9.0/as2/"
const SEED := 5
const HELD: Array[StringName] = [
	&"gun_twin", &"gun_pierce", &"gun_homing", &"ember_core", &"trigger_on_hit"
]
const OFFER: Array[StringName] = [&"halo_shot", &"gun_ricochet", &"storm_core"]
const SHOTS := [["pick", "en"], ["pick", "es"], ["build", "en"], ["swap", "en"], ["menu", "en"]]
const SETTLE := 10

var _w: World
var _frame := 0
var _at := -1
var _wait := 0
var _overlay: Control


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("as2: renderer=%s" % RenderingServer.get_current_rendering_method())
	var repo := ContentRepository.load_all()
	_w = CardPoolSurvey.world(repo, SEED, &"gun", [])
	_w.wand_table = WandCompiler.from_repo(repo)
	_w.slot_table = WandCompiler.slots(repo, _w.item_tables)
	_w.floor_index = 3
	_w.run_floor = 3
	for id in HELD:
		BuildSlots.take(_w, _code(id))


func _code(id: StringName) -> int:
	return AttackScenario.item_index(_w.item_tables, id)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 3000:
		print("as2: gave up")
		quit(1)
		return true
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			_grab()
		return false
	_at += 1
	if _at >= SHOTS.size():
		print("as2: done")
		quit(0)
		return true
	_show(SHOTS[_at])
	_wait = SETTLE
	return false


func _show(shot: Array) -> void:
	TranslationServer.set_locale(shot[1])
	if _overlay != null:
		_overlay.queue_free()
	BuildSlots.close_swap(_w)
	match shot[0]:
		"pick":
			_overlay = _pick()
		"build":
			var page := BuildPage.new()
			page.open(WorldReader.new(_w).wand(), Wand.slots(_w))
			_overlay = page
		"swap":
			BuildSlots.open_swap(_w, _code(&"gun_ricochet"), BuildSlots.Source.REWARD, 1)
			var panel := SwapPanel.new()
			_overlay = panel
			root.add_child(panel)
			panel.sync(WorldReader.new(_w))
			return
		"menu":
			var m := PauseMenu.new()
			m.show_run(3, 222.0, 87, 146)
			_overlay = m
	root.add_child(_overlay)


func _pick() -> Control:
	var reader := WorldReader.new(_w)
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
		var s := PickSlot.new(k)
		s.show_card(PickPanel.card_face(self, reader, _code(OFFER[k])))
		s.set_focused(k == 0)
		row.add_child(s)
	return top


func _grab() -> void:
	var shot: Array = SHOTS[_at]
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "%s_%s.png" % shot
	img.save_png(path)
	print("as2: ", path, " ", img.get_size())
