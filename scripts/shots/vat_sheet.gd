extends SceneTree
## v0.10.5 W3-V1 (the enemy VAT pilot, G2: the owner judges the tolerance): one sheet of the pilot kind (the Swarmer) in
## each state it can show, the old path (its pieces as nodes, left) beside VAT (VatCrowd's MultiMesh, right), each pair
## driven by the very same calls (apply_state / advance / flinch / show_hit, as ActorViews and HitFeel make them) and
## drawn in two identical little worlds (iso camera, a sun, a floor, the proxy shadow). Also prints and writes, per
## state, how far the two images differ (max channel difference and the share of pixels off by more than 8 / 255).
## Needs a renderer (NOT --headless); off screen:
##   APPDATA=<temp> godot --path . --resolution 1920x1080 --position -10000,-10000 -s scripts/shots/vat_sheet.gd
## Writes build/shots/<version>/vat/vat_sheet.png and vat_diff.txt.
## v0.10.5 W3-V4a: `-- --kind=charger` draws the Charger's states instead (CHARGER_PLAN: its run, wind-up, lunge,
## recovery and daze, and one Hatchling), into vat_sheet_charger.png and vat_diff_charger.txt; `--out=<res:// dir>`
## writes elsewhere than build/shots/<version>/vat/.
## v0.10.5 W3-V4b: `-- --kind=<name>` (splitter, splitling, shield_bearer, mender, mine_layer, sniper) draws that kind
## in its own states (KIND_PLANS: the walk, the death, the heal, the mine dropped, the muzzle) into
## vat_sheet_<name>.png and vat_diff_<name>.txt; `--version-dir=<v>` writes under build/shots/<v>/vat/. Every horde
## sheet also gives each state's largest vertex error (the shader's arithmetic on the CPU).
## v0.10.5 W3-V4c: `-- --kind=<name>` (needle, warden, arc_caster, bomb_drone) draws that stand-alone kind in
## SOLO_PLAN's states (its walk, wind-up, attack, recovery) into vat_sheet_<name>.png and vat_diff_<name>.txt, with
## the vertex error.

const CELL := Vector2i(220, 220)
const COLS := 4
const DT := 1.0 / 60.0
const KIND := WorldReader.KIND_SWARMER
## The states: [label, build: {tint, role} or {}, steps].
const PLAN := [
	["idle", {}, "idle"],
	["scuttle (t 1.37 s)", {}, "scuttle"],
	["windup 31 %", {}, "windup_early"],
	["windup 90 % (flash)", {}, "windup_late"],
	["strike snap (0.05 s)", {}, "strike_snap"],
	["strike out (0.15 s)", {}, "strike_out"],
	["strike easing back", {}, "strike_back"],
	["flinch at its peak", {}, "flinch"],
	["Blade knock", {}, "knock"],
	["hit flash", {}, "flash"],
	["status tint (burn)", {}, "tint"],
	["rise-in, half way", {}, "spawn"],
	["biome cast + role glow", {"tint": Color(0.45, 0.65, 1.0, 0.5), "role": 0.45}, "idle"],
	["reduced motion + flinch", {}, "calm"],
]
## v0.10.5 W3-V4a: the Charger's states (build "hatchling": the Brood Mother's, at two thirds of the size).
const CHARGER_PLAN := [
	["idle (t 1.5 s)", {}, "idle"],
	["idle fidget (t 3.9 s)", {}, "fidget"],
	["run 3 m/s", {}, "run"],
	["windup 31 %", {}, "windup_early"],
	["windup 90 % (flash)", {}, "windup_late"],
	["lunge snap (0.05 s)", {}, "strike_snap"],
	["charge 15 m/s", {}, "charge"],
	["recovery (0.2 s in)", {}, "recover"],
	["dazed (1 s in)", {}, "dazed"],
	["flinch at its peak", {}, "flinch"],
	["Blade knock", {}, "knock"],
	["hit flash", {}, "flash"],
	["status tint (burn)", {}, "tint"],
	["rise-in, half way", {}, "spawn"],
	["biome cast + role glow", {"tint": Color(0.45, 0.65, 1.0, 0.5), "role": 0.45}, "run"],
	["reduced motion + windup", {}, "calm"],
	["Hatchling, run", {"hatchling": true}, "run"],
	["Hatchling, charge", {"hatchling": true}, "charge"],
]

