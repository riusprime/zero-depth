# gdlint: disable=max-public-methods
class_name PlaygroundApi
extends RefCounted
## v0.7.5 PG (owner N20, docs/tools/PLAYGROUND.md): the Playground's commands. The panel queues them and SimDriver
## applies them between ticks (apply_pending), also while the panel holds the sim paused, so a placed dummy shows at
## once. They touch only the Playground's World, never a run's.
## - Dummies are the sim's DUMMY actor (the enemy team: hits, procs, statuses and on-kill triggers land on it), still
##   and silent. An endless one ("∞") gets its HP back here before every tick; one with a set HP dies.
## - Enemies and bosses are spawned as the entities they are (their AI, attacks and phases), at a point.
## - Cards go in through the sim's own take (BuildSlots / Offers), at a chosen level.
## - v0.8.0 FB1: the final boss (FinalBoss): summoned at the room's centre as the whole fight (its bodies shatter into
##   the next), and a phase jump that hands the fight to a body (summoning it first when no fight runs). Clearing the
##   room's bosses ends the fight.

## An endless dummy's pool: no tick of any build empties it, and it is refilled before the next.
const ENDLESS_HP := 100_000_000
const DUMMY_RADIUS_M := 0.5
## How far past a body's edge a delete click still picks it, in metres.
const PICK_SLACK_M := 0.6
## After a death the player is back at once, unhurtable for a second.
const REVIVE_INVULN_TICKS := 60
## The panel's card groups, in its order.
const GROUP_WAND := &"wand"
const GROUP_ABILITY_MOD := &"ability_mod"
const GROUP_PASSIVE := &"passive"
const GROUP_ABILITY := &"ability"
const GROUP_STAT := &"stat"
const GROUPS: Array[StringName] = [
	GROUP_WAND, GROUP_ABILITY, GROUP_ABILITY_MOD, GROUP_PASSIVE, GROUP_STAT
]
## Stat cards are offered as common, rare and epic (their amounts).
const STAT_RARITIES := 3

var world: World
## The player can't be hurt (as DebugApi.god).
var god := false
## Ids of the endless dummies.
var endless := {}
## v0.8.0 FB1: the final boss's bodies (indices into World.boss_tables, in phase order: found by their kinds), the
## shatter's length and the fight's name (Main sets the last two from the run's content).
var final_tables := PackedInt32Array()
var final_shatter_ticks := 90
var final_name_key := &"BOSS_HOLLOW_CROWN"
var _queue: Array[Callable] = []


func _init(p_world: World) -> void:
	world = p_world
	for kind in [ActorStore.Kind.COLOSSUS, ActorStore.Kind.PRISM, ActorStore.Kind.NEMESIS]:
		for k in world.boss_tables.size():
			if world.boss_tables[k].kind == kind:
				final_tables.append(k)
				break


func has_pending() -> bool:
	return not _queue.is_empty()


## Runs the queued commands, then refills the endless dummies and keeps god mode. Returns whether a command ran.
func apply_pending() -> bool:
	var ran := not _queue.is_empty()
	var q := _queue
	_queue = []
	for c in q:
		c.call()
	_upkeep()
	return ran


# --- Queued commands (the panel's) -------------------------------------------------------------------------------


## A dummy at `at`; `hp` <= 0 makes it endless.
func place_dummy(at: Vector2, hp: int = 0) -> void:
	_queue.append(func() -> void: place_dummy_now(at, hp))


func place_enemy(kind: int, at: Vector2) -> void:
	_queue.append(func() -> void: place_enemy_now(kind, at))


## Boss `table_index` (an index into World.boss_tables) at `at`.
func place_boss(table_index: int, at: Vector2) -> void:
	_queue.append(func() -> void: place_boss_now(table_index, at))


## Removes what stands under `at` (the nearest body whose edge is within PICK_SLACK_M), never the player.
func remove_at(at: Vector2) -> void:
	_queue.append(func() -> void: remove_at_now(at))


## Removes every enemy and boss; with `dummies` the dummies too.
func clear(dummies: bool) -> void:
	_queue.append(func() -> void: clear_now(dummies))


## Card `code` (Offers' codes) at `level` (wand cards and abilities 1..5; others ignore it).
func grant(code: int, level: int = 1) -> void:
	_queue.append(func() -> void: grant_now(code, level))


func remove_card(code: int) -> void:
	_queue.append(func() -> void: remove_card_now(code))


## v0.8.0 FB1: the final boss's fight from body `phase` (0 = the first), at the room's centre.
func summon_final(phase: int = 0) -> void:
	_queue.append(func() -> void: summon_final_now(phase))


## v0.8.0 FB1: the fight goes to body `phase` now (a fight is summoned first when none runs).
func final_phase(phase: int) -> void:
	_queue.append(func() -> void: final_phase_now(phase))


func heal() -> void:
	_queue.append(func() -> void: world.actors.hp[0] = world.actors.max_hp[0])


# --- Applied now (between ticks; the tests call these directly) ------------------------------------------------


