class_name RunState
extends RefCounted
## A run of floors (v0.3.0 PLAN L3-L4, "Run (B)"): the floor number, the biome order (shuffled once per run from the
## `biomes` stream), each floor's seed (floor 1 uses the run seed, later floors one derived from it), the enemy scaling
## per floor, the carry between floors and the totals the recap shows. Pure sim code; the app owns one per run and
## builds a fresh World per floor. v0.7.5 AP (owner N4, the Ascension loop): after the last floor's boss the Ascension
## portal ends the run or starts loop + 1 at floor 1 with the build carried (finish_floor). v0.8.0 P2 (owner O28): two
## devices instead of a choice: the Ascension portal leads to the final boss, the Loop device starts loop + 1.
## `floor_index` stays the floor within the loop (1.. floors: the floor tables, boss pools, curves and prices read it);
## run_floor() counts the run's floors across loops (the floor seeds, the bosses drawn, the routes, the biome order, the
## boss's floor-1 ease and FloorCadence's shop and curse floors read it, so loop 2 is new ground and two featured floors
## never meet at a seam). Each loop past the first scales enemies and bosses (loop_permille) and adds threat and
## catch-up cap (prepare).

## v0.7.5 MG: the floor rules the current floor was built with. FLOOR_RULES (2): v0.7.5's bigger floors, fewer arenas,
## the shop every two floors (data/map, data/arenas, data/shop). 1: v0.7.0's (FloorParams.v070(), a third of the
## combat rooms as arenas, a shop on every floor), only for a floor resumed from a save made before v0.7.5 (its
## payload has no floor_rules), so the floor rebuilt under its snapshot is the floor it was saved on. The next floor
## is always built with FLOOR_RULES.
## v0.7.5 BF1 (owner N18, "always put them in the big rooms"): 3 is today's, every boss room 4 x 4; a floor saved under
## rules 1 or 2 rebuilds its boss room at the boss's legacy_arena_cells (legacy_boss_room), so it is the floor it was
## saved on.
## v0.8.0 RT (owner O12): 4 added the designed room layouts (data/room_layouts); a floor saved under rules 1-3 is
## rebuilt with the rule-built interiors it had (designed_rooms; RunSaver.floor_tables).
## v0.8.0 RT2 (G2 RT) and SR (owner O13), merged into one step of the rules: 5 is today's, with layouts for every room
## size (24) and the shop room a biome's tent stall (data/shop_rooms; ShopRoom). A floor saved under rules 4 is rebuilt
## with RT1's three layouts only (rt1_rooms; RunSaver.RT1_LAYOUTS) and the shop terminal it had (RunSaver.shop_rooms).
## v0.8.0 N14 (owner O72): 6 is today's: the gamble shrine stands on some floors only (GambleTable's
## floor_chance_permille), in a combat room away from the start hall (Gamble.site). A floor saved under rules 1-5 is
## rebuilt with the shrine in its start hall, as it was saved (FloorScenario.legacy_shrine_of).
## v0.8.0 N17 (owner O75): 7 is today's: the curse room (Events.curse_site: on some floors, one combat room with the
## curse altar, the curse events drawn only there). A floor saved under rules 1-6 is rebuilt with its event rooms as
## they were (no curse room, every event in the common draw; FloorScenario.legacy_curse_room_of).
## v0.8.0 N19 (owner O80): 8 is today's: the curse room is a room of its own (CurseRoom.furnish: interior cleared, the
## altar centred and solid, crystals, no spawns), small rooms first, on every Deep floor (Whispering Deep at its altar),
## Echo Mirror only once a stat is raised. A floor saved under rules 7 is rebuilt with N17's curse room (a combat room
## keeping its interior; FloorScenario.curse_room_rules_of).
## v0.8.0 BD (owner O83): 9 is today's: the boss door is shut and solid until the interact press opens it
## (BossFlow.Door, set in prepare). A floor saved under rules 1-8 keeps its open doorway, as it was saved.
## v0.9.0 TD (owner W §2, Q20): 10 is today's: on some floors a dead end is a secret room behind a timed door
## (TimedDoor.setup). A floor saved under rules 1-9 is rebuilt without one, as it was saved (FloorPlan).
## v0.9.0 RA (owner W §4 A, Q22): 11 is today's: on some floors a rune puzzle seals a dead end (RuneAlignment.setup).
## A floor saved under rules 1-10 is rebuilt without one, as it was saved (FloorPlan). v0.9.0 DX (owner W §4 C, Q23)
## rides the same rule (both land together): cracked walls, containers and explosive barrels (Breakables.setup).
## v0.9.0 DP (owner Q26b): 12 is today's: the Purple Portal is earned (a purple-rune room on some floors,
## PurpleRunes.setup; the Deep gate opens only on a floor whose runes were awakened). A floor saved under rules 1-11
## keeps the Deep gate on every floor before the last, as it was saved (PurpleRunes.legacy_deep_gate).
## v0.9.0 LK (owner Q21): 13 is today's: 1-2 Lockdown rooms a floor (Lockdowns.setup). A floor saved under rules 1-12
## is rebuilt without any, as it was saved (FloorPlan).
## v0.9.0 SH, HF (owner Q29b): 14 is today's: the floor's shrine is drawn as Fortune (the gamble shrine), Blood or
## Chaos, and some floors from floor 2 have a healing fountain (Shrines.setup). A floor saved under rules 1-13 is
## rebuilt as it was saved: its shrine is the gamble shrine (Fortune), and it has no Blood or Chaos shrine and no
## fountain (FloorPlan).
## v0.9.0 EL (owner Q24, Q25, Q21): 15 is today's: floors 4-5 mark their elite rooms (Elites.setup), an Elite Lockdown
## may be drawn there, and the retired Ambush Cache is never drawn. A floor saved under rules 1-14 is rebuilt as it was
## saved: no elite rooms, no Elite Lockdown, the Ambush Cache's old weight in the event draw (its pedestal then closes
## on load: Events.drop_retired).
## v0.9.0 CF (owner: "lets never make it a 1x1"): 16 is today's: no closed fight (an arena, the Overrun room, a
## Lockdown, the Chaos shrine) in a room of fewer than its kind's min_cells grid cells. A floor saved under rules 1-15
## is rebuilt with the rooms it had (the min_cells read as 0: RunSaver.floor_tables, FloorPlan.add_secrets).
## v0.9.0 CF2 (owner: "Lockdowns get rooms first"): 17 is today's: the Lockdowns (Elite ones too) pick their rooms
## right after the arenas and the Overrun room (FloorScenario.build, RunSaver.floor_tables' lockdown_first), before
## the shrine, the fountain, the events, the curse room and the secrets, which then take the rooms left. A floor
## saved under rules 1-16 is rebuilt in the old order, its Lockdowns last (FloorPlan.add_secrets).
## v0.9.5 AQ (owner: event altars "more special like the curse room"): 19 is today's: an event room on about a third
## of floors, at most two a run, never the same event twice (Events.pick_rooms; World.events_seen). A floor saved under
## rules 1-18 is rebuilt with its 1-2 event rooms (FloorScenario.rare_events_of).
## v0.9.5 DR (owner Q6: "we will only have locked rooms ... and overrun"): 20 is today's: a locked room (a Lockdown)
## fights one burst of two formations 1 s apart and the floor's arena rooms are locked rooms; every sealed door drops
## bars. A floor saved under rules 1-19 keeps its three-formation Lockdowns and its wave Arenas
## (RunSaver.lockdown_table).
## v0.9.5 TS (owner Q7): 21 is today's: the timed door's switches sit in two other rooms 1-2 steps from it, its timer is
## 20 s, and a lever inside reopens it for 5 s. A floor saved under rules 10-20 keeps both switches by the door and
## 15 s (FloorPlan.add_secrets).
const FLOOR_RULES := 22
const FLOOR_RULES_V070 := 1
const FLOOR_RULES_V075_MG := 2
const FLOOR_RULES_V075_BF1 := 3
const FLOOR_RULES_V080_RT1 := 4
const FLOOR_RULES_V080_SR := 5
const FLOOR_RULES_V080_N14 := 6
const FLOOR_RULES_V080_N17 := 7
const FLOOR_RULES_V080_N19 := 8
const FLOOR_RULES_V080_BD := 9
const FLOOR_RULES_V090_TD := 10
const FLOOR_RULES_V090_RA := 11
const FLOOR_RULES_V090_DP := 12
const FLOOR_RULES_V090_LK := 13
const FLOOR_RULES_V090_SH := 14
const FLOOR_RULES_V090_EL := 15
const FLOOR_RULES_V090_CF := 16
const FLOOR_RULES_V090_CF2 := 17
## v0.9.5 SB: the props that look solid are solid (Solids).
const FLOOR_RULES_V095_SB := 18
const FLOOR_RULES_V095_AQ := 19
const FLOOR_RULES_V095_DR := 20
const FLOOR_RULES_V095_TS := 21
## v0.9.5 BK: breakables are solid until broken, and never placed within 1.5 m of a doorway.
const FLOOR_RULES_V095_BK := 22