## v0.10.5 W3-V4b: the other horde kinds by name (--kind=<name>).
const KINDS := {
	"splitter": WorldReader.KIND_SPLITTER,
	"splitling": WorldReader.KIND_SPLITLING,
	"shield_bearer": WorldReader.KIND_SHIELD_BEARER,
	"mender": WorldReader.KIND_MENDER,
	"mine_layer": WorldReader.KIND_MINE_LAYER,
	"sniper": WorldReader.KIND_SNIPER,
}
const CAST := {"tint": Color(0.45, 0.65, 1.0, 0.5), "role": 0.45}
## v0.10.5 W3-V4b: the other kinds' states (the Swarmer's: PLAN).
const KIND_PLANS := {
	"melee_model":
	[
		["idle", {}, "idle"],
		["walking", {}, "walk"],
		["windup 31 %", {}, "windup_early"],
		["windup 90 % (flash)", {}, "windup_late"],
		["strike snap (0.05 s)", {}, "strike_snap"],
		["strike out (0.15 s)", {}, "strike_out"],
		["strike easing back", {}, "strike_back"],
		["death, 0.1 s in", {}, "death_early"],
		["death, 0.3 s in", {}, "death_late"],
		["flinch at its peak", {}, "flinch"],
		["Blade knock", {}, "knock"],
		["hit flash", {}, "flash"],
		["status tint (burn)", {}, "tint"],
		["rise-in, half way", {}, "spawn"],
		["biome cast + role glow", CAST, "idle"],
		["reduced motion + flinch", {}, "calm"],
	],
	"mender":
	[
		["idle", {}, "idle"],
		["idle, 1.3 s later", {}, "idle_late"],
		["walking (floats)", {}, "walk"],
		["healing", {}, "heal"],
		["healing, later", {}, "heal_late"],
		["death, 0.1 s in", {}, "death_early"],
		["death, 0.3 s in", {}, "death_late"],
		["flinch at its peak", {}, "flinch"],
		["Blade knock", {}, "knock"],
		["hit flash", {}, "flash"],
		["status tint (burn)", {}, "tint"],
		["rise-in, half way", {}, "spawn"],
		["biome cast + role glow", CAST, "idle"],
		["reduced motion + flinch", {}, "calm"],
	],
	"mine_layer":
	[
		["idle", {}, "idle"],
		["windup 31 % (hopper lowers)", {}, "windup_early"],
		["windup 90 %", {}, "windup_late"],
		["mine dropped (active)", {}, "strike_snap"],
		["active, 0.15 s", {}, "strike_out"],
		["recovering (mine back)", {}, "strike_back"],
		["flinch at its peak", {}, "flinch"],
		["Blade knock", {}, "knock"],
		["hit flash", {}, "flash"],
		["status tint (burn)", {}, "tint"],
		["rise-in, half way", {}, "spawn"],
		["biome cast + role glow", CAST, "idle"],
		["reduced motion + flinch", {}, "calm"],
	],
	"sniper":
	[
		["idle", {}, "idle"],
		["windup 31 % (muzzle)", {}, "windup_early"],
		["windup 90 % (flash)", {}, "windup_late"],
		["shot (0.05 s)", {}, "strike_snap"],
		["shot (0.15 s)", {}, "strike_out"],
		["easing back", {}, "strike_back"],
		["flinch at its peak", {}, "flinch"],
		["Blade knock", {}, "knock"],
		["hit flash", {}, "flash"],
		["status tint (burn)", {}, "tint"],
		["rise-in, half way", {}, "spawn"],
		["biome cast + role glow", CAST, "idle"],
		["reduced motion + flinch", {}, "calm"],
	],
}

