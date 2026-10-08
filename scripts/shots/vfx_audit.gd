extends SceneTree
## v0.5.5 LK (A3, owner: "Some VFX need to match the new style of the game … some don't match neither style nor
## lighting"): the VFX audit shots. Boots the real game (main.tscn), starts a run, spawns a ring of Chargers round the
## hero and drives the attacks with real input actions, taking one shot per effect: the weapon at each heat tier, the
## vent blast, the skill, the enemy telegraphs, the element abilities and a death pop. Needs a renderer:
##   xvfb-run -a godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 \
##     -s scripts/shots/vfx_audit.gd -- \
##     build=blade look=game
## (--fixed-fps 60 keeps one sim tick per frame on a slow software renderer, so the shots land on their ticks.)
## build=blade|gun; look=game draws the floor as the game does, look=new lays the owner's new art over it (the
## ground-a.png texture and the environment .glb models from the repo root, which the game does not use yet) under a
## darker, warm-lit light: an approximation of the new style for comparing the effects against it, not a spec.
## Shot setup only (the hero can't be hurt, heat is held at a tier, enemies are spawned and abilities granted as the
## dev panel would). Writes build/shots/v0.5.5/vfx_audit/<build>_<look>/NN_name.png.

const OUT := "res://build/shots/v0.5.5/vfx_audit/%s_%s/"
## The owner's environment models placed round the hero for look=new: [file, sim offset, target height m, yaw].
const PROPS := [
	["res://wall_2m.glb", Vector2(-4.5, 3.5), 2.4, 0.0],
	["res://wall_broken.glb", Vector2(-1.5, 5.0), 1.8, 0.4],
	["res://wall_pillar.glb", Vector2(3.5, 4.5), 2.6, 0.0],
	["res://fire_barrel.glb", Vector2(5.0, 2.0), 1.0, 0.0],
	["res://brazier_pole.glb", Vector2(-5.0, -2.5), 2.0, 0.0],
	["res://car_wreck.glb", Vector2(4.5, -4.5), 1.4, 0.8],
	["res://rubble_small.glb", Vector2(-2.5, -4.5), 0.5, 0.0],
	["res://debris_low.glb", Vector2(1.5, -5.5), 0.5, 1.2],
	["res://rock_large.glb", Vector2(-6.0, 0.5), 1.2, 0.0],
	["res://dead_tree.glb", Vector2(6.5, 5.5), 2.8, 0.0],
]

var _main: Main
var _frame := 0
var _build := &"blade"
var _look := &"game"
var _dir := ""
## Heat held for the shot (points), or -1 to let the sim run it.
var _heat := -1
var _script: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("build="):
			_build = StringName(a.trim_prefix("build="))
		if a.begins_with("look="):
			_look = StringName(a.trim_prefix("look="))
	_dir = OUT % [_build, _look]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	print("vfx_audit: renderer=%s" % RenderingServer.get_current_rendering_method())
	var profile := ProfileStore.new("")
	profile.section("loadout")["build"] = String(_build)  # the build picker focuses the last build
	ProfileStore.use_shared(profile)
	_main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	var btn := MOUSE_BUTTON_LEFT if _build == &"blade" else MOUSE_BUTTON_RIGHT
	var at := 3 if _build == &"blade" else 9  # frames from the press to the shot: mid-swing, or bolts in flight
	_script = [
		[10, _tap.bind(KEY_ENTER)],
		[36, _tap.bind(KEY_ENTER)],
		[44, _setup],
		[100, _set_heat.bind(0)],
		[102, _mouse.bind(btn, true)],
		[102 + at, _shot.bind("01_attack_cool")],
		[114, _mouse.bind(btn, false)],
		[130, _set_heat.bind(55)],
		[132, _mouse.bind(btn, true)],
		[132 + at, _shot.bind("02_attack_hot")],
		[144, _mouse.bind(btn, false)],
		[160, _set_heat.bind(85)],
		[162, _mouse.bind(btn, true)],
		[162 + at, _shot.bind("03_attack_overclock")],
		[174, _mouse.bind(btn, false)],
		[189, _set_heat.bind(-1)],
		[190, _key.bind(KEY_F, true)],
		[191, _key.bind(KEY_F, false)],
		[194, _shot.bind("04_vent_blast")],
		[230, _key.bind(KEY_Q, true)],
		[231, _key.bind(KEY_Q, false)],
		[236, _shot.bind("05_skill_start")],
		[245, _shot.bind("06_skill_hit")],
		[270, _shot_when_telegraph.bind("07_enemy_telegraphs")],
		[300, _grant],
		[350, _shot.bind("08_element_abilities")],
		[352, _doom],
		[354, _mouse.bind(btn, true)],
		[354 + at + 2, _shot.bind("09_hits_and_deaths")],
		[370, _mouse.bind(btn, false)],
		[372, quit.bind(0)],
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
	Input.warp_mouse(Vector2(1000, 450))
	if _look == &"new":
		_backdrop(p)


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


## look=new: the owner's ground texture over the floor round the hero, the environment models, a dimmer warm light.
func _backdrop(at: Vector2) -> void:
	var holder := Node3D.new()
	holder.name = "AuditBackdrop"
	_main.view.add_child(holder)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(28, 28)
	plane.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://ground-a.png")
	gm.uv1_scale = Vector3(7, 7, 1)
	gm.roughness = 1.0
	plane.material_override = gm
	plane.position = SimPlane.to_3d(at, 0.004)
	holder.add_child(plane)
	for row: Array in PROPS:
		var scene := load(row[0]) as PackedScene
		if scene == null:
			print("vfx_audit: missing ", row[0])
			continue
		var n := scene.instantiate() as Node3D
		holder.add_child(n)
		var box := _aabb(n)
		var s: float = row[2] / maxf(box.size.y, 0.001)
		n.scale = Vector3.ONE * s
		n.rotation.y = row[3]
		var foot := SimPlane.to_3d(at + (row[1] as Vector2), 0.0)
		n.position = foot - Vector3(0, box.position.y * s, 0)
		if String(row[0]).contains("fire") or String(row[0]).contains("brazier"):
			var omni := OmniLight3D.new()
			omni.light_color = Color("#FF9A4A")
			omni.light_energy = 2.5
			omni.omni_range = 6.0
			omni.position = foot + Vector3(0, row[2] + 0.3, 0)
			holder.add_child(omni)
	for we: WorldEnvironment in _main.view.find_children("*", "WorldEnvironment", true, false):
		we.environment.ambient_light_color = Color("#6E6458")
		we.environment.ambient_light_energy = 0.35
		we.environment.background_color = Color("#121014")
	for light: DirectionalLight3D in _main.view.find_children(
		"*", "DirectionalLight3D", true, false
	):
		light.light_energy = 0.6
		light.light_color = Color("#C8C4D8")


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := (
			(mi.get_global_transform() if mi.is_inside_tree() else mi.transform) * mi.get_aabb()
		)
		box = b if first else box.merge(b)
		first = false
	return box


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
	ev.position = Vector2(1000, 450)
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
