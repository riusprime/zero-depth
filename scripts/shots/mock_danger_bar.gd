extends SceneTree
## v0.10.5 O6 (G2, docs/process/OWNER_GATES.md §3; owner P4, 2026-11-01): three mockups of the top plate with the
## ember teeth replaced by a thin hazard-striped danger bar shaped like the HP bar (green → yellow → red, blinking
## when full) and the depths' answer (the floor's catch-up m) as a small separate tag. English and Spanish, 1920 x 1080.
## The frame is the real game: main.tscn, a run started from code (the profile and run saves in memory), floor 1 of
## the default seed, posed at 5:00 of floor time (tier 6 and two thirds of the way to 7) with the player invulnerable,
## and the floor's catch-up read as if the build were twice the expected power (P 2000 / E 1000: m = ×1.41, the
## blueprint's §H example; CatchUp.multiplier, the sim's own function). The real HUD draws the bar and the tag; for A
## and B this script rearranges them (built here, not shipped). An inset on the left shows the bar's states at 2×.
## - A: inline: a short bar (150 × 8) between the time and the kills; the tag is the number alone ("×1.41") in the row.
## - B: wide: the bar runs the plate's width (500 × 6) under the time and the kills; the tag, in words, under it.
## - C: HP twin: a 190 × 9 bar in the row, with the tier number; the tag, in words, hangs under the plate's right end.
## A tool, not a test; it quits on every path. Needs a renderer (not --headless):
##   godot --path . --resolution 1920x1080 --position -10000,-10000 -s scripts/shots/mock_danger_bar.gd
## Writes build/shots/v0.10.5/o6/<a|b|c>_<en|es>.png.

const OUT := "res://build/shots/v0.10.5/o6/"
const VARIANTS := ["c", "a", "b"]
const LANGS := ["en", "es"]
const SETTLE := 12
const POSE_S := 300.0
const POWER := 2000
const EXPECTED := 1000
## The inset's states: [fill, brightness, caption key].
const STATES := [
	[0.15, 1.0, "MOCK_EARLY"],
	[0.5, 1.0, "MOCK_MID"],
	[0.8, 1.0, "MOCK_LATE"],
	[1.0, 1.0, "MOCK_FULL_ON"],
	[1.0, DangerMeter.BLINK_LOW, "MOCK_FULL_OFF"],
]
const TEXTS := {
	"en":
	{
		"MOCK_CAP_A": "A — Inline: a short bar between time and kills; the tag is the number alone",
		"MOCK_CAP_B": "B — Wide: the bar spans the plate under the row; the tag in words under it",
		"MOCK_CAP_C":
		"C — HP twin: a 190 px bar in the row; the tag in words under the plate's right end",
		"MOCK_STATES": "The bar's states (2×)",
		"MOCK_EARLY": "15 %",
		"MOCK_MID": "50 %",
		"MOCK_LATE": "80 %",
		"MOCK_FULL_ON": "full: blink, bright",
		"MOCK_FULL_OFF": "full: blink, dim",
	},
	"es":
	{
		"MOCK_CAP_A":
		"A — En línea: una barra corta entre el tiempo y las bajas; la etiqueta es solo el número",
		"MOCK_CAP_B":
		"B — Ancha: la barra cruza la placa bajo la fila; la etiqueta en palabras debajo",
		"MOCK_CAP_C":
		"C — Gemela de la vida: barra de 190 px en la fila; la etiqueta bajo el extremo derecho",
		"MOCK_STATES": "Estados de la barra (2×)",
		"MOCK_EARLY": "15 %",
		"MOCK_MID": "50 %",
		"MOCK_LATE": "80 %",
		"MOCK_FULL_ON": "lleno: parpadeo, claro",
		"MOCK_FULL_OFF": "lleno: parpadeo, tenue",
	},
}

var main: Main
var _hud: Hud
var _row: HBoxContainer
var _col: VBoxContainer
var _own_tag := DepthsTag.new()
var _inset := _Inset.new()
var _step := 0
var _frames := 0
var _at := -1
var _wait := 0


