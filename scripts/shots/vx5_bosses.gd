extends SceneTree
## v0.10.0 VX5 (VFX_PACK R13, R19, R21, R27, R36-R42): the boss, elite and shield effects before (the old look: no
## PackFx above the view) and after (the pack's), side by side. Four sheets, each row one effect, the old on the left
## and the new on the right, from an iso camera like the game's: strikes, beams, shields and sigils. A green ring or a
## green box marks the strike's hit area (radius / lane), which the pack effect must not outgrow. Each tile is the real
## view class driven the way the game drives it. A tool, not a test. Needs a renderer (no --headless) and a fixed
## frame time (run it off screen: --position -10000,-10000):
##   godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx5_bosses.gd
## Writes build/shots/v0.10.0/vx5/<sheet>.png and prints each path.

const TILE := Vector2i(360, 210)
const SHEETS: Array[StringName] = [&"strikes", &"beams", &"shields", &"sigils"]
## Frames after a sheet starts that it is grabbed on.
const GRAB := {&"strikes": 22, &"beams": 40, &"shields": 36, &"sigils": 26}
const BASE_TICK := 100.0
const MX4World := preload("res://tests/support/mx4_world.gd")
const RING := Color(0.2, 1.0, 0.3)

var _sheet_k := 0
var _frame := 0
var _tiles: Array[Dictionary] = []
var _holders: Array[Node] = []
var _dir := ""
var _hero_world: World


class Holder:
	extends Node3D
	var pack_fx: PackFx


func _initialize() -> void:
	_dir = "res://build/shots/v0.10.0/vx5/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	ViewPrefs.effects_density = "high"
	_build_sheet()


func _process(_delta: float) -> bool:
	_frame += 1
	for t in _tiles:
		(t["drive"] as Callable).call(_frame)
	if _frame < int(GRAB[SHEETS[_sheet_k]]):
		return false
	var rows := _tiles.size() / 2
	var img := Image.create(TILE.x * 2, TILE.y * rows, false, Image.FORMAT_RGB8)
	for k in _tiles.size():
		var tile := (t_vp(_tiles[k])).get_texture().get_image()
		tile.convert(Image.FORMAT_RGB8)
		img.blit_rect(
			tile, Rect2i(Vector2i.ZERO, TILE), Vector2i((k % 2) * TILE.x, (k / 2) * TILE.y)
		)
	var path := _dir + "%s.png" % SHEETS[_sheet_k]
	img.save_png(path)
	print("vx5_bosses: ", path)
	_clear()
	_sheet_k += 1
	if _sheet_k >= SHEETS.size():
		return true
	_build_sheet()
	return false


func t_vp(t: Dictionary) -> SubViewport:
	return t["vp"] as SubViewport


func _clear() -> void:
	for t in _tiles:
		(t["vp"] as SubViewport).queue_free()
	_tiles.clear()


func _build_sheet() -> void:
	_frame = 0
	match SHEETS[_sheet_k]:
		&"strikes":
			_row(_strike.bind(&"crater", {"discs": [[Vector2.ZERO, 2.5, true]]}, 2.5, 0.0))
			_row(_strike.bind(&"light_burst", {"discs": [[Vector2.ZERO, 2.5, true]]}, 2.5, 0.0))
			_row(_strike.bind(&"light_ring", {"ring": [Vector2.ZERO, 1.0, 3.5]}, 3.5, 0.0))
			_row(_strike.bind(&"shock_ring", {"ring": [Vector2.ZERO, 0.6, 5.0]}, 5.0, 0.0))
			_row(_strike.bind(&"steam_ring", {"ring": [Vector2.ZERO, 0.6, 5.0]}, 5.0, 0.0))
			_row(_strike.bind(&"dust_arc", {"arc": [Vector2.ZERO, 1.0, 4.5, -0.6, 0.6]}, 4.5, 0.0))
		&"beams":
			_row(_lanes)
			_row(_rail)
			_row(_prism)
			_row(_gaze)
			_row(_mender)
			_row(_conduit)
		&"shields":
			_row(_shell, true)
			_row(_blink)
			_row(_shatter)
			_row(_lava)
			_row(_fallen)
		&"sigils":
			_row(_elite_sigil)
			_row(_nemesis_sigil, true)


## One effect row: the old tile then the new one.
func _row(setup: Callable, hero := false) -> void:
	for new in [false, true]:
		_tiles.append(_tile(setup, new, hero))


