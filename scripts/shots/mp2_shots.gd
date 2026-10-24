extends SceneTree
## v0.9.0 MP2 (owner, PLAN "Owner decisions" MP2): the robe prices, the "???" robe and the two epic robes, in the real
## main.tscn on a memory-only profile (a tool, not a test: 600 Rune Fragments banked, nothing bought). Per language:
## the Progression Station's panel with "???" shown, then after buying it (revealed). Then (en only: no text) the hero
## in the hub in each epic robe, the camera zoomed 3x (IsoRig.flourish_zoom): front (three-quarter, toward the
## camera), back, and moving (the move keys held), Effects density Low, and in the hub (zoom 1.5); and today's Cream
## cloak front and back to compare.
## Needs a renderer (the GPU on the owner's PC):
##   godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mp2_shots.gd
## Writes build/shots/v0.9.0/mp2/<lang>_<shot>.png (copy the ones the owner looks at into the evidence by hand).

const OUT := "res://build/shots/v0.9.0/mp2/"
const LANGS: Array[String] = ["en", "es"]
const SETTLE := 70
## Facing away from the camera (up the screen) and three-quarters toward it, in 4096ths of a turn.
const AWAY := 1536
## How long the moving shots hold the key before the picture (the cloak streaming, the trail out behind).
const MOVE_FRAMES := 34
const TOWARD := 3584
## [shot, robe, facing, density, zoom, moving]
const HEROES: Array = [
	["cream_front", &"cream", TOWARD, "high", 3.0, false],
	["cream_back", &"cream", AWAY, "high", 3.0, false],
	["fallen_front", &"fallen", TOWARD, "high", 3.0, false],
	["fallen_back", &"fallen", AWAY, "high", 3.0, false],
	["fallen_low", &"fallen", TOWARD, "low", 3.0, false],
	["fallen_hub", &"fallen", TOWARD, "high", 1.5, false],
	["divine_front", &"divine", TOWARD, "high", 3.0, false],
	["divine_back", &"divine", AWAY, "high", 3.0, false],
	["divine_low", &"divine", TOWARD, "low", 3.0, false],
	["divine_hub", &"divine", TOWARD, "high", 1.5, false],
	["fallen_moving", &"fallen", AWAY, "high", 3.0, true],
	["divine_moving", &"divine", AWAY, "high", 3.0, true],
]

var main: Main
var _lang := 0
var _step := 0
var _frames := 0
var _hero := 0
var _repo: ContentRepository


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_repo = ContentRepository.load_all()
	_boot()


func _boot() -> void:
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = LANGS[_lang]
	MetaProgress.bank(profile, 600)
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _shot(shot_name: String) -> void:
	var path := OUT + "%s_%s.png" % [LANGS[_lang], shot_name]
	root.get_texture().get_image().save_png(path)
	print("mp2_shots: ", path)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			if _frames == SETTLE:
				_key(KEY_ENTER)  # Play
				_next()
		1:
			if _frames == SETTLE * 4 and main.hub == null:
				print("mp2_shots: no hub; UI: ", main.get_node("UI").get_children())
			if main.hub != null and _frames >= SETTLE:
				var w := main.hub.driver.world
				var at := main.hub.layout.station(&"progression").at
				w.actors.set_pos(0, HubLayout.to_sim(at + Vector2(1.9, 0.6)))
				w.vel = Vector2.ZERO
				_next()
		2:
			if _frames == 20:
				main.hub.open_progression()
			if _frames == SETTLE:
				_shot("1_station_hidden")
				var p := main.get_node("UI/ProgressionPanel") as ProgressionPanel
				p.buy_requested.emit(&"fallen")
			if _frames == SETTLE + 20:
				_shot("2_station_revealed")
				main.hub.close_overlay()
				_next()
				if _lang > 0:
					_step = 5
		3:
			if _frames == 2:
				_dress(HEROES[_hero])
			var moving: bool = HEROES[_hero][5]
			if moving and _frames > 2:
				main.hub.view.rig.snap_to(SimPlane.to_3d(main.hub.driver.world.player_pos()))
			if _frames == (MOVE_FRAMES if moving else SETTLE):
				_shot("3_hero_%s" % HEROES[_hero][0])
				for a: StringName in [&"move_right", &"move_up"]:
					Input.action_release(a)
				_hero += 1
				_frames = 0
				if _hero >= HEROES.size():
					ViewPrefs.effects_density = "high"
					_next()
		4:
			_next()
		5:
			main.queue_free()
			_lang += 1
			if _lang >= LANGS.size():
				return true
			TranslationServer.set_locale(LANGS[_lang])
			_step = 6
			_frames = 0
		6:
			if _frames == 2:
				_boot()
				_step = 0
				_frames = 0
	return false


## The hero in the hub in robe `h[1]`, facing `h[2]`, at density `h[3]`, the camera at zoom `h[4]`; moving (`h[5]`):
## the move key held (up the screen) with the hub running, so the cloak and the trail stream.
func _dress(h: Array) -> void:
	ViewPrefs.effects_density = h[3]
	var hub := main.hub
	var w := hub.driver.world
	w.actors.set_pos(0, hub.layout.spawn() + Vector2(-1.5 if h[5] else 0.0, 1.2))
	w.aim_angle = h[2]
	w.actors.facing[0] = h[2]
	w.vel = Vector2.ZERO
	# A colour robe first, so the epic robe is built again at this density.
	hub.view.set_look(Wardrobe.look(_repo, _repo.get_def(&"robe", &"cream"), &"none"))
	hub.view.set_look(Wardrobe.look(_repo, _repo.get_def(&"robe", h[1]), &"astral"))
	hub.view.sync()
	hub.driver.paused = not h[5]
	if h[5]:
		Input.action_press(&"move_up")
	else:
		# Standing still keeps the last facing (PlayerAvatar): turn the body and legs.
		hub.view.avatar.set("_body_yaw", SimPlane.yaw_of(h[2]))
		hub.view.avatar.set("_leg_yaw", SimPlane.yaw_of(h[2]))
		hub.view.avatar.set("_vel_s", Vector3.ZERO)
	var at := SimPlane.to_3d(w.player_pos())
	hub.view.rig.flourish_zoom = h[4]
	hub.view.rig.snap_to(at)
	hub.hud.visible = false


func _next() -> void:
	_step += 1
	_frames = 0
