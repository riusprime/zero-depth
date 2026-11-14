class_name RunState
extends RefCounted
## A run of floors (v0.3.0 PLAN L3-L4, "Run (B)"): the floor number, the biome order (shuffled once per run from the
## `biomes` stream), each floor's seed (floor 1 uses the run seed, later floors one derived from it), the enemy scaling
## per floor, the carry between floors and the totals the recap shows. Pure sim code; the app owns one per run and
## builds a fresh World per floor. after the last floor's boss the Ascension
## portal ends the run or starts loop + 1 at floor 1 with the build carried (finish_floor). two
## devices instead of a choice: the Ascension portal leads to the final boss, the Loop device starts loop + 1.
## `floor_index` stays the floor within the loop (1.. floors: the floor tables, boss pools, curves and prices read it);
## run_floor() counts the run's floors across loops (the floor seeds, the bosses drawn, the routes, the biome order, the
## boss's floor-1 ease and FloorCadence's shop and curse floors read it, so loop 2 is new ground and two featured floors
## never meet at a seam). Each loop past the first scales enemies and bosses (loop_permille) and adds threat and
## catch-up cap (prepare).

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
## The run's starting build: a BuildDefinition id chosen on the start screen, the same on every
## floor. Each floor's PlayerTable is compiled with it (the world hashes its weapons and damage factors).
var build_id := &""
## The route of each floor reached (Routes.Route), entry f − 1; floor 1 is always NORMAL. A saved run
## keeps it (RunSaver.payload_of / run_from, payload version 2).
var routes := PackedInt32Array([Routes.Route.NORMAL])
## M-THREAT: threat T at the end of each finished floor.
var threat_by_floor := PackedInt32Array()
## The loop (1 until the first Ascend) and the floors of the loops before it (run_floor()). A saved run
## keeps both (RunSaver).
var loop := 1
var loop_floors := 0
## End the run took the hero to the final boss: the run's next (and last)
## world is the final arena (FinalArenaScenario), on the loop's last floor (floor_index stays). Saved (RunSaver).
var final_fight := false
## The run's floors (run_floor(), across loops) that held a purple-rune room, so a loop holds
## one at most (PurpleRunes.chance). Saved (RunSaver).
var purple_floors := PackedInt32Array()
## The rune affinity picked at the Wardrobe before the run (an
## AffinityDefinition id; &"" or &"none" = None), the same on every floor. Saved (RunSaver).
var affinity := &""
## PLAN W49-W50: the Rune Fragments the finished floors earned (RuneFragments.of_floor; collectibles
## through RuneFragments.add_collectibles), banked into the profile when the run ends (MetaProgress). Saved
## (RunSaver).
var fragments_done := 0
## How fragments are earned (FragmentTable; FloorPlan sets it from content). Null: the run earns none.
var fragment_table: FragmentTable
## The card ids no offer draws in this
## run (the profile's locked forms when the run started; FloorPlan resolves them into World.locked_items). Emptied
## when the run travels through a Purple Portal (app side). Saved (RunSaver).
var locked_cards: Array[StringName] = []
## COLLECTIBLES.md: the collectibles no floor of this run arms again (the profile's found ones when the run
## started, and each one taken in it: the app adds it), the ones taken in this run (one Stone a run), and the secrets
## behind hidden rune markings the finished floors found (Collectibles.marked; the Rune Rubbing counts the run's).
## Saved (RunSaver).
var collected: Array[StringName] = []
var collected_run: Array[StringName] = []
var marked_done := 0
## The loop rules the run holds (LoopRules.POOL ids, in the order drawn: one a loop past the
## first) and the loop that drew the newest (the floor card announces it on that loop). Saved (RunSaver).
var loop_rules: Array[StringName] = []
var loop_rule_loop := 0
## The profile had learned all ten Runic Stone lines (r11 known) when the run began,
## so its final approach holds the hidden room under the throne (FinalArena.add_heart_room). Saved (RunSaver; a run
## without it: false).
var heart_room := false


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


## The run's floor number counted across loops (1-based): floor f of the current loop.
func run_floor(f: int = floor_index) -> int:
	return loop_floors + f