func _tile(setup: Callable, new: bool, hero: bool) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = TILE
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.06, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	vp.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.29, 0.26)
	floor_mi.material_override = fm
	vp.add_child(floor_mi)
	var holder := Holder.new()
	vp.add_child(holder)
	var focus := Vector3.ZERO
	if new:
		holder.pack_fx = PackFx.new()
		holder.add_child(holder.pack_fx)
	var drive: Callable = setup.call(holder, new, vp)
	if hero:
		focus = holder.get_meta(&"focus", Vector3.ZERO)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.0
	vp.add_child(cam)
	cam.look_at_from_position(focus + Vector3(9, 10, 9), focus, Vector3.UP)
	cam.current = true
	return {"vp": vp, "drive": drive}


func _ring(parent: Node, r: float) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = r - 0.03
	torus.outer_radius = r + 0.03
	mi.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = RING
	mi.material_override = m
	mi.position.y = 0.04
	parent.add_child(mi)


func _box(parent: Node, size: Vector2) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(RING, 0.18)
	mi.material_override = m
	mi.position.y = 0.03
	parent.add_child(mi)


## A strike drawn by BossStrikeFx (its pack effects vs its old sprites), on the effects layer.
func _strike(
	holder: Holder, _new: bool, _vp: Node, kind: StringName, geo: Dictionary, ring: float, _x: float
) -> Callable:
	var layer := VfxLayer.new()
	layer.pack_fx = holder.pack_fx
	holder.add_child(layer)
	_ring(holder, ring)
	var s := {
		"kind": kind,
		"tick": int(BASE_TICK),
		"end": int(BASE_TICK),
		"seed": 7,
		"glow": Color(1.0, 0.7, 0.35)
	}
	s.merge(geo, true)
	return func(f: int) -> void:
		var now := BASE_TICK + float(f)
		layer.begin(now)
		BossStrikeFx.draw(layer, [s] as Array[Dictionary], now)
		layer.finish()


func _lane_drive(holder: Holder, kind: StringName, lane: Obb, glow: Color) -> Callable:
	var layer := VfxLayer.new()
	layer.pack_fx = holder.pack_fx
	holder.add_child(layer)
	_box(holder, lane.half * 2.0)
	var s := {
		"kind": kind, "tick": int(BASE_TICK), "end": -1, "seed": 11, "glow": glow, "lanes": [lane]
	}
	return func(f: int) -> void:
		var now := BASE_TICK + float(f)
		layer.begin(now)
		BossStrikeFx.draw(layer, [s] as Array[Dictionary], now)
		layer.finish()


func _lanes(holder: Holder, _new: bool, _vp: Node) -> Callable:
	return _lane_drive(
		holder, &"fire_lanes", Obb.make(Vector2.ZERO, Vector2(4.0, 0.9), 0), Color(1.0, 0.5, 0.2)
	)


func _rail(holder: Holder, _new: bool, _vp: Node) -> Callable:
	var lane := Obb.make(Vector2.ZERO, Vector2(4.0, 0.5), 0)
	var layer := VfxLayer.new()
	layer.pack_fx = holder.pack_fx
	holder.add_child(layer)
	_box(holder, lane.half * 2.0)
	var s := {
		"kind": &"rail",
		"tick": int(BASE_TICK),
		"end": int(BASE_TICK),
		"seed": 5,
		"glow": Color(1.0, 0.8, 0.5),
		"lanes": [lane]
	}
	return func(f: int) -> void:
		var now := BASE_TICK + float((f + 5) % 20)  # the rail fires again every 20 frames
		layer.begin(now)
		BossStrikeFx.draw(layer, [s] as Array[Dictionary], now)
		layer.finish()


func _prism(holder: Holder, _new: bool, _vp: Node) -> Callable:
	var v := PrismViews.new()
	holder.add_child(v)
	v.set_process(false)
	var arms: Array = []
	for k in 4:
		var a := TAU * k / 4.0 + 0.3
		arms.append([Vector2(cos(a), sin(a)) * 0.8, Vector2(cos(a), sin(a)) * 5.5, true])
	v._cross = {"progress": 0, "window": false, "winding": false, "half_width": 0.35, "arms": arms}
	return func(f: int) -> void: v._draw(float(f))


func _gaze(holder: Holder, _new: bool, _vp: Node) -> Callable:
	var v := BossSignatureViews.new()
	holder.add_child(v)
	v.set_process(false)
	v._gaze = {
		"progress": 1000,
		"winding": false,
		"angle": 0,
		"half_width": 0.35,
		"from": Vector2(0, 0),
		"to": Vector2(6.0, 0),
		"hit": true,
		"eye": Vector2(-3.0, 0),
	}
	return func(f: int) -> void: v._draw_bs2(float(f), false)


func _mender(holder: Holder, new: bool, _vp: Node) -> Callable:
	var v := HordeVisuals.new()
	holder.add_child(v)
	v._hold = BossPackHold.new(holder.pack_fx) if new else null
	return func(_f: int) -> void:
		if v._hold != null:
			v._hold.begin()
		v._beam(1, Vector2(-3, 0), Vector2(3, 0.5))
		if v._hold != null:
			v._hold.end()


