extends GutTest
## v0.9.0 BR (owner Q13 "12 per attack": "At most 12 projectiles per attack (pattern × Twin × Split children) … a
## regression test fails above 40 projectiles a second for the worst legal build"; PLAN C75, C76): the caps of
## ShotCap held by every Gun form (data/wand/attack_slots.tres, its ten rows) with every Pattern (Twin, Halo, Ring,
## Backfire) and the shot Secondaries (Spiral, Swirl) its row allows, all at level 5, at the top attack speed (20 Epic
## Attack Speed cards, the stat's cap) on a Gun run, holding fire at a wall of tough dummies (the Lance tapping, its
## fastest release). The table is read from the data: a card is in a form's builds when AttackSlots.usable says so.
## Per attack: the compiled volley (ShotCap.shots of the bolt × each split child's) and the most launched in one
## tick are at most shots_per_attack_max; per second: at most shots_per_second_max launched in any 60 ticks. The
## Laser is a beam (it launches no projectile, laser.gd) and is checked to stay at 0.

const W := preload("res://tests/support/mx4_world.gd")
## The ten forms: [row id, form card (&"" for the Orbs, the Gun's own shot)].
const FORMS: Array = [
	[&"orbs", &""],
	[&"laser", &"gun_laser"],
	[&"bomb", &"gun_bomb"],
	[&"void", &"gun_void"],
	[&"lance", &"gun_lance"],
	[&"rune_explosion", &"gun_rune_explosion"],  # v0.9.5 FC0: replaces the Scatter
	[&"glaive", &"gun_glaive"],
	[&"seekers", &"gun_seekers"],
	[&"wave", &"gun_wave"],
	[&"wisps", &"gun_wisps"],
]
const PATTERNS: Array[StringName] = [&"gun_twin", &"halo_shot", &"gun_ring", &"gun_backfire"]
const SECONDARIES: Array[StringName] = [&"gun_spiral", &"gun_swirl"]
const TICKS := 360


## A Gun run on floor 5 with the shipped wand and slot table, holding nothing yet.
func _world() -> World:
	var w := W.world(&"gun")
	var r := W.repo()
	w.wand_table = WandCompiler.from_repo(r)
	w.slot_table = WandCompiler.slots(r, w.item_tables)
	w.floor_index = 5
	w.run_floor = 5
	return w


## Every legal build of `form`: [the form card (if any), a Pattern or none, the Secondaries it allows], as id lists.
func _builds(form: StringName) -> Array:
	var probe := _world()
	if form != &"":
		assert_true(BuildSlots.take(probe, W.item(probe, form)), "took %s" % form)
	var pats: Array = [&""]
	for id in PATTERNS:
		if AttackSlots.usable(probe, W.item(probe, id)):
			pats.append(id)
	var secs: Array = []
	for id in SECONDARIES:
		if AttackSlots.usable(probe, W.item(probe, id)):
			secs.append(id)
	var out: Array = []
	for p: StringName in pats:
		var ids: Array = [] if form == &"" else [form]
		if p != &"":
			ids.append(p)
		ids.append_array(secs)
		out.append(ids)
	return out


## The fight world for `ids`, every card at level 5, the top attack speed, a wall of tough dummies in front.
func _fight(ids: Array) -> World:
	var w := _world()
	for id: StringName in ids:
		assert_true(BuildSlots.take(w, W.item(w, id)), "took %s" % id)
	for idx in w.mod_slots:
		if CardLevels.is_card(w, idx):
			CardLevels.set_level(w, idx, CardLevels.MAX_LEVEL)
	for k in 20:
		Stats.add_card(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC)
	Modifiers.invalidate(w)
	for x in 6:
		for y in 3:
			w.add_dummy(w.player_pos() + Vector2(2.5 + x * 1.2, (y - 1) * 1.4), 0.45, 1000000)
	return w


## The compiled shots of one attack: the bolt's volley × the volley of each (non-cast) child it splits into.
func _per_attack(w: World) -> int:
	var s := Modifiers.bolt(w)
	var n := ShotCap.shots(s)
	var most := n
	for k in s.hooks:
		if k.child != null and not k.child.has_tag(WandCasts.TAG_CAST) and k.remnant == null:
			most = maxi(most, n * ShotCap.shots(k.child))
	return most


## Player projectiles (bolts and rings) launched each tick of TICKS; SHOOT held (the Lance taps: held every other tick).
func _launches(w: World, tap: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	var seen := -1
	var rings := {}
	for t in TICKS:
		W.run(w, 1, 0, W.S if not tap or t % 2 == 0 else 0)
		var n := 0
		var top := seen
		var p := w.projectiles
		for k in p.ids.size():
			if p.team[k] == ActorStore.TEAM_PLAYER and p.ids[k] > seen:
				n += 1
				top = maxi(top, p.ids[k])
		seen = top
		for k in w.ab.ring_pos.size():
			var key := "%d:%d:%d" % [w.ab.ring_start[k], w.ab.ring_root[k], w.ab.ring_k[k]]
			if not rings.has(key):
				rings[key] = true
				n += 1
		out.append(n)
	return out


static func _most_in_a_second(per_tick: PackedInt32Array) -> int:
	var most := 0
	var sum := 0
	for k in per_tick.size():
		sum += per_tick[k]
		if k >= ShotCap.WINDOW:
			sum -= per_tick[k - ShotCap.WINDOW]
		most = maxi(most, sum)
	return most


static func _most_in_a_tick(per_tick: PackedInt32Array) -> int:
	var most := 0
	for n in per_tick:
		most = maxi(most, n)
	return most


func test_the_shipped_caps_are_twelve_an_attack_and_forty_a_second() -> void:
	var w := _world()
	assert_eq(
		[w.slot_table.shots_per_attack_max, w.slot_table.shots_per_second_max], [12, 40], "Q13"
	)


func test_every_form_with_its_patterns_and_secondaries_holds_the_caps() -> void:
	var report := PackedStringArray()
	var count := 0
	for f: Array in FORMS:
		for ids: Array in _builds(f[1]):
			var w := _fight(ids)
			var name := "%s[%s]" % [f[0], ",".join(ids)]
			assert_eq(w.mod_slots.size(), ids.size(), "%s is a legal wand" % name)
			assert_eq(AttackSlots.form_id(w), f[0], "%s fires its form" % name)
			var compiled := _per_attack(w)
			var per := _launches(w, f[0] == &"lance")
			var tick := _most_in_a_tick(per)
			var second := _most_in_a_second(per)
			report.append("%s attack %d, tick %d, second %d" % [name, compiled, tick, second])
			assert_lte(compiled, 12, "%s: at most 12 an attack compiled (%d)" % [name, compiled])
			assert_lte(tick, 12, "%s: at most 12 launched in one tick (%d)" % [name, tick])
			assert_lte(second, 40, "%s: at most 40 in any 60 ticks (%d)" % [name, second])
			if f[0] in [&"laser", &"rune_explosion"]:  # no projectile
				assert_eq(second, 0, "%s: a beam or a burst launches no projectile" % name)
			else:
				assert_gt(second, 0, "%s fires" % name)
			count += 1
	assert_eq(count, 22, "the builds the shipped rows allow (orbs 5, wave 3, the rest 2 or 1)")
	gut.p("BR shots (compiled a attack, most in a tick, most in 60 ticks): " + "; ".join(report))
