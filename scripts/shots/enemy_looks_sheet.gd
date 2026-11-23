extends SceneTree
## The contact sheet of one biome's four enemy-look stills (enemy_looks.gd): now, a / b / c in a 2 x 2 grid.
## godot --headless --path . -s scripts/shots/enemy_looks_sheet.gd -- biome=red_canyon


func _initialize() -> void:
	var biome := String(ScriptArgs.parse().get("biome", "red_canyon"))
	var dir := ProjectSettings.globalize_path(
		"res://build/shots/%s/enemy_looks/" % GameVersion.label()
	)
	var look_ids := ["now", "a", "b", "c"]
	var cells: Array[Image] = []
	for l in look_ids:
		var img := Image.load_from_file("%s%s_%s.png" % [dir, biome, l])
		if img == null:
			print("enemy_looks_sheet: missing %s_%s.png" % [biome, l])
			quit(1)
			return
		cells.append(img)
	var w := cells[0].get_width()
	var h := cells[0].get_height()
	var sheet := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for k in cells.size():
		sheet.blit_rect(cells[k], Rect2i(0, 0, w, h), Vector2i((k % 2) * w, (k / 2) * h))
	var path := "%s%s_sheet.png" % [dir, biome]
	sheet.save_png(path)
	print("enemy_looks_sheet: ", path)
	quit(0)
