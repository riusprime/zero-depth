extends SceneTree
## v0.10.5 O13 (G2, docs/process/OWNER_GATES.md §3; owner P10, 2026-11-01: "ok"): three mockups of the wand forecast on
## the Build page, and the pick on the Swap panel, in English and Spanish, at 1920 × 1080. Real data: a Gun run
## (CardPoolSurvey.world, seed 5) on floor 1 holding Big Shot, Split Shot, Ember Core and Twin (BuildSlots.take under
## the shipped slot rules); the forecast is the game's own (WorldReader.wand_forecast: WandForecast, the sim's compile).
## - A (built): a "FORECAST" block under the wand: the spell left to right in ember, its numbers in one line under it.
## - B: the spell line, and the numbers as four stat chips (a big number over its caption).
## - C: A's block plus a small diagram of the volley (the shot's size, the casts each hit makes), drawn by this script.
## The Swap shot (A only) holds the same wand with Homing incoming (a Secondary: it replaces Big Shot or Split Shot):
## "AFTER THE SWAP".
## A tool, not a test; it quits on every path. Needs a renderer (not --headless):
##   godot --path . --resolution 1920x1080 --position -10000,-10000 -s scripts/shots/mock_wand_forecast.gd
## Writes build/shots/v0.10.5/o13/<a|b|c>_build_<en|es>.png and a_swap_<en|es>.png.

const OUT := "res://build/shots/v0.10.5/o13/"
const SEED := 5
const HELD: Array[StringName] = [&"gun_big_shot", &"split_shot", &"ember_core", &"gun_twin"]
const INCOMING := &"gun_homing"
const LANGS := ["en", "es"]
const SETTLE := 8
const NOTES := {
	"a":
	"A (built): a FORECAST block under the wand: the spell left to right, its numbers in one line",
	"b": "B: the spell line, and the numbers as four stat chips",
	"c": "C: A's block plus a small diagram of the volley (shot size, casts per hit)",
	"s": "A on the Swap panel: the forecast of the wand the focused answer leaves",
}
const CHIPS_EN := ["shots per attack", "damage each", "damage per second", "radius (m)"]
const CHIPS_ES := ["disparos por ataque", "daño de cada uno", "daño por segundo", "radio (m)"]

var _w: World
var _reader: WorldReader
var _frame := 0
var _shots: Array = []
var _at := -1
var _wait := 0
var _overlay: Control


class _Diagram:
	extends Control
	var forecast := {}
	var spec: AttackSpec

	func _draw() -> void:
		HudStyle.draw_plate(self, Rect2(Vector2.ZERO, size), true)
		if spec == null:
			return
		var y := size.y * 0.5
		var r := clampf(spec.radius_m * 60.0, 6.0, 30.0)
		var x := 40.0
		draw_circle(Vector2(x, y), 10.0, Color(HudStyle.TEXT, 0.5))
		x += 70.0
		draw_line(Vector2(x - 50, y), Vector2(x - r - 6, y), HudStyle.EMBER_ACCENT, 3.0)
		draw_circle(Vector2(x, y), r, HudStyle.EMBER)
		for h in spec.hooks:
			if h.child == null:
				continue
			var n := WandForecast.shots_of_child(h.child)
			var cr := clampf(h.child.radius_m * 60.0, 4.0, 24.0)
			var cx := x + r + 110.0
			for k in n:
				var a := (k - (n - 1) * 0.5) * 0.5
				var p := Vector2(cx, y) + Vector2(1, 0).rotated(a) * 40.0
				draw_line(Vector2(x + r + 4, y), p, Color(HudStyle.EMBER_ACCENT, 0.7), 2.0)
				draw_circle(p, cr, Color(HudStyle.EMBER, 0.8))
			x = cx + 60.0
			break


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("o13: renderer=%s" % RenderingServer.get_current_rendering_method())
	var repo := ContentRepository.load_all()
	_w = CardPoolSurvey.world(repo, SEED, &"gun", [])
	_w.wand_table = WandCompiler.from_repo(repo)
	_w.slot_table = WandCompiler.slots(repo, _w.item_tables)
	for id in HELD:
		BuildSlots.take(_w, _code(id))
	_reader = WorldReader.new(_w)
	print("o13: wand %s" % str(_ids()))
	for d in ["a", "b", "c"]:
		for lang in LANGS:
			_shots.append([d, "build", lang])
	for lang in LANGS:
		_shots.append(["a", "swap", lang])


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
		print("o13: gave up")
		quit(1)
		return true
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			_grab()
		return false
	_at += 1
	if _at >= _shots.size():
		print("o13: done")
		quit(0)
		return true
	_show(_shots[_at])
	_wait = SETTLE
	return false


