extends SceneTree
## v0.10.5 W3-S17: the overlevel pick card (loop 2, a wand card held at its max) in the real pick panel.
## A tool, not a test:
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/w3s17_overlevel.gd
## Writes build/shots/v0.10.5/w3s17/overlevel.png.

const OUT := "res://build/shots/v0.10.5/w3s17/"
var _frame := 0
var _top: Control


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	TranslationServer.set_locale("en")
	var repo := ContentRepository.load_all()
	_top = Control.new()
	_top.size = Vector2(1920, 1080)
	var bg := ColorRect.new()
	bg.color = Color("#0A0D18")
	bg.size = _top.size
	_top.add_child(bg)
	root.add_child(_top)
	var w := CardPoolSurvey.world(repo, 4242, &"gun", [])
	var pierce := -1
	for k in w.item_tables.size():
		if pierce < 0 and CardLevels.is_card(w, k):
			pierce = k
	w.loop = 2
	w.add_item(pierce)
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(1, 0), 0)
	w.rewards.set_offer(w.rewards.size() - 1, PackedInt32Array([pierce]))
	CardLevels.set_level(w, pierce, CardLevels.max_level(w, pierce))
	w.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, InputFrame.INTERACT))
	var p := PickPanel.new()
	_top.add_child(p)
	p.sync(WorldReader.new(w))
	p.skip_deal()
	p._set_focus(0)
	p.set_process(false)
	p.deal.time = p.deal.length() + 3.0
	print("w3s17: badge = ", p.slot(0).card.level_text())


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 30:
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_png(OUT + "overlevel.png")
		print("w3s17: saved")
		quit(0)
	return false
