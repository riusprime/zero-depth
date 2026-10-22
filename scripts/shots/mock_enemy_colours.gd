extends SceneTree
## v0.8.0 EC G2 (owner O2, Q1 "By role"): the 14 normal enemy kinds in a 7 x 2 grid, lit in the real game view
## (WorldViewRoot: the biome's mood, look and stage, the iso camera, ActorViews) of a real World, once per palette in
## EnemyPalettes (current, A, B, C), each kind labelled with its name and role. Needs a renderer:
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mock_enemy_colours.gd
## Options after `--`: palettes=current,a,b,c  biomes=ruins,frozen_shore  modes=off,deuteranopia,tritanopia
## (the colour-blind modes are ThemePalette's: the views build with that mode on, as a player with it set would see).
## v0.8.0 N1 (owner O39: "yellow orange and red are close because of the room lighning"): fire=1 lights the line-up
## with two of the room's fire lights (StageKit's: the mood's warm colour, energy and range, at a barrel's height)
## either side of the grid, as a room with torches does; measure=1 then reads each kind's body on screen (the mean
## of its coloured pixels in a box on its body) and prints its colour, hue, CIE L*, chroma, and the closest ΔE
## across roles and inside the warm trio (the reds, oranges and yellows); tag=<t> adds a suffix to the file name.
## Writes build/shots/<version>/ec/<palette>_<biome>_<mode>.png and prints each path. The world is stepped only until
## every kind has risen out of the ground (each held on its grid spot), then frozen while the frame-time animation
## settles. Labels are drawn by this script (English). Quits on every path.

const SETTLE := 40
const STEP_LIMIT := 600
const COLUMNS := 7
const SPACING := 2.05
const ROW_GAP := 3.2
const VIEW_SIZE := 8.8
## [kind, label]. The hovering drones sit in the top row, so they float into the empty space above it.
const PLAN := [
	[ActorStore.Kind.NEEDLE, "Needle"],
	[ActorStore.Kind.ARC_CASTER, "Arc Caster"],
	[ActorStore.Kind.SNIPER, "Sniper"],
	[ActorStore.Kind.LENS_DRONE, "Lens Drone"],
	[ActorStore.Kind.BOMB_DRONE, "Bomb Drone"],
	[ActorStore.Kind.MINE_LAYER, "Mine Layer"],
	[ActorStore.Kind.MENDER, "Mender"],
	[ActorStore.Kind.CHARGER, "Charger"],
	[ActorStore.Kind.HATCHLING, "Hatchling"],
	[ActorStore.Kind.SWARMER, "Swarmer"],
	[ActorStore.Kind.SPLITTER, "Splitter"],
	[ActorStore.Kind.SPLITLING, "Splitling"],
	[ActorStore.Kind.WARDEN, "Warden"],
	[ActorStore.Kind.SHIELD_BEARER, "Shield Bearer"],
]
const TITLES := {
	&"current": "Today (shipped default): red and grey",
	&"a": "A: saturated role colours",
	&"b": "B: muted, weathered role colours on the plates",
	&"c": "C: grey bodies, role colour on trims and glow",
}
const ROLE_NAMES := {
	&"melee": "melee rusher",
	&"ranged": "ranged caster",
	&"bomber": "bomber / mines",
	&"support": "support",
	&"tank": "tank",
}
## Screen right and screen down on the sim plane under the fixed iso yaw (IsoRig.YAW_DEG = 45).
const RIGHT := Vector2(0.70710678, 0.70710678)
const DOWN := Vector2(0.70710678, -0.70710678)
## The hero stands below the grid's middle, so the kinds face the camera and the hero's warm light reaches them, as
## in play.
const PLAYER_AT := Vector2(3.75, -3.75)

var _dir := ""
var _repo: ContentRepository
var _jobs: Array = []
var _job := -1
var _world: World
var _view: WorldViewRoot
var _labels: CanvasLayer
var _spots: Array[Vector2] = []
var _ids: Array[int] = []
var _ticks := 0
var _settle := -1
var _frame := 0
var _fire := false
var _measure := false
var _tag := ""


