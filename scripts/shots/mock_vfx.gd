extends SceneTree
## G2 "Effects" mockup (owner, 2026-10-09: "fire, bombs, electrical … fire should be fire"): the player's fire,
## bomb and electric forms in a lit Ruins room, before (the flat v0.6.0 look: ground circles and box particles) and
## after (the VfxLayer: the owner's textures, light flashes, scorch marks). Boots main.tscn, starts a run with keys,
## then spawns each scene's effects round the hero at fixed ages.
## Saves PNGs to build/shots/<version>/vfx/. Needs a renderer (not --headless):
##   xvfb-run -a godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mock_vfx.gd
## Optional (after --): scenes=fire,all, zoom=14 (the ortho camera size), biome=night_rocks.

const SETTLE := 40
const SHOT_WAIT := 10

var _main: Main
var _frame := 0
var _dir := ""
var _zoom := 0.0
var _biome: StringName = &"ruins"
var _jobs: Array = []
var _wait := 0
var _phase := 0
var _scenes: Array = [
	"fire", "bomb", "bomb_smoke", "electric", "all", "frost", "venom", "void", "bleed", "status"
]
## Scene "status": the dummies added by the hero (their ids), given statuses each frame.
var _dummies: Array[int] = []
var _layer: VfxLayer
## This scene's effects and the age each is held at: [effect, age]. The clock runs on (software rendering is slow),
## so each frame sets every effect's start back to hold its age.
var _held: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("zoom="):
			_zoom = float(arg.trim_prefix("zoom="))
		elif arg.begins_with("scenes="):
			_scenes = Array(arg.trim_prefix("scenes=").split(","))
		elif arg.begins_with("biome="):
			_biome = StringName(arg.trim_prefix("biome="))
	_dir = "res://build/shots/%s/vfx/" % GameVersion.label()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	for scene: String in _scenes:
		for variant in ["before", "after"]:
			_jobs.append([scene, variant])


func _process(_delta: float) -> bool:
	_frame += 1
	match _phase:
		0:
			if _frame in [10, 20]:
				_key(KEY_ENTER, true)
			elif _frame in [11, 21]:
				_key(KEY_ENTER, false)
			elif _frame == 40:
				if _main.run == null:
					_main.start_stage()
				_main._end_floor()
				_main._run_biomes = [_biome, _biome, _biome, _biome] as Array[StringName]
				_main._start_floor()
				if _zoom > 0.0:
					_main.view.rig.view_size = _zoom
				_wait = SETTLE
				_phase = 1
		1:
			_wait -= 1
			if _wait <= 0:
				_layer = _main.view.attack_forms.vfx
				_phase = 2
		2:
			if _jobs.is_empty():
				quit(0)
				return false
			var job: Array = _jobs[0]
			_stage(job[0], job[1] == "after")
			_wait = SHOT_WAIT
			_phase = 3
		3:
			var forms: AttackFormView = _main.view.attack_forms
			if _jobs[0][0] == "status":
				_hold_statuses()
			for pair: Array in _held:
				(pair[0] as Dictionary)["start"] = float(forms._tick) - float(pair[1])
			_wait -= 1
			if _wait <= 0:
				var job: Array = _jobs.pop_front()
				_shot("%s_%s_%s" % [job[0], job[1], _biome])
				_phase = 2
	return false


