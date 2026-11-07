class_name StarfallViews
extends Node3D
## v0.11.0 O13d (ENEMIES.md R9, R10): the Starfall signatures' tells, read through WorldReader (EI-07), in the premade
## pack's effects (PD-13; data/vfx/pack_fx_o13d.tres, BinbunVFX):
## - the Star Warper's star: while it winds up, a ring on the floor the size of its strike (o13d_star_ring:
##   magic_areas rim_area_vfx_02, pale gold) and the star itself at its centre (o13d_star_core: magic_orbs
##   magic_orb_flare_vfx_01), held until the windup ends (the red disc that fills is EnemyAi.telegraph's, as every
##   ground tell);
## - the blink: a flash where it left and where it lands (o13d_blink: magic_orbs magic_orb_flash_vfx_01, violet);
## - the stun (the hero stood on the star): a gold ripple at its feet (o13d_stun: magic_areas ripple_area_vfx_01);
## - the Gravity Node's swirl: a violet ripple the size of its pull's reach, held while it lives (o13d_swirl:
##   magic_areas ripple_area_vfx_03).
## Nothing here decides.

const STAR_RING := &"o13d_star_ring"
const STAR_CORE := &"o13d_star_core"
const BLINK := &"o13d_blink"
const STUN := &"o13d_stun"
const SWIRL := &"o13d_swirl"
## The pack's area scenes' scale per metre of the radius they fill (as VfxPackViews' rings).
const RING_PER_M := 0.55
const CORE_SCALE := 0.6
const BLINK_SCALE := 0.8
const STUN_SCALE := 0.6
const GROUND_Y := 0.05

## The pack (WorldViewRoot sets it; null: nothing drawn).
var pack_fx: PackFx = null
var _stars := {}  # warper id -> [ring node, core node]
var _swirls := {}  # node id -> swirl node
var _seen := {}  # warper id -> [state, stunned, pos]


func sync(reader: WorldReader) -> void:
	if pack_fx == null:
		return
	var any_warper := reader.any_kind(WorldReader.KIND_STAR_WARPER)
	var any_node := reader.any_kind(WorldReader.KIND_GRAVITY_NODE)
	if not any_warper and not any_node and _stars.is_empty() and _swirls.is_empty():
		return
	var live_stars := {}
	var live_swirls := {}
	for i in range(1, reader.actor_count()):
		var kind := reader.actor_kind(i)
		var id := reader.actor_id(i)
		if kind == WorldReader.KIND_STAR_WARPER:
			_sync_warper(reader, i, id, live_stars)
		elif kind == WorldReader.KIND_GRAVITY_NODE and not reader.actor_dead(i):
			live_swirls[id] = true
			var at := SimPlane.to_3d(reader.actor_pos(i), GROUND_Y)
			if not _swirls.has(id) or not pack_fx.is_live(_swirls[id]):
				_swirls[id] = pack_fx.spawn(
					SWIRL, at, reader.gravity_reach(i) * RING_PER_M, {}, 0.0
				)
			elif _swirls[id] != null:
				(_swirls[id] as Node3D).global_position = at
	for id in _stars.keys():
		if not live_stars.has(id):
			_drop_star(id)
	for id in _swirls.keys():
		if not live_swirls.has(id):
			if _swirls[id] != null and pack_fx.is_live(_swirls[id]):
				pack_fx.release(_swirls[id])
			_swirls.erase(id)
	for id in _seen.keys():
		if reader.actor_index(id) < 0:
			_seen.erase(id)


## Stars and swirls held now (tests).
func star_count() -> int:
	return _stars.size()


func swirl_count() -> int:
	return _swirls.size()


func _sync_warper(reader: WorldReader, i: int, id: int, live: Dictionary) -> void:
	var star := reader.warper_star(i)
	if not star.is_empty():
		live[id] = true
		if not _stars.has(id):
			var c := SimPlane.to_3d(star[0], GROUND_Y)
			_stars[id] = [
				pack_fx.spawn(STAR_RING, c, float(star[1]) * RING_PER_M, {}, 0.0),
				pack_fx.spawn(STAR_CORE, SimPlane.to_3d(star[0], 0.3), CORE_SCALE, {}, 0.0),
			]
	var st := reader.actor_state(i)
	var stunned := reader.warper_stunned(i)
	var pos := reader.actor_pos(i)
	var was: Array = _seen.get(id, [st, stunned, pos])
	if st == WorldReader.STATE_ACTIVE and int(was[0]) != st:  # the blink: a flash where it left and where it lands
		pack_fx.spawn(BLINK, SimPlane.to_3d(was[2], SimPlane.CORE_HEIGHT), BLINK_SCALE)
		pack_fx.spawn(BLINK, SimPlane.to_3d(pos, SimPlane.CORE_HEIGHT), BLINK_SCALE)
	if stunned and not bool(was[1]):
		pack_fx.spawn(STUN, SimPlane.to_3d(pos, GROUND_Y), STUN_SCALE)
	_seen[id] = [st, stunned, pos]


func _drop_star(id: int) -> void:
	for node: Variant in _stars[id]:
		if node != null and pack_fx.is_live(node):
			pack_fx.release(node)
	_stars.erase(id)