func _initialize() -> void:
	var palettes: Array = ["current", "a", "b", "c"]
	var biomes: Array = ["ruins", "frozen_shore"]
	var modes: Array = ["off"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("palettes="):
			palettes = a.trim_prefix("palettes=").split(",")
		elif a.begins_with("biomes="):
			biomes = a.trim_prefix("biomes=").split(",")
		elif a.begins_with("modes="):
			modes = a.trim_prefix("modes=").split(",")
		elif a == "fire=1":
			_fire = true
		elif a == "measure=1":
			_measure = true
		elif a.begins_with("glow="):  # v0.8.0 N1: the role glow's energy (ActorViews.ROLE_GLOW; 0 = the look before)
			ActorViews.role_glow_energy = float(a.trim_prefix("glow="))
		elif a.begins_with("tag="):
			_tag = "_" + a.trim_prefix("tag=")
	for p in palettes:
		for b in biomes:
			for m in modes:
				_jobs.append([StringName(p), StringName(b), StringName(m)])
	_dir = "res://build/shots/v0.8.0/ec/"  # the step's version (the project still reads v0.7.5-dev here)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	_repo = ContentRepository.load_all()
	for k in PLAN.size():
		var col := k % COLUMNS - (COLUMNS - 1) * 0.5
		var row := float(k / COLUMNS) - 0.5
		_spots.append(RIGHT * col * SPACING + DOWN * row * ROW_GAP + DOWN * 0.6)
	_next()


func _next() -> bool:
	if _view != null:
		_view.queue_free()
		_view = null
	if _labels != null:
		_labels.queue_free()
		_labels = null
	_job += 1
	if _job >= _jobs.size():
		EnemyPalettes.active = EnemyPalettes.CURRENT
		ThemePalette.mode = &"off"
		return false
	var job: Array = _jobs[_job]
	if not EnemyPalettes.TABLE.has(job[0]):
		push_error("mock_enemy_colours: no palette %s" % job[0])
		return false
	EnemyPalettes.active = job[0]
	ThemePalette.mode = job[2] if ThemePalette.MODES.has(job[2]) else &"off"
	var biome: BiomeDefinition = _repo.get_def(&"biomes", job[1])
	_world = World.new(7, PlayerTable.starting_values())
	_world.set_enemy_tables(ContentCompiler.compile_enemies(_repo))
	var walls: Array[Obb] = []
	walls.append(Obb.make(Vector2(0, 9.5), Vector2(9, 0.4), 0))
	walls.append(Obb.make(Vector2(0, -9.5), Vector2(9, 0.4), 0))
	walls.append(Obb.make(Vector2(9.5, 0), Vector2(0.4, 9), 0))
	walls.append(Obb.make(Vector2(-9.5, 0), Vector2(0.4, 9), 0))
	_world.set_walls(walls)
	_world.actors.set_pos(0, PLAYER_AT)
	_ids.clear()
	for k in PLAN.size():
		_ids.append(_world.add_enemy(PLAN[k][0], _spots[k]))
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	if biome.look != null:  # the first three biomes have no look (Ruins draws as before)
		_view.stage.look = biome.look
		_view.actors.enemy_tint = biome.look.enemy_tint
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	_view.setup(WorldReader.new(_world), biome.palette, 12.0)
	_view.rig.view_size = VIEW_SIZE
	_view.rig.camera.size = VIEW_SIZE
	_view.rig.snap_to(SimPlane.to_3d(Vector2.ZERO))
	_view.rig.set_process(false)
	_view.rig.camera.current = true
	if _fire:  # two of the room's fire lights, as StageKit builds them (v0.8.0 N1)
		for side: float in [-1.0, 1.0]:
			var l := OmniLight3D.new()
			l.light_color = biome.mood.warm_light_color
			l.light_energy = biome.mood.warm_light_energy
			l.omni_range = biome.mood.warm_light_range
			l.omni_attenuation = 1.1
			l.position = SimPlane.to_3d(RIGHT * side * 5.2 + DOWN * -0.4, 1.15)
			_view.add_child(l)
	_ticks = 0
	_settle = -1
	return true


func _hold() -> void:
	var a := _world.actors
	a.set_pos(0, PLAYER_AT)
	a.hp[0] = a.max_hp[0]
	for k in _ids.size():
		var i := a.index_of(_ids[k])
		if i >= 0:
			a.set_pos(i, _spots[k])


func _all_risen() -> bool:
	var a := _world.actors
	for id in _ids:
		var i := a.index_of(id)
		if i < 0 or a.state[i] == EnemyAi.State.SPAWN:
			return false
	return true


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 20000 or _view == null:
		quit(1 if _view == null and _job < _jobs.size() else 0)
		return false
	if _settle < 0:
		_hold()
		_world.step(InputFrame.make(Vector2i.ZERO, 0, 0, 0, 0))
		_hold()
		_view.sync()
		_ticks += 1
		if (_all_risen() and _ticks > 60) or _ticks > STEP_LIMIT:
			_settle = SETTLE
			_draw_labels()
		return false
	_settle -= 1
	if _settle > 0:
		return false
	var job: Array = _jobs[_job]
	var path := _dir + "%s_%s_%s" % job + _tag + ".png"
	var img := root.get_texture().get_image()
	if _measure and img != null:
		_report(img, job)
	if img == null or img.save_png(path) != OK:
		push_error("mock_enemy_colours: could not save %s" % path)
		quit(1)
		return false
	print(
		(
			"mock_enemy_colours: %s (ticks=%d risen=%s projectiles=%d size=%s)"
			% [path, _ticks, _all_risen(), _world.projectiles.size(), img.get_size()]
		)
	)
	if not _next():
		quit(0)
	return false


## measure=1: each kind's body colour on screen, and how far apart the roles read.
func _report(img: Image, job: Array) -> void:
	var cam := _view.rig.camera
	var k := Vector2(img.get_size()) / root.get_visible_rect().size
	var got := {}
	var lines := PackedStringArray()
	for n in PLAN.size():
		var id := EnemyPalettes.KIND_IDS[int(PLAN[n][0])] as StringName
		var at := _body_centre(_ids[n], int(PLAN[n][0]))
		var c := cam.unproject_position(at) * k
		var half := maxf(
			3.0, (cam.unproject_position(at + Vector3(0.09, 0, 0.09)) * k).distance_to(c)
		)
		var sum := Color(0, 0, 0)
		var count := 0
		for y in range(int(c.y - half), int(c.y + half)):
			for x in range(int(c.x - half), int(c.x + half)):
				if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
					continue
				var p := img.get_pixel(x, y)
				if p.s >= 0.12 and p.v >= 0.1:  # coloured, not the outline or a grey
					sum += p
					count += 1
		var mean := Color(sum.r / maxi(count, 1), sum.g / maxi(count, 1), sum.b / maxi(count, 1))
		got[id] = mean
		var lab := _lab(mean)
		lines.append(
			(
				"  %-13s %-8s %s hue %5.1f  L* %5.1f  chroma %5.1f  (%d px)"
				% [
					id,
					EnemyPalettes.ROLES[id],
					mean.to_html(false),
					mean.h * 360.0,
					lab.x,
					Vector2(lab.y, lab.z).length(),
					count
				]
			)
		)
	var across := [INF, "", ""]
	var warm := [INF, "", ""]
	var warm_ids := [
		&"charger",
		&"hatchling",
		&"swarmer",
		&"splitter",
		&"splitling",
		&"bomb_drone",
		&"mine_layer"
	]
	for a: StringName in got:
		for b: StringName in got:
			if String(a) >= String(b):
				continue
			var de := _lab(got[a]).distance_to(_lab(got[b]))
			if EnemyPalettes.ROLES[a] != EnemyPalettes.ROLES[b] and de < across[0]:
				across = [de, a, b]
			if (
				a in warm_ids
				and b in warm_ids
				and EnemyPalettes.ROLES[a] != EnemyPalettes.ROLES[b]
				and de < warm[0]
			):
				warm = [de, a, b]
	print(
		(
			"measure: palette=%s biome=%s mode=%s fire=%s glow=%.2f%s"
			% [job[0], job[1], job[2], str(_fire), ActorViews.role_glow_energy, _tag]
		)
	)
	print("\n".join(lines))
	print("  closest across roles: ΔE %.1f (%s / %s)" % across)
	print("  closest red/orange vs yellow (melee vs bombers): ΔE %.1f (%s / %s)" % warm)
	var hues := PackedStringArray()
	for id: StringName in [&"charger", &"splitter", &"splitling", &"bomb_drone", &"mine_layer"]:
		hues.append("%s %.1f" % [id, (got[id] as Color).h * 360.0])
	print("  warm hues (deg): " + ", ".join(hues))


## The centre of kind `kind`'s body plate (its mesh drawn in the palette's body colour) on actor `id`, else its spot.
func _body_centre(id: int, kind: int) -> Vector3:
	var node := _view.actors.actor_node(id)
	var want := EnemyPalettes.color(kind, &"body")
	if node != null:
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var mats: Array = [mi.material_override]
			for sfc in mi.get_surface_override_material_count():
				mats.append(mi.get_surface_override_material(sfc))
			for m in mats:
				var sm := m as StandardMaterial3D
				if sm != null and sm.albedo_color.is_equal_approx(want) and mi.is_visible_in_tree():
					return mi.global_transform * mi.get_aabb().get_center()
	return SimPlane.to_3d(_spots[_ids.find(id)], 0.42)


static func _lab(c: Color) -> Vector3:
	var lin := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	var r: float = lin.call(c.r)
	var g: float = lin.call(c.g)
	var b: float = lin.call(c.b)
	var x := (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
	var y := 0.2126 * r + 0.7152 * g + 0.0722 * b
	var z := (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
	var f := func(t: float) -> float:
		return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	return Vector3(
		116.0 * f.call(y) - 16.0, 500.0 * (f.call(x) - f.call(y)), 200.0 * (f.call(y) - f.call(z))
	)


func _draw_labels() -> void:
	_labels = CanvasLayer.new()
	root.add_child(_labels)
	var job: Array = _jobs[_job]
	var title := Label.new()
	title.text = (
		"%s  |  %s  |  colour mode: %s"
		% [TITLES.get(job[0], String(job[0])), String(job[1]).capitalize(), job[2]]
	)
	title.label_settings = _settings(30)
	title.position = Vector2(32, 20)
	_labels.add_child(title)
	var cam := _view.rig.camera
	for k in PLAN.size():
		var id := EnemyPalettes.KIND_IDS[int(PLAN[k][0])] as StringName
		var role: StringName = EnemyPalettes.ROLES[id]
		var at := cam.unproject_position(SimPlane.to_3d(_spots[k]))
		var l := Label.new()
		l.text = "%s\n%s" % [PLAN[k][1], ROLE_NAMES[role]]
		l.label_settings = _settings(20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(220, 60)
		l.position = at + Vector2(-110, 34)
		_labels.add_child(l)


func _settings(size: int) -> LabelSettings:
	var s := LabelSettings.new()
	s.font_size = size
	s.font_color = Color("#F3E9DD")
	s.outline_size = 6
	s.outline_color = Color(0, 0, 0, 0.9)
	return s
