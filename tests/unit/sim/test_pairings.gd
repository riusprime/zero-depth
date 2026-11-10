extends GutTest
## Enemy pairings (v0.10.5 O15, docs/roadmap/v0.10.5/O15_PAIRINGS.md): a lead kind's pack may bring partners, only from
## the duo's floor and when the partner is unlocked, inside the alive cap, never in the boss room, deterministic.

const KIND := ActorStore.Kind
const LONG := 1 << 24


func _repo() -> ContentRepository:
	return SharedContent.repo()


## A wall-less world, the real spawner with every kind open and only `lead` in the mix's draw, the duo chance forced.
func _world(lead: int, floor_i: int, chance: int = 1000, seed_value: int = 11) -> World:
	var repo := _repo()
	var w := World.new(seed_value, PlayerTable.starting_values())
	w.set_enemy_tables(CombatLab.tables())
	for r in [9.0, 12.0]:
		for k in 8:
			w.spawn_points.append(Kin.dir(k * 512) * r)
	var t := ContentCompiler.compile_spawning(repo.get_def(&"spawning", &"floor_1"), repo)
	t.pairings = ContentCompiler.compile_pairings(repo.get_def(&"pairing", &"pairings"), repo)
	for r in t.pairings.size():
		t.pairings.chance[r] = chance
	for k in t.kinds.size():
		t.unlock_tiers[k] = 0
		t.weights[k] = 100000 if t.kinds[k] == lead else 1  # (a weight must be positive)
	w.spawner = t
	w.floor_index = floor_i
	w.actors.invuln[0] = LONG
	return w


func _kinds_alive(w: World) -> Dictionary:
	var out := {}
	for i in range(1, w.actors.size()):
		out[w.actors.kinds[i]] = int(out.get(w.actors.kinds[i], 0)) + 1
	return out


func _run(w: World, n: int) -> void:
	for t in n:
		w.step(InputFrame.new())


func test_the_six_rows_load_and_validate() -> void:
	var def: PairingSetDefinition = _repo().get_def(&"pairing", &"pairings")
	assert_not_null(def)
	assert_eq(def.rows.size(), 6)
	assert_eq(def.validate().size(), 0)
	var t := ContentCompiler.compile_pairings(def, _repo())
	assert_eq(t.size(), 6)


func test_a_pairing_fires_only_from_its_floor() -> void:
	var early := _world(KIND.CHARGER, 1)  # Charger -> Mine Layer from floor 2
	_run(early, 400)
	assert_gt(_kinds_alive(early).size(), 0, "packs came")
	assert_false(_kinds_alive(early).has(KIND.MINE_LAYER), "floor 1: no mine layer")
	var late := _world(KIND.CHARGER, 2)
	_run(late, 400)
	assert_true(_kinds_alive(late).has(KIND.MINE_LAYER), "floor 2: the mine layer joins")
	assert_eq(late.pairs_seen.size(), 1)


func test_it_needs_the_partner_unlocked() -> void:
	var w := _world(KIND.CHARGER, 2)
	var t := w.spawner
	var open := PackedInt32Array([KIND.CHARGER])
	assert_eq(Pairings.rows_for(w, t, KIND.CHARGER, open).size(), 0, "mine layer locked")
	open.append(KIND.MINE_LAYER)
	assert_eq(Pairings.rows_for(w, t, KIND.CHARGER, open).size(), 1)


func test_warden_brings_two_needles_flanking() -> void:
	var w := _world(KIND.WARDEN, 1)
	_run(w, 200)
	var k := _kinds_alive(w)
	assert_eq(int(k.get(KIND.NEEDLE, 0)), 2, "two needles")
	assert_gt(int(k.get(KIND.WARDEN, 0)), 0)


func test_partners_respect_the_alive_cap() -> void:
	var w := _world(KIND.WARDEN, 1)
	w.spawner.cap_by_floor = PackedInt32Array([3])
	w.spawner.pack_min_by_floor = PackedInt32Array([3])
	w.spawner.pack_max_by_floor = PackedInt32Array([3])
	_run(w, 900)
	assert_lte(w.actors.size() - 1, 3, "never past the cap")
	assert_false(
		_kinds_alive(w).has(KIND.NEEDLE), "a full pack leaves no room: partners dropped first"
	)
	var w2 := _world(KIND.WARDEN, 1)
	w2.spawner.cap_by_floor = PackedInt32Array([4])
	w2.spawner.pack_min_by_floor = PackedInt32Array([3])
	w2.spawner.pack_max_by_floor = PackedInt32Array([3])
	_run(w2, 200)
	assert_lte(w2.actors.size() - 1, 4)
	assert_eq(int(_kinds_alive(w2).get(KIND.NEEDLE, 0)), 1, "one slot of slack: one partner")


func test_no_partner_stands_in_the_boss_room_or_an_arena() -> void:
	var w := _world(KIND.WARDEN, 1)
	var f := FloorLayout.new()
	f.rooms = [Rect2(-20, -20, 40, 40), Rect2(30, -5, 10, 10)]
	f.boss_room = 1
	f.arena_rooms = PackedInt32Array([])
	w.floor_layout = f
	assert_true(SpawnDirector.spot_ok(w, Vector2(10, 0), 0, 4.0))
	assert_false(SpawnDirector.spot_ok(w, Vector2(34, 0), -1, 4.0), "boss room")
	f.boss_room = -1
	f.arena_rooms = PackedInt32Array([1])
	assert_false(SpawnDirector.spot_ok(w, Vector2(34, 0), -1, 4.0), "arena room")
	assert_false(SpawnDirector.spot_ok(w, Vector2(1, 0), 0, 4.0), "too near the hero")


func test_same_seed_same_pairings() -> void:
	var a := _world(KIND.WARDEN, 1, 500, 7)
	var b := _world(KIND.WARDEN, 1, 500, 7)
	_run(a, 1200)
	_run(b, 1200)
	assert_eq(a.state_hash(), b.state_hash())
	assert_eq(a.pairs_seen, b.pairs_seen)
