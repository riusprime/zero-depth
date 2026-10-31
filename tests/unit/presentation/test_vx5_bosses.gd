extends GutTest
## v0.10.0 VX5 (VFX_PACK R13, R19, R21, R27, R36-R42): the boss, elite and shield effects that are the pack's. Each
## replaced effect spawns its pack id, the held ones (beams, fire lanes, molten floor, the shell) are let go the frame
## they end, one-shots start once a strike, and a full family keeps that instance's old look.


## A node PackHold.find reads a PackFx from (WorldViewRoot's `pack_fx`).
class Holder:
	extends Node3D
	var pack_fx: PackFx


var _holder: Holder
var _fx: PackFx
var _saved := ""


func before_each() -> void:
	_saved = ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"
	_holder = add_child_autofree(Holder.new())
	_fx = PackFx.new()
	_holder.add_child(_fx)
	_holder.pack_fx = _fx


func after_each() -> void:
	ViewPrefs.effects_density = _saved


func _under(n: Node) -> Node:
	_holder.add_child(n)
	return n


func _fill(family: StringName, id: StringName) -> void:
	while _fx.has_room(family):
		_fx.spawn(id, Vector3.ZERO, 1.0, {}, 0.0)


# --- The table and the helper -------------------------------------------------------------------------------------
func test_every_id_is_in_the_table_with_the_family_the_helper_says() -> void:
	for id: StringName in PackHold.FAMILY:
		assert_true(_fx.has_id(id), "%s is in data/vfx" % id)
		var n := _fx.spawn(id, Vector3.ZERO, 1.0, {}, 0.0)
		assert_not_null(n, "%s loads" % id)
		assert_eq(
			_fx.live_count(PackHold.FAMILY[id]) > 0,
			true,
			"%s is in its family %s" % [id, PackHold.FAMILY[id]]
		)
		_fx.release(n)


func test_a_beam_takes_the_scene_nearest_its_colour() -> void:
	assert_eq(PackHold.beam_id(Color(1.0, 0.16, 0.3)), &"bx_beam_05", "the Prism's pink-red")
	assert_eq(PackHold.beam_id(Color(0.9, 0.1, 0.05)), &"bx_beam_01", "red")
	assert_eq(PackHold.beam_id(Color("#B8FFF4")), &"bx_beam_04", "the Conduit's teal")
	assert_eq(PackHold.beam_id(Color(0.9, 0.9, 0.92)), &"bx_beam_08", "near white is the steel one")


func test_a_held_effect_goes_back_when_it_is_not_asked_again() -> void:
	var h := PackHold.new(_fx)
	h.begin()
	assert_not_null(h.hold(&"a", &"bx_shell", Vector3.ZERO))
	h.end()
	assert_eq(_fx.live_count(&"area"), 1, "held")
	h.begin()
	h.hold(&"a", &"bx_shell", Vector3(1, 0, 0))
	h.end()
	assert_eq(_fx.live_count(&"area"), 1, "still the one")
	assert_eq(_fx.spawned, 1, "not a new one each frame")
	h.begin()
	h.end()
	assert_eq(_fx.live_count(&"area"), 0, "let go the frame it stopped")
	assert_eq(h.held_count(), 0)


func test_a_full_family_answers_no_and_a_one_shot_remembers_it() -> void:
	var h := PackHold.new(_fx)
	_fill(&"cloud", &"bx_smoke_dust")
	h.begin()
	assert_false(h.once(&"k", &"bx_smoke_big", Vector3.ZERO), "no room: the old look")
	h.end()
	h.begin()
	_fx.release(_fx.spawn(&"bx_smoke_dust", Vector3.ZERO, 1.0, {}, 0.0))  # a slot opens
	assert_false(h.once(&"k", &"bx_smoke_big", Vector3.ZERO), "the same strike keeps its old look")
	assert_true(h.once(&"k2", &"bx_smoke_big", Vector3.ZERO), "a new strike takes the pack's")
	h.end()
	var beams := PackHold.new(_fx)
	_fill(&"beam", &"bx_beam_01")
	beams.begin()
	assert_null(beams.hold(1, &"bx_beam_05", Vector3.ZERO), "no beam slot: the old cylinders")


func test_a_one_shot_starts_once_per_key_across_frames() -> void:
	var h := PackHold.new(_fx)
	for k in 5:
		h.begin()
		h.once(&"strike", &"bx_impact_a", Vector3.ZERO)
		h.end()
	assert_eq(_fx.spawned, 1, "once")
	h.begin()
	h.end()
	assert_false(h.decided(&"strike"), "forgotten when the strike is gone")


# --- The strikes (R27 rail, R36-R39) -----------------------------------------------------------------------------
func _layer() -> VfxLayer:
	var l: VfxLayer = _under(VfxLayer.new())
	l.pack_fx = _fx
	return l


func _strike(kind: StringName, extra: Dictionary) -> Dictionary:
	var s := {"kind": kind, "tick": 100, "end": 100, "seed": 7, "glow": Color(1.0, 0.5, 0.2)}
	s.merge(extra, true)
	return s


func _frame(l: VfxLayer, strikes: Array[Dictionary], now: float) -> void:
	l.begin(now)
	BossStrikeFx.draw(l, strikes, now)
	l.finish()


