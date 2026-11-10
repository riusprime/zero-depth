class_name RuinsRocksViews
extends Node3D
## ENEMIES.md R1-R4: what the Ruins' and the Night Rocks' signature enemies put on the floor, read
## through WorldReader (EI-07), in the premade packs' effects (PD-13):
## - a Wire Weaver's cable: a glowing yellow line between its posts' tops (code), crackling with the pack's storm hit
##   spark (vx1_hit_storm: BinbunVFX hit vfx_hit_01, tinted yellow) along it; while it marks a cable, the same spark
##   at the two spots its posts go in (the tell: "the posts spark as they go in"); a cable dropping bursts the spark at
##   both ends;
## - a Stone Thrower's rock: v0.11.0 O17c (owner 2026-11-08: "animate also the rock impact with assets we already have
##   in the game"): as it tears the rock out of the floor, the pack's dust and debris (bx_shatter) burst in front of
##   it; the owner's rock (its model's `rock` part, the one StoneThrowerAvatar holds overhead; the kit's small
##   boulder, KitModels boulder_small, without the model) flies from the Thrower's hands (StoneThrowerAvatar.RELEASE_AT)
##   on the sim's arc to its ring, tumbling forward; landing, it hits: the pack's rock impact (bx_impact_a:
##   vfx_impact_03, its sparks in stone colours and its ground decal, as the quake pillars' shatter), its dust
##   (bx_smoke_dust: smoke_vfx_05), the boss strikes' crack mark on the floor (BossStrikeFx.crack_mark, a VfxCore
##   mark), a small camera shake (IsoRig.shake; none with shake off or reduced motion) and the rock's own squash and
##   settle; it stands in the pose it landed in for its time, then cracks down into the floor over its last half
##   second and crumbles (the debris and the dust). A rock with no room to stand (the sim skips it) bursts where it
##   lands;
## - a Rock Lurker: the pack's dust puffing at its foot while it rumbles, and the dust with the shatter
##   (bx_shatter) as it bursts out; the same dust, wide, where its claws smash down (its hit tick);
## - a Scrap Hound's yelp: the pack's plain hit spark (vx1_hit_plain) at its head when a hit stops it.
## Nothing here decides.

const ROCK_MODEL := &"boulder_small"
const ROCK_SPREAD := 1.25
const ROCK_HEIGHT := 0.6
## The thrown rock's tumble (turns over its flight), its landing (the squash's length in seconds, the
## shake, the debris's and the impact's scales, the crack mark's radius and colour) and its end (the ticks it sinks
## over, how deep).
const TUMBLE_TURNS := 1.25
const LAND_SECONDS := 0.32
const LAND_SHAKE := 0.12
const IMPACT_ID := &"bx_impact_a"
const IMPACT_SCALE := 0.5
const IMPACT_HIDE := ["Core", "Smoke", "Ground_Impact", "Impact_Streaks1", "Impact_Streaks2"]
const IMPACT_COLORS := {
	&"primary": Color(0.8, 0.75, 0.68),
	&"secondary": Color(0.56, 0.5, 0.45),
	&"tertiary": Color(0.3, 0.27, 0.24)
}
const DEBRIS_SCALE := 0.6
const CRACK_R := 1.05
const CRACK_COLOR := Color(0.07, 0.05, 0.045, 0.85)
const CRUMBLE_TICKS := 30
## The rip: the lift's share at which the hands tear the rock out (StoneThrowerPoses: the dig), and how far in front of
## the Thrower (m) its dust and debris burst.
const RIP_AT := 0.34
const RIP_AHEAD_M := 0.45
const CRUMBLE_SINK_M := 0.3
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
## The flying rock's arc: from the hands (StoneThrowerAvatar.RELEASE_AT), peaking this much above
## the line.
const THROW_ARC_M := 2.2