var run_seed := 0
var table: RunTable
## 1-based floor number.
var floor_index := 1
## Indices into the run's biome list, one per floor.
var biome_order := PackedInt32Array()
## RunCarry.take of the last finished floor ({} on floor 1).
var carry := {}
## Totals of the floors already finished (the current floor's World holds its own).
var ticks_done := 0
var kills_done := 0
## The run's starting build (v0.3.0 L15): a BuildDefinition id chosen on the start screen, the same on every
## floor. Each floor's PlayerTable is compiled with it (the world hashes its weapons and damage factors).
var build_id := &""
## v0.5.0 RT: the route of each floor reached (Routes.Route), entry f − 1; floor 1 is always NORMAL. A saved run
## keeps it (RunSaver.payload_of / run_from, payload version 2).
var routes := PackedInt32Array([Routes.Route.NORMAL])
## v0.5.0 EV (M-THREAT): threat T at the end of each finished floor.
var threat_by_floor := PackedInt32Array()
## v0.7.5 MG: see FLOOR_RULES.
var floor_rules := FLOOR_RULES
## v0.7.5 AP: the loop (1 until the first Ascend) and the floors of the loops before it (run_floor()). A saved run
## keeps both (RunSaver; a payload without them is loop 1).
var loop := 1
var loop_floors := 0
## v0.8.0 FB1 (owner O16; FINAL_BOSS.md F1): End the run took the hero to the final boss: the run's next (and last)
## world is the final arena (FinalArenaScenario), on the loop's last floor (floor_index stays). Saved (RunSaver; an
## older payload has none).
var final_fight := false
## v0.9.0 DP (owner Q26b): the run's floors (run_floor(), across loops) that held a purple-rune room, so a loop holds
## one at most (PurpleRunes.chance). Saved (RunSaver; an older payload has none).
var purple_floors := PackedInt32Array()
## v0.9.0 RB (owner: "locked once a run starts"): the rune affinity picked at the Wardrobe before the run (an
## AffinityDefinition id; &"" or &"none" = None), the same on every floor. Saved (RunSaver; an older payload: None).
var affinity := &""
## v0.9.0 MP (PLAN W49-W50): the Rune Fragments the finished floors earned (RuneFragments.of_floor; collectibles
## through RuneFragments.add_collectibles), banked into the profile when the run ends (MetaProgress). Saved
## (RunSaver; an older payload: 0).
var fragments_done := 0
## v0.9.0 MP: how fragments are earned (FragmentTable; FloorPlan sets it from content). Null: the run earns none.
var fragment_table: FragmentTable
## v0.9.0 MP (owner: "void unlocked when traveling through a purple portal"): the card ids no offer draws in this
## run (the profile's locked forms when the run started; FloorPlan resolves them into World.locked_items). Emptied
## when the run travels through a Purple Portal (app side). Saved (RunSaver; an older payload: none locked).
var locked_cards: Array[StringName] = []
## v0.9.0 CL (COLLECTIBLES.md): the collectibles no floor of this run arms again (the profile's found ones when the run
## started, and each one taken in it: the app adds it), the ones taken in this run (one Stone a run), and the secrets
## behind hidden rune markings the finished floors found (Collectibles.marked; the Rune Rubbing counts the run's).
## Saved (RunSaver; an older payload: none).
var collected: Array[StringName] = []
var collected_run: Array[StringName] = []
var marked_done := 0


