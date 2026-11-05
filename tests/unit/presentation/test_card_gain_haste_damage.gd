extends GutTest
## v0.10.5 W3-P10n: past the rate curve's top (loop 2 on) an attack-speed card's rate gain is 0, so its gain line shows
## the damage it gives instead (the forecast's own dmg_old, dmg_new). Loop 1 keeps the old "rate → rate" line.

const W := preload("res://tests/support/mx4_world.gd")
const AS := Stats.Stat.ATTACK_SPEED


func _world(loop: int, raw: int) -> World:
	var w := W.world(&"gun")
	w.loop = loop
	Stats.grow(w, AS)
	w.stat_values[AS] = raw
	return w


func test_past_the_top_the_card_shows_its_damage() -> void:
	var w := _world(2, 2500)
	var code := Offers.stat_code(AS, Stats.Rarity.EPIC)
	var f := CardForecast.of(w, code)
	assert_true(CardGain.gives_damage(f))
	var want := (
		tr("UI_GAIN_HASTE_DAMAGE") % GambleIcons.percent(int(f["dmg_new"]) - int(f["dmg_old"]))
	)
	assert_eq(CardGain.final_text(self, f), want)
	assert_true(want.contains("%") and want.contains("+"), want)
	assert_ne(
		CardGain.final_text(self, f),
		(
			tr("UI_GAIN_ARROW")
			% [CardGain.percent(self, int(f["old"])), CardGain.percent(self, int(f["new"]))]
		)
	)


func test_loop_1_keeps_the_rate_line() -> void:
	var w := _world(1, 2400)
	var f := CardForecast.of(w, Offers.stat_code(AS, Stats.Rarity.EPIC))
	assert_false(CardGain.gives_damage(f))
	assert_eq(
		CardGain.final_text(self, f),
		(
			tr("UI_GAIN_ARROW")
			% [CardGain.percent(self, int(f["old"])), CardGain.percent(self, int(f["new"]))]
		)
	)


func test_loop_2_below_the_top_keeps_the_rate_line() -> void:
	var f := CardForecast.of(_world(2, 800), Offers.stat_code(AS, Stats.Rarity.COMMON))
	assert_false(CardGain.gives_damage(f))
