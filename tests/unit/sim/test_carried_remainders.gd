extends GutTest
## v0.10.5 W3-P9 (owner, 2026-11-04: "lets do only A then"): the carried remainders. A player hit, a DoT tick and the
## Gun's shot period keep the fraction the integer maths drops (World.dmg_carry, dot_carry, shot_carry), so a rare
## Power or Haste card counts on a small hit: 1000 hits average the exact value, deterministically; the carries are
## hashed and saved (an older save without them loads with 0; a save mid-remainder round-trips with the same hash);
## the wand forecast reads the exact period.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _world(build: StringName = &"blade", crit: int = 0) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	t.crit_chance_permille = crit
	var w := World.new(23, t)
	w.dummy_speed = 0.0
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	w.add_dummy(Vector2(2, 0), 0.35, 1000000)
	return w


## `cards` damage cards of `rarity`; returns the damage multiplier then, per mille.
func _damage_to(w: World, rarity: int, cards: int) -> int:
	for k in cards:
		Stats.add_card(w, Stats.Stat.DAMAGE, rarity)
	return Stats.damage_permille(w)


func test_hits_average_the_exact_damage() -> void:
	var w := _world()
	var m := _damage_to(w, Stats.Rarity.RARE, 2)
	assert_ne(m % 200, 0, "a multiplier a 5-point hit can't show in whole points (%d)" % m)
	var n := 1000
	var total := 0
	var seen := {}
	for k in n:
		var d: int = Stats.outgoing(w, 5, 0)[0]
		seen[d] = true
		total += d
	var exact := 5 * m * n / 1000
	assert_true(
		absi(total - exact) <= 1, "1000 hits of 5 x %d deal %d (exact %d)" % [m, total, exact]
	)
	assert_eq(
		seen.size(),
		2,
		"the hits land on the two whole points around the exact one: %s" % [seen.keys()]
	)
	assert_between(w.dmg_carry, 0, 999)


func test_the_carry_is_deterministic_and_off_at_x1() -> void:
	var a := _world()
	var b := _world()
	_damage_to(a, Stats.Rarity.COMMON, 3)
	_damage_to(b, Stats.Rarity.COMMON, 3)
	var sa := []
	var sb := []
	for k in 300:
		sa.append(Stats.outgoing(a, 3 + k % 4, 0)[0])
		sb.append(Stats.outgoing(b, 3 + k % 4, 0)[0])
	assert_eq(sa, sb, "the same hits land the same")
	assert_eq(a.dmg_carry, b.dmg_carry)
	var c := _world()
	for k in 50:
		assert_eq(Stats.outgoing(c, 7, 0)[0], 7, "x 1.00: the hit as it is")
	assert_eq(c.dmg_carry, 0, "and no carry")


func test_crits_and_dots_carry_too() -> void:
	var w := _world()
	var m := _damage_to(w, Stats.Rarity.RARE, 1)
	var dot_total := 0
	for k in 1000:
		dot_total += Stats.dot(w, 1)
	assert_true(absi(dot_total - m) <= 1, "1000 DoT ticks of 1 x %d deal %d" % [m, dot_total])
	var crit := _world(&"blade", 500)
	var cm := Stats.crit_mult(crit)
	var cc := Stats.crit_chance(crit)
	var hits := 0
	var crits := 0
	var total := 0
	for k in 1000:
		var out := Stats.outgoing(crit, 3, 0)
		total += int(out[0])
		hits += 1
		crits += 1 if int(out[1]) & SimEvent.TAG_CRIT else 0
	var exact := (hits - crits) * 3 + crits * 3 * cm / 1000
	assert_gt(crits, 0, "%d per mille crits" % cc)
	assert_true(
		absi(total - exact) <= 1,
		"3-point hits, %d crits x %d: %d (exact %d)" % [crits, cm, total, exact]
	)


func test_shot_periods_average_the_exact_period() -> void:
	var w := _world(&"gun")
	for k in 3:
		Stats.add_card(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.RARE)
	var spec := Modifiers.bolt(w)
	var milli := ItemEffects.shot_period_milli_of(w, spec)
	assert_ne(milli % 1000, 0, "a period between whole ticks (%d)" % milli)
	assert_eq(
		ItemEffects.shot_period_of(w, spec),
		(milli + 500) / 1000,
		"the HUD's period is the exact one rounded"
	)
	var n := 1000
	var total := 0
	for k in n:
		var cd := ItemEffects.next_shot_cd(w)
		assert_eq(ItemEffects.last_shot_cd(w), cd, "the last shot's cooldown reads back")
		total += cd
	assert_true(
		absi(total - milli * n / 1000) <= 1, "%d shots take %d ticks (exact %d)" % [n, total, milli]
	)


func test_the_wand_forecast_reads_the_exact_period() -> void:
	var w := _world(&"gun")
	for k in 3:
		Stats.add_card(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.RARE)
	var nums: Dictionary = WandForecast.of(w, w.mod_slots)["numbers"]
	var milli := ItemEffects.shot_period_milli_of(w, Modifiers.bolt(w))
	assert_eq(int(nums["period_milli"]), milli)
	var volley := int(nums["shots"]) * int(nums["damage"])
	assert_eq(
		int(nums["per_second_x10"]),
		volley * 1000 * 600 / milli,
		"the damage a second over the exact period"
	)


func test_carries_are_hashed_and_saved() -> void:
	var w := _world()
	_damage_to(w, Stats.Rarity.RARE, 2)
	var h0 := w.state_hash()
	Stats.outgoing(w, 5, 0)
	assert_ne(w.dmg_carry, 0, "a carried fraction")
	var h1 := w.state_hash()
	assert_ne(h1, h0, "the carry is hashed")
	ItemEffects.next_shot_cd(w)  # a shot carry too (the blade world's period: whatever it reads)
	var snap: Dictionary = bytes_to_var(var_to_bytes(w.to_snapshot()))
	var r := World.from_snapshot(snap, _world())
	assert_not_null(r, "the save restores")
	if r == null:
		return
	assert_eq(r.dmg_carry, w.dmg_carry, "the carry round-trips")
	assert_eq(r.shot_carry, w.shot_carry)
	assert_eq(r.state_hash(), w.state_hash(), "with the same hash")
	assert_eq(
		Stats.outgoing(r, 5, 0)[0], Stats.outgoing(w, 5, 0)[0], "and the next hit lands the same"
	)


func test_an_old_save_without_the_carries_loads_with_none() -> void:
	var w := _world()
	var snap: Dictionary = bytes_to_var(var_to_bytes(w.to_snapshot()))
	var data: Dictionary = snap["world"]
	for f: StringName in [&"dmg_carry", &"dot_carry", &"shot_carry"]:
		data.erase(f)
		data.erase(String(f))
	assert_false(
		data.has(&"dmg_carry") or data.has("dmg_carry"), "the fields are gone, as in an older save"
	)
	var base := _world()
	base.dmg_carry = 0
	var r := World.from_snapshot(snap, base)
	assert_not_null(r, "an older save restores (%s)" % WorldSnapshot.apply(_world(), snap))
	if r == null:
		return
	assert_eq(r.dmg_carry, 0)
	assert_eq(r.state_hash(), w.state_hash(), "an untouched carry hashes as before")