static func start(p_run_seed: int, p_table: RunTable, p_build_id: StringName = &"") -> RunState:
	var r := RunState.new()
	r.run_seed = p_run_seed
	r.build_id = p_build_id
	r.table = p_table
	var n := maxi(1, p_table.biome_count)
	var order := PackedInt32Array()
	for i in n:
		order.append(i)
	var rng := RngStream.derive(p_run_seed, "biomes")
	for i in range(n - 1, 0, -1):
		var j := rng.range_int(0, i)
		var t := order[i]
		order[i] = order[j]
		order[j] = t
	for f in p_table.floors:
		r.biome_order.append(order[f % n])
	return r


## v0.7.5 AP: the run's floor number counted across loops (1-based): floor f of the current loop.
func run_floor(f: int = floor_index) -> int:
	return loop_floors + f


## v0.7.5 AP: the next loop's biomes (N4, "new biomes drawn from all"): every biome of the run's list shuffled from
## the stream `biomes_loop_<loop>`, appended for its floors; the loop's first floor never repeats the floor before it
## (when there are two biomes or more).
func _draw_loop_biomes() -> void:
	var n := maxi(1, table.biome_count)
	var order := PackedInt32Array()
	for i in n:
		order.append(i)
	var rng := RngStream.derive(run_seed, "biomes_loop_%d" % loop)
	for i in range(n - 1, 0, -1):
		var j := rng.range_int(0, i)
		var t := order[i]
		order[i] = order[j]
		order[j] = t
	var last := biome_order[biome_order.size() - 1] if not biome_order.is_empty() else -1
	if n > 1 and order[0] == last:
		order[0] = order[1]
		order[1] = last
	for f in table.floors:
		biome_order.append(order[f % n])