## v0.10.5 W3-V4c: the stand-alone kinds by name (--kind=<name>), their states, and their framing
## [camera size, look height].
const SOLO := {
	"needle": WorldReader.KIND_NEEDLE,
	"warden": WorldReader.KIND_WARDEN,
	"arc_caster": WorldReader.KIND_ARC_CASTER,
	"bomb_drone": WorldReader.KIND_BOMB_DRONE,
	"rock_lurker": WorldReader.KIND_ROCK_LURKER,  # v0.11.0 O17b
}
const SOLO_FRAME := {
	WorldReader.KIND_NEEDLE: [1.5, 0.4],
	WorldReader.KIND_WARDEN: [2.6, 0.75],
	WorldReader.KIND_ARC_CASTER: [1.9, 0.65],
	WorldReader.KIND_BOMB_DRONE: [2.8, 1.1],
	WorldReader.KIND_ROCK_LURKER: [2.0, 0.45],
}
const SOLO_PLAN := [
	["idle (t 1.5 s)", {}, "idle"],
	["walking", {}, "walk"],
	["windup 31 %", {}, "windup_early"],
	["windup 90 % (flash)", {}, "windup_late"],
	["attack (0.05 s)", {}, "strike_snap"],
	["attack (0.15 s)", {}, "strike_out"],
	["recovery (0.4 s in)", {}, "recover"],
	["flinch at its peak", {}, "flinch"],
	["Blade knock", {}, "knock"],
	["hit flash", {}, "flash"],
	["status tint (burn)", {}, "tint"],
	["rise-in, half way", {}, "spawn"],
	["biome cast + role glow", CAST, "walk"],
	["reduced motion + windup", {}, "calm"],
]

var _dir := ""
var _pairs: Array = []  # [label, live SubViewport, vat SubViewport]
var _frame := 0
var _kind := KIND
var _suffix := ""


func _initialize() -> void:
	_dir = "res://build/shots/%s/vat/" % GameVersion.label()
	var plan: Array = PLAN
	for arg in OS.get_cmdline_user_args():
		if arg == "--kind=charger":
			_kind = WorldReader.KIND_CHARGER
			_suffix = "_charger"
			plan = CHARGER_PLAN
		elif arg.begins_with("--kind=") and KINDS.has(arg.trim_prefix("--kind=")):
			var kname := arg.trim_prefix("--kind=")
			_kind = KINDS[kname]
			_suffix = "_" + kname
			match kname:
				"splitter", "splitling", "shield_bearer":
					plan = KIND_PLANS["melee_model"]
				_:
					plan = KIND_PLANS[kname]
		elif arg.begins_with("--kind=") and SOLO.has(arg.trim_prefix("--kind=")):  # v0.10.5 W3-V4c
			_kind = SOLO[arg.trim_prefix("--kind=")]
			_suffix = "_" + arg.trim_prefix("--kind=")
			plan = SOLO_PLAN
			if _kind == WorldReader.KIND_ROCK_LURKER:  # v0.11.0 O17b: its disguise and rumble too
				plan = SOLO_PLAN + [["disguised", {}, "hidden"], ["rumbling", {}, "rumble"]]
		elif arg.begins_with("--version-dir="):
			_dir = "res://build/shots/%s/vat/" % arg.trim_prefix("--version-dir=")
		elif arg.begins_with("--out="):
			_dir = arg.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var grid := GridContainer.new()
	grid.columns = COLS
	root.add_child(grid)
	for spec: Array in plan:
		var cell := VBoxContainer.new()
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = "%s   (old | VAT)" % spec[0]
		cell.add_child(label)
		var row := HBoxContainer.new()
		cell.add_child(row)
		grid.add_child(cell)
		var build: Dictionary = spec[1]
		var live := _world(row, false, build, spec[2])
		var vat := _world(row, true, build, spec[2])
		_pairs.append([spec[0], live, vat])


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 12:
		return false
	_finish()
	return true


