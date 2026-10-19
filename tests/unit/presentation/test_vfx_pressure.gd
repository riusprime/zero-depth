extends GutTest
## v0.8.0 FV (owner O86, feedback 2026-10-19 Part 3; O87: "when a visual op build hits a horde of enemies the game
## lags"): every effect's light merges into one of its colour within 2.5 m (a lone one as before), the burning
## enemies' lights are budgeted (the brightest few get slots), and past PRESSURE of a pool an effect halves its
## debris, smoke, sparks and crystals (its blast and flash stay).
## Evidence: docs/roadmap/v0.8.0/evidence/PERF_GRAPHICS.md (## FV).


func before_each() -> void:
	ViewPrefs.effects_density = "high"


## A fresh layer mid-frame at tick 3.
func _layer() -> VfxLayer:
	var layer := VfxLayer.new()
	add_child_autofree(layer)
	layer.begin(3.0)
	return layer


func test_a_lone_blast_keeps_its_light() -> void:
	var layer := _layer()
	layer.burst(&"fire", Vector3.ZERO, 1.4, 0.1, 7)
	layer.finish()
	assert_eq(layer.lights_asked(), 1)
	assert_eq(layer.lights_merged, 0)
	assert_almost_eq(
		layer.lights[0].light_energy, 7.0 * 0.81, 0.0001, "the explosion's flash as before"
	)


func test_overlapping_blasts_ask_for_one_merged_light() -> void:
	var layer := _layer()
	var n := 8
	for k in n:  # eight blasts within 1.8 m (a Twin pair's detonations on one crowd)
		layer.burst(&"fire", Vector3(0.2 * k, 0, 0.1 * k), 1.4, 0.1, 40 + k)
	layer.finish()
	assert_eq(layer.bursts_drawn, n, "all drawn (below BURST_FULL)")
	assert_eq(layer.lights_asked(), 1, "one light for the cluster")
	assert_eq(layer.lights_merged, n - 1)
	assert_lte(
		layer.lights[0].light_energy,
		7.0 * 0.81 * VfxCore.LIGHT_MERGE_BOOST_MAX + 0.0001,
		"brighter, but capped"
	)


func test_chained_lightning_hits_share_a_light() -> void:
	var layer := _layer()
	for k in 5:  # a chain's hits a metre apart
		layer.line(&"storm", Vector3(k, 0.6, 0), Vector3(k + 1, 0.6, 0), 1.0, 2.0, 70 + k)
	layer.finish()
	assert_lte(layer.lights_asked(), 2, "five bolts, at most two lights")


func test_a_cold_flash_never_merges_into_a_fire_light() -> void:
	var layer := _layer()
	layer.burst(&"fire", Vector3.ZERO, 1.4, 0.1, 7)
	layer.burst(&"storm", Vector3(0.3, 0, 0), 1.4, 0.1, 8)
	layer.burst(&"frost", Vector3(0.6, 0, 0), 1.4, 0.1, 9)
	layer.finish()
	assert_eq(layer.lights_asked(), 3, "warm, cold and ice each keep their own")


func test_a_lone_burning_enemy_keeps_its_light() -> void:
	var layer := _layer()
	layer.status(Vector3.ZERO, 0.4, {&"burn": 4}, 3)
	layer.finish()
	assert_eq(layer.status_lights_asked, 1)
	assert_eq(layer.lights_asked(), 1)
	assert_almost_eq(layer.lights[0].light_energy, 1.1, 0.0001, "0.7 + 0.1 per stack, as before")


func _burning_horde(layer: VfxLayer, n: int) -> void:
	for k in n:  # a burning horde in a 10 m x 5 m crowd
		var at := Vector3((k % 10) * 1.0, 0, (k / 10) * 1.25)
		layer.status(at, 0.4, {&"burn": 1 + k % 5}, 100 + k)


func _lights_shown(layer: VfxLayer) -> Array:
	var out: Array = []
	for l in layer.lights:
		if l.visible:
			out.append([l.position, l.light_energy])
	return out


