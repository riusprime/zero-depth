class_name RunState
extends RefCounted
## A run of floors (v0.3.0 PLAN L3-L4, "Run (B)"): the floor number, the biome order (shuffled once per run from
## the `biomes` stream), each floor's seed (floor 1 uses the run seed, later floors one derived from it), the enemy
## scaling per floor, the carry between floors and the totals the recap shows. Pure sim code; the app owns one per
## run and builds a fresh World per floor.

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


## The seed of floor f (1-based): the run seed on floor 1, then one derived from it per floor.
func floor_seed(f: int = floor_index) -> int:
	if f <= 1:
		return run_seed
	return RngStream.derive(run_seed, "floor_%d" % f).next_u32()


## The biome (an index into the run's biome list) of floor f.
func biome_of(f: int = floor_index) -> int:
	return biome_order[clampi(f - 1, 0, biome_order.size() - 1)]


func is_last_floor() -> bool:
	return floor_index >= table.floors


## v0.5.0 RT: floor f's route (Routes.Route; NORMAL past the floors reached) and whether it is Deep.
func route_of(f: int = floor_index) -> int:
	return routes[f - 1] if f >= 1 and f <= routes.size() else Routes.Route.NORMAL


func is_deep(f: int = floor_index) -> bool:
	return route_of(f) == Routes.Route.DEEP


## Floor f's extra scaling in per mille: the Deep factor on a Deep floor, else 1000.
func route_permille(f: int = floor_index) -> int:
	return table.deep_scale_permille if is_deep(f) else 1000


## Scales freshly compiled enemy tables for floor f (v0.4.0 SC): HP and damage × the run's per-floor per-mille
## tables, rounded (SpawnTable.scale). The danger tier's scaling comes on top as each enemy arrives (SpawnDirector);
## the tier restarts with each floor's World. Enemies a boss brings in (eggs, turrets) get the floor's only.
## v0.5.0 RT: on a Deep floor the per-floor factor is first multiplied by the Deep factor (one rounding, one scale).
func scale_enemies(tables: Array[EnemyTable], f: int = floor_index) -> void:
	var deep := route_permille(f)
	var hp_pm := SpawnTable.scale(SpawnTable.per_floor(table.enemy_hp_floor_permille, f), deep)
	var dmg_pm := SpawnTable.scale(SpawnTable.per_floor(table.enemy_damage_floor_permille, f), deep)
	for t in tables:
		t.hp = maxi(1, SpawnTable.scale(t.hp, hp_pm))
		t.damage = SpawnTable.scale(t.damage, dmg_pm)


## Scales freshly compiled boss tables for floor f by the bosses' own factors (not the enemies' tables, so nothing
## applies twice): HP, and every attack's damage. v0.5.0 RT: × the Deep factor on a Deep floor, in the same step.
func scale_bosses(tables: Array[BossTable], f: int = floor_index) -> void:
	var deep := route_permille(f)
	var hp_pm := (1000 + table.boss_hp_per_floor_permille * (f - 1)) * deep / 1000
	var dmg_pm := (1000 + table.boss_damage_per_floor_permille * (f - 1)) * deep / 1000
	for t in tables:
		t.hp = maxi(1, t.hp * hp_pm / 1000)
		for a in t.attacks:
			a.damage = a.damage * dmg_pm / 1000


## Floor f's boss: one of its pool (indices into the compiled bosses), drawn from a stream of the run seed
## (`boss_<f>`), so a run always meets the same bosses. -1 for an empty pool.
func pick_boss(pool: PackedInt32Array, f: int = floor_index) -> int:
	return BossTable.pick(pool, RngStream.derive(run_seed, "boss_%d" % f))


## Sets up a fresh floor's world: its number, and the carry from the floor before.
func prepare(w: World) -> void:
	w.floor_index = floor_index
	w.floor_count = table.floors
	if w.boss_flow != null:  # v0.5.0 RT
		w.boss_flow.deep = is_deep()
	if not carry.is_empty():
		RunCarry.apply(w, carry)


## Closes the floor `w` (its portal taken): adds its totals, takes the carry and moves to the next floor.
func finish_floor(w: World) -> void:
	ticks_done += w.run_ticks
	kills_done += w.kills
	carry = RunCarry.take(w, table.heal_permille)
	floor_index += 1
	var taken := w.boss_flow.route_taken if w.boss_flow != null else -1
	routes.resize(floor_index - 1)  # v0.5.0 RT: the next floor's route, the one walked into
	routes.append(taken if taken >= 0 else Routes.Route.NORMAL)


## Run totals including the current floor's world (null = only the finished floors).
func total_ticks(w: World) -> int:
	return ticks_done + (w.run_ticks if w != null else 0)


func total_kills(w: World) -> int:
	return kills_done + (w.kills if w != null else 0)
