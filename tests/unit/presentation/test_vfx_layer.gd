extends GutTest
## v0.5.9 art (owner, 2026-10-09: "fire should be fire … not a circle with bad made particles on top"): with a
## VfxLayer, every element draws its own look on every form (fire flames, storm lightning, frost ice crystals, venom
## bubbles, bleed splashes, void tendrils and rifts), bombs land as element bursts, enemy statuses draw in the layer,
## and none of them lays a ground circle. Without one the canvas draws as before (test_attack_forms.gd).

const AT := Vector2(2, 3)
## Each element's main pool: what its patch, ring, beam and burst must draw.
const ELEMENT_POOL := {
	"frost": &"ice",
	"venom": &"bubble",
	"bleed": &"splash",
	"void": &"tendril",
}

var _view: AttackFormView
var _vfx: VfxLayer


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	_view = add_child_autofree(AttackFormView.new())
	_vfx = add_child_autofree(VfxLayer.new())
	_view.vfx = _vfx


func _spec(form: int, els: Array, extra: Dictionary = {}) -> Dictionary:
	var s := {"form": form, "elements": PackedStringArray(els)}
	s.merge(extra, true)
	return s


func _used(id: StringName) -> int:
	return _view.pool(id).used


func test_the_owners_textures_are_installed() -> void:
	assert_true(VfxLayer.available())


func test_a_fire_zone_is_flames_not_a_circle() -> void:
	_view.spawn(
		_spec(WorldReader.FORM_ZONE, ["ember"], {"radius_m": 2.0, "life_ticks": 120}),
		AT,
		0.0,
		{"start": 0}
	)
	_view.draw_at(60.0)
	assert_eq(_used(&"zone_fill"), 0, "no ground disc")
	assert_eq(_used(&"zone_rim"), 0, "no ground ring")
	assert_gt(_vfx.used(&"flame"), 3, "flames")
	assert_gt(_vfx.lights_on(), 0, "the fire lights the floor")
	_view.draw_at(130.0)
	assert_eq(_vfx.used(&"flame"), 0, "gone after its life")


func test_an_electric_zone_and_ring_are_lightning() -> void:
	_view.spawn(
		_spec(WorldReader.FORM_ZONE, ["storm"], {"radius_m": 2.0, "life_ticks": 120}),
		AT,
		0.0,
		{"start": 0}
	)
	_view.spawn(_spec(WorldReader.FORM_RING, ["storm"], {"radius_m": 3.0}), AT, 0.0, {"start": 0})
	_view.draw_at(6.0)
	assert_eq(_used(&"zone_fill") + _used(&"ring_fill") + _used(&"ring_front"), 0, "no circles")
	assert_gt(_vfx.used(&"bolt"), 0, "lightning")


func test_an_electric_beam_is_a_lightning_bolt() -> void:
	_view.spawn(
		_spec(WorldReader.FORM_BEAM, ["storm"]), AT, 0.0, {"start": 0, "to": AT + Vector2(0, 5)}
	)
	_view.draw_at(1.0)
	assert_eq(_used(&"beam_core"), 0)
	assert_gt(_vfx.used(&"bolt"), 0)


func test_a_bomb_has_no_ground_circle_and_lands_as_an_explosion() -> void:
	var e := _view.spawn(
		_spec(WorldReader.FORM_LOB, ["ember"], {"reach_m": 5.0, "radius_m": 1.8}),
		AT,
		0.0,
		{"start": 0}
	)
	var flight: float = e["flight"]
	_view.draw_at(flight * 0.5)
	assert_eq(_used(&"lob_body"), 1, "the bomb itself")
	assert_eq(_used(&"lob_ground"), 0, "no ground circle")
	_view.draw_at(flight + 2.0)
	assert_eq(_used(&"burst_fill"), 0, "no flat flash")
	assert_gt(_vfx.used(&"blast"), 0, "a fireball")
	assert_gt(_vfx.marks_of(&"scorch"), 0, "a scorch mark")
	_view.draw_at(flight + 40.0)
	assert_gt(_vfx.used(&"smoke"), 0, "smoke still rising")


func test_without_an_element_a_patch_keeps_the_flat_look() -> void:
	_view.spawn(
		_spec(WorldReader.FORM_ZONE, [], {"radius_m": 2.0, "life_ticks": 120}),
		AT,
		0.0,
		{"start": 0}
	)
	_view.draw_at(60.0)
	assert_eq(_used(&"zone_fill"), 1, "no element, nothing for the layer to draw")