## False (nothing placed) when a body of the dummy's size at `at` would overlap a wall.
func place_dummy_now(at: Vector2, hp: int = 0) -> bool:
	if not clear_spot(at, DUMMY_RADIUS_M):
		return false
	var id := world.add_dummy(at, DUMMY_RADIUS_M, hp if hp > 0 else ENDLESS_HP)
	if hp <= 0:
		endless[id] = true
	return true


func place_enemy_now(kind: int, at: Vector2) -> bool:
	var t := world.enemy_table(kind)
	if t == null or BossAi.is_boss_kind(kind) or not clear_spot(at, t.radius_m):
		return false
	world.add_enemy(kind, at)
	return true


func place_boss_now(table_index: int, at: Vector2) -> bool:
	if table_index < 0 or table_index >= world.boss_tables.size():
		return false
	if not clear_spot(at, world.boss_tables[table_index].radius_m):
		return false
	world.spawn_boss(table_index, at)
	return true


## v0.8.0 FB1: clears the room's enemies and bosses, then the final boss's body `phase` rises at the room's centre.
## False without the final boss's tables.
func summon_final_now(phase: int = 0) -> bool:
	if final_tables.is_empty():
		return false
	clear_now(false)
	var at := (
		world.floor_layout.rooms[0].get_center() if world.floor_layout != null else Vector2.ZERO
	)
	FinalBoss.begin(world, final_tables, final_shatter_ticks, at, phase)
	world.final_fight.name_key = final_name_key
	return true


func final_phase_now(phase: int) -> bool:
	if world.final_fight == null or world.final_fight.won:
		return summon_final_now(phase)
	FinalBoss.jump(world, phase)
	return true


## The actor index under `at` (not the player), or -1.
func actor_at(at: Vector2) -> int:
	var a := world.actors
	var best := -1
	var best_d := INF
	for i in range(1, a.size()):
		if a.dead[i] == 1:
			continue
		var d := (a.pos(i) - at).length() - a.radius[i]
		if d <= PICK_SLACK_M and d < best_d:
			best = i
			best_d = d
	return best


func remove_at_now(at: Vector2) -> bool:
	var i := actor_at(at)
	if i < 0:
		return false
	_remove(PackedInt32Array([i]))
	return true


func clear_now(dummies: bool) -> int:
	var gone := PackedInt32Array()
	for i in range(1, world.actors.size()):
		if dummies or world.actors.kinds[i] != ActorStore.Kind.DUMMY:
			gone.append(i)
	_remove(gone)
	return gone.size()


## Takes `code` as a found card would, then sets its level. False when it can't go in: the wand is full (the
## Playground opens no Swap: remove a card first), the build already has a utility, or the code is unknown.
func grant_now(code: int, level: int = 1) -> bool:
	level = clampi(level, 1, CardLevels.MAX_LEVEL)
	match Offers.type_of(code):
		Offers.MOD:
			return _grant_item(code, level)
		Offers.ABILITY:
			return _grant_ability(Offers.ability_of(code), level)
		Offers.STAT:
			Offers.apply(world, code)
			return true
	return false


## Takes `code` out of the build (a stat card: its last copy). The build's weapon stays.
func remove_card_now(code: int) -> bool:
	match Offers.type_of(code):
		Offers.MOD:
			return _remove_item(code)
		Offers.ABILITY:
			return _remove_ability(Offers.ability_of(code))
		Offers.STAT:
			if not world.stat_cards.has(code):
				return false
			Shop.remove_stat_card(world, code)
			return true
	return false


func _grant_item(idx: int, level: int) -> bool:
	if idx < 0 or idx >= world.item_tables.size():
		return false
	if not world.items_owned.has(idx):
		if BuildSlots.needs_swap(world, idx):
			return false
		Offers.apply(world, idx)
	if CardLevels.is_card(world, idx):
		CardLevels.set_level(world, idx, level)
	return world.items_owned.has(idx)


func _grant_ability(idx: int, level: int) -> bool:
	if idx < 0 or idx >= world.ability_tables.size():
		return false
	if Abilities.level_of(world, idx) > level:
		_remove_ability(idx)  # down a level: it goes in again from level 1
	if not Abilities.owned(world, idx) and not Abilities.grant(world, idx):
		return false
	while Abilities.level_of(world, idx) < level and Abilities.grant(world, idx):
		pass
	return true


func _remove_item(idx: int) -> bool:
	if not world.items_owned.has(idx):
		return false
	var s := world.mod_slots.find(idx)
	if s >= 0:
		BuildSlots.drop(world, s)
	else:
		Shop.remove_item(world, idx)
		CardLevels.reset(world, idx)
	return true


func _remove_ability(idx: int) -> bool:
	var slot := world.ability_owned.find(idx)
	if slot < 0 or world.ability_tables[idx].start_weapon != 0:
		return false
	var s := world.mod_slots.find(Offers.ability_code(idx))
	if s >= 0:
		BuildSlots.drop(world, s)
	else:
		Abilities.remove_slot(world, slot)
		BuildSlots.sync(world)
		world.refresh_build(true)
	return true


