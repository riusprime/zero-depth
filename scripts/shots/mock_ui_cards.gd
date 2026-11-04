extends "res://scripts/shots/mock_ui_refs.gd"
## v0.10.5 W3-O13c G2, round 3 (owner, 2026-11-04: "Astral I like the most but the shape of the cards is odd, that
## pointy top is bad."): Astral's three card shapes without a pointed top (scripts/shots/mock_ui2/cards3.gd), each on
## the shop (four cards, the first focused) and the altar's pick of three, plus the focused card of each shape side by
## side, large. Round 2's plumbing (mock_ui_refs.gd): the stage run, the real shop opened with E, the game's own
## CanvasLayers hidden. A prototype for the owner to pick from, not game code.
## Needs a renderer (not --headless); open it off screen:
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/mock_ui_cards.gd
## Writes build/shots/v0.10.5/w3o13c/astral_card_<1|2|3>_<shop|pick>.png and cards_compare.png.

const OUT3 := "res://build/shots/v0.10.5/w3o13c/"
const Cards3 := preload("res://scripts/shots/mock_ui2/cards3.gd")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT3))
	print("mock_ui_cards: renderer=%s" % RenderingServer.get_current_rendering_method())
	_styles = ["astral"]
	for shape in [1, 2, 3]:
		for screen in ["shop", "pick"]:
			_jobs.append(["astral", screen, "en", shape])
	_jobs.append(["astral", "cards", "en", 0])
	ProfileStore.use_shared(ProfileStore.new(""))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


## The job's shape on round 2's painter; the comparison has no HUD under it.
func _paint(layer: CanvasLayer, style: String, kind: String, data: Dictionary) -> void:
	var j: Array = _jobs[_job]
	if kind == "hud" and j[1] == "cards":
		return
	var s := Cards3.new(style, kind, data)
	s.card_shape = int(j[3]) if int(j[3]) > 0 else 1
	var g := Glass2.new(s)
	g.size = VIEW
	layer.add_child(g)
	layer.add_child(s)


func _shot(_shot_name: String, _strip: bool) -> void:
	var j: Array = _jobs[_job]
	var shot_name := (
		"cards_compare" if j[1] == "cards" else "astral_card_%d_%s" % [int(j[3]), String(j[1])]
	)
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := ProjectSettings.globalize_path(OUT3 + shot_name + ".png")
	img.save_png(path)
	print("mock_ui_cards: shot ", path)


func _sheets() -> void:
	pass