## The next loop's biomes (N4, "new biomes drawn from all"): every biome of the run's list shuffled from
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


## A loop factor per mille: `step` once per loop past the first, compounding, capped (1000 on loop 1).
func loop_permille(step: int, p_loop: int = loop) -> int:
	var m := 1000
	for k in maxi(0, p_loop - 1):
		m = mini(table.loop_scale_cap_permille, m * maxi(1000, step) / 1000)
	return m


## The seed of floor f (1-based): the run seed on floor 1, then one derived from it per floor. f is the
## run's floor (run_floor()), so every loop's floors are new.
func floor_seed(f: int = run_floor()) -> int:
	if f <= 1:
		return run_seed
	return RngStream.derive(run_seed, "floor_%d" % f).next_u32()


## The biome (an index into the run's biome list) of floor f (the run's floor).
func biome_of(f: int = run_floor()) -> int:
	return biome_order[clampi(f - 1, 0, biome_order.size() - 1)]


func is_last_floor() -> bool:
	return floor_index >= table.floors


## Floor f's route (Routes.Route; NORMAL past the floors reached) and whether it is Deep. f is
## the run's floor (run_floor()); routes holds one entry per floor of the run, across loops.
func route_of(f: int = run_floor()) -> int:
	return routes[f - 1] if f >= 1 and f <= routes.size() else Routes.Route.NORMAL


func is_deep(f: int = run_floor()) -> bool:
	return route_of(f) == Routes.Route.DEEP


## Run floor f's extra scaling in per mille: the Deep factor on a Deep floor, else 1000.
func route_permille(f: int = run_floor()) -> int:
	return table.deep_scale_permille if is_deep(f) else 1000


## Run floor f's ease in per mille: RunTable.loop_deep_ease_permille on a Deep floor past loop 1
## (the second loop + the Purple Portal), else 1000. Loop 2 alone and a Deep floor on loop 1 are unchanged.
func _loop_deep_ease(f: int = run_floor()) -> int:
	return table.loop_deep_ease_permille if loop > 1 and is_deep(f) else 1000


## Scales freshly compiled enemy tables for floor f: HP and damage × the run's per-floor per-mille
## tables, rounded (SpawnTable.scale). The danger tier's scaling comes on top as each enemy arrives (SpawnDirector);
## the tier restarts with each floor's World. Enemies a boss brings in (eggs, turrets) get the floor's only.
## On a Deep floor the per-floor factor is first multiplied by the Deep factor (one rounding, one scale).
## F is the floor within the current loop; past loop 1, × the loop's factor (loop_permille).
func scale_enemies(tables: Array[EnemyTable], f: int = floor_index) -> void:
	var deep := route_permille(run_floor(f))
	var hp_pm := SpawnTable.scale(SpawnTable.per_floor(table.enemy_hp_floor_permille, f), deep)
	var dmg_pm := SpawnTable.scale(SpawnTable.per_floor(table.enemy_damage_floor_permille, f), deep)
	if loop > 1:
		hp_pm = SpawnTable.scale(hp_pm, loop_permille(table.loop_enemy_hp_permille))
		dmg_pm = SpawnTable.scale(dmg_pm, loop_permille(table.loop_enemy_damage_permille))
	var ease := _loop_deep_ease(run_floor(f))  # v0.8.0 P3
	if ease != 1000:
		hp_pm = SpawnTable.scale(hp_pm, ease)
		dmg_pm = SpawnTable.scale(dmg_pm, ease)
	for t in tables:
		t.hp = maxi(1, SpawnTable.scale(t.hp, hp_pm))
		t.damage = SpawnTable.scale(t.damage, dmg_pm)
		if t.elite != null:  # An elite's ability, plain attack and contact, by the same factor
			t.elite.scale_damage(dmg_pm)
		_remix_enemy(t)  # v0.10.5 O5b