## No wall overlaps a body of radius `r` at `at`, and `at` is on the floor.
func clear_spot(at: Vector2, r: float) -> bool:
	var layout := world.floor_layout
	if layout != null and not layout.rooms[0].grow(-r).has_point(at):
		return false
	for wall in world.walls:
		if Collide.circle_vs_obb(at, r, wall) != Vector2.ZERO:
			return false
	return true


# --- Reads (the panel's lists) ---------------------------------------------------------------------------------


## Every card the build can take now, as {code, group, name_key, rarity, levels (it has levels 1-5), held, level}:
## wand cards, abilities (not the starting weapons), ability mods (only while you own their ability), passives (items
## outside the wand) and stat cards (common, rare, epic). Retired cards and the other weapon's cards are left out.
func catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in world.item_tables.size():
		if not ItemPool.usable(world, k):
			continue
		var it := world.item_tables[k]
		var group := GROUP_PASSIVE
		if CardLevels.is_card(world, k):
			group = GROUP_WAND
		elif it.requires_ability >= 0:
			group = GROUP_ABILITY_MOD
		_add_entry(out, k, group, CardLevels.is_card(world, k))
	for a in world.ability_tables.size():
		if world.ability_tables[a].start_weapon == 0:
			_add_entry(out, Offers.ability_code(a), GROUP_ABILITY, true)
	for s in world.stat_tables.size():
		for r in STAT_RARITIES:
			_add_entry(out, Offers.stat_code(s, r), GROUP_STAT, false)
	return out


## The cards held now, in the order the panel lists them: the wand left to right, then the other abilities, the
## passives and the stat cards (one row per copy). Same fields as catalog().
func held() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for code in world.mod_slots:
		var levels := Offers.type_of(code) == Offers.ABILITY or CardLevels.is_card(world, code)
		_add_entry(out, code, GROUP_WAND, levels)
	for a in world.ability_owned:
		var code := Offers.ability_code(a)
		if not world.mod_slots.has(code) and world.ability_tables[a].start_weapon == 0:
			_add_entry(out, code, GROUP_ABILITY, true)
	for k in world.items_owned:
		if not world.mod_slots.has(k):
			_add_entry(out, k, GROUP_PASSIVE, false)
	for code in world.stat_cards:
		_add_entry(out, code, GROUP_STAT, false)
	return out


## The enemy kinds that can be placed, as {kind, name_key}, in kind order.
func enemy_choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in range(ActorStore.Kind.CHARGER, ActorStore.Kind.size()):
		var t := world.enemy_table(k)
		if t != null and not BossAi.is_boss_kind(k):
			out.append({"kind": k, "name_key": t.name_key})
	return out


## The bosses that can be placed, as {index (into World.boss_tables), name_key}.
func boss_choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in world.boss_tables.size():
		out.append({"index": b, "name_key": world.boss_tables[b].name_key})
	return out


func _add_entry(out: Array[Dictionary], code: int, group: StringName, levels: bool) -> void:
	var info := Offers.info(world, code)
	var level := 0
	match Offers.type_of(code):
		Offers.MOD:
			level = CardLevels.level(world, code) if world.items_owned.has(code) else 0
		Offers.ABILITY:
			level = Abilities.level_of(world, Offers.ability_of(code))
	var entry := {
		"code": code,
		"group": group,
		"name_key": info["name_key"],
		"rarity": info["rarity"],
		"levels": levels,
		"held": BuildSlots.held(world, code) or world.stat_cards.has(code),
		"level": level,
	}
	out.append(entry)


# --- Inside -----------------------------------------------------------------------------------------------------


## Removes actors `gone` (indices, any order) with no kill, shards or reward: one ENEMY_DISSOLVED each (as a
## summoned boss dissolves a run's floor, BossChallenge.dissolve_floor); a boss leaves the boss store too.
func _remove(gone: PackedInt32Array) -> void:
	var a := world.actors
	gone.sort()
	for i in gone:
		var id := a.ids[i]
		var e := world.emit_event(SimEvent.Kind.ENEMY_DISSOLVED, id, id, id, a.pos(i))
		e.amount = a.kinds[i]
		var b := world.bosses.index_of(id)
		if b >= 0:
			world.bosses.remove(b)
			if world.boss_id == id:
				world.boss_id = -1
		if world.final_fight != null and world.final_fight.body_id == id:
			world.final_fight = null  # v0.8.0 FB1: the fight ends with its body
		endless.erase(id)
	a.remove_sorted(gone)
	if world.boss_id < 0 and world.bosses.size() > 0:
		world.boss_id = world.bosses.ids[world.bosses.size() - 1]


## The player never stays dead in the Playground: back at full HP before the next tick, where it fell.
func _upkeep() -> void:
	var a := world.actors
	if a.dead[0] == 1:
		a.dead[0] = 0
		a.hp[0] = a.max_hp[0]
		a.invuln[0] = maxi(a.invuln[0], REVIVE_INVULN_TICKS)
	for i in range(1, a.size()):
		if endless.has(a.ids[i]) and a.dead[i] == 0:
			a.hp[i] = a.max_hp[i]
	if god and a.invuln[0] < 2:
		a.invuln[0] = 2