var pack_fx: PackFx = null
## The floor marks' layer (the crack where a rock lands) and the camera (its small shake), or null.
var vfx: VfxCore = null
var rig: IsoRig = null
var _cables: Array[MeshInstance3D] = []
var _cable_ends := {}  # owner|a|b key -> [a, b] (the last ends seen: a drop bursts there)
var _rocks: Array[MeshInstance3D] = []
var _rock_spots: Array = []
var _flying := {}  # thrower id -> MeshInstance3D
var _aim := {}  # A flight's landing spot (key) -> [its rock's basis now, thrower id]
var _landed := {}  # thrower id -> the landing spot of its flight already hit (its impact plays once)
var _settle: Array[float] = []  # per standing rock: frame seconds since it landed (its squash; -1 done)
var _rock_base: Array[Basis] = []  # per standing rock: its landed pose
var _hidden := {}  # lurker id -> was hidden
var _slamming := {}  # lurker id -> was in its hit tick
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


## The thrown rock: the owner's (its model's `rock` part, at the size StoneThrowerAvatar holds it), else
## the kit's boulder (sized as before).
func _boulder() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := EnemyModels.get_model(StoneThrowerAvatar.MODEL_ID)
	var parts: Dictionary = m.get("parts", {})
	if parts.has(&"rock"):
		mi.mesh = (parts[&"rock"] as Dictionary)["mesh"]
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = m["texture"]
		mat.roughness = 1.0
		mi.material_override = mat
		mi.set_meta(&"owner_rock", float(m["scale"]) * StoneThrowerAvatar.ROCK_SCALE)
		return mi
	var piece := KitModels.get_piece(ROCK_MODEL)
	if piece.is_empty():
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		mi.mesh = box
	else:
		mi.mesh = piece["mesh"]
		mi.material_override = piece["material"]
	return mi


## The scale a rock's mesh is drawn at (`side`: the sim's square, for the kit's boulder).
static func _rock_scale(mi: MeshInstance3D, side: float, flying: bool) -> Vector3:
	if mi.has_meta(&"owner_rock"):
		return Vector3.ONE * float(mi.get_meta(&"owner_rock"))
	return Vector3(0.7, 0.6, 0.7) if flying else Vector3(side, ROCK_HEIGHT, side)


## How high the rock's middle stands over the floor (the owner's rock is centred on its pivot).
static func _rest_y(mi: MeshInstance3D) -> float:
	if mi.has_meta(&"owner_rock") and mi.mesh != null:
		return -mi.mesh.get_aabb().position.y * float(mi.get_meta(&"owner_rock"))
	return 0.0


static func _spot_key(at: Vector2) -> String:
	return "%d:%d" % [roundi(at.x * 100.0), roundi(at.y * 100.0)]


func _sync_rocks(rocks: Array) -> void:
	var spots := []
	for r: Array in rocks:
		spots.append(r[0])
	for k in range(_rocks.size() - 1, -1, -1):
		if not spots.has(_rock_spots[k]):
			if pack_fx != null:  # it crumbles: debris and dust
				var at3 := SimPlane.to_3d(_rock_spots[k], 0.0)
				pack_fx.spawn(DUST_ID, at3, DUST_SCALE)
				pack_fx.spawn(SHATTER_ID, at3 + Vector3(0, 0.2, 0), DEBRIS_SCALE * 0.8)
			_rocks[k].queue_free()
			_rocks.remove_at(k)
			_rock_spots.remove_at(k)
			_settle.remove_at(k)
			_rock_base.remove_at(k)
	for r: Array in rocks:
		var k := _rock_spots.find(r[0])
		if k >= 0:
			_crumble(k, int(r[2]))
			continue
		var at := SimPlane.to_3d(r[0], 0.0)
		var side: float = float(r[1]) * 2.0 * ROCK_SPREAD
		var mi := _boulder()
		var aim: Array = _aim.get(_spot_key(r[0]), [])
		var basis := Basis(Vector3.UP, 0.7 * _rocks.size())
		if not aim.is_empty():  # it stands as it came down
			basis = aim[0]
			_landed[aim[1]] = _spot_key(r[0])
			_aim.erase(_spot_key(r[0]))
			_impact(at)
		basis = basis.orthonormalized()
		mi.basis = basis.scaled_local(_rock_scale(mi, side, false))
		mi.position = at + Vector3(0, _rest_y(mi), 0)
		add_child(mi)
		_rocks.append(mi)
		_rock_spots.append(r[0])
		_settle.append(0.0 if not aim.is_empty() else -1.0)
		_rock_base.append(basis)
		if pack_fx != null and aim.is_empty():
			pack_fx.spawn(DUST_ID, at, DUST_SCALE)


