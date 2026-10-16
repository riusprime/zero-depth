extends SceneTree
## v0.8.0 N1 (owner O54, D42 "(a)"): the glyph badges a card's socket wears, one socket each: a plain Blade card
## (the crossed blades), a Legendary card (the star burst), an elemental card (its element) and a plain card (none).
## Needs a renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 1920x1080 -s scripts/shots/n1_glyphs.gd (the sockets sit top left)
## Writes build/shots/v0.8.0/n1/glyphs.png and prints each socket's glyph. Quits on every path.

const CARDS: Array[StringName] = [
	&"flurry", &"long_edge", &"chain_blast", &"inferno_core", &"ember_edge", &"swift_feet"
]
const OUT := "res://build/shots/v0.8.0/n1/"

var _frame := 0


func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	for k in CARDS.size():
		var s := InlaySocket.new()
		s.position = Vector2(30 + k * 150, 60)
		s.size = Vector2(120, 120)
		root.add_child(s)
		var col := ItemLooks.color_of_id(CARDS[k])
		s.show_item(CARDS[k], col, col)
		var l := Label.new()
		l.text = "%s\n%s" % [CARDS[k], s.element if s.element != &"" else "(none)"]
		l.position = Vector2(30 + k * 150, 190)
		l.size = Vector2(120, 60)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(l)
		print("n1_glyphs: %s -> %s (shows=%s)" % [CARDS[k], s.element, str(s.shows_glyph())])


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 6:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png(OUT + "glyphs.png")
		print("n1_glyphs: %sglyphs.png %s" % [OUT, str(img.get_size())])
	quit(0)
	return true