## One little world showing one avatar (`vat`: drawn by a VatCrowd), driven through `steps`.
func _world(row: HBoxContainer, vat: bool, build: Dictionary, steps: String) -> SubViewport:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(CELL)
	row.add_child(box)
	var vp := SubViewport.new()
	vp.size = CELL
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(vp)
	var scene := Node3D.new()
	vp.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#1b1d24")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#9aa3b5")
	env.environment.ambient_light_energy = 0.5
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4, 4)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#5a564f")
	floor_mi.material_override = fm
	scene.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.15
	var look := Vector3(0.15, 0.12, 0)
	if _kind == WorldReader.KIND_CHARGER:  # v0.10.5 W3-V4a: a longer, taller body
		cam.size = 1.9
		look = Vector3(0.05, 0.35, 0)
	elif SoloVat.is_solo(_kind):  # v0.10.5 W3-V4c
		cam.size = SOLO_FRAME[_kind][0]
		look = Vector3(0.0, SOLO_FRAME[_kind][1], 0)
	elif _kind != WorldReader.KIND_SWARMER:  # v0.10.5 W3-V4b: framed to the horde kind's height
		var h := HordeAvatar.height_of(_kind)
		cam.size = maxf(1.15, h * 1.7)
		look = Vector3(0.0, h * 0.5, 0)
	var dir := (
		Basis(Vector3.UP, deg_to_rad(45.0))
		* Basis(Vector3.RIGHT, deg_to_rad(-35.26))
		* Vector3.BACK
	)
	scene.add_child(cam)
	cam.look_at_from_position(look + dir * 10.0, look, Vector3.UP)
	cam.current = true
	var actor := Node3D.new()
	scene.add_child(actor)
	var facing := Node3D.new()
	facing.rotation.y = 0.6
	actor.add_child(facing)
	var a := _avatar(vat, build)
	var kind: int = a.get(&"kind")
	facing.add_child(a)
	a.set_process(false)
	if vat:
		var crowd := VatCrowd.new()
		scene.add_child(crowd)
		crowd.add(actor, facing, a, Color("#1A1A22"), true)
	else:
		EnemyShadows.apply(actor, facing, a, kind, 0.25, "proxy")
	a.name = "Avatar"
	if SoloVat.is_solo(_kind):  # v0.10.5 W3-V4c
		_drive_solo(a, steps)
		if vat:
			print(
				"%s: lift %.3f m, drives %s" % [steps, a.call(&"vat_lift"), a.call(&"vat_drives")]
			)
		return vp
	if a is ChargerAvatar:
		_drive_charger(a as ChargerAvatar, steps)
	else:
		_drive(a as HordeAvatar, steps, actor)
	if vat and a is HordeAvatar:
		var h := a as HordeAvatar
		print(
			(
				"%s: lift %.3f m, raise %.2f, strike %.2f"
				% [steps, h.vat_lift(), h.windup_pose(), h.strike_pose()]
			)
		)
	elif vat:
		var c := a as ChargerAvatar
		print("%s: lift %.3f m, drives %s" % [steps, c.vat_lift(), c.vat_drives()])
	return vp


## v0.10.5 W3-V4a: the avatar a cell shows (`vat`: drawn by a VatCrowd), as ActorViews builds it.
func _avatar(vat: bool, build: Dictionary) -> AvatarBase:
	var tint: Color = build.get("tint", Color(0, 0, 0, 0))
	var role := float(build.get("role", 0.0))
	if SoloVat.is_solo(_kind):  # v0.10.5 W3-V4c: as ActorViews builds one (its cast on its own materials after)
		var s: AvatarBase = VatBake.vat_avatar_of(_kind, Color("#1A1A22")) if vat else null
		if s == null:
			s = VatBake.reference_of(_kind, tint, role, Color("#1A1A22"))
			s.set_process(true)
		s.enemy_tint = tint
		s.role_glow = role
		return s
	if _kind == WorldReader.KIND_CHARGER:
		var c := ChargerAvatar.new()
		c.enemy_tint = tint
		c.role_glow = role
		c.vat = vat
		var hatch := bool(build.get("hatchling", false))
		c.setup(
			Color("#1A1A22"),
			&"outline",
			WorldReader.KIND_HATCHLING if hatch else WorldReader.KIND_CHARGER
		)
		if hatch:
			c.scale = Vector3.ONE * 0.66
		return c
	var a := HordeAvatar.new()
	a.enemy_tint = tint
	a.role_glow = role
	a.vat = vat
	a.setup(_kind, Color("#1A1A22"))
	return a


