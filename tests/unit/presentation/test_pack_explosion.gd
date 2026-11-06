extends GutTest
## v0.10.0 VX0 (VFX_PACK R18): VfxLayer's fire explosion is the pack's: one effect per burst (the first frame its
## seed is drawn, not every frame), no smoke after it (v0.10.0 FX), a thinned burst small, the burst budget unchanged,
## and the sprite explosion kept without a PackFx.

var _layer: VfxLayer
var _fx: PackFx
var _saved := ""


func before_each() -> void:
	_saved = ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"
	_layer = add_child_autofree(VfxLayer.new())
	_fx = add_child_autofree(PackFx.new())
	_layer.pack_fx = _fx


func after_each() -> void:
	ViewPrefs.effects_density = _saved


## One frame at `now` with the burst at `u`.
func _frame(now: float, at: Vector3, u: float, sd: int) -> void:
	_layer.begin(now)
	_layer.burst(&"fire", at, 2.0, u, sd)
	_layer.finish()


func test_a_burst_spawns_one_pack_explosion_not_one_per_frame() -> void:
	for k in 10:
		_frame(float(k), Vector3.ZERO, k / 10.0, 7)
	assert_eq(_fx.spawned, 1, "one explosion for ten frames of one burst")
	assert_eq(_fx.live_count(&"explosion"), 1)
	_frame(11.0, Vector3(6, 0, 0), 0.1, 8)
	assert_eq(_fx.live_count(&"explosion"), 2, "another seed is another explosion")


## v0.10.0 FX (owner: "lingering smoke"): no smoke cloud follows the explosion.
func test_no_smoke_follows_the_explosion() -> void:
	_frame(0.0, Vector3.ZERO, 0.0, 7)
	for k in 60:
		_layer.begin(float(k + 1))
		_layer.finish()
	assert_eq(_fx.live_count(&"cloud"), 0, "no smoke")
	assert_eq(_fx.spawned, 1, "the explosion alone")


func test_a_thinned_burst_is_a_small_explosion_without_smoke() -> void:
	_layer.begin(0.0)
	for k in VfxLayer.BURST_FULL:  # full bursts, far apart (none merges)
		_layer.burst(&"fire", Vector3(k * 5.0, 0, 0), 2.0, 0.1, 100 + k)
	var before := _fx.spawned
	assert_eq(before, VfxLayer.BURST_FULL, "the full bursts each spawned one explosion")
	_layer.burst(&"fire", Vector3(0, 0, 50), 2.0, 0.1, 999)
	assert_eq(_fx.spawned, before + 1, "the thinned burst spawns an explosion")
	_layer.finish()


func test_the_burst_budget_still_caps_the_explosions() -> void:
	_layer.begin(0.0)
	for k in VfxLayer.BURST_MAX + 8:
		_layer.burst(&"fire", Vector3(k * 5.0, 0, 0), 2.0, 0.1, 500 + k)
	assert_eq(_layer.bursts_drawn, VfxLayer.BURST_MAX)
	assert_eq(_fx.spawned, VfxLayer.BURST_MAX, "none past BURST_MAX")


func test_the_sprite_explosion_stays_without_a_pack() -> void:
	_layer.pack_fx = null
	_frame(0.0, Vector3.ZERO, 0.3, 7)
	assert_eq(_fx.spawned, 0, "no pack effect")
	var drawn := 0
	for id: StringName in _layer.pools:
		drawn += _layer.used(id)
	assert_gt(drawn, 0, "the sprites drew it")


func test_the_light_and_the_scorch_stay_the_layers() -> void:
	_frame(0.0, Vector3.ZERO, 0.1, 7)
	assert_gt(_layer.lights_asked(), 0, "VfxCore's merged light still flashes")
	assert_gt(_layer.marks(), 0, "and the scorch mark is laid")
