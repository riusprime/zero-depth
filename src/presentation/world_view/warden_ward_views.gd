class_name WardenWardViews
extends Node3D
## The Twin Wardens' shields, drawn from WorldReader.boss_wardens and boss_twin (EI-07: what is warded, which side the
## Mirror Ward faces, what it turns back and when the whole ward breaks are the sim's, BossWard).
## - The resting Warden's immune shield: a clear dome in its own colour round it (the pack's forcefield, amber or
##   violet), up while it stands back; a hit on it sparks off (HitFeel's TAG_BLOCKED spark, unchanged).
## - The Mirror Ward: a curved violet wall on the reader's arc (its centre and half width) round the violet Warden,
##   a sheet of violet light climbing it (WardenLooks.ARC_SHADER), with the pack's ripple at its foot. Through the
##   cast it rises toward the hero (the side it will face); it stands at full height through the ward and sinks over
##   its last FADE_S. A shot it turns back flashes where it struck (the pack's hit); the returned shot is the hostile
##   violet look the data names. A swing it blocks rings the pack's pulse on the hero, pushed back.
## - The whole ward (the last phase): a larger, brighter dome on the violet Warden (its own forcefield scene) with a
##   rim on the floor. While the amber Warden winds a charge up under it, his lane glows on the floor, white-hot when
##   she stands on it. The break: the pack's shatter and stun flash on her, stars over her while she is stunned (her
##   avatar slumps in its stagger clip, his staggers too), then a ring on the floor counting down to the ward's return
##   and, for its last RETURN_GLOW_S, the pack's rising light as it re-forms.
## Every slot is built hidden at the start. Reduced motion stills the pulses. Nothing here decides an outcome.

const AMBER := WardenLooks.AMBER
const VIOLET := WardenLooks.VIOLET
const DEEP_VIOLET := Color("#5A1FD0")
const DOME_IDS := {
	&"amber": &"tw_dome_amber", &"violet": &"tw_dome_violet", &"full": &"tw_dome_full"
}
## The domes stand for a whole phase: they live in the pack's larger status family, so a crowd of short area effects
## (the floor's own, a burst's rim) never pushes one out.
const DOME_FAMILY := &"status"
const RIM_ID := &"tw_ward_rim"
const REFLECT_ID := &"tw_reflect"
const PUSH_ID := &"tw_push"
const SHATTER_ID := &"tw_shatter"
const REFORM_ID := &"tw_reform"
const STARS_ID := &"o13d_star_ring"
const STUN_ID := &"o13d_stun"
const RIPPLE_ID := &"vx2_zone_ripple"
const EFFECT_REFLECT := &"warden_reflect"
const EFFECT_BLOCK := &"warden_block"
const EFFECT_BREAK := &"warden_ward_break"
## The domes' radius (m, the forcefield is 1 m at scale 1): the resting one round the body, the whole ward wider.
const REST_R := 1.55
const FULL_R := 2.1
const DOME_H := 1.0
## The Mirror Ward's wall: its distance from the Warden's centre and its height (m); it sinks over its last FADE_S.
const WALL_R := 1.9
const WALL_H := 2.6
const FADE_S := 0.3
## Through the cast the sim has no arc yet (it is set as the cast ends): the wall rises on the brief's 160°.
const CAST_HALF_DEG := 80.0
## The ward's return: the floor ring's radius and when the re-forming light starts (s before it returns).
const RETURN_R := 2.4
const RETURN_GLOW_S := 2.0
## The long lane's width (m) and how bright it glows (white-hot while it would break the ward).
const LANE_W := 2.2

## The pack's effects (WorldViewRoot hands them over; a view built alone draws its own meshes only).
var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
var _st := {}
var _resting: Array = []  # [body position (sim), colour key]
var _violet_at := Vector2.ZERO
var _hero_at := Vector2.ZERO
## The Mirror Ward as drawn: its centre angle, half width (1/4096 turns), 0..1 height and whether it is the cast.
var _wall_centre := 0
var _wall_half := 0
var _wall_up := 0.0
var _casting := false
var _cast_share := 0.0
var _left_s := 0.0
## The ward's whole wait to return, as first read after the break (the ring's full turn).
var _return_total := 0.0
var _wall: MeshInstance3D
var _wall_mat: ShaderMaterial
var _lane: MeshInstance3D
var _return_ring: MeshInstance3D
var _last_seq := 0
var _primed := false
var _clock := 0.0


