extends GutTest
## v0.10.5 O12 (owner P9: "yes cap it it will also help fps"; pillar 2, readable chaos): the hero's effect budget
## (HeroFxBudget). The hero's own sprites, meshes and particles keep to a cap a frame (the oldest dim, then go), and
## dim gently when hostile threats crowd the screen; the enemies' telegraphs, shots and boss attacks are never in it.
## Probe: scripts/checks/frame_probe.gd --heavy --fx (docs/roadmap/v0.10.5/evidence/O12_EFFECT_BUDGET.md).

var _vfx: VfxLayer
var _budget: HeroFxBudget


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	_vfx = add_child_autofree(VfxLayer.new())
	_budget = HeroFxBudget.new()
	_vfx.hero_budget = _budget


func after_each() -> void:
	ViewPrefs.effects_density = "high"


## `n` sprites of pool `pool` (one frame's worth from a drawer).
static func _sprites(layer: VfxCore, pool: StringName, n: int) -> void:
	for k in n:
		layer.sprite(pool, Vector3(k * 0.1, 0.5, 0.0), 0.4, Color(1, 1, 1, 1), 0, 0.0)


func test_the_caps_shrink_with_the_effects_density() -> void:
	var hi := HeroFxBudget.sprites_for("high")
	var mid := HeroFxBudget.sprites_for("medium")
	var lo := HeroFxBudget.sprites_for("low")
	assert_gt(hi, mid)
	assert_gt(mid, lo)
	assert_gt(lo, 0)
	assert_eq(HeroFxBudget.sprites_for("nonsense"), hi, "an unknown density is High's")
	assert_gt(HeroFxBudget.live_bolts_for("high"), HeroFxBudget.live_bolts_for("low"))
	assert_true(
		HeroFxBudget.sprites_for("high") < VfxCore.MAX_SPRITES,
		"the hero never takes the whole layer: the enemies' effects keep the rest"
	)


func test_past_the_soft_limit_the_oldest_dim_and_past_the_cap_they_go() -> void:
	_budget.alpha = 1.0
	_budget.begin("low")
	var cap := _budget.cap
	var factors: Array[float] = []
	for k in cap + 25:
		factors.append(_budget.admit())
	assert_eq(_budget.used, cap, "never more than the cap")
	assert_eq(_budget.skipped, 25)
	assert_eq(_budget.dimmed, cap - _budget.soft)
	assert_eq(factors[0], 1.0, "the newest draw at full strength")
	assert_eq(factors[cap - 1], HeroFxBudget.OVER_ALPHA, "the oldest drawn ones are dimmed")
	assert_eq(factors[cap], 0.0, "past the cap: skipped")


func test_the_dimming_rule() -> void:
	assert_eq(HeroFxBudget.target_alpha(0), 1.0)
	assert_eq(HeroFxBudget.target_alpha(HeroFxBudget.DIM_FROM), 1.0, "a few threats: no dimming")
	assert_almost_eq(HeroFxBudget.target_alpha(HeroFxBudget.DIM_FULL), HeroFxBudget.DIM_ALPHA, 1e-5)
	assert_almost_eq(HeroFxBudget.target_alpha(500), HeroFxBudget.DIM_ALPHA, 1e-5, "never below")
	var last := 1.0
	for n in range(HeroFxBudget.DIM_FROM, HeroFxBudget.DIM_FULL + 1):
		var a := HeroFxBudget.target_alpha(n)
		assert_true(a <= last, "more threats never brighten the hero's effects")
		last = a


func test_the_opacity_drops_gently_and_comes_back() -> void:
	var b := HeroFxBudget.new()
	b.settle(HeroFxBudget.DIM_FULL + 4)
	assert_almost_eq(
		b.alpha, 1.0 - HeroFxBudget.DIM_PER_S * HeroFxBudget.TICK_S, 1e-5, "one tick: a small step"
	)
	for t in 120:
		b.settle(HeroFxBudget.DIM_FULL + 4)
	assert_almost_eq(b.alpha, HeroFxBudget.DIM_ALPHA, 1e-5, "two seconds of a crowd: dimmed")
	for t in 120:
		b.settle(0)
	assert_almost_eq(b.alpha, 1.0, 1e-5, "the threats gone: back to full")


