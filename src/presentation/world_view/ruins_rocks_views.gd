class_name RuinsRocksViews
extends Node3D
## v0.11.0 O13b (ENEMIES.md R1-R4): what the Ruins' and the Night Rocks' signature enemies put on the floor, read
## through WorldReader (EI-07), in the premade packs' effects (PD-13):
## - a Wire Weaver's cable: a glowing yellow line between its posts' tops (code), crackling with the pack's storm hit
##   spark (vx1_hit_storm: BinbunVFX hit vfx_hit_01, tinted yellow) along it; while it marks a cable, the same spark
##   at the two spots its posts go in (the tell: "the posts spark as they go in"); a cable dropping bursts the spark at
##   both ends;
## - a Stone Thrower's rock: in flight, the kit's small boulder (KitModels boulder_small, as the Rubble Warden's rocks)
##   on its arc from the Thrower's hands to its ring; landed, the same boulder standing for its time, with the pack's
##   dust (bx_smoke_dust: smoke_vfx_05) where it lands and where it crumbles;
## - a Rock Lurker: the pack's dust puffing at its foot while it rumbles, and the dust with the shatter
##   (bx_shatter) as it bursts out; v0.11.0 O17b: the same dust, wide, where its claws smash down (its hit tick);
## - a Scrap Hound's yelp: the pack's plain hit spark (vx1_hit_plain) at its head when a hit stops it.
## Nothing here decides.

const ROCK_MODEL := &"boulder_small"
const ROCK_SPREAD := 1.25
const ROCK_HEIGHT := 0.6
const CABLE_Y := 0.86
const CABLE_R := 0.035
const CABLE_COLOR := Color("#FFE15A")
const CABLE_ENERGY := 3.5
const SPARK_ID := &"vx1_hit_storm"
const SPARK_SCALE := 0.45
const SPARK_COLORS := {
	&"primary": Color(1.0, 0.93, 0.45),
	&"secondary": Color(1.0, 0.78, 0.2),
	&"tertiary": Color(0.55, 0.38, 0.05)
}
## A spark along each live cable every this many ticks, at the marked posts every MARK_EVERY.
const SPARK_EVERY := 15
const MARK_EVERY := 6
const DUST_ID := &"bx_smoke_dust"
const DUST_SCALE := 0.45
const SHATTER_ID := &"bx_shatter"
const YELP_ID := &"vx1_hit_plain"
const RUMBLE_EVERY := 30
## The flying rock's arc: from this height at the hands, peaking this much above the line.
const THROW_FROM_Y := 1.95
const THROW_ARC_M := 2.2

var pack_fx: PackFx = null
var _cables: Array[MeshInstance3D] = []
var _cable_ends := {}  # owner|a|b key -> [a, b] (the last ends seen: a drop bursts there)
var _rocks: Array[MeshInstance3D] = []
var _rock_spots: Array = []
var _flying := {}  # thrower id -> MeshInstance3D
var _hidden := {}  # lurker id -> was hidden
var _slamming := {}  # lurker id -> was in its hit tick (v0.11.0 O17b)
var _yelped := {}
var _cable_mat: StandardMaterial3D


func _ready() -> void:
	_cable_mat = StandardMaterial3D.new()
	_cable_mat.albedo_color = CABLE_COLOR
	_cable_mat.emission_enabled = true
	_cable_mat.emission = CABLE_COLOR
	_cable_mat.emission_energy_multiplier = CABLE_ENERGY
	_cable_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


## Live cables drawn now, rocks standing, rocks in the air (tests).
func cable_count() -> int:
	return _cables.size()


func rock_count() -> int:
	return _rocks.size()


func flying_count() -> int:
	return _flying.size()


func sync(reader: WorldReader) -> void:
	var tick := reader.tick()
	_sync_cables(reader, tick)
	_sync_rocks(reader.thrown_rocks())
	var seen := {}
	for i in range(1, reader.actor_count()):
		var kind := reader.actor_kind(i)
		var id := reader.actor_id(i)
		match kind:
			WorldReader.KIND_WIRE_WEAVER:
				if reader.actor_state(i) == WorldReader.STATE_WINDUP and tick % MARK_EVERY == 0:
					var tg := reader.telegraph(i)
					if tg.has("obb"):
						var o: Obb = tg["obb"]
						for s in [1.0, -1.0]:
							_spark(o.center + Kin.dir(o.angle) * (o.half.x * s), 0.15)
			WorldReader.KIND_STONE_THROWER:
				seen[id] = true
				_sync_flight(reader, i, id)
			WorldReader.KIND_ROCK_LURKER:
				_sync_lurker(reader, i, id, tick)
			WorldReader.KIND_SCRAP_HOUND:
				var y := reader.hound_yelped(i)
				if y and not _yelped.get(id, false) and pack_fx != null:
					pack_fx.spawn(YELP_ID, SimPlane.to_3d(reader.actor_pos(i), 0.6), 0.7)
				_yelped[id] = y
	for id: int in _flying.keys():
		if not seen.has(id):
			(_flying[id] as Node).queue_free()
			_flying.erase(id)