## Clears the canvas and spawns `scene`'s effects round the hero, with the VfxLayer on (after) or off (before).
func _stage(scene: String, after: bool) -> void:
	var forms: AttackFormView = _main.view.attack_forms
	forms.clear()
	_held.clear()
	if _layer != null:
		_layer.clear_marks()
		_main.view.status_fx.vfx = _layer if after else null
		_layer.visible = after
		forms.vfx = _layer if after else null
	var hero := _main.view.reader.player_pos()
	var now := float(forms._tick)
	if scene in ["fire", "all"]:
		_at(
			forms,
			{"form": 4, "elements": ["ember"], "radius_m": 2.0, "life_ticks": 240},
			hero + Vector2(3.2, 0.5),
			0.0,
			now,
			50.0
		)
	if scene in ["bomb", "all"]:
		_lob(forms, hero + Vector2(-1.0, -1.0), now, 4.0)
	if scene == "bomb_smoke":
		_lob(forms, hero + Vector2(-1.0, -1.0), now, 30.0)
	if scene in ["electric", "all"]:
		_at(
			forms,
			{"form": 3, "elements": ["storm"]},
			hero,
			-0.6,
			now,
			2.0,
			{"to": hero + Vector2(4.5, -2.6)}
		)
		_at(forms, {"form": 2, "elements": ["storm"], "radius_m": 3.0}, hero, 0.0, now, 10.0)
		_at(
			forms,
			{"form": 4, "elements": ["storm"], "radius_m": 1.8, "life_ticks": 240},
			hero + Vector2(-3.4, 2.4),
			0.0,
			now,
			40.0
		)

	if scene == "status" and _dummies.is_empty():
		var w: World = _main.driver.world
		for off: Vector2 in [
			Vector2(2.2, 0.6), Vector2(-2.2, 0.8), Vector2(0.6, 2.4), Vector2(-0.4, -2.4)
		]:
			_dummies.append(w.add_dummy(hero + off, 0.4, 100000))
	for el: String in ["frost", "venom", "void", "bleed"]:
		if scene == el:
			_element_scene(forms, el, hero, now)


## One element on four forms round the hero: a patch, a ring, a beam and a bomb just landed.
func _element_scene(forms: AttackFormView, el: String, hero: Vector2, now: float) -> void:
	_at(
		forms,
		{"form": 4, "elements": [el], "radius_m": 2.0, "life_ticks": 240},
		hero + Vector2(3.2, 0.5),
		0.0,
		now,
		50.0
	)
	_at(forms, {"form": 2, "elements": [el], "radius_m": 2.6}, hero, 0.0, now, 10.0)
	_at(
		forms,
		{"form": 3, "elements": [el]},
		hero,
		-0.6,
		now,
		2.0,
		{"to": hero + Vector2(4.5, -2.6)}
	)
	var e := _at(
		forms,
		{"form": 6, "elements": [el], "reach_m": 4.5, "radius_m": 1.8},
		hero + Vector2(-1.0, -1.0),
		-0.5,
		now,
		0.0
	)
	_held[-1][1] = float(e.get("flight", float(e["life"]) * 0.75)) + 8.0


## Scene "status": four dummies by the hero, burning, frozen, poisoned, and bleeding and shocked. The stacks are set
## on the world each frame (the sim would let them run out); StatusVisuals draws them through its real path.
func _hold_statuses() -> void:
	var w: World = _main.driver.world
	var a := w.actors
	var looks: Array = [
		{"burn_stacks": 6, "burn_t": 120},
		{"frozen_t": 30},
		{"poison_stacks": 6, "poison_t": 120},
		{"bleed_stacks": 7, "bleed_t": 120, "shock_stacks": 3, "shock_t": 120},
	]
	for k in _dummies.size():
		var i := a.ids.find(_dummies[k])
		if i < 0:
			continue
		for field: String in looks[k]:
			var arr: PackedInt32Array = a.get(field)
			arr[i] = int(looks[k][field])
			a.set(field, arr)


func _at(
	forms: AttackFormView,
	spec: Dictionary,
	at: Vector2,
	angle: float,
	now: float,
	age: float,
	opts: Dictionary = {}
) -> Dictionary:
	spec["elements"] = PackedStringArray(spec["elements"])
	opts["start"] = now - age
	var e := forms.spawn(spec, at, angle, opts)
	_held.append([e, age])
	return e


## An ember bomb thrown 4.5 m up and right, `after_landing` ticks after it lands.
func _lob(forms: AttackFormView, from: Vector2, now: float, after_landing: float) -> void:
	var e := _at(
		forms,
		{"form": 6, "elements": ["ember"], "reach_m": 4.5, "radius_m": 1.8},
		from,
		-0.5,
		now,
		0.0
	)
	var flight: float = e.get("flight", float(e["life"]) * 0.75)
	_held[-1][1] = flight + after_landing


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _shot(name: String) -> void:
	var path := _dir + name + ".png"
	root.get_texture().get_image().save_png(path)
	print("mock_vfx: ", path)
