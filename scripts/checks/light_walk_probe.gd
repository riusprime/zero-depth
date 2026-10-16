extends SceneTree
## v0.8.0 N1 (owner O55: "give a check to lighting again so the game properly renders all the lightning"; O46 the
## fire sprites): walks the camera through a real generated floor (SaveLab.floor_world, drawn by the game's own
## WorldViewRoot in one biome: its mood, kit, fire props and their lights, the hero's light, the effect layer) at a
## hero's pace (6 m/s), room centre to room centre, and checks every frame:
##   kit lights hidden on screen      fire lights whose spot is inside the view but hidden (a missing light): 0
##   kit light toggles on screen      a fire light switching visible/hidden inside the view (a pop): 0
##   kit energy step max              the largest change of a fire light's energy in one frame, as a share of its
##                                    full energy (the flicker plus P3's 0.4 s fade: about 0.05; a pop would be ~1)
##   shadow toggles while visible     a shown light's shadow switched on/off while its opacity was over 0.05: 0
##   shadow casters max               fire lights casting at once (StageKit.SHADOW_LIGHTS: 4)
##   flames far from a fire           flame sprites placed over 1 m from every visible fire light: 0 (read from
##                                    VfxCore.record: a headless renderer keeps no instance transforms)
##   flame slot changes               flame-pool slots that hold another flame than the frame before (moved > 1 m;
##                                    pooling does this whenever a light hides or shows: harmless unless the pool
##                                    is physics-interpolated, which drew the slot between the two places)
##   pools interpolated               effect pools / pooled lights that the renderer interpolates between physics
##                                    ticks (must be 0: they are laid out on frame time)
##   hero light                       frames the hero's light was missing or dark (0)
## Headless works (CPU-side checks):
##   godot --headless --fixed-fps 60 --path . -s scripts/checks/light_walk_probe.gd -- [biome=ruins]
##     [seed=20261008] [floor=1] [rooms=6] [tag=after] [interp=inherit]
## Writes only under build/ (build/perf/light_walk_<biome>[_<tag>].txt) and prints the same report. Quits on every
## path.

const OUT_DIR := "res://build/perf"
const STEP_M := 0.1

var _biome_id := &"ruins"
var _seed := 20261008
var _floor := 1
var _rooms := 6
var _tag := ""
## interp=inherit: the effect layer follows the scene's physics interpolation (the look before N1).
var _inherit := false
var _view: WorldViewRoot
var _reader: WorldReader
var _path: Array[Vector2] = []
var _leg := 0
var _at := Vector2.ZERO
var _frame := 0
var _prev_vis: Array[bool] = []
var _prev_energy: Array[float] = []
var _prev_shadow: Array[bool] = []
var _prev_flames: PackedVector3Array = PackedVector3Array()
var _n := {
	"frames": 0,
	"kit_hidden_on_screen": 0,
	"kit_toggles_on_screen": 0,
	"kit_toggles_off_screen": 0,
	"kit_energy_step_max": 0.0,
	"shadow_toggles_visible": 0,
	"shadow_casters_max": 0,
	"flames_far": 0,
	"flames_drawn_max": 0,
	"flame_slot_changes": 0,
	"frames_with_slot_changes": 0,
	"pools_interpolated": 0,
	"hero_light_missing": 0,
	"vfx_lights_on_max": 0,
}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("biome="):
			_biome_id = StringName(a.trim_prefix("biome="))
		elif a.begins_with("seed="):
			_seed = int(a.trim_prefix("seed="))
		elif a.begins_with("floor="):
			_floor = int(a.trim_prefix("floor="))
		elif a.begins_with("rooms="):
			_rooms = int(a.trim_prefix("rooms="))
		elif a.begins_with("tag="):
			_tag = a.trim_prefix("tag=")
		elif a == "interp=inherit":
			_inherit = true
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", _biome_id)
	if biome == null:
		print("light_walk_probe: no biome %s" % _biome_id)
		quit(1)
		return
	var w := SaveLab.floor_world(_seed, _floor)
	IcePatches.place(w, BiomeCompiler.compile_surface(biome))
	_reader = WorldReader.new(w)
	_view = WorldViewRoot.new()
	_view.stage.mood = biome.mood
	_view.stage.prop_style = biome.id
	_view.stage.look = biome.look
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	var b := _reader.floor_bounds()
	var half := maxf(maxf(-b.position.x, b.end.x), maxf(-b.position.y, b.end.y))
	_view.setup(_reader, biome.palette, half + 4.0)
	_view.sync()
	if _inherit and _view.attack_forms.vfx != null:
		_view.attack_forms.vfx.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	var start := _reader.floor_start_room()
	_path.append(_reader.floor_room(start).get_center())
	for i in _reader.floor_room_count():
		if _path.size() >= _rooms:
			break
		if i != start:
			_path.append(_reader.floor_room(i).get_center())
	_at = _path[0]
	_view.rig.view_size = 17.0
	_view.rig.snap_to(SimPlane.to_3d(_at))
	var kit := _view.stage.kit
	for l in kit.lights:
		_prev_vis.append(l.visible)
		_prev_energy.append(l.light_energy)
		_prev_shadow.append(l.shadow_enabled)
	print(
		(
			"light_walk_probe: biome=%s seed=%d floor=%d rooms=%d kit_lights=%d step=%.2f m/frame"
			% [_biome_id, _seed, _floor, _path.size(), kit.lights.size(), STEP_M]
		)
	)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	if _frame > 20000:
		quit(1)
		return
	_check(_frame > 30)  # the first frames settle the lights' fades from the start spot (not counted)
	if _leg + 1 >= _path.size():
		_finish()
		return
	var to := _path[_leg + 1]
	var d := to - _at
	if d.length() <= STEP_M:
		_at = to
		_leg += 1
	else:
		_at += d.normalized() * STEP_M
	_view.rig.snap_to(SimPlane.to_3d(_at))


