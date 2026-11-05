extends SceneTree
## v0.10.5 W3-O12 (owner, 2026-11-04; docs/roadmap/v0.10.5/W3_O12_VFX_GALLERY.md): the Effects gallery's contact sheets.
## With `-- --sheets`, every group's grid pages (EffectsGallery, the same stages the dev menu's gallery shows: each
## entry live in its own game view, labelled with its name and source), one PNG per page:
##   build/shots/v0.10.5/w3o12/<group>.png (one page) or <group>_<n>.png (several).
## `--groups=hero,bosses` keeps those groups; `--pages=N` at most N pages per group (a quick look).
## A tool, not a test. Needs a renderer (no --headless), off screen:
##   godot --position -10000,-10000 --path . --fixed-fps 60 --audio-driver Dummy --resolution 1920x1080 \
##     -s scripts/shots/vfx_gallery.gd -- --sheets
## Prints each path it writes. The gallery's own keys are off for the run, and the group and page are pinned each
## frame (W3-S21: stray input once switched them mid-run, so `--groups=` sheets showed another group).

const DIR := "res://build/shots/v0.10.5/w3o12/"
## When a page's picture is taken. A hero page: at its stages' tick HERO_TICK (Shoot held, a swing and the recipe's
## buttons 8 ticks old: EffectStage's loop; the Vent's cooldown allows only the first); an enemy or boss page at
## FIGHT_TICK (their attacks under way). A pack page: SHOT_S into its stages' second play (the shaders
## compiled in the first), when a burst is near its brightest and a flying effect has left the hand.
const HERO_TICK := EffectStage.PRESS_EVERY / 2 + 8
const FIGHT_TICK := 308
const SHOT_S := 0.1
## Frames at most per page (a page that never gets there is taken anyway).
const MAX_FRAMES := 900

var _gallery: EffectsGallery
var _groups: Array[int] = []
var _g := 0
var _frame := 0
var _page := 0
var _max_pages := 0
var _written := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--sheets"):
		print("vfx_gallery: pass -- --sheets")
		quit(1)
		return
	for a in args:
		if a.begins_with("--groups="):
			for id in a.trim_prefix("--groups=").split(","):
				var k := EffectsCatalog.GROUPS.find(StringName(id))
				if k >= 0:
					_groups.append(k)
		elif a.begins_with("--pages="):
			_max_pages = int(a.trim_prefix("--pages="))
	if _groups.is_empty():
		for k in EffectsCatalog.GROUPS.size():
			_groups.append(k)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	ViewPrefs.effects_density = "high"
	_gallery = EffectsGallery.new(EffectsCatalog.build())
	root.add_child(_gallery)
	_gallery.grid = true
	_mute_input()
	_gallery.set_group(_groups[0])


## The gallery's keys and clicks (group, page, grid) are off: only this script turns its pages.
func _mute_input() -> void:
	_gallery.set_process_unhandled_input(false)
	_gallery.set_process_input(false)


## Puts the gallery back on this run's group and page if anything moved it; true when it had to.
func _pin() -> bool:
	if _gallery.group == _groups[_g] and _gallery.page == _page:
		return false
	_gallery.set_group(_groups[_g])
	for i in _page:
		_gallery.next()
	return true


func _ready_to_shoot() -> bool:
	if _gallery.stages.is_empty():
		return true
	var s := _gallery.stages[0]
	if s.entry["kind"] == &"pack":
		return s.loops >= 2 and s.loop_t >= SHOT_S
	return s.ticks >= (HERO_TICK if s.entry["group"] == &"hero" else FIGHT_TICK)


func _process(_delta: float) -> bool:
	if _gallery == null:
		return true
	_mute_input()
	if _pin():
		_frame = 0
	_frame += 1
	if not _ready_to_shoot() and _frame < MAX_FRAMES:
		return false
	_frame = 0
	var n := _gallery.pages() if _max_pages <= 0 else mini(_max_pages, _gallery.pages())
	var file := String(_gallery.group_id())
	if _gallery.pages() > 1:
		file += "_%d" % (_gallery.page + 1)
	var img := root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(DIR + file + ".png")
	print("vfx_gallery: ", DIR + file + ".png")
	_written += 1
	if _gallery.page + 1 < n:
		_gallery.next()
		_page += 1
		return false
	_g += 1
	_page = 0
	if _g >= _groups.size():
		print("vfx_gallery: %d sheets" % _written)
		return true
	_gallery.set_group(_groups[_g])
	return false