func _init() -> void:
	name = "WardenWardViews"
	_wall = MeshInstance3D.new()
	_wall_mat = WardenLooks.arc_material(VIOLET)
	_wall.material_override = _wall_mat
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall.visible = false
	add_child(_wall)
	_lane = WardenLooks.floor_mesh(self, false, AMBER)
	_return_ring = WardenLooks.floor_mesh(self, true, VIOLET)


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	_st = reader.boss_wardens()
	_hero_at = reader.player_pos()
	_resting = []
	_casting = false
	if not _st.is_empty():
		var j := int(_st["violet"])
		_violet_at = reader.actor_pos(j)
		for body: int in [int(_st["lead"]), j]:
			if bool(reader.boss_twin(body).get("resting", false)):
				_resting.append([reader.actor_pos(body), &"violet" if body == j else &"amber"])
		_read_cast(reader, j)
	_events(reader)


## The Mirror Ward's cast: the violet Warden winds it up; the wall rises toward the hero.
func _read_cast(reader: WorldReader, j: int) -> void:
	var ward: Dictionary = _st["ward"]
	if ward["kind"] == &"mirror":
		_wall_centre = int(ward["centre"])
		_wall_half = int(ward["half_arc"])
		_left_s = float(ward["left"]) / 60.0
		return
	if (
		reader.boss_move(j) != WorldReader.MOVE_MIRROR_WARD
		or reader.actor_state(j) != WorldReader.STATE_WINDUP
	):
		return
	_casting = true
	var ticks := reader.boss_attack_ticks(j)
	_cast_share = clampf(float(reader.actor_state_ticks(j)) / maxf(1.0, ticks.x), 0.0, 1.0)
	var to := _hero_at - _violet_at
	_wall_centre = int(round(fposmod(to.angle(), TAU) / TAU * WardenLooks.TURN))
	_wall_half = int(round(CAST_HALF_DEG / 360.0 * WardenLooks.TURN))


func _events(reader: WorldReader) -> void:
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # joining a fight under way replays nothing that already happened
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.STATUS_APPLY:
			continue
		match e.effect_id:
			EFFECT_REFLECT:
				_spawn(REFLECT_ID, &"hit", SimPlane.to_3d(e.pos, 1.0), 0.7)
			EFFECT_BLOCK:
				_spawn(PUSH_ID, &"impact", SimPlane.to_3d(_hero_at, 0.08), 0.45)
			EFFECT_BREAK:
				_spawn(SHATTER_ID, &"impact", SimPlane.to_3d(_violet_at, 1.1), 1.4)
				_spawn(STUN_ID, &"hit", SimPlane.to_3d(_violet_at, 2.4), 0.9)


func _spawn(id: StringName, family: StringName, at: Vector3, scale: float) -> void:
	if pack_fx != null and pack_fx.has_id(id) and pack_fx.has_room(family):
		pack_fx.spawn(id, at, scale)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	var idle := _st.is_empty() and _wall_up <= 0.0 and hold.count() == 0
	if idle:
		if quiet:
			return
		quiet = true
	else:
		quiet = false
	_clock += delta * (0.0 if ViewPrefs.reduced_motion else 1.0)
	hold.begin()
	_draw_domes()
	_draw_wall(delta)
	_draw_full()
	hold.end()


func _draw_domes() -> void:
	for k in _resting.size():
		var r: Array = _resting[k]
		var which: StringName = r[1]
		var n := hold.put(
			[&"rest", which], DOME_IDS[which], DOME_FAMILY, _dome_at(r[0], REST_R, 1.0)
		)
		var m: ShaderMaterial = null
		if which == &"violet":  # a deep violet: the pale one vanishes on a pale floor (the shader adds its glow)
			m = WardenLooks.field_material(which, DEEP_VIOLET, VIOLET, VIOLET.lightened(0.6))
		else:
			m = WardenLooks.field_material(
				which, AMBER, AMBER.lightened(0.35), AMBER.lightened(0.7)
			)
		WardenLooks.wear(n, m, which)


static func _dome_at(at: Vector2, radius: float, squash: float) -> Transform3D:
	return Transform3D(
		Basis.from_scale(Vector3(radius, radius * DOME_H * squash, radius)), SimPlane.to_3d(at, 0.0)
	)