## The calls a state is made of (both avatars of a pair get the same ones).
func _drive(a: HordeAvatar, steps: String, actor: Node3D) -> void:
	var tick := 0
	if steps == "spawn":  # spawned sunk, then half risen (2.5 a second)
		a.apply_state({"tick": 0, "state": WorldReader.STATE_SPAWN})
		_run(a, 2)
		for k in 12:
			a.apply_state({"tick": 1 + k, "state": WorldReader.STATE_MOVE})
			_run(a, 1)
		return
	if steps == "calm":
		ViewPrefs.reduced_motion = true
	a.apply_state({"tick": tick, "state": WorldReader.STATE_MOVE})
	var idle := 82 if steps == "scuttle" else (138 if steps in ["idle_late", "heal_late"] else 60)
	var healing := steps.begins_with("heal")
	for k in idle:
		tick += 1
		a.apply_state({"tick": tick, "state": WorldReader.STATE_MOVE, "healing": healing})
		_run(a, 1)
	match steps:
		"walk":  # v0.10.5 W3-V4b: the actor walks 1.6 m/s (the models' stride comes from how fast they move)
			actor.position.x = -0.4
			for k in 30:
				tick += 1
				a.apply_state({"tick": tick, "state": WorldReader.STATE_MOVE})
				actor.position.x += 1.6 * DT
				_run(a, 1)
		"death_early", "death_late":
			a.die()
			_run(a, 6 if steps == "death_early" else 18)
		"windup_early", "windup_late", "strike_snap", "strike_out", "strike_back":
			var n := 15 if steps == "windup_early" else (43 if steps == "windup_late" else 48)
			for k in n:
				tick += 1
				a.apply_state(
					{"tick": tick, "state": WorldReader.STATE_WINDUP, "windup": float(k + 1) / 48.0}
				)
				_run(a, 1)
			if steps.begins_with("strike"):
				var active := 3 if steps == "strike_snap" else 9
				for k in active:
					tick += 1
					a.apply_state({"tick": tick, "state": WorldReader.STATE_ACTIVE})
					_run(a, 1)
				if steps == "strike_back":
					for k in 22:  # out of ACTIVE: the hold, then part of the ease back
						tick += 1
						a.apply_state({"tick": tick, "state": WorldReader.STATE_RECOVER})
						_run(a, 1)
		"flinch", "calm":
			a.flinch(Vector2(1.0, 0.4), 1.0)
			_run(a, 3)
		"knock":
			a.flinch(Vector2(1.0, 0.4), 1.0, 1.0)
			_run(a, 3)
		"flash":
			a.show_hit(true, Color.WHITE, 1.6)
		"tint":
			a.show_hit(true, Color(1.0, 0.45, 0.1), 1.2)
	ViewPrefs.reduced_motion = false


## v0.10.5 W3-V4a: the Charger's calls (both avatars of a pair get the same ones): its sim states and positions, one
## a tick, as ActorViews.sync gives them.
func _drive_charger(a: ChargerAvatar, steps: String) -> void:
	var tick := 0
	var x := 0.0
	if steps == "spawn":  # spawned sunk, then half risen (RISE_TIME 0.35 s)
		a.apply_state({"tick": 0, "pos": Vector2.ZERO, "state": WorldReader.STATE_SPAWN})
		_run(a, 2)
		for k in 10:
			a.apply_state({"tick": 1 + k, "pos": Vector2.ZERO, "state": WorldReader.STATE_MOVE})
			_run(a, 1)
		return
	if steps == "calm":
		ViewPrefs.reduced_motion = true
	var idle := 234 if steps == "fidget" else 90
	var speed := 0.05 if steps in ["run", "charge", "strike_snap", "recover", "dazed"] else 0.0
	for k in idle:
		tick += 1
		x += speed
		a.apply_state({"tick": tick, "pos": Vector2(x, 0), "state": WorldReader.STATE_MOVE})
		_run(a, 1)
	match steps:
		"windup_early", "windup_late", "strike_snap", "charge", "recover", "dazed", "calm":
			var n := (
				15 if steps == "windup_early" else (43 if steps in ["windup_late", "calm"] else 48)
			)
			for k in n:
				tick += 1
				a.apply_state(
					{
						"tick": tick,
						"pos": Vector2(x, 0),
						"state": WorldReader.STATE_WINDUP,
						"windup": float(k + 1) / 48.0
					}
				)
				_run(a, 1)
			if steps in ["windup_early", "windup_late", "calm"]:
				ViewPrefs.reduced_motion = false
				return
			var active := 3 if steps == "strike_snap" else 18
			for k in active:
				tick += 1
				x += 0.25  # the charge: 15 m/s
				a.apply_state(
					{"tick": tick, "pos": Vector2(x, 0), "state": WorldReader.STATE_ACTIVE}
				)
				_run(a, 1)
			if steps in ["recover", "dazed"]:
				for k in 12 if steps == "recover" else 60:
					tick += 1
					a.apply_state(
						{"tick": tick, "pos": Vector2(x, 0), "state": WorldReader.STATE_RECOVER}
					)
					_run(a, 1)
		"flinch":
			a.flinch(Vector2(1.0, 0.4), 1.0)
			_run(a, 3)
		"knock":
			a.flinch(Vector2(1.0, 0.4), 1.0, 1.0)
			_run(a, 3)
		"flash":
			a.show_hit(true, Color.WHITE, 1.6)
		"tint":
			a.show_hit(true, Color(1.0, 0.45, 0.1), 1.2)
	ViewPrefs.reduced_motion = false