func _conduit(holder: Holder, _new: bool, _vp: Node) -> Callable:
	var v := EliteViews.new()
	holder.add_child(v)
	var o := Obb.make(Vector2.ZERO, Vector2(4.0, 0.7), 0)
	return func(f: int) -> void:
		if f % 24 == 2:
			v._beam(o)


func _shell(holder: Holder, _new: bool, _vp: Node) -> Callable:
	var w := MX4World.world(&"blade", [&"aether_shell"])
	MX4World.run(w, 200)
	_hero_world = w
	var o := ModifierOverlays.new()
	holder.add_child(o)
	holder.set_meta(&"focus", SimPlane.to_3d(WorldReader.new(w).player_pos()))
	return func(_f: int) -> void: o.sync(WorldReader.new(w))


func _blink(holder: Holder, _new: bool, _vp: Node) -> Callable:
	var b := BlinkFlash.new()
	holder.add_child(b)
	return func(f: int) -> void:
		if f % 30 == 2:
			b.play(Vector3.ZERO)


func _shatter(holder: Holder, _new: bool, _vp: Node) -> Callable:
	var v := FinalBossViews.new()
	holder.add_child(v)
	var layer := VfxLayer.new()
	layer.pack_fx = holder.pack_fx
	holder.add_child(layer)
	return func(f: int) -> void:
		if f % 40 == 2:
			v._burst(Vector3.ZERO, 1.5, f)
		layer.begin(BASE_TICK + float(f))
		v.draw_fx(layer)
		layer.finish()


func _lava(holder: Holder, new: bool, _vp: Node) -> Callable:
	var v := BossSignatureViews.new()
	holder.add_child(v)
	v.set_process(false)
	v._hold = BossPackHold.new(holder.pack_fx) if new else null
	v._lava_rows = [[Rect2(-3, -1.5, 6, 3), 0.0, 400.0]]
	v._sync_lava_nodes()
	return func(f: int) -> void:
		if v._hold != null:
			v._hold.begin()
		v._draw_lava(float(f) + 20.0)
		if v._hold != null:
			v._hold.end()


func _fallen(holder: Holder, _new: bool, _vp: Node) -> Callable:
	var v := InterphaseViews.new()
	holder.add_child(v)
	v.set_process(false)
	v._data = {
		"beams": [],
		"lines": [],
		"points": [],
		"ret": {},
		"stage": 1,
		"erupts": [{"pos": Vector2.ZERO, "radius": 1.8, "striking": false, "progress": 1000}],
	}
	return func(f: int) -> void:
		if f == 6:
			v._data["erupts"][0]["striking"] = true
			v._note_strikes()
		v._draw(1.0 / 60.0)


func _elite_sigil(holder: Holder, new: bool, _vp: Node) -> Callable:
	var v := EliteViews.new()
	holder.add_child(v)
	return func(f: int) -> void:
		if f == 2:
			if new:
				v._arrival(Vector2.ZERO)
			else:  # the old look: the gold disc and ring (EliteViews._arrival before VX5)
				var sigil := v._disc(1.6, EliteViews.GOLD, 0.85)
				sigil.position = Vector3(0, 0.05, 0)
				v.add_child(sigil)
				v._fx.append([sigil, EliteViews.ARRIVE_S, EliteViews.ARRIVE_S, &"arrive"])
				var ring := v._ring(1.0, 1.25, EliteViews.GOLD)
				ring.position = Vector3(0, 0.06, 0)
				v.add_child(ring)
				v._fx.append([ring, EliteViews.ARRIVE_S, EliteViews.ARRIVE_S, &"dust"])


func _nemesis_sigil(holder: Holder, new: bool, _vp: Node) -> Callable:
	var w := NemesisLab.world(
		404, &"gun", [[&"gun_twin", 2], [&"ember_core", 3], [&"halo_shot", 1]]
	)
	var reader := WorldReader.new(w)
	var i := FinalLab.body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(6, 0))
	var k := -1
	for n in w.final_fight.casts.size():
		if w.final_fight.casts[n].card_id == &"ember_core":
			k = n
	var v := NemesisViews.new()
	holder.add_child(v)
	holder.set_meta(&"focus", SimPlane.to_3d(w.actors.pos(i)))
	NemesisLab.start(w, StringName("nemesis_card_%d" % (k + 1)))
	return func(_f: int) -> void:
		w.step(InputFrame.new())
		v.sync(reader)
		if not new and v._area != null:  # the old look: the owner's sigil texture
			v._area.queue_free()
			v._area = null
			v._sigil.layers = 1