## v0.7.5 AP: a loop factor per mille: `step` once per loop past the first, compounding, capped (1000 on loop 1).
func loop_permille(step: int, p_loop: int = loop) -> int:
	var m := 1000
	for k in maxi(0, p_loop - 1):
		m = mini(table.loop_scale_cap_permille, m * maxi(1000, step) / 1000)
	return m


## The seed of floor f (1-based): the run seed on floor 1, then one derived from it per floor. v0.7.5 AP: f is the
## run's floor (run_floor()), so every loop's floors are new.
func floor_seed(f: int = run_floor()) -> int:
	if f <= 1:
		return run_seed
	return RngStream.derive(run_seed, "floor_%d" % f).next_u32()


## The biome (an index into the run's biome list) of floor f (v0.7.5 AP: the run's floor).
func biome_of(f: int = run_floor()) -> int:
	return biome_order[clampi(f - 1, 0, biome_order.size() - 1)]


func is_last_floor() -> bool:
	return floor_index >= table.floors


## v0.5.0 RT: floor f's route (Routes.Route; NORMAL past the floors reached) and whether it is Deep. v0.7.5 AP: f is
## the run's floor (run_floor()); routes holds one entry per floor of the run, across loops.
func route_of(f: int = run_floor()) -> int:
	return routes[f - 1] if f >= 1 and f <= routes.size() else Routes.Route.NORMAL


func is_deep(f: int = run_floor()) -> bool:
	return route_of(f) == Routes.Route.DEEP


## Run floor f's extra scaling in per mille: the Deep factor on a Deep floor, else 1000.
func route_permille(f: int = run_floor()) -> int:
	return table.deep_scale_permille if is_deep(f) else 1000


## v0.8.0 P3 (owner O35): run floor f's ease in per mille: RunTable.loop_deep_ease_permille on a Deep floor past loop 1
## (the second loop + the Purple Portal), else 1000. Loop 2 alone and a Deep floor on loop 1 are unchanged.
func _loop_deep_ease(f: int = run_floor()) -> int:
	return table.loop_deep_ease_permille if loop > 1 and is_deep(f) else 1000


## Scales freshly compiled enemy tables for floor f (v0.4.0 SC): HP and damage × the run's per-floor per-mille
## tables, rounded (SpawnTable.scale). The danger tier's scaling comes on top as each enemy arrives (SpawnDirector);
## the tier restarts with each floor's World. Enemies a boss brings in (eggs, turrets) get the floor's only.
## v0.5.0 RT: on a Deep floor the per-floor factor is first multiplied by the Deep factor (one rounding, one scale).
## v0.7.5 AP: f is the floor within the current loop; past loop 1, × the loop's factor (loop_permille).
func scale_enemies(tables: Array[EnemyTable], f: int = floor_index) -> void:
	var deep := route_permille(run_floor(f))
	var hp_pm := SpawnTable.scale(SpawnTable.per_floor(table.enemy_hp_floor_permille, f), deep)
	var dmg_pm := SpawnTable.scale(SpawnTable.per_floor(table.enemy_damage_floor_permille, f), deep)
	if loop > 1:
		hp_pm = SpawnTable.scale(hp_pm, loop_permille(table.loop_enemy_hp_permille))
		dmg_pm = SpawnTable.scale(dmg_pm, loop_permille(table.loop_enemy_damage_permille))
	var ease := _loop_deep_ease(run_floor(f))  # v0.8.0 P3 (owner O35)
	if ease != 1000:
		hp_pm = SpawnTable.scale(hp_pm, ease)
		dmg_pm = SpawnTable.scale(dmg_pm, ease)
	for t in tables:
		t.hp = maxi(1, SpawnTable.scale(t.hp, hp_pm))
		t.damage = SpawnTable.scale(t.damage, dmg_pm)
		if t.elite != null:  # v0.9.0 EL: an elite's ability, plain attack and contact, by the same factor
			t.elite.scale_damage(dmg_pm)