## LoopRules SWIFT, POINT_BLANK: enemy table `t` under the run's loop rules.
func _remix_enemy(t: EnemyTable) -> void:
	if LoopRules.run_holds(self, LoopRules.SWIFT):
		t.speed = t.speed * table.loop_swift_permille / 1000.0
		t.charge_speed = t.charge_speed * table.loop_swift_permille / 1000.0
	if (
		LoopRules.run_holds(self, LoopRules.POINT_BLANK)
		and (t.bolt_speed > 0.0 or t.spread_speed > 0.0)
	):
		t.bolt_speed = t.bolt_speed * table.loop_bolt_permille / 1000.0
		t.spread_speed = t.spread_speed * table.loop_bolt_permille / 1000.0
		t.keep_distance_m = t.keep_distance_m * table.loop_keep_permille / 1000.0
		t.keep_min_m = t.keep_min_m * table.loop_keep_permille / 1000.0


## Scales freshly compiled boss tables for floor f by the bosses' own factors (not the enemies' tables, so nothing
## applies twice): HP, and every attack's damage. × the Deep factor on a Deep floor, in the same step.
## F is the floor within the current loop; past loop 1, × the loop's boss factor, and the floor-1 ease
## reads the run's floor (only the run's first floor is eased).
func scale_bosses(tables: Array[BossTable], f: int = floor_index) -> void:
	var deep := route_permille(run_floor(f))
	var hp_pm := (1000 + table.boss_hp_per_floor_permille * (f - 1)) * deep / 1000
	var dmg_pm := (1000 + table.boss_damage_per_floor_permille * (f - 1)) * deep / 1000
	if loop > 1:
		hp_pm = hp_pm * loop_permille(table.loop_boss_hp_permille) / 1000
		dmg_pm = dmg_pm * loop_permille(table.loop_boss_damage_permille) / 1000
	var deep_ease := _loop_deep_ease(run_floor(f))  # v0.8.0 P3
	if deep_ease != 1000:
		hp_pm = hp_pm * deep_ease / 1000
		dmg_pm = dmg_pm * deep_ease / 1000
	# Floor 1's bosses are eased (-20 % HP and damage), in the same step.
	var ease := SpawnTable.per_floor(table.boss_ease_floor_permille, run_floor(f))
	if ease > 0 and ease != 1000:
		hp_pm = hp_pm * ease / 1000
		dmg_pm = dmg_pm * ease / 1000
	for t in tables:
		if t.mimic:
			continue  # The Nemesis's HP and damage come from the build, which carries the loops
		t.hp = maxi(1, t.hp * hp_pm / 1000)
		for a in t.attacks:
			a.damage = a.damage * dmg_pm / 1000
			a.orb_damage = a.orb_damage * dmg_pm / 1000  # The orbs scale with it


## Floor f's boss: one of its pool (indices into the compiled bosses), drawn from a stream of the run seed
## (`boss_<f>`), so a run always meets the same bosses. -1 for an empty pool. f is the run's floor.
func pick_boss(pool: PackedInt32Array, f: int = run_floor()) -> int:
	return BossTable.pick(pool, RngStream.derive(run_seed, "boss_%d" % f))


## Sets up a fresh floor's world: its number, and the carry from the floor before.
func prepare(w: World) -> void:
	w.floor_index = floor_index
	w.floor_count = table.floors
	w.boss_room_heal_permille = SpawnTable.per_floor(
		table.boss_room_heal_floor_permille, run_floor()
	)  # TU; the run's first floor only
	w.loop = loop  # The loop, the run's floor, the loop's threat and catch-up cap
	if loop > 1:  # The compile reads the loop (Attacks.hook_depth); never a stale loop-1 book
		Modifiers.invalidate(w)
	w.run_floor = run_floor()
	w.loop_threat = table.loop_threat * (loop - 1)
	w.loop_cap_permille = table.loop_catch_up_cap_permille * (loop - 1)
	_prepare_rules(w)  # v0.10.5 O5b
	if w.boss_flow != null:  # v0.5.0 RT
		w.boss_flow.deep = is_deep()
		w.boss_flow.ascension = is_last_floor()  # The loop's last floor has the Ascension portal
		w.boss_flow.door = BossFlow.Door.SET  # Shut until pressed
		w.boss_flow.final_next = is_last_floor() and _has_final()  # End leads to the final boss
	w.deep_threat = routes.count(Routes.Route.DEEP)  # v0.5.0 RT + EV: +1 threat T per Deep floor taken
	w.floor_hp_bonus = _hp_bonus()  # Before the carry, so its max HP includes it
	if not carry.is_empty():
		RunCarry.apply(w, carry)
	elif w.floor_hp_bonus > 0:
		Gamble.after_carry(w)
		w.actors.hp[0] = w.actors.max_hp[0]