func _show(shot: Array) -> void:
	TranslationServer.set_locale(shot[2])
	if _overlay != null:
		_overlay.queue_free()
	_overlay = _swap() if shot[1] == "swap" else _build(shot[0], shot[2])
	var cap := Label.new()
	cap.text = NOTES["s" if shot[1] == "swap" else shot[0]]
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
	var f := _reader.wand_forecast()
	var words := WorldReader.wand_forecast_text(f, func(k: StringName) -> String: return tr(k))
	print("o13: ", path, " ", img.get_size(), " | ", words[0], " | ", words[1])


func _build(dir: String, lang: String) -> Control:
	var page := BuildPage.new()
	page.open(_reader.wand(), Wand.slots(_w), _reader)
	var col := page.row.get_parent() as VBoxContainer
	match dir:
		"b":
			page.forecast.get_node("Numbers").visible = false
			var chips := HBoxContainer.new()
			chips.add_theme_constant_override("separation", 36)
			var n: Dictionary = _reader.wand_forecast()["numbers"]
			var vals := [
				str(n["shots"]),
				str(n["damage"]),
				"%.1f" % (int(n["per_second_x10"]) / 10.0),
				"%.2f" % (int(n["area_mm"]) / 1000.0),
			]
			var caps: Array = CHIPS_EN if lang == "en" else CHIPS_ES
			for k in 4:
				var v := VBoxContainer.new()
				var big := Label.new()
				big.text = vals[k]
				big.add_theme_font_override("font", HudStyle.font(true))
				big.add_theme_font_size_override("font_size", 40)
				big.add_theme_color_override("font_color", HudStyle.EMBER_ACCENT)
				var small := Label.new()
				small.text = caps[k]
				small.add_theme_font_size_override("font_size", 15)
				small.add_theme_color_override("font_color", MenuStyle.DIM)
				for l: Label in [big, small]:
					l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
					v.add_child(l)
				chips.add_child(v)
			col.add_child(chips)
			col.move_child(chips, page.forecast.get_index() + 1)
		"c":
			var d := _Diagram.new()
			d.spec = Modifiers.bolt(_w)
			d.custom_minimum_size = Vector2(420, 110)
			col.add_child(d)
			col.move_child(d, page.forecast.get_index() + 1)
	return page


func _swap() -> Control:
	var w := CardPoolSurvey.world(ContentRepository.load_all(), SEED, &"gun", [])
	w.wand_table = _w.wand_table
	w.slot_table = WandCompiler.slots(ContentRepository.load_all(), w.item_tables)
	for id in HELD:
		BuildSlots.take(w, _code(id))
	BuildSlots.open_swap(w, _code(INCOMING), BuildSlots.Source.GRANT, -1)
	var r := WorldReader.new(w)
	print("o13: swapping=%s" % r.swapping())
	var top := Control.new()
	top.size = Vector2(1920, 1080)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.07)
	bg.size = top.size
	top.add_child(bg)
	var panel := SwapPanel.new()
	top.add_child(panel)
	panel.sync(r)
	print("o13: swap forecast | %s" % ", ".join(panel.forecast_ids()))
	return top
