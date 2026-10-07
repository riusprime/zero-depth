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


## Scales freshly compiled enemy tables for floor f: HP and damage. The danger tier restarts with each floor's World.
func scale_enemies(tables: Array[EnemyTable], f: int = floor_index) -> void:
	for t in tables:
		t.hp = maxi(1, t.hp * (1000 + table.hp_per_floor_permille * (f - 1)) / 1000)
		t.damage = t.damage * (1000 + table.damage_per_floor_permille * (f - 1)) / 1000


## Scales freshly compiled boss tables for floor f by the same factors: HP, and every attack's damage.
func scale_bosses(tables: Array[BossTable], f: int = floor_index) -> void:
	for t in tables:
		t.hp = maxi(1, t.hp * (1000 + table.hp_per_floor_permille * (f - 1)) / 1000)
		for a in t.attacks:
			a.damage = a.damage * (1000 + table.damage_per_floor_permille * (f - 1)) / 1000


## Floor f's boss: one of its pool (indices into the compiled bosses), drawn from a stream of the run seed
## (`boss_<f>`), so a run always meets the same bosses. -1 for an empty pool.
func pick_boss(pool: PackedInt32Array, f: int = floor_index) -> int:
	return BossTable.pick(pool, RngStream.derive(run_seed, "boss_%d" % f))


## Sets up a fresh floor's world: its number, and the carry from the floor before.
func prepare(w: World) -> void:
	w.floor_index = floor_index
	w.floor_count = table.floors
	if not carry.is_empty():
		RunCarry.apply(w, carry)


## Closes the floor `w` (its portal taken): adds its totals, takes the carry and moves to the next floor.
func finish_floor(w: World) -> void:
	ticks_done += w.run_ticks
	kills_done += w.kills
	carry = RunCarry.take(w, table.heal_permille)
	floor_index += 1


## Run totals including the current floor's world (null = only the finished floors).
func total_ticks(w: World) -> int:
	return ticks_done + (w.run_ticks if w != null else 0)


func total_kills(w: World) -> int:
	return kills_done + (w.kills if w != null else 0)