## A rock coming down: the pack's rock impact (its stone-coloured sparks and ground decal), its dust,
## the crack mark, a small shake.
func _impact(at: Vector3) -> void:
	if pack_fx != null:
		pack_fx.spawn(
			IMPACT_ID, at + Vector3(0, 0.05, 0), IMPACT_SCALE, IMPACT_COLORS, -1.0, 1.0, IMPACT_HIDE
		)
		pack_fx.spawn(DUST_ID, at, DUST_SCALE * 1.6)
	if vfx != null:
		var key := 0x5A000000 + absi(roundi(at.x * 37.0) * 7919 + roundi(at.z * 53.0)) % 0xFFFFFF
		vfx.mark(key, BossStrikeFx.crack_mark(), at + Vector3(0, 0.02, 0), CRACK_R, CRACK_COLOR)
	if rig != null:
		rig.shake(LAND_SHAKE)


## Standing rock k with `left` ticks to go: over its last CRUMBLE_TICKS it cracks down into the floor.
func _crumble(k: int, left: int) -> void:
	var u := 1.0 - clampf(float(left) / CRUMBLE_TICKS, 0.0, 1.0)
	if u <= 0.0:
		return
	_settle[k] = -1.0
	var mi := _rocks[k]
	var at := SimPlane.to_3d(_rock_spots[k], 0.0)
	var tilt := Basis(Vector3.RIGHT, 0.18 * u) * Basis(Vector3.BACK, -0.12 * u)
	mi.basis = (tilt * _rock_base[k]).scaled_local(_rock_scale(mi, 1.0, false) * (1.0 - 0.12 * u))
	mi.position = at + Vector3(0, _rest_y(mi) - CRUMBLE_SINK_M * u * u, 0)
	if pack_fx != null and left == CRUMBLE_TICKS - 1:
		pack_fx.spawn(DUST_ID, at, DUST_SCALE * 0.4)


## The landed rocks' squash and settle (frame time: it only plays out the landing the sim made).
func _process(delta: float) -> void:
	for k in _settle.size():
		if _settle[k] < 0.0:
			continue
		_settle[k] += clampf(delta, 0.0, 0.05)
		var u := _settle[k] / LAND_SECONDS
		var mi := _rocks[k]
		var sq := land_squash(u, ViewPrefs.reduced_motion)
		var size := _rock_scale(mi, 1.0, false)
		mi.basis = _rock_base[k].scaled_local(
			size * Vector3(1.0 + 0.5 * sq, 1.0 - sq, 1.0 + 0.5 * sq)
		)
		mi.position.y = _rest_y(mi) * (1.0 - sq)
		if u >= 1.0:
			_settle[k] = -1.0


## The landing's squash at u (0..1 of LAND_SECONDS): flattened on the hit, a little rebound past round, settled.
static func land_squash(u: float, calm: bool) -> float:
	if u >= 1.0 or u < 0.0:
		return 0.0
	var k := 0.5 if calm else 1.0
	return k * 0.22 * cos(u * PI * 2.2) * (1.0 - u) * (1.0 - u)


## Standing rocks still settling from their landing (tests).
func settling_count() -> int:
	var n := 0
	for s in _settle:
		n += 1 if s >= 0.0 else 0
	return n


