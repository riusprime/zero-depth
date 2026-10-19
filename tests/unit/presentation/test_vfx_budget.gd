extends GutTest
## v0.8.0 PF (owner O9: Spread + Split + Explosive "goes two FPS … maybe we can stop applying some effects"): the
## effects' frame budget. A few explosions draw exactly as before; under load nearby ones merge, the extra ones thin
## (fewer sprites, no light of their own) and past a cap none is drawn; the live bolts past a budget keep only their
## plain dart. Probe: scripts/checks/perf_probe.gd, docs/roadmap/v0.8.0/evidence/PERF.md.

var _view: AttackFormView
var _vfx: VfxLayer


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	_view = add_child_autofree(AttackFormView.new())
	_vfx = add_child_autofree(VfxLayer.new())
	_view.vfx = _vfx


## An Explosive blast (an ember BURST, as shared_explosive's hook child).
static func _blast() -> Dictionary:
	return {
		"form": WorldReader.FORM_BURST, "elements": PackedStringArray(["ember"]), "radius_m": 1.4
	}


## `n` blasts at `start`, `spacing` m apart along x (far apart: none merges).
func _blasts(n: int, spacing: float, start: float = 0.0) -> void:
	for k in n:
		_view.spawn(_blast(), Vector2(k * spacing, 0), 0.0, {"start": start})


func _sprites() -> int:
	var n := 0
	for id: StringName in _vfx.pools:
		n += _vfx.used(id)
	return n


func test_one_blast_draws_its_full_look() -> void:
	_blasts(1, 0.0)
	_view.draw_at(3.0)
	assert_eq(_vfx.bursts_drawn, 1)
	assert_gt(_vfx.used(&"blast"), 0, "the fireball")
	assert_gt(_vfx.used(&"debris"), 0, "debris")
	assert_gt(_vfx.used(&"spark"), 0, "sparks")
	assert_eq(_vfx.lights_asked(), 1, "its light")


func test_a_few_blasts_draw_as_before_even_on_one_spot() -> void:
	_blasts(1, 0.0)
	_view.draw_at(3.0)
	var one := _sprites()
	_view.clear()
	_blasts(4, 0.0)  # four on one spot (three Spread shots and a Split on one enemy): no merging under the crowd
	_view.draw_at(3.0)
	assert_eq(_vfx.bursts_drawn, 4)
	assert_eq(_vfx.bursts_merged, 0)
	assert_eq(_sprites(), one * 4, "each with its full look")
	assert_eq(_vfx.lights_asked(), 1, "v0.8.0 FV: one light shared by the four on one spot")


func test_under_load_the_extra_blasts_thin_and_ask_for_no_light() -> void:
	_blasts(VfxLayer.BURST_FULL + 6, 5.0)
	_view.draw_at(3.0)
	assert_eq(_vfx.bursts_drawn, VfxLayer.BURST_FULL + 6, "far apart: none merges")
	assert_eq(_vfx.lights_asked(), VfxLayer.BURST_FULL, "a light for the full ones only")
	var full := VfxLayer.new()
	add_child_autofree(full)
	full.begin(3.0)
	full.burst(&"fire", Vector3.ZERO, 1.4, 0.04, 7)
	var one := full.sprites_asked
	full.burst(&"fire", Vector3(50, 0, 0), 1.4, 0.04, 9)
	assert_eq(full.sprites_asked, one * 2)
	for k in VfxLayer.BURST_FULL - 2:
		full.burst(&"fire", Vector3(100 + 5 * k, 0, 0), 1.4, 0.04, 11 + k)
	var before := full.sprites_asked
	full.burst(&"fire", Vector3(-50, 0, 0), 1.4, 0.04, 99)
	assert_lt(full.sprites_asked - before, one, "a thinned blast draws fewer sprites")
	assert_gt(full.sprites_asked - before, 0, "but still draws")


func test_under_load_a_blast_on_a_drawn_one_merges_into_it() -> void:
	var layer := VfxLayer.new()
	add_child_autofree(layer)
	layer.begin(3.0)
	for k in VfxLayer.BURST_FULL:
		layer.burst(&"fire", Vector3(5 * k, 0, 0), 1.4, 0.1, k)
	layer.burst(&"fire", Vector3(0.3, 0, 0), 1.4, 0.1, 500)
	assert_eq(layer.bursts_merged, 1, "on top of a drawn one")
	assert_eq(layer.bursts_drawn, VfxLayer.BURST_FULL)


func test_past_the_cap_no_blast_is_drawn() -> void:
	var layer := VfxLayer.new()
	add_child_autofree(layer)
	layer.begin(3.0)
	for k in VfxLayer.BURST_MAX + 10:
		layer.burst(&"fire", Vector3(5 * k, 0, 0), 1.4, 0.1, k)
	assert_eq(layer.bursts_drawn, VfxLayer.BURST_MAX)
	assert_eq(layer.bursts_skipped, 10)
	layer.begin(4.0)
	assert_eq(layer.bursts_drawn, 0, "the count starts again each frame")


func test_the_canvas_keeps_at_most_its_live_blasts() -> void:
	_blasts(BurstBudget.MAX_LIVE + 20, 5.0)
	assert_eq(_view.effect_count(), BurstBudget.MAX_LIVE)
	assert_eq(_view.bursts_dropped, 20, "the oldest went")


func test_the_canvas_merges_blasts_on_one_spot_only_in_a_crowd() -> void:
	_blasts(BurstBudget.BURST_CROWD, 0.1)  # a crowd within the merge distance
	assert_eq(_view.effect_count(), BurstBudget.BURST_CROWD, "below the crowd all are kept")
	_view.spawn(_blast(), Vector2(0.2, 0), 0.0, {"start": 2.0})
	assert_eq(_view.bursts_merged, 1, "the crowd's next one on the spot merges")
	assert_eq(_view.effect_count(), BurstBudget.BURST_CROWD)
	_view.spawn(_blast(), Vector2(30, 0), 0.0, {"start": 2.0})
	assert_eq(_view.effect_count(), BurstBudget.BURST_CROWD + 1, "elsewhere it joins")
	_view.spawn(_blast(), Vector2(0.2, 0), 0.0, {"start": 40.0})
	assert_eq(_view.effect_count(), BurstBudget.BURST_CROWD + 2, "later on the spot it joins")


func test_without_the_layer_bursts_are_not_budgeted() -> void:
	_view.vfx = null
	_blasts(BurstBudget.MAX_LIVE + 5, 0.0)
	assert_eq(_view.effect_count(), BurstBudget.MAX_LIVE + 5, "the flat look keeps MAX_EFFECTS")


func test_past_the_bolt_budget_bolts_keep_only_their_dart() -> void:
	var look := AttackFormLooks.compose(
		{"form": WorldReader.FORM_BOLT, "elements": PackedStringArray(["ember"])}
	)
	for k in AttackFormCanvas.LIVE_BOLTS_MAX + 30:
		var p := Vector2(k, 0)
		(
			_view
			. _live
			. append(
				{
					"id": k,
					"pos": p,
					"vel": Vector2(0.2, 0),
					"look": look,
					"trail": PackedVector2Array([p - Vector2(0.4, 0), p]),
				}
			)
		)
	_view.draw_at(1.0)
	assert_eq(
		_view.pool(&"bolt_core").used, AttackFormCanvas.LIVE_BOLTS_MAX, "one rim per drawn bolt"
	)