func _draw_wall(delta: float) -> void:
	var ward: Dictionary = _st.get("ward", {})
	var up: bool = ward.get("kind", &"") == &"mirror"
	var want := 0.0
	if up:
		want = clampf(_left_s / FADE_S, 0.0, 1.0)
	elif _casting:
		want = _cast_share
	_wall_up = move_toward(_wall_up, want, delta * 6.0) if not up and not _casting else want
	_wall.visible = _wall_up > 0.01
	if not _wall.visible:
		return
	_wall.mesh = WardenLooks.arc_wall(_wall_half, WALL_R, WALL_H)
	_wall.position = SimPlane.to_3d(_violet_at, 0.0)
	_wall.rotation = Vector3(0.0, SimPlane.yaw_of(_wall_centre), 0.0)
	_wall.scale = Vector3(1.0, maxf(0.02, _wall_up), 1.0)
	_wall_mat.set_shader_parameter("alpha", (0.45 if _casting else 1.0) * _wall_up)
	_wall_mat.set_shader_parameter(
		"arc_m", WALL_R * TAU * float(_wall_half) * 2.0 / WardenLooks.TURN
	)
	_wall_mat.set_shader_parameter("clock", _clock)
	if up:
		var foot := _violet_at + WardenLooks.dir_of(_wall_centre) * WALL_R
		hold.put(&"wall", RIPPLE_ID, &"area", WardenLooks.at(SimPlane.to_3d(foot, 0.06), 0.7))


func _draw_full() -> void:
	var ward: Dictionary = _st.get("ward", {})
	var full: bool = ward.get("kind", &"") == &"full"
	if full:
		var n := hold.put(
			&"full", DOME_IDS[&"full"], DOME_FAMILY, _dome_at(_violet_at, FULL_R, 1.15)
		)
		var hot := VIOLET.lightened(0.25)
		WardenLooks.wear(
			n, WardenLooks.field_material(&"full", hot, Color(1, 0.9, 1), Color.WHITE), &"full"
		)
		hold.put(
			&"full_rim", RIM_ID, &"area", WardenLooks.at(SimPlane.to_3d(_violet_at, 0.05), 1.3)
		)
	var charge: Dictionary = _st.get("charge", {})
	_lane.visible = full and not charge.is_empty()
	if _lane.visible:
		var o: Obb = charge["lane"]
		var breaks := bool(charge["breaks"])
		WardenLooks.lay_strip(
			_lane, o.center - o.axis_u * o.half.x, o.center + o.axis_u * o.half.x, LANE_W, 0.07
		)
		WardenLooks.param(_lane, &"tint", Color(1, 0.95, 0.8) if breaks else AMBER)
		WardenLooks.param(_lane, &"glow", 2.2 if breaks else 1.3)
		WardenLooks.param(_lane, &"alpha", 0.55 + 0.45 * float(charge["progress"]) / 1000.0)
		WardenLooks.param(_lane, &"clock", _clock)
	var broken := bool(ward.get("broken", false))
	_return_ring.visible = broken
	if not broken:
		_return_total = 0.0
		return
	var stun := int(ward["stun_left"])
	if stun > 0:
		hold.put(&"stars", STARS_ID, &"area", WardenLooks.at(SimPlane.to_3d(_violet_at, 2.5), 0.4))
	var back := float(ward["return_in"]) / 60.0
	_return_ring.position = SimPlane.to_3d(_violet_at, 0.04)
	_return_ring.scale = Vector3.ONE * RETURN_R
	WardenLooks.param(_return_ring, &"share", return_share(ward))
	WardenLooks.param(_return_ring, &"alpha", 0.8)
	WardenLooks.param(_return_ring, &"locked", 0.0)
	WardenLooks.param(_return_ring, &"clock", _clock)
	if back <= RETURN_GLOW_S:
		hold.put(&"reform", REFORM_ID, &"status", WardenLooks.at(SimPlane.to_3d(_violet_at), 1.2))


## The return ring's lit share: it fills from the break (the wait first seen) to the ward's return (0..1).
func return_share(ward: Dictionary) -> float:
	var left := float(ward.get("return_in", 0))
	_return_total = maxf(_return_total, left)
	if left <= 0.0 or _return_total <= 0.0:
		return 1.0
	return clampf(1.0 - left / _return_total, 0.0, 1.0)


## Tests and the shot scripts: what is drawn now.
func resting_domes() -> int:
	return _resting.size()


func wall_shown() -> bool:
	return _wall.visible


func wall_centre() -> int:
	return _wall_centre


func wall_half() -> int:
	return _wall_half


## The wall's height share now (0..1).
func wall_up() -> float:
	return _wall_up


func full_shown() -> bool:
	return _st.get("ward", {}).get("kind", &"") == &"full"


func lane_shown() -> bool:
	return _lane.visible


func return_shown() -> bool:
	return _return_ring.visible