func test_a_crater_spawns_its_burst_and_dust_once_per_disc() -> void:
	var l := _layer()
	var s := _strike(&"crater", {"discs": [[Vector2(2, 0), 2.0, true], [Vector2(6, 0), 2.0, true]]})
	for k in 6:
		_frame(l, [s], 100.0 + k)
	assert_eq(_fx.live_count(&"impact"), 2, "one burst a disc, not a frame")
	assert_eq(_fx.live_count(&"cloud"), 2, "one dust cloud a disc")
	_frame(l, [], 110.0)
	assert_eq(_fx.spawned, 4)


func test_a_crack_impact_takes_the_other_burst() -> void:
	var l := _layer()
	var n := _fx.spawned
	_frame(l, [_strike(&"crack_impact", {"discs": [[Vector2.ZERO, 1.5, true]]})], 100.0)
	assert_eq(_fx.spawned, n + 2)


func test_the_rings_and_the_light_strikes_spawn_their_areas() -> void:
	var l := _layer()
	_frame(l, [_strike(&"light_burst", {"discs": [[Vector2.ZERO, 2.0, true]]})], 100.0)
	assert_eq(_fx.live_count(&"area"), 1, "a pillar of light")
	_frame(l, [_strike(&"light_ring", {"ring": [Vector2(9, 0), 1.0, 3.0], "seed": 6})], 100.0)
	assert_eq(_fx.live_count(&"area"), 2, "a pulse")
	_frame(l, [_strike(&"shock_ring", {"ring": [Vector2(0, 9), 0.5, 6.0], "seed": 8})], 100.0)
	assert_eq(_fx.live_count(&"area"), 3, "a shock pulse")
	_frame(l, [_strike(&"steam_ring", {"ring": [Vector2(0, -9), 0.5, 6.0], "seed": 9})], 100.0)
	assert_eq(_fx.live_count(&"area"), 4, "a steam pulse")
	assert_eq(_fx.live_count(&"cloud"), 1, "and its thin smoke")


func test_a_dust_arc_and_a_skid_puff_the_small_dust() -> void:
	var l := _layer()
	var arc := _strike(&"dust_arc", {"arc": [Vector2.ZERO, 1.0, 5.0, 0.0, 1.0]})
	_frame(l, [arc], 100.0)
	assert_eq(_fx.live_count(&"cloud"), 1, "the arc's dust")
	var skid := _strike(&"skid", {"end": -1, "to": Vector2(4, 0), "seed": 12})
	_frame(l, [skid], 101.0)
	assert_eq(_fx.live_count(&"cloud"), 2, "the skid's puff")
	_frame(l, [skid], 102.0)
	assert_eq(_fx.live_count(&"cloud"), 2, "not another every frame")


func test_fire_lanes_are_a_row_of_flames_held_while_the_strike_burns() -> void:
	var l := _layer()
	var lane := Obb.make(Vector2(5, 0), Vector2(4.0, 1.0), 0)
	var s := _strike(&"fire_lanes", {"end": -1, "lanes": [lane]})
	_frame(l, [s], 110.0)
	var row := _fx.live_count(&"status")
	assert_between(row, 2, BossStrikeFx.FLAMES_PER_LANE, "a flame about every metre, capped")
	assert_eq(row, 8, "an eight metre lane is eight flames")
	_frame(l, [s], 111.0)
	assert_eq(_fx.live_count(&"status"), row, "held, not respawned")
	s["end"] = 111
	_frame(l, [s], 130.0)
	assert_eq(_fx.live_count(&"status"), 0, "let go when the lane stops burning")


func test_a_long_lane_is_capped() -> void:
	var l := _layer()
	var lane := Obb.make(Vector2(10, 0), Vector2(20.0, 1.0), 0)
	_frame(l, [_strike(&"fire_lanes", {"end": -1, "lanes": [lane]})], 110.0)
	assert_eq(_fx.live_count(&"status"), BossStrikeFx.FLAMES_PER_LANE)


func test_full_status_keeps_the_old_flames_for_the_lane() -> void:
	var l := _layer()
	_fill(&"status", &"bx_fire_lane_a")
	var n := _fx.spawned
	var lane := Obb.make(Vector2(5, 0), Vector2(4.0, 1.0), 0)
	_frame(l, [_strike(&"fire_lanes", {"end": -1, "lanes": [lane]})], 110.0)
	assert_eq(_fx.spawned, n, "no pack flames when the family is full")


func test_a_rail_is_a_blast_beam_for_its_first_ten_ticks() -> void:
	var l := _layer()
	var lane := Obb.make(Vector2(8, 0), Vector2(8.0, 0.6), 0)
	var s := _strike(&"rail", {"lanes": [lane]})
	_frame(l, [s], 102.0)
	assert_eq(_fx.live_count(&"beam"), 1, "the blast")
	_frame(l, [s], 103.0)
	assert_eq(_fx.live_count(&"beam"), 1, "held")
	_frame(l, [s], 112.0)
	assert_eq(_fx.live_count(&"beam"), 0, "let go when the rail is over")


func test_a_full_cloud_family_keeps_the_dust_sprites() -> void:
	var l := _layer()
	_fill(&"cloud", &"bx_smoke_dust")
	var n := _fx.spawned
	_frame(l, [_strike(&"crater", {"discs": [[Vector2(2, 0), 2.0, true]]})], 100.0)
	assert_eq(_fx.live_count(&"cloud"), _fx.cap_for(&"cloud"), "no new smoke")
	assert_eq(_fx.spawned, n + 1, "only the burst")
