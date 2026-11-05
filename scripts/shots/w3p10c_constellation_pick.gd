extends SceneTree
## v0.10.5 W3-P10c: a new loop's Constellation pick (ConstellationPanel) on the owner's violet Constellation frames,
## the deal settled and the first card focused. Real sim state: the reward-card tests' world (CardPoolSurvey.world,
## seed 4242, the Gun) with a loop's offer of Prism, Glass Sky and Hunter's Sky open. A tool, not a test; it quits on
## every path. Needs a renderer (not --headless):
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/w3p10c_constellation_pick.gd
## Writes build/shots/v0.10.5/w3p10c/pick.png.

const OUT := "res://build/shots/v0.10.5/w3p10c/"
const SETTLE := 30

var _frame := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	TranslationServer.set_locale("en")
	var top := Control.new()
	top.size = Vector2(1920, 1080)
	var bg := ColorRect.new()
	bg.color = Color("#0A0D18")
	bg.size = top.size
	top.add_child(bg)
	root.add_child(top)
	var w := CardPoolSurvey.world(ContentRepository.load_all(), 4242, &"gun", [])
	w.constellation_offer = PackedInt32Array(
		[Constellations.PRISM, Constellations.GLASS_SKY, Constellations.HUNTERS_SKY]
	)
	var p := ConstellationPanel.new()
	top.add_child(p)
	p.sync(WorldReader.new(w))
	p.skip_deal()
	p._set_focus(0)
	p.deal.time = p.deal.length() + 3.0  # the deal settled


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < SETTLE:
		return false
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := OUT + "pick.png"
	img.save_png(path)
	print("w3p10c: ", path, " ", img.get_size())
	quit(0)
	return true