func _sync_flight(reader: WorldReader, i: int, id: int) -> void:
	var lift := reader.thrower_ticks(i).x
	if (
		pack_fx != null
		and reader.actor_state(i) == WorldReader.STATE_WINDUP
		and reader.actor_state_ticks(i) == roundi(lift * RIP_AT)
	):  # The rock torn out of the floor in front of it
		var ahead := SimPlane.to_3d(
			reader.actor_pos(i) + Kin.dir(reader.actor_facing(i)) * RIP_AHEAD_M
		)
		pack_fx.spawn(DUST_ID, ahead, DUST_SCALE * 1.2)
		pack_fx.spawn(SHATTER_ID, ahead + Vector3(0, 0.1, 0), DEBRIS_SCALE * 0.6)
	var u := reader.thrower_flight(i)
	var to := reader.thrower_target(i)
	if u < 0:
		if _flying.has(id):
			if _landed.get(id, "") != _spot_key(to):  # no rock stood up where it fell: it bursts there
				_burst(SimPlane.to_3d(to, 0.0))
				_aim.erase(_spot_key(to))
			(_flying[id] as Node).queue_free()
			_flying.erase(id)
			_landed.erase(id)
		return
	var mi: MeshInstance3D = _flying.get(id)
	if mi == null:
		mi = _boulder()
		add_child(mi)
		_flying[id] = mi
		_landed.erase(id)
	var p := u / 1000.0
	var d3 := SimPlane.to_3d(Kin.dir(reader.actor_facing(i))).normalized()
	var start := (
		SimPlane.to_3d(reader.actor_pos(i), StoneThrowerAvatar.RELEASE_AT.y)
		+ d3 * StoneThrowerAvatar.RELEASE_AT.x
	)
	var end := SimPlane.to_3d(to, _rest_y(mi))
	var y := lerpf(start.y, end.y, p) + THROW_ARC_M * 4.0 * p * (1.0 - p)
	var flat := Vector2(start.x, start.z).lerp(Vector2(end.x, end.z), p)
	mi.position = Vector3(flat.x, y, flat.y)
	var travel := Vector3(end.x - start.x, 0.0, end.z - start.z)
	var ahead := travel.normalized() if travel.length() > 0.01 else d3
	var axis := Vector3.UP.cross(ahead).normalized()
	var held := Basis(d3, Vector3.UP, d3.cross(Vector3.UP))  # as it sat in the hands (the avatar's frame)
	var basis := Basis(axis, -TUMBLE_TURNS * TAU * p) * held
	mi.basis = basis.scaled_local(_rock_scale(mi, 1.0, true))
	_aim[_spot_key(to)] = [basis, id]


## A rock the sim found no room for bursts where it fell (the debris and the dust).
func _burst(at: Vector3) -> void:
	_impact(at)
	if pack_fx != null:
		pack_fx.spawn(SHATTER_ID, at + Vector3(0, 0.3, 0), DEBRIS_SCALE * 1.2)
		pack_fx.spawn(DUST_ID, at, DUST_SCALE * 1.3)


func _sync_lurker(reader: WorldReader, i: int, id: int, tick: int) -> void:
	var hidden := reader.lurker_hidden(i)
	var was: bool = _hidden.get(id, hidden)
	_hidden[id] = hidden
	if pack_fx == null:
		return
	var at := SimPlane.to_3d(reader.actor_pos(i), 0.0)
	var slam := reader.actor_state(i) == WorldReader.STATE_ACTIVE
	if slam and not _slamming.get(id, false):  # The smash lands (its disc is round where it stands)
		pack_fx.spawn(DUST_ID, at, DUST_SCALE * 2.2)
	_slamming[id] = slam
	if was and not hidden:
		pack_fx.spawn(DUST_ID, at, DUST_SCALE * 1.6)
		pack_fx.spawn(SHATTER_ID, at + Vector3(0, 0.5, 0), 0.8)
	elif hidden and reader.lurker_rumbling(i) and (tick + id) % RUMBLE_EVERY == 0:
		pack_fx.spawn(DUST_ID, at, DUST_SCALE * 0.6)