func _on_screen(cam: Camera3D, p: Vector3) -> bool:
	if cam.is_position_behind(p):
		return false
	return root.get_visible_rect().has_point(cam.unproject_position(p))


func _check(counted: bool) -> void:
	if not counted:
		for k in _view.stage.kit.lights.size():
			var l0 := _view.stage.kit.lights[k]
			_prev_vis[k] = l0.visible
			_prev_energy[k] = l0.light_energy
			_prev_shadow[k] = l0.shadow_enabled
		return
	_n["frames"] += 1
	var cam := root.get_camera_3d()
	var kit := _view.stage.kit
	var casting := 0
	var fires: Array[Vector3] = []
	for k in kit.lights.size():
		var l := kit.lights[k]
		var on := _on_screen(cam, l.global_position)
		if on and not l.visible:
			_n["kit_hidden_on_screen"] += 1
		if l.visible != _prev_vis[k]:
			_n["kit_toggles_on_screen" if on else "kit_toggles_off_screen"] += 1
		if l.visible and _prev_vis[k]:
			var full := maxf(0.001, float(kit.get("_light_energy")[k]))
			_n["kit_energy_step_max"] = maxf(
				_n["kit_energy_step_max"], absf(l.light_energy - _prev_energy[k]) / full
			)
		if l.visible and l.shadow_enabled != _prev_shadow[k] and l.shadow_opacity > 0.05:
			_n["shadow_toggles_visible"] += 1
		if l.shadow_enabled and l.visible:
			casting += 1
		if l.visible:
			fires.append(l.global_position - Vector3(0, 0.36, 0))
		_prev_vis[k] = l.visible
		_prev_energy[k] = l.light_energy
		_prev_shadow[k] = l.shadow_enabled
	_n["shadow_casters_max"] = maxi(_n["shadow_casters_max"], casting)
	var vfx := _view.attack_forms.vfx
	if vfx == null:
		return
	vfx.record = true
	var flames := vfx.placed_flames.duplicate()
	for o in flames:
		var near := false
		for f in fires:
			if Vector2(o.x - f.x, o.z - f.z).length() < 1.0:
				near = true
				break
		if not near:
			_n["flames_far"] += 1
	_n["flames_drawn_max"] = maxi(_n["flames_drawn_max"], flames.size())
	var changed := 0
	for i in mini(flames.size(), _prev_flames.size()):
		if flames[i].distance_to(_prev_flames[i]) > 1.0:
			changed += 1
	_n["flame_slot_changes"] += changed
	if changed > 0:
		_n["frames_with_slot_changes"] += 1
	_prev_flames = flames
	var interp := 0
	for p: Dictionary in vfx.pools.values():
		if (p["node"] as Node).is_physics_interpolated_and_enabled():
			interp += 1
	for l in vfx.lights:
		if l.is_physics_interpolated_and_enabled():
			interp += 1
	_n["pools_interpolated"] = maxi(_n["pools_interpolated"], interp)
	_n["vfx_lights_on_max"] = maxi(_n["vfx_lights_on_max"], vfx.lights_on())
	var hero := _view.find_children("HeroLight", "OmniLight3D", true, false)
	if hero.is_empty() or not (hero[0] as OmniLight3D).is_visible_in_tree():
		_n["hero_light_missing"] += 1
	elif (hero[0] as OmniLight3D).light_energy <= 0.0:
		_n["hero_light_missing"] += 1


func _finish() -> void:
	var lines := PackedStringArray()
	lines.append(
		(
			"light_walk_probe: biome=%s seed=%d floor=%d rooms=%d physics_interpolation=%s"
			% [
				_biome_id,
				_seed,
				_floor,
				_path.size(),
				str(ProjectSettings.get_setting("physics/common/physics_interpolation"))
			]
		)
	)
	for k: String in _n:
		var v = _n[k]
		lines.append("%-26s %s" % [k, ("%.3f" % v) if v is float else str(v)])
	var text := "\n".join(lines)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var name := "light_walk_%s%s.txt" % [_biome_id, ("_" + _tag) if _tag != "" else ""]
	var f := FileAccess.open("%s/%s" % [OUT_DIR, name], FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
	quit(0)
