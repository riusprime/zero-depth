class_name CardPoolSurvey
extends RefCounted
## The card pool (v0.5.0 CP, ROADMAP v0.5.0: "a 40–50 card candidate pool"): which distinct cards a run of each
## build can be offered, and how often altars and chests offer each one from reachable states. Shared by
## tests/unit/sim/test_card_pool_reach.gd (no dead cards, the pool size) and scripts/checks/card_pool.gd (the
## frequency table for evidence).
##
## A distinct card is an ability (a new one or its level-ups: one card), a stat-card kind (its three rarities: one
## card) or a mod. A run's candidate pool is what its build can ever be offered: every ability but the other
## build's start weapon, every stat card with a weight, every mod whose weapon the build has. The three abilities
## step AB adds next (PLAN v0.4.0: Arc Field, Frost Nova, Flame Trail) count as planned until their data exists.

const BUILDS: Array[StringName] = [&"blade", &"gun"]
const PLANNED_ABILITIES: Array[StringName] = [&"arc_field", &"flame_trail", &"frost_nova"]
const POOL_MIN := 40
const POOL_MAX := 50
## The reachable states the survey rolls from: no card yet, then the four slots filled three ways (so every
## ability's mod and both utilities' items can come up).
const STATES: Array = [
	[],
	[AbilityTable.Kind.BOMB_LOBBER, AbilityTable.Kind.DRONE_BUDDY, AbilityTable.Kind.ORBIT_BLADES],
	[AbilityTable.Kind.BLINK, AbilityTable.Kind.BOMB_LOBBER, AbilityTable.Kind.ORBIT_BLADES],
	[AbilityTable.Kind.AEGIS, AbilityTable.Kind.DRONE_BUDDY, AbilityTable.Kind.BOMB_LOBBER],
]


## A run's world for `build` (as main.gd builds one: items, abilities, stat cards, rewards, heat) after taking
## the abilities `kinds`.
static func world(
	repo: ContentRepository, seed_value: int, build: StringName, kinds: Array
) -> World:
	var t := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, repo.get_def(&"build", build))
	var w := World.new(seed_value, t)
	w.set_item_tables(ContentCompiler.compile_items(repo))
	w.reward_table = ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor"))
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	for kind: int in kinds:
		Abilities.grant(w, Abilities.index_of_kind(w, kind))
	return w


## A card code's pool key: "ability:<id>", "stat:<id>" or "mod:<id>".
static func key(w: World, code: int) -> String:
	match Offers.type_of(code):
		Offers.ABILITY:
			return "ability:%s" % w.ability_tables[Offers.ability_of(code)].id
		Offers.STAT:
			return "stat:%s" % w.stat_tables[Offers.stat_of(code)].id
	return "mod:%s" % w.item_tables[code].id


## The build's candidate pool, sorted: [keys of cards in the data, keys of planned abilities not yet in it].
static func pool(repo: ContentRepository, build: StringName) -> Array[PackedStringArray]:
	var w := world(repo, 1, build, [])
	var have := PackedStringArray()
	for t in w.ability_tables:
		if t.start_weapon == 0 or (t.start_weapon & w.player.weapons) != 0:
			have.append("ability:%s" % t.id)
	for t in w.stat_tables:
		if t != null and t.weight > 0:
			have.append("stat:%s" % t.id)
	for t in w.item_tables:
		if t.requires_weapon == 0 or (t.requires_weapon & w.player.weapons) != 0:
			have.append("mod:%s" % t.id)
	have.sort()
	var planned := PackedStringArray()
	for id in PLANNED_ABILITIES:
		if not have.has("ability:%s" % id):
			planned.append("ability:%s" % id)
	return [have, planned]


## Rolls an altar and a chest offer in every STATE of `build` for `seeds` seeds (each roll on a fresh world).
## Returns {key: [altar count, chest count]} and, under "_rolls", [altar rolls, chest rolls].
static func survey(repo: ContentRepository, build: StringName, seeds: int) -> Dictionary:
	var out := {}
	var rolls := [0, 0]
	for s in seeds:
		for state: Array in STATES:
			for src in 2:
				var w := world(repo, 7000 + s, build, state)
				var kind := RewardStore.Kind.ALTAR if src == 0 else RewardStore.Kind.CHEST
				var id := w.add_reward(kind, Vector2(100, 100), 0)
				rolls[src] += 1
				for c in Offers.roll(w, w.rewards.index_of(id)):
					var k := key(w, c)
					if not out.has(k):
						out[k] = [0, 0]
					out[k][src] += 1
	out["_rolls"] = rolls
	return out


## The frequency table as text lines: key, altar, chest, total, and the share of all cards offered.
static func table(
	build: StringName, counts: Dictionary, keys: PackedStringArray
) -> PackedStringArray:
	var lines := PackedStringArray()
	var total := 0
	for k in keys:
		var c: Array = counts.get(k, [0, 0])
		total += c[0] + c[1]
	var rolls: Array = counts["_rolls"]
	lines.append(
		"%s: %d altar rolls, %d chest rolls, %d cards" % [build, rolls[0], rolls[1], total]
	)
	lines.append("%-28s %7s %7s %7s %7s" % ["card", "altar", "chest", "total", "share"])
	for k in keys:
		var c: Array = counts.get(k, [0, 0])
		var n: int = c[0] + c[1]
		var share := 100.0 * n / maxi(1, total)
		lines.append("%-28s %7d %7d %7d %6.2f%%" % [k, c[0], c[1], n, share])
	return lines