## v0.10.5 W3-V4c: a stand-alone kind's calls (both avatars of a pair get the same ones): its sim states and positions,
## one a tick, as ActorViews.sync gives them; the flash and the tint as ActorViews._set_flash makes them (the old path
## on its own materials, VAT through show_hit).
func _drive_solo(a: AvatarBase, steps: String) -> void:
	var tick := 0
	var x := 0.0
	var speed: float = (
		{
			WorldReader.KIND_NEEDLE: 3.2,
			WorldReader.KIND_WARDEN: 1.6,
			WorldReader.KIND_ARC_CASTER: 2.0,
			WorldReader.KIND_BOMB_DRONE: 2.5,
			WorldReader.KIND_ROCK_LURKER: 2.2,
		}[_kind]
		/ 60.0
	)
	if steps == "spawn":
		a.call(&"apply_state", _solo_state(tick, x, WorldReader.STATE_SPAWN, 0.0))
		_run(a, 2)
		for k in 12:
			tick += 1
			a.call(&"apply_state", _solo_state(tick, x, WorldReader.STATE_MOVE, 0.0))
			_run(a, 1)
		return
	if steps == "hidden" or steps == "rumble":  # v0.11.0 O17b: the Rock Lurker waiting as a boulder
		for k in 40:
			tick += 1
			var hs := _solo_state(tick, x, WorldReader.STATE_MOVE, 0.0)
			hs["hidden"] = true
			hs["rumbling"] = steps == "rumble"
			a.call(&"apply_state", hs)
			_run(a, 1)
		return
	if steps == "calm":
		ViewPrefs.reduced_motion = true
	for k in 90:
		tick += 1
		if steps == "walk":
			x += speed
		a.call(&"apply_state", _solo_state(tick, x, WorldReader.STATE_MOVE, 0.0))
		_run(a, 1)
	match steps:
		"windup_early", "windup_late", "calm", "strike_snap", "strike_out", "recover":
			var n := (
				9 if steps == "windup_early" else (27 if steps in ["windup_late", "calm"] else 30)
			)
			for k in n:
				tick += 1
				a.call(
					&"apply_state",
					_solo_state(tick, x, WorldReader.STATE_WINDUP, float(k + 1) / 30.0)
				)
				_run(a, 1)
			if steps.begins_with("strike") or steps == "recover":
				for k in 3 if steps == "strike_snap" else 9:
					tick += 1
					a.call(&"apply_state", _solo_state(tick, x, WorldReader.STATE_ACTIVE, 0.0))
					_run(a, 1)
			if steps == "recover":
				for k in 24:
					tick += 1
					a.call(&"apply_state", _solo_state(tick, x, WorldReader.STATE_RECOVER, 0.0))
					_run(a, 1)
		"flinch":
			a.flinch(Vector2(1.0, 0.4), 1.0)
			_run(a, 3)
		"knock":
			a.flinch(Vector2(1.0, 0.4), 1.0, 1.0)
			_run(a, 3)
		"flash":
			_solo_flash(a, Color.WHITE, 1.6)
		"tint":
			_solo_flash(a, Color(1.0, 0.45, 0.1), 1.2)
	ViewPrefs.reduced_motion = false


static func _solo_state(tick: int, x: float, state: int, windup: float) -> Dictionary:
	return {"tick": tick, "pos": Vector2(x, 0), "state": state, "windup": windup, "radius": 2.4}


static func _solo_flash(a: AvatarBase, c: Color, energy: float) -> void:
	if bool(a.get(&"vat")):
		a.show_hit(true, c, energy)
		return
	for m in a.body_materials:
		m.emission = c
		m.emission_energy_multiplier = energy


## v0.10.5 W3-V4c: the largest vertex error (m) of a stand-alone kind's pair: the old avatar's posed vertices against
## the shader's arithmetic on the CPU at the VAT one's drives and lift (pieces() skips nothing of the old path's but its
## shadow stand-in, which comes last).
func _solo_error(live_vp: SubViewport, vat_vp: SubViewport) -> float:
	var live := live_vp.find_child("Avatar", true, false) as AvatarBase
	var vat := vat_vp.find_child("Avatar", true, false) as AvatarBase
	var pose := VatBake.pose_for(_kind)
	var mesh := VatBake.mesh_for(_kind, vat.enemy_tint, vat.role_glow, Color("#1A1A22"))
	var a := VatBake.live_vertices(live)
	var b := VatBake.eval_vertices(pose, mesh, VatBake.drives_of(vat, pose), vat.call(&"vat_lift"))
	var worst := 0.0
	for k in mini(a.size(), b.size()):
		worst = maxf(worst, a[k].distance_to(b[k]))
	return worst