func test_every_element_draws_its_own_look_on_every_form() -> void:
	for el: String in ELEMENT_POOL:
		var pool: StringName = ELEMENT_POOL[el]
		_view.clear()
		_vfx.clear_marks()
		_view.spawn(
			_spec(WorldReader.FORM_ZONE, [el], {"radius_m": 2.0, "life_ticks": 120}),
			AT,
			0.0,
			{"start": 0}
		)
		_view.draw_at(40.0)
		assert_eq(_used(&"zone_fill") + _used(&"zone_rim"), 0, el + ": no ground circle")
		assert_gt(_vfx.used(pool), 0, el + " patch")
		_view.clear()
		_view.spawn(_spec(WorldReader.FORM_RING, [el], {"radius_m": 3.0}), AT, 0.0, {"start": 0})
		_view.draw_at(8.0)
		assert_eq(_used(&"ring_fill") + _used(&"ring_front"), 0, el + ": no ring disc")
		assert_gt(_vfx.used(pool) + _vfx.used(&"splash"), 0, el + " ring")
		_view.clear()
		_view.spawn(
			_spec(WorldReader.FORM_BEAM, [el]), AT, 0.0, {"start": 0, "to": AT + Vector2(0, 5)}
		)
		_view.draw_at(1.0)
		assert_eq(_used(&"beam_core"), 0, el + ": no flat beam")
		var line_used := 0
		for id: StringName in [&"ice", &"splash", &"rift", &"tendril"]:
			line_used += _vfx.used(id)
		assert_gt(line_used, 0, el + " beam")
		_view.clear()
		_view.spawn(_spec(WorldReader.FORM_BURST, [el], {"radius_m": 2.0}), AT, 0.0, {"start": 0})
		_view.draw_at(6.0)
		assert_eq(_used(&"burst_fill") + _used(&"burst_rim"), 0, el + ": no flat burst")
		assert_gt(_vfx.lights_on(), 0, el + " burst lights the room")


func test_frost_and_liquids_leave_marks_on_the_floor() -> void:
	_view.spawn(
		_spec(WorldReader.FORM_ZONE, ["frost"], {"radius_m": 2.0, "life_ticks": 120}),
		AT,
		0.0,
		{"start": 0}
	)
	_view.spawn(
		_spec(WorldReader.FORM_ZONE, ["venom"], {"radius_m": 2.0, "life_ticks": 120}),
		AT + Vector2(5, 0),
		0.0,
		{"start": 0}
	)
	_view.draw_at(30.0)
	assert_eq(_vfx.marks_of(&"frost"), 1, "frost on the floor")
	var splats := 0
	for k in 4:
		splats += _vfx.marks_of(StringName("splat%d" % k))
	assert_gt(splats, 0, "a venom splatter")


func test_a_frost_bomb_bursts_into_ice() -> void:
	var e := _view.spawn(
		_spec(WorldReader.FORM_LOB, ["frost"], {"reach_m": 5.0, "radius_m": 1.8}),
		AT,
		0.0,
		{"start": 0}
	)
	_view.draw_at(float(e["flight"]) + 6.0)
	assert_gt(_vfx.used(&"ice"), 0, "ice erupts")
	assert_eq(_vfx.used(&"blast"), 0, "not a fireball")
	assert_eq(_vfx.marks_of(&"frost_burst"), 1)


func test_enemy_statuses_draw_in_the_layer_not_as_boxes() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	w.add_dummy(Vector2(1.2, 0), 0.35, 500)
	var reader := WorldReader.new(w)
	var actors: ActorViews = add_child_autofree(ActorViews.new())
	var fx: StatusVisuals = add_child_autofree(StatusVisuals.new(actors))
	fx.use_vfx(_vfx)
	actors.sync(reader)
	var a := w.actors
	a.burn_stacks[1] = 4
	a.bleed_stacks[1] = 6
	a.frozen_t[1] = 30
	fx.sync(reader)
	var id := w.actors.ids[1]
	assert_eq(fx.shown(id, &"embers"), 0, "no box embers")
	assert_eq(fx.shown(id, &"shell"), 0, "no sphere shell")
	_vfx.begin(10.0)
	_vfx.finish()
	assert_gt(_vfx.used(&"flame"), 0, "a burning body")
	assert_gt(_vfx.used(&"splash"), 0, "bleeding drips")
	assert_gt(_vfx.used(&"ice"), 5, "a frozen enemy's crystal cage")
	assert_eq(_vfx.marks_of(&"frost"), 1, "frost under it")


