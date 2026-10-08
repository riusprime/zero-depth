extends SceneTree
## v0.5.5 LK (A3, owner: "Some VFX need to match the new style of the game … some don't match neither style nor
## lighting"): the VFX audit shots. Boots the real game (main.tscn), starts a run, spawns a ring of Chargers round the
## hero and drives the attacks with real input events, taking one shot per effect: the weapon at each heat tier, the
## vent blast, the skill, the enemy telegraphs, the element abilities and a death pop. Needs a renderer:
##   xvfb-run -a godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 \
##     -s scripts/shots/vfx_audit.gd -- build=blade
## (--fixed-fps 60 keeps one sim tick per frame on a slow software renderer, so the shots land on their ticks.)
## build=blade|gun. The floor is drawn as the game draws it (since v0.5.9 "Embers": the owner's kit, the biome's
## lighting mood and the hero's warm light), so the effects are judged against the real look and light.
## Shot setup only (the hero can't be hurt, heat is held at a tier, enemies are spawned and abilities granted as the
## dev panel would). Writes build/shots/v0.5.5/vfx_audit/<build>/NN_name.png.

const OUT := "res://build/shots/v0.5.5/vfx_audit/%s/"
var _main: Main
var _frame := 0
var _build := &"blade"
var _dir := ""
## Heat held for the shot (points), or -1 to let the sim run it.
var _heat := -1
var _script: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("build="):
			_build = StringName(a.trim_prefix("build="))
	_dir = OUT % _build
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	print("vfx_audit: renderer=%s" % RenderingServer.get_current_rendering_method())
	var profile := ProfileStore.new("")
	profile.section("loadout")["build"] = String(_build)  # the build picker focuses the last build
	ProfileStore.use_shared(profile)
	RunSaveStore.use_shared(RunSaveStore.new(""))  # no run save read or left behind
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	var btn := MOUSE_BUTTON_LEFT if _build == &"blade" else MOUSE_BUTTON_RIGHT
	var at := 3 if _build == &"blade" else 9  # frames from the press to the shot: mid-swing, or bolts in flight
	_script = [
		[6, _tap.bind(KEY_ENTER)],
		[14, _tap.bind(KEY_ENTER)],
		[20, _setup],
		[30, _set_heat.bind(0)],
		[32, _mouse.bind(btn, true)],
		[32 + at, _shot.bind("01_attack_cool")],
		[44, _mouse.bind(btn, false)],
		[52, _set_heat.bind(55)],
		[54, _mouse.bind(btn, true)],
		[54 + at, _shot.bind("02_attack_hot")],
		[66, _mouse.bind(btn, false)],
		[74, _set_heat.bind(85)],
		[76, _mouse.bind(btn, true)],
		[76 + at, _shot.bind("03_attack_overclock")],
		[88, _mouse.bind(btn, false)],
		[95, _set_heat.bind(-1)],
		[96, _key.bind(KEY_F, true)],
		[97, _key.bind(KEY_F, false)],
		[100, _shot.bind("04_vent_blast")],
		[120, _key.bind(KEY_Q, true)],
		[121, _key.bind(KEY_Q, false)],
		[126, _shot.bind("05_skill_start")],
		[135, _shot.bind("06_skill_hit")],
		[150, _shot_when_telegraph.bind("07_enemy_telegraphs")],
		[180, _grant],
		[215, _shot.bind("08_element_abilities")],
		[217, _doom],
		[219, _mouse.bind(btn, true)],
		[219 + at + 2, _shot.bind("09_hits_and_deaths")],
		[235, _mouse.bind(btn, false)],
		[237, quit.bind(0)],
	]


func _process(_delta: float) -> bool:
	_frame += 1
	if _main.driver != null and _main.driver.world != null:
		var w := _main.driver.world
		w.actors.invuln[0] = 60  # shot setup: the hero can't be hurt
		w.actors.hp[0] = w.actors.max_hp[0]
		if _heat >= 0 and w.heat != null:
			w.heat.milli = _heat * HeatTable.MILLI
			w.heat.idle = 0
	for step: Array in _script.duplicate():
		if step[0] == _frame:
			(step[1] as Callable).call()
	return false


func _setup() -> void:
	var w := _main.driver.world
	var p := w.player_pos()
	for k in 7:
		w.add_enemy(ActorStore.Kind.CHARGER, p + Kin.dir(k * 585) * (1.9 + 0.3 * (k % 2)))
	for i in range(1, w.actors.size()):
		w.actors.hp[i] = 9999
		w.actors.max_hp[i] = 9999
	Input.warp_mouse(Vector2(900, 360))


func _set_heat(points: int) -> void:
	_heat = points


func _grant() -> void:
	var w := _main.driver.world
	for id: StringName in [&"bomb_lobber", &"frost_nova", &"arc_field"]:
		for k in w.ability_tables.size():
			if w.ability_tables[k].id == id:
				Abilities.grant(w, k)


## Lowers the ring's health so the next swing or volley kills some (the death pop).
func _doom() -> void:
	var w := _main.driver.world
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 0:
			w.actors.hp[i] = 1


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _mouse(button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = Vector2(900, 360)
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


## Waits (up to 25 frames) for an enemy telegraph on screen, then shoots.
func _shot_when_telegraph(label: String, tries: int = 25) -> void:
	var r := WorldReader.new(_main.driver.world)
	var any := false
	for i in r.actor_count():
		any = any or not r.telegraph(i).is_empty()
	if any or tries <= 0:
		_shot(label)
		return
	_script.append([_frame + 1, _shot_when_telegraph.bind(label, tries - 1)])


func _shot(label: String) -> void:
	var path := _dir + label + ".png"
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	var w := _main.driver.world
	var s := WorldReader.new(w).heat_state()
	var r := WorldReader.new(w)
	print(
		(
			"vfx_audit: %s tick=%d heat_tier=%s skill_kind=%s projectiles=%d"
			% [
				path,
				w.tick,
				s.get("tier", "-"),
				r.skill_state().get("kind", "-"),
				r.projectile_count()
			]
		)
	)