func _sync_cables(reader: WorldReader, tick: int) -> void:
	var live := reader.cables()
	while _cables.size() > live.size():
		_cables.pop_back().queue_free()
	while _cables.size() < live.size():
		var mi := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = CABLE_R
		m.bottom_radius = CABLE_R
		m.height = 1.0
		m.radial_segments = 5
		m.rings = 1
		mi.mesh = m
		mi.material_override = _cable_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_cables.append(mi)
	var now := {}
	for k in live.size():
		var a: Vector2 = live[k][0]
		var b: Vector2 = live[k][1]
		var a3 := SimPlane.to_3d(a, CABLE_Y)
		var b3 := SimPlane.to_3d(b, CABLE_Y)
		var mi := _cables[k]
		var span := a3.distance_to(b3)
		mi.position = (a3 + b3) * 0.5
		if span > 0.001:
			mi.basis = Basis(Quaternion(Vector3.UP, (b3 - a3) / span)).scaled(Vector3(1, span, 1))
		var key := "%d" % live[k][3] + "|%d" % k
		now[key] = [a, b]
		if (tick + k * 7) % SPARK_EVERY == 0:
			var u := float((tick / SPARK_EVERY + k * 3) % 7) / 6.0
			_spark(a.lerp(b, u), CABLE_Y)
		if int(live[k][2]) == 0:  # it just went live: a spark at each post
			_spark(a, CABLE_Y)
			_spark(b, CABLE_Y)
	for key: String in _cable_ends:
		if not now.has(key):
			var ends: Array = _cable_ends[key]
			_spark(ends[0], CABLE_Y)
			_spark(ends[1], CABLE_Y)
	_cable_ends = now


func _spark(at: Vector2, y: float) -> void:
	if pack_fx != null:
		pack_fx.spawn(SPARK_ID, SimPlane.to_3d(at, y), SPARK_SCALE, SPARK_COLORS)


func _boulder() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var piece := KitModels.get_piece(ROCK_MODEL)
	if piece.is_empty():
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		mi.mesh = box
	else:
		mi.mesh = piece["mesh"]
		mi.material_override = piece["material"]
	return mi


func _sync_rocks(rocks: Array) -> void:
	var spots := []
	for r: Array in rocks:
		spots.append(r[0])
	for k in range(_rocks.size() - 1, -1, -1):
		if not spots.has(_rock_spots[k]):
			if pack_fx != null:
				pack_fx.spawn(DUST_ID, SimPlane.to_3d(_rock_spots[k], 0.0), DUST_SCALE)
			_rocks[k].queue_free()
			_rocks.remove_at(k)
			_rock_spots.remove_at(k)
	for r: Array in rocks:
		if _rock_spots.has(r[0]):
			continue
		var at := SimPlane.to_3d(r[0], 0.0)
		var side: float = float(r[1]) * 2.0 * ROCK_SPREAD
		var mi := _boulder()
		mi.position = at
		mi.scale = Vector3(side, ROCK_HEIGHT, side)
		mi.rotation.y = 0.7 * _rocks.size()
		add_child(mi)
		_rocks.append(mi)
		_rock_spots.append(r[0])
		if pack_fx != null:
			pack_fx.spawn(DUST_ID, at, DUST_SCALE)


func _sync_flight(reader: WorldReader, i: int, id: int) -> void:
	var u := reader.thrower_flight(i)
	if u < 0:
		if _flying.has(id):
			(_flying[id] as Node).queue_free()
			_flying.erase(id)
		return
	var mi: MeshInstance3D = _flying.get(id)
	if mi == null:
		mi = _boulder()
		mi.scale = Vector3(0.7, 0.6, 0.7)
		add_child(mi)
		_flying[id] = mi
	var p := u / 1000.0
	var from := reader.actor_pos(i)
	var to := reader.thrower_target(i)
	var y := THROW_FROM_Y * (1.0 - p) + THROW_ARC_M * 4.0 * p * (1.0 - p)
	mi.position = SimPlane.to_3d(from.lerp(to, p), y)


func _sync_lurker(reader: WorldReader, i: int, id: int, tick: int) -> void:
	var hidden := reader.lurker_hidden(i)
	var was: bool = _hidden.get(id, hidden)
	_hidden[id] = hidden
	if pack_fx == null:
		return
	var at := SimPlane.to_3d(reader.actor_pos(i), 0.0)
	var slam := reader.actor_state(i) == WorldReader.STATE_ACTIVE
	if slam and not _slamming.get(id, false):  # v0.11.0 O17b: the smash lands (its disc is round where it stands)
		pack_fx.spawn(DUST_ID, at, DUST_SCALE * 2.2)
	_slamming[id] = slam
	if was and not hidden:
		pack_fx.spawn(DUST_ID, at, DUST_SCALE * 1.6)
		pack_fx.spawn(SHATTER_ID, at + Vector3(0, 0.5, 0), 0.8)
	elif hidden and reader.lurker_rumbling(i) and (tick + id) % RUMBLE_EVERY == 0:
		pack_fx.spawn(DUST_ID, at, DUST_SCALE * 0.6)