func test_a_burning_horde_asks_for_at_most_the_status_budget() -> void:
	var layer := _layer()
	_burning_horde(layer, 40)
	layer.finish()
	assert_eq(layer.status_lights_asked, 40, "every burning enemy asks")
	assert_lte(layer.lights_asked(), VfxCore.STATUS_LIGHTS_MAX, "a few lights for the horde")
	assert_eq(
		layer.lights_asked() + layer.lights_merged + layer.status_lights_dropped,
		40,
		"each one opened, merged or dropped"
	)
	var placed := _lights_shown(layer)
	layer.begin(3.0)
	_burning_horde(layer, 40)
	layer.finish()
	assert_eq(_lights_shown(layer), placed, "the same frame picks the same lights")


func test_a_burning_enemy_by_a_fire_patch_joins_its_light() -> void:
	var layer := _layer()
	layer.field(&"fire", Vector3.ZERO, 1.0, 1.0, 3.0, 5)
	layer.status(Vector3(1.0, 0, 0), 0.4, {&"burn": 2}, 6)
	layer.finish()
	assert_eq(layer.lights_asked(), 1, "one warm light")


func test_below_pressure_nothing_is_thinned() -> void:
	var layer := _layer()
	layer.burst(&"fire", Vector3.ZERO, 1.4, 0.1, 7)
	assert_eq(layer.pieces_thinned, 0)
	assert_eq(layer.used(&"debris"), 4)


func test_under_pressure_a_blast_halves_its_debris_but_keeps_its_fireball() -> void:
	var lone := _layer()
	lone.burst(&"fire", Vector3.ZERO, 1.4, 0.1, 7)
	var layer := _layer()
	var full := int(float(VfxCore.POOLS[&"debris"][4]) * VfxCore.PRESSURE)
	for k in full:  # the debris pool past PRESSURE of its cap
		layer.sprite(&"debris", Vector3(k, 0, 0), 0.5, Color.WHITE, 0, 0.0)
	layer.burst(&"fire", Vector3.ZERO, 1.4, 0.1, 7)
	assert_eq(layer.used(&"debris") - full, lone.used(&"debris") / 2, "half the debris")
	assert_eq(layer.used(&"blast"), lone.used(&"blast"), "the fireball whole")
	assert_eq(layer.used(&"spark"), lone.used(&"spark"), "the sparks' pool is not pressed")
	assert_eq(layer.used(&"smoke"), lone.used(&"smoke"), "nor the smoke's")
	assert_eq(layer.pieces_thinned, lone.used(&"debris") / 2)
	assert_eq(layer.lights_asked(), 1, "the flash kept")


func test_under_pressure_ice_crystals_halve() -> void:
	var lone := _layer()
	lone.burst(&"frost", Vector3.ZERO, 1.4, 0.3, 7)
	var layer := _layer()
	var full := int(float(VfxCore.ICE_CAP) * VfxCore.PRESSURE)
	for k in full:
		layer._crystal(Vector3(k, 0, 0), Vector3.UP, 0.5, 0.2, Color.WHITE)
	layer.burst(&"frost", Vector3.ZERO, 1.4, 0.3, 7)
	var n := lone.used(&"ice")
	assert_eq(layer.used(&"ice") - full, (n + 1) / 2, "half the crystals, rounded up")


func test_a_full_frame_thins_every_pool() -> void:
	var layer := _layer()
	var full := int(float(VfxCore.MAX_SPRITES) * VfxCore.PRESSURE)
	var left := full
	for pool: StringName in [&"spark", &"flame", &"bolt", &"smoke"]:  # the frame's pieces, not the debris pool
		for k in mini(left, int(VfxCore.POOLS[pool][4])):
			layer.sprite(pool, Vector3(k, 0, 0), 0.5, Color.WHITE, 0, 0.0)
		left -= mini(left, int(VfxCore.POOLS[pool][4]))
	assert_eq(left, 0)
	var before := layer.used(&"debris")
	layer.burst(&"fire", Vector3.ZERO, 1.4, 0.1, 7)
	assert_eq(layer.used(&"debris") - before, 2, "the frame's budget past PRESSURE thins too")
