extends SceneTree
## v0.8.0 SG (owner O91: "Audit CatchUp.power after changing stat semantics; hidden enemy scaling must not cancel
## earned synergy"): the hidden catch-up's P and its multiplier m on floors 1-3 for a few fixed Gun builds, before
## and after SG. "after" is the real code (CatchUp.power, CatchUp.multiplier on a SaveLab floor world, as Main).
## "before" re-computes the pre-SG formula in this probe: the stat cards compounding, the old crit amounts
## (4/8/12 and 15/30/50 points), P = weapon × damage × Glass Cannon × (1 + Onrush) × crit × the attack speed stat
## (the wand's rate bonus not read), × the same levels term. No threat, loop 1. Prints only; paste by hand.
##   godot --headless --path . -s scripts/checks/catch_up_probe.gd

const S := Stats.Stat
const R := Stats.Rarity
## The pre-SG crit amounts per rarity, per mille (chance, damage).
const OLD_CRIT_CHANCE: Array[int] = [40, 80, 120]
const OLD_CRIT_DAMAGE: Array[int] = [150, 300, 500]
## [name, [[stat, rarity, count], ...], wand cards].
const BUILDS := [
	["fresh", [], []],
	["5 damage (rare)", [[S.DAMAGE, R.RARE, 5]], []],
	["5 attack speed (rare) + Rapid Fire", [[S.ATTACK_SPEED, R.RARE, 5]], [&"gun_rapid_fire"]],
	["3 Glass Cannon (rare)", [[S.GLASS_CANNON, R.RARE, 3]], []],
	[
		"crit: 3 chance + 2 damage (rare)",
		[[S.CRIT_CHANCE, R.RARE, 3], [S.CRIT_DAMAGE, R.RARE, 2]],
		[]
	],
	[
		"synergy: 5 dmg + 5 AS + RF + 3 GC",
		[[S.DAMAGE, R.RARE, 5], [S.ATTACK_SPEED, R.RARE, 5], [S.GLASS_CANNON, R.RARE, 3]],
		[&"gun_rapid_fire"]
	],
]


func _initialize() -> void:
	print(
		"build | P before | P after | enemy m f1 / f2 / f3 before -> after | boss m f1 / f2 / f3 before -> after"
	)
	for b: Array in BUILDS:
		var w := SaveLab.floor_world(31, 1, &"gun")
		for id: StringName in b[2]:
			for k in w.item_tables.size():
				if w.item_tables[k].id == id:
					BuildSlots.take(w, k)  # the pick's own step
		var old := {}
		for c: Array in b[1]:
			for n in c[2]:
				Stats.add_card(w, c[0], c[1])
				_old_card(w, old, c[0], c[1])
		var before := _old_power(w, old)
		var after := CatchUp.power(w)
		var t := w.catch_up_table
		var row := "%s | %d | %d" % [b[0], before, after]
		for pair: Array in [
			[t.expected_permille, t.cap_permille], [t.boss_expected_permille, t.boss_cap_permille]
		]:
			var m := [[], []]
			for f in [1, 2, 3]:
				var e := CatchUpTable.at_floor(pair[0], f)
				var cap := CatchUpTable.at_floor(pair[1], f)
				m[0].append(CatchUp.multiplier(before, e, cap))
				m[1].append(CatchUp.multiplier(after, e, cap))
			row += " | %s -> %s" % [m[0], m[1]]
		print(row)
	quit()


## The pre-SG value of each stat the builds touch, card by card.
func _old_card(w: World, old: Dictionary, s: int, r: int) -> void:
	var t := Stats.table(w, s)
	var v: int = old.get(s, Stats.BASE[s])
	match s:
		S.CRIT_CHANCE:
			v += OLD_CRIT_CHANCE[r]
		S.CRIT_DAMAGE:
			v += OLD_CRIT_DAMAGE[r]
		_:
			v = (v * (1000 + t.amounts[r]) + 500) / 1000
			v = mini(v, t.cap) if t.cap > 0 else v
	old[s] = v


## CatchUp.power as it was before SG (catch_up.gd at db725a0), with the old stat values.
func _old_power(w: World, old: Dictionary) -> int:
	var t := w.catch_up_table
	var p := Abilities.weapon_permille(w)
	p = p * int(old.get(S.DAMAGE, 1000)) / 1000
	p = p * int(old.get(S.GLASS_CANNON, 1000)) / 1000
	p = p * (1000 + int(old.get(S.ONRUSH, 0))) / 1000
	var chance := mini(w.player.crit_chance_permille + int(old.get(S.CRIT_CHANCE, 0)), 750)
	var mult := mini(w.player.crit_mult_permille + int(old.get(S.CRIT_DAMAGE, 0)), 4000)
	p = p * CatchUp.expected_crit(w, chance, mult) / CatchUp.base_crit(w)
	p = p * int(old.get(S.ATTACK_SPEED, 1000)) / 1000
	var levels := 0
	for s in Wand.size(w):
		levels += CatchUp.power_level(w, s)
	for s in w.ability_owned.size():
		if w.ability_tables[w.ability_owned[s]].is_utility():
			levels += w.ability_levels[s]
	var plain := 0
	for idx in w.items_owned:
		if not BuildSlots.is_modifier(w, idx):
			plain += 1
	var extra := (
		t.ability_level_permille * levels
		+ t.item_permille * plain
		+ t.combo_permille * w.combos_owned.size()
	)
	return maxi(1, p * (1000 + extra) / 1000)