func _run(a: AvatarBase, frames: int) -> void:
	for k in frames:
		a.advance(DT)
		a.advance_flinch(DT)


## v0.10.5 W3-V4b: the largest distance (m) between the old avatar's posed vertices and the VAT one's, the shader's
## arithmetic run on the CPU (VatBake.eval_vertices_at) at the drives it was drawn with; a hidden piece is skipped.
func _vertex_error(live_vp: SubViewport, vat_vp: SubViewport) -> float:
	if SoloVat.is_solo(_kind):  # v0.10.5 W3-V4c
		return _solo_error(live_vp, vat_vp)
	var lives := live_vp.find_children("*", "HordeAvatar", true, false)
	if lives.is_empty():
		return -1.0  # the Charger's sheet: its own check (the bake report)
	var live := lives[0] as HordeAvatar
	var vat := vat_vp.find_children("*", "HordeAvatar", true, false)[0] as HordeAvatar
	var pose := VatBake.pose_for(_kind)
	var mesh := VatBake.mesh_for(_kind, vat.enemy_tint, vat.role_glow, Color("#1A1A22"))
	var a := VatBake.live_vertices(live)
	var b := VatBake.eval_vertices_at(pose, mesh, VatBake.drives_of(vat, pose), vat.vat_offset())
	var worst := 0.0
	var k0 := 0
	for p: Dictionary in VatBake.pieces(live, VatBake.joints(live)):
		var mi: MeshInstance3D = p["node"]
		var nv := (
			(mi.mesh.surface_get_arrays(p["surface"])[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			. size()
		)
		if mi.name == EnemyShadows.PROXY_NAME:  # the old path's shadow stand-in, not the body
			continue
		if mi.is_visible_in_tree():
			for k in range(k0, k0 + nv):
				worst = maxf(worst, a[k].distance_to(b[k]))
		k0 += nv
	return worst


func _finish() -> void:
	var lines: PackedStringArray = []
	lines.append("vat sheet: old (left) vs VAT (right), %dx%d px each, msaa 4x" % [CELL.x, CELL.y])
	var proxy := VatCrowd.shadow_mesh(_kind)  # the old path's shadow stand-in (EnemyShadows), cached per kind
	lines.append(
		(
			"kind %d shadow proxy aabb (avatar space, m): %s (top y %.3f; the floor is y 0)"
			% [_kind, proxy.get_aabb(), proxy.get_aabb().end.y]
		)
	)
	lines.append(
		"state | max channel diff (0-255) | pixels off by > 8 | share | max vertex error (mm, CPU)"
	)
	for p: Array in _pairs:
		var a := (p[1] as SubViewport).get_texture().get_image()
		var b := (p[2] as SubViewport).get_texture().get_image()
		a.convert(Image.FORMAT_RGBA8)
		b.convert(Image.FORMAT_RGBA8)
		var worst := 0
		var off := 0
		for y in a.get_height():
			for x in a.get_width():
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y)
				var d := roundi(
					maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) * 255.0
				)
				worst = maxi(worst, d)
				if d > 8:
					off += 1
		lines.append(
			(
				"%s | %d | %d | %.4f | %s"
				% [
					p[0],
					worst,
					off,
					float(off) / float(a.get_width() * a.get_height()),
					_mm(_vertex_error(p[1], p[2]))
				]
			)
		)
	var sheet := root.get_texture().get_image()
	var png := ProjectSettings.globalize_path(_dir + "vat_sheet%s.png" % _suffix)
	sheet.save_png(png)
	var text := "\n".join(lines) + "\n"
	print(text)
	print("sheet: " + png)
	var f := FileAccess.open(
		ProjectSettings.globalize_path(_dir + "vat_diff%s.txt" % _suffix), FileAccess.WRITE
	)
	if f != null:
		f.store_string(text)
		f.close()
	quit(0)


## A vertex error (m) in mm, or "—" when the sheet's kind has none here (the Charger: its bake report gives it).
static func _mm(e: float) -> String:
	return "—" if e < 0.0 else "%.3f" % (e * 1000.0)