## The floor's loop rules (World.loop_rules), SHIELDED's numbers and LEAN_MENDING's heal orbs (the
## floor's freshly compiled reward table).
func _prepare_rules(w: World) -> void:
	w.loop_rules = LoopRules.indices(loop_rules)
	if LoopRules.held(w, LoopRules.SHIELDED):
		w.loop_shield_permille = table.loop_shield_permille
		w.loop_shield_half_arc = table.loop_shield_half_arc
	if LoopRules.held(w, LoopRules.LEAN_MENDING) and w.reward_table != null:
		var r := w.reward_table
		r.heal_orb_meter = r.heal_orb_meter * 1000 / maxi(1, table.loop_heal_chance_permille)  # v0.11.0 F3
		r.heal_orb_heal_permille = r.heal_orb_heal_permille * table.loop_heal_amount_permille / 1000


## The floors' max HP growth on the current floor (RunCarry.floor_hp_bonus).
func _hp_bonus() -> int:
	return RunCarry.floor_hp_bonus(table, run_floor())


## Closes the floor `w` (its portal taken): adds its totals, takes the carry and moves to the next floor.
## when the Loop device took it (v0.7.5's Ascend), the next floor is floor 1 of the next loop (new biomes drawn).
func finish_floor(w: World) -> void:
	ticks_done += w.run_ticks
	kills_done += w.kills
	threat_by_floor.append(Curses.threat(w))
	fragments_done += RuneFragments.of_floor(w, fragment_table, true)  # v0.9.0 MP
	marked_done += Collectibles.marked(w)  # The Rune Rubbing counts the run's marked secrets
	if w.purple != null and not purple_floors.has(run_floor()):  # One purple room a loop
		purple_floors.append(run_floor())
	ShardDrops.collect_all(w)  # The shards left lying on the floor are taken with you
	carry = RunCarry.take(w, table.heal_permille, table.shard_carry_permille)
	var grown_from := _hp_bonus()
	if Ascension.took_portal(w) and _has_final():  # FB1; the Ascension portal: the final arena
		final_fight = true
	elif Ascension.looped(w):  # The Loop device
		loop_floors += floor_index
		loop += 1
		floor_index = 1
		_draw_loop_biomes()
		LoopRules.draw(self)  # Each loop adds a rule
		# The new loop's floor 1 opens with a free Constellation pick (none left: none)
		carry[RunCarry.OFFER] = Constellations.offer(run_seed, loop, w.constellations)
	else:
		floor_index += 1
	RunCarry.grow(w, carry, grown_from, _hp_bonus())  # The new max HP arrives filled
	var taken := w.boss_flow.route_taken if w.boss_flow != null else -1
	routes.resize(run_floor() - 1)  # The next floor's route, the one walked into
	routes.append(taken if taken >= 0 else Routes.Route.NORMAL)


## The loops the run cleared, with `w` the current floor's world (null: the finished floors only): the
## loops left by the Loop device, and the current one when its Ascension portal ended the run (a run with no final
## boss). with a final boss,
## the current loop counts once the final boss is beaten (dying to it clears none).
func loops_cleared(w: World = null) -> int:
	var done := loop - 1
	if w != null and (Ascension.took_portal(w) or (w.final_fight != null and w.final_fight.won)):
		done += 1
	return done


## The run has a final boss (the Ascension portal leads to it; v0.8.0 P2).
func _has_final() -> bool:
	return not table.final_bosses.is_empty()


## Run totals including the current floor's world (null = only the finished floors).
func total_ticks(w: World) -> int:
	return ticks_done + (w.run_ticks if w != null else 0)


func total_kills(w: World) -> int:
	return kills_done + (w.kills if w != null else 0)