## Scales freshly compiled boss tables for floor f by the bosses' own factors (not the enemies' tables, so nothing
## applies twice): HP, and every attack's damage. v0.5.0 RT: × the Deep factor on a Deep floor, in the same step.
## v0.7.5 AP: f is the floor within the current loop; past loop 1, × the loop's boss factor, and the floor-1 ease
## reads the run's floor (only the run's first floor is eased).
func scale_bosses(tables: Array[BossTable], f: int = floor_index) -> void:
	var deep := route_permille(run_floor(f))
	var hp_pm := (1000 + table.boss_hp_per_floor_permille * (f - 1)) * deep / 1000
	var dmg_pm := (1000 + table.boss_damage_per_floor_permille * (f - 1)) * deep / 1000
	if loop > 1:
		hp_pm = hp_pm * loop_permille(table.loop_boss_hp_permille) / 1000
		dmg_pm = dmg_pm * loop_permille(table.loop_boss_damage_permille) / 1000
	var deep_ease := _loop_deep_ease(run_floor(f))  # v0.8.0 P3 (owner O35)
	if deep_ease != 1000:
		hp_pm = hp_pm * deep_ease / 1000
		dmg_pm = dmg_pm * deep_ease / 1000
	# v0.4.0 TU (owner D9): floor 1's bosses are eased (-20 % HP and damage), in the same step.
	var ease := SpawnTable.per_floor(table.boss_ease_floor_permille, run_floor(f))
	if ease > 0 and ease != 1000:
		hp_pm = hp_pm * ease / 1000
		dmg_pm = dmg_pm * ease / 1000
	for t in tables:
		if t.mimic:
			continue  # v0.8.0 FB3 (owner F7): the Nemesis's HP and damage come from the build, which carries the loops
		t.hp = maxi(1, t.hp * hp_pm / 1000)
		for a in t.attacks:
			a.damage = a.damage * dmg_pm / 1000
			a.orb_damage = a.orb_damage * dmg_pm / 1000  # v0.8.0 BP: the orbs scale with it


## Floor f's boss: one of its pool (indices into the compiled bosses), drawn from a stream of the run seed
## (`boss_<f>`), so a run always meets the same bosses. -1 for an empty pool. v0.7.5 AP: f is the run's floor.
func pick_boss(pool: PackedInt32Array, f: int = run_floor()) -> int:
	return BossTable.pick(pool, RngStream.derive(run_seed, "boss_%d" % f))


## Sets up a fresh floor's world: its number, and the carry from the floor before.
func prepare(w: World) -> void:
	w.floor_index = floor_index
	w.floor_count = table.floors
	w.boss_room_heal_permille = SpawnTable.per_floor(
		table.boss_room_heal_floor_permille, run_floor()
	)  # TU (D9); v0.7.5 AP: the run's first floor only
	w.loop = loop  # v0.7.5 AP: the loop, the run's floor, the loop's threat and catch-up cap
	w.run_floor = run_floor()
	w.loop_threat = table.loop_threat * (loop - 1)
	w.loop_cap_permille = table.loop_catch_up_cap_permille * (loop - 1)
	if w.boss_flow != null:  # v0.5.0 RT
		w.boss_flow.deep = is_deep()
		w.boss_flow.ascension = is_last_floor()  # v0.7.5 AP: the loop's last floor has the Ascension portal
		if floor_rules > FLOOR_RULES_V080_N19:  # v0.8.0 BD (O83): shut until pressed (before BD: an open doorway)
			w.boss_flow.door = BossFlow.Door.SET
		w.boss_flow.final_next = is_last_floor() and _has_final()  # v0.8.0 FB1: End leads to the final boss
	w.deep_threat = routes.count(Routes.Route.DEEP)  # v0.5.0 RT + EV: +1 threat T per Deep floor taken
	w.floor_hp_bonus = _hp_bonus()  # v0.9.0 SV: before the carry, so its max HP includes it
	if not carry.is_empty():
		RunCarry.apply(w, carry)
	elif w.floor_hp_bonus > 0:
		Gamble.after_carry(w)
		w.actors.hp[0] = w.actors.max_hp[0]