class _Inset:
	extends Control
	var variant := "c"
	var lang := "en"
	var bar := DangerMeter.SIZE

	func _draw() -> void:
		var t: Dictionary = TEXTS[lang]
		var font := HudStyle.font(true)

		var w := maxf(bar.x * 2.0 + 40.0, 760.0)
		var h := 76.0 + STATES.size() * (bar.y * 2.0 + 30.0)
		HudStyle.draw_plate(self, Rect2(0, 0, w, h), true)
		var cap: String = t["MOCK_CAP_" + variant.to_upper()]
		draw_string(font, Vector2(20, 30), cap, HORIZONTAL_ALIGNMENT_LEFT, w - 30, 15)
		draw_string(
			font,
			Vector2(20, 58),
			t["MOCK_STATES"],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color(HudStyle.TEXT, 0.8)
		)
		var y := 82.0
		for s: Array in STATES:
			draw_string(
				font,
				Vector2(20, y + 4),
				t[s[2]],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				13,
				Color(HudStyle.TEXT, 0.7)
			)
			draw_set_transform(Vector2(20, y + 10), 0.0, Vector2(2, 2))
			DangerMeter.draw_bar(self, Rect2(Vector2.ZERO, bar), s[0], s[1])
			draw_set_transform(Vector2.ZERO)
			y += bar.y * 2.0 + 30.0


static func _bar(v: String) -> Vector2:
	match v:
		"a":
			return Vector2(150, 8)
		"b":
			return Vector2(500, 6)
	return DangerMeter.SIZE


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	print("mock_danger_bar: renderer=%s" % RenderingServer.get_current_rendering_method())
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var layer := CanvasLayer.new()
	layer.layer = 90
	root.add_child(layer)
	_inset.position = Vector2(40, 330)
	_inset.size = Vector2(1100, 400)
	layer.add_child(_inset)
	_own_tag.short = true


func _world() -> World:
	return main.driver.world


func _pose() -> void:
	var w := _world()
	w.actors.invuln[0] = 1 << 24
	w.run_ticks = SimTick.seconds_to_ticks(POSE_S)
	var s := w.catch_up
	s.power = POWER
	s.expected = EXPECTED
	s.enemy = CatchUp.multiplier(POWER, EXPECTED, s.cap)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 6000:
		push_error("mock_danger_bar: stuck at step %d" % _step)
		quit(1)
		return true
	match _step:
		0:
			if _frames == 3:
				main.start_stage()
				_step = 1
		1:
			if (
				main.driver != null
				and not main.loads.cover.showing()
				and main.driver.reader.arrival_progress() < 0.0
				and _frames > 60
			):
				_hud = main.get_node("UI/Hud")
				_row = _hud.danger_meter().get_parent()
				_col = _row.get_parent()
				_step = 2
				_frames = 0
		2:
			_pose()
			if _wait > 0:
				_wait -= 1
				if _wait == 0:
					_grab()
				return false
			_at += 1
			if _at >= VARIANTS.size() * LANGS.size():
				print("mock_danger_bar: done")
				quit(0)
				return true
			_layout(VARIANTS[_at / LANGS.size()])
			TranslationServer.set_locale(LANGS[_at % LANGS.size()])
			_inset.variant = VARIANTS[_at / LANGS.size()]
			_inset.lang = LANGS[_at % LANGS.size()]
			_inset.bar = _bar(_inset.variant)
			_inset.queue_redraw()
			_wait = SETTLE
	return false


## Puts the real meter and a tag where variant `v` wants them.
func _layout(v: String) -> void:
	var meter := _hud.danger_meter()
	var real_tag := _hud.depths_tag
	if _own_tag.get_parent() != null:
		_own_tag.get_parent().remove_child(_own_tag)
	meter.get_parent().remove_child(meter)
	real_tag.modulate.a = 1.0 if v == "c" else 0.0
	match v:
		"a":
			meter.show_number = true
			_row.add_child(meter)
			_row.move_child(meter, 1)
			_own_tag.short = true
			_row.add_child(_own_tag)
			_row.move_child(_own_tag, 2)
		"b":
			meter.show_number = false
			_col.add_child(meter)
			meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_own_tag.short = false
			_own_tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_col.add_child(_own_tag)
		_:
			meter.show_number = true
			_row.add_child(meter)
			_row.move_child(meter, 1)
	meter.resize_to(_bar(v))
	_own_tag.set_multiplier(main.driver.reader.catch_up_permille())


func _grab() -> void:
	_own_tag.set_multiplier(main.driver.reader.catch_up_permille())
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var v: String = VARIANTS[_at / LANGS.size()]
	var lang: String = LANGS[_at % LANGS.size()]
	var path := OUT + "%s_%s.png" % [v, lang]
	img.save_png(path)
	var r := main.driver.reader
	print(
		(
			"mock_danger_bar: %s %s tier=%d progress=%.3f fill=%.3f m=%d"
			% [
				path,
				img.get_size(),
				r.tier(),
				r.tier_progress(),
				_hud.danger_meter().fill(),
				r.catch_up_permille()
			]
		)
	)