func test_hostile_drawers_are_never_culled_or_inside_the_budget() -> void:
	var seen := {"hero": false, "hostile": true}
	_vfx.hero_drawers.append(
		func(l: VfxCore) -> void:
			seen["hero"] = l.is_hero_drawing()
			_sprites(l, &"spark", 2000)
	)
	_vfx.drawers.append(
		func(l: VfxCore) -> void:
			seen["hostile"] = l.is_hero_drawing()
			_sprites(l, &"blast", 40)
	)
	_budget.begin("low")
	_vfx.begin(1.0)
	_vfx.finish()
	assert_true(seen["hero"], "the hero's drawers draw under the budget")
	assert_false(seen["hostile"], "the enemies' drawers never do")
	assert_eq(_vfx.used(&"spark"), _budget.cap, "the hero's flood stops at its cap")
	assert_eq(_vfx.used(&"blast"), 40, "every hostile sprite still draws after it")


func test_without_hero_mode_nothing_is_budgeted() -> void:
	_budget.begin("low")
	_vfx.begin(1.0)
	_sprites(_vfx, &"spark", _budget.cap + 50)
	_vfx.finish()
	assert_eq(_vfx.used(&"spark"), _budget.cap + 50, "outside hero_begin/hero_end: no budget")
	assert_eq(_budget.used, 0)


func test_the_canvas_hands_its_budget_to_the_layer_and_dims_its_meshes() -> void:
	var view: AttackFormView = add_child_autofree(AttackFormView.new())
	view.vfx = _vfx
	view.draw_at(1.0)
	assert_eq(_vfx.hero_budget, view.budget, "the canvas's budget rules the layer's hero sprites")
	view.budget.alpha = HeroFxBudget.DIM_ALPHA
	var c := view.budget.tint(Color(1, 0.5, 0.2, 1.0), false)
	assert_almost_eq(c.a, HeroFxBudget.DIM_ALPHA, 1e-5, "the global opacity")
	assert_eq(c.r, 1.0, "the colour stays the element's")
	var over := view.budget.tint(Color(1, 0.5, 0.2, 1.0), true)
	assert_almost_eq(
		over.a, HeroFxBudget.DIM_ALPHA * HeroFxBudget.OVER_ALPHA, 1e-5, "and past the soft cap"
	)


func test_the_live_bolt_cap_follows_the_density() -> void:
	var view: AttackFormView = add_child_autofree(AttackFormView.new())
	view.set_density("high")
	assert_eq(view.live_bolts_cap(), AttackFormCanvas.LIVE_BOLTS_MAX)
	view.set_density("low")
	assert_eq(view.live_bolts_cap(), HeroFxBudget.LIVE_BOLTS["low"])


func test_a_boss_windup_counts_as_a_hostile_threat() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2.ZERO)
	w.actors.set_pos(0, Vector2(6, 0))
	w.actors.hp[0] = 1 << 20
	var reader := WorldReader.new(w)
	var tv: TelegraphViews = add_child_autofree(TelegraphViews.new())
	tv.sync(reader)
	assert_eq(tv.threats, 0, "no windup: no threat")
	BossLab.start(w, i, &"fist_slam")
	CombatLab.idle(w, 2)
	tv.sync(reader)
	assert_gt(tv.threats, 0, "the boss winding up is a threat the hero's effects make room for")


func test_telegraphs_count_one_each_and_enemy_shots_one_per_four() -> void:
	var w := BossLab.world()
	var reader := WorldReader.new(w)
	assert_eq(HeroFxBudget.threats_of(3, reader, null), 3, "no shots: the telegraphs alone")
	assert_eq(
		HeroFxBudget.threats_of(HeroFxBudget.DIM_FULL + 5, reader, null),
		HeroFxBudget.DIM_FULL + 5,
		"the telegraphs are never cut short"
	)