## v0.9.0 SV: the floors' max HP growth on the current floor (RunCarry.floor_hp_bonus).
func _hp_bonus() -> int:
	return RunCarry.floor_hp_bonus(table, run_floor())


## v0.7.5 MG: whether the current floor is a v0.7.0 floor resumed from an older save.
func v070_floor() -> bool:
	return floor_rules == FLOOR_RULES_V070


## v0.7.5 BF1 (N18): whether the current floor's boss room is the one before the 4 x 4 rooms (a floor resumed from a
## save made before BF1).
func legacy_boss_room() -> bool:
	return floor_rules < 3


## v0.8.0 RT: whether the current floor has the designed room layouts (false: a floor resumed from a save made before
## RT, rebuilt with its rule-built rooms).
func designed_rooms() -> bool:
	return floor_rules >= FLOOR_RULES_V080_RT1


## v0.8.0 RT2: whether the current floor was built with RT1's three layouts only (a floor resumed from a save made
## between RT1 and RT2).
func rt1_rooms() -> bool:
	return floor_rules == FLOOR_RULES_V080_RT1


## Closes the floor `w` (its portal taken): adds its totals, takes the carry and moves to the next floor. v0.7.5 AP:
## when the Loop device took it (v0.7.5's Ascend), the next floor is floor 1 of the next loop (new biomes drawn).
func finish_floor(w: World) -> void:
	ticks_done += w.run_ticks
	kills_done += w.kills
	threat_by_floor.append(Curses.threat(w))
	fragments_done += RuneFragments.of_floor(w, fragment_table, true)  # v0.9.0 MP
	marked_done += Collectibles.marked(w)  # v0.9.0 CL: the Rune Rubbing counts the run's marked secrets
	if w.purple != null and not purple_floors.has(run_floor()):  # v0.9.0 DP: one purple room a loop
		purple_floors.append(run_floor())
	carry = RunCarry.take(w, table.heal_permille, table.shard_carry_permille)
	var grown_from := _hp_bonus()
	if Ascension.took_portal(w) and _has_final():  # FB1; v0.8.0 P2: the Ascension portal: the final arena
		final_fight = true
	elif Ascension.looped(w):  # v0.8.0 P2 (O28): the Loop device
		loop_floors += floor_index
		loop += 1
		floor_index = 1
		_draw_loop_biomes()
	else:
		floor_index += 1
	floor_rules = FLOOR_RULES  # v0.7.5 MG: a new floor, always on today's rules
	RunCarry.grow(w, carry, grown_from, _hp_bonus())  # v0.9.0 SV: the new max HP arrives filled
	var taken := w.boss_flow.route_taken if w.boss_flow != null else -1
	routes.resize(run_floor() - 1)  # v0.5.0 RT: the next floor's route, the one walked into
	routes.append(taken if taken >= 0 else Routes.Route.NORMAL)


## v0.7.5 AP: the loops the run cleared, with `w` the current floor's world (null: the finished floors only): the
## loops left by the Loop device, and the current one when its Ascension portal ended the run (a run with no final
## boss). v0.8.0 FB1: with a final boss,
## the current loop counts once the final boss is beaten (dying to it clears none).
func loops_cleared(w: World = null) -> int:
	var done := loop - 1
	if w != null and (Ascension.took_portal(w) or (w.final_fight != null and w.final_fight.won)):
		done += 1
	return done


## v0.8.0 FB1: the run has a final boss (the Ascension portal leads to it; v0.8.0 P2).
func _has_final() -> bool:
	return not table.final_bosses.is_empty()


## Run totals including the current floor's world (null = only the finished floors).
func total_ticks(w: World) -> int:
	return ticks_done + (w.run_ticks if w != null else 0)


func total_kills(w: World) -> int:
	return kills_done + (w.kills if w != null else 0)
