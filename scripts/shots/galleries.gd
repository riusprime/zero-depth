extends SceneTree
## Captures the v0.0.1 gallery shots (PLAN Step 7) to build/shots/v0.0.1/en/. Needs a renderer:
##   xvfb-run -a godot --path . --resolution 1600x900 -s scripts/shots/galleries.gd [-- only=<prefix>]
## Run twice for the renderer gate: as is (Forward+), and with --rendering-method gl_compatibility.

const OUT := "res://build/shots/v0.0.1/en/"
const SHOTS := [
	# [name, biome, pitch, technique, occlusion]
	["camera_pitch30", &"ruins", 30.0, &"xray", true],
	["camera_pitch35", &"ruins", 35.26, &"xray", true],
	["camera_pitch45", &"ruins", 45.0, &"xray", true],
	["occlusion_none", &"ruins", 35.26, &"outline", false],
	["occlusion_fade", &"ruins", 35.26, &"outline", true],
	["occlusion_xray", &"ruins", 35.26, &"xray", false],
	["occlusion_fade_xray", &"ruins", 35.26, &"xray", true],
	["biome_ruins", &"ruins", 35.26, &"xray", true],
	["biome_night_rocks", &"night_rocks", 35.26, &"xray", true],
	["biome_red_canyon", &"red_canyon", 35.26, &"xray", true],
	["biome_frozen_shore", &"frozen_shore", 35.26, &"xray", true],
]

var _index := -1
var _frames := 0
var _gallery: Gallery
var _suffix := ""
var _only := ""


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_suffix = "_" + RenderingServer.get_current_rendering_method()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			_only = arg.trim_prefix("only=")
	print(
		(
			"galleries: renderer=%s device=%s"
			% [_suffix.substr(1), RenderingServer.get_video_adapter_name()]
		)
	)
	_next()


func _next() -> void:
	if _gallery != null:
		_gallery.queue_free()
	_index += 1
	while _index < SHOTS.size() and not String(SHOTS[_index][0]).begins_with(_only):
		_index += 1
	if _index >= SHOTS.size():
		quit(0)
		return
	var s: Array = SHOTS[_index]
	_gallery = Gallery.new()
	root.add_child(_gallery)
	_gallery.setup(s[1], s[2], s[3], s[4])
	_frames = 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 8 and _index < SHOTS.size():
		var path := OUT + String(SHOTS[_index][0]) + _suffix + ".png"
		root.get_texture().get_image().save_png(path)
		print("galleries: ", path)
		_next()
	return false