## Owner, 2026-10-12 ("that's too much fire"): a dash's overlapping Flame Trail patches draw one layer of flames, one
## light for the cluster and one scorch per spot, not a set per patch.
func test_overlapping_fire_patches_thin_out() -> void:
	_vfx.begin(40.0)
	_vfx.field(&"fire", Vector3.ZERO, 0.9, 1.0, 40.0, 11)
	_vfx.finish()
	var one := _vfx.used(&"flame")
	_vfx.clear_marks()
	_vfx.begin(40.0)
	for k in 6:
		_vfx.field(&"fire", Vector3(k * 0.8, 0, 0), 0.9, 1.0, 40.0, 11 + k)
	_vfx.finish()
	assert_lt(
		_vfx.used(&"flame"),
		one * 4,
		"six overlapping patches, far fewer than six patches of flames"
	)
	assert_lte(_vfx.lights_on(), 2, "one light per cluster")
	assert_lte(_vfx.marks_of(&"scorch"), 3, "no stack of scorches")


## Lighting pass (owner, 2026-10-12): a fire prop draws real flames (bright enough to bloom).
func test_a_fire_prop_draws_flames_that_bloom() -> void:
	_vfx.begin(10.0)
	_vfx.prop_fire(Vector3(1, 1, 1), 5)
	_vfx.finish()
	assert_eq(_vfx.used(&"flame"), 3, "three tongues (their HDR colour is not readable headless)")


## Audit P-13: the shock ring draws fewer bolt segments at a lower Effects density, like every other element ring.
func test_the_shock_ring_follows_effects_density() -> void:
	_vfx.density = 1.0
	_vfx.begin(0.0)
	_vfx.ring(&"storm", Vector3.ZERO, 4.0, 1.0, 0.0, 7)
	var full := _vfx.used(&"bolt")
	_vfx.density = 0.5
	_vfx.begin(0.0)
	_vfx.ring(&"storm", Vector3.ZERO, 4.0, 1.0, 0.0, 7)
	var half := _vfx.used(&"bolt")
	assert_eq(full, 12, "r 4 m at full density: 12 segments")
	assert_eq(half, 6, "half density: half the segments")


## Audit P-8: marks suppressed by an overlapping one don't pile up in the de-duplication cache for the whole floor;
## the overlap still suppresses them (one decal on screen).
func test_suppressed_marks_dont_grow_the_cache_forever() -> void:
	_vfx.begin(0.0)
	_vfx.mark(1, &"scorch", Vector3.ZERO, 1.0, Color.WHITE)
	for k in 2000:
		_vfx.mark(100 + k, &"scorch", Vector3(0.01, 0, 0), 1.0, Color.WHITE)
		if k % 50 == 0:
			_vfx.finish()
	_vfx.finish()
	assert_eq(_vfx.marks_of(&"scorch"), 1, "the overlap still suppresses them")
	assert_lte(_vfx._mark_keys.size(), VfxCore.DECALS * 4 + 50, "the cache is trimmed")


## Audit P-20: every pool together stays within PRESENTATION §7's 2,000 live particles a frame (the pools' own caps
## sum to more), and a new frame starts with the whole budget again.
func test_the_pools_share_one_sprite_budget() -> void:
	_vfx.begin(0.0)
	for id: StringName in VfxCore.POOLS:
		for k in int(VfxCore.POOLS[id][4]):
			_vfx._put(id, Transform3D(), Color.WHITE, 0, 0.0, 0.0)
	for k in VfxCore.ICE_CAP:
		_vfx._put(&"ice", Transform3D(), Color.WHITE, 0, 0.0, 0.0)
	var total := 0
	for id: StringName in _vfx.pools:
		total += _vfx.used(id)
	assert_eq(total, VfxCore.MAX_SPRITES, "capped at the budget")
	_vfx.begin(1.0)
	assert_true(
		_vfx._put(&"spark", Transform3D(), Color.WHITE, 0, 0.0, 0.0), "a new frame draws again"
	)


## Audit P-19b: a payoff already on the floor's first sync (a resumed save) is stamped with the sim's tick, so the
## effects layer's first frame draws it instead of dropping it as long gone.
func test_a_payoff_on_the_first_sync_draws() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	w.tick = 5000
	w.wildfire_tick = 4995
	w.wildfire_pos = Vector2(1, 1)
	var reader := WorldReader.new(w)
	var actors: ActorViews = add_child_autofree(ActorViews.new())
	var fx: StatusVisuals = add_child_autofree(StatusVisuals.new(actors))
	fx.use_vfx(_vfx)
	assert_eq(_vfx.now(), 0.0, "the layer has not drawn a frame yet")
	fx.sync(reader)
	_vfx.begin(5000.5)
	_vfx.finish()
	assert_eq(fx.shot_count(), 1, "the wildfire burst is still drawing")
