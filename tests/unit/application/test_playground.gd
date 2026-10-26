# gdlint: disable=max-public-methods
extends GutTest
## v0.7.5 PG (owner N20, docs/tools/PLAYGROUND.md): the Playground's one room, its World and its commands.


func _repo() -> ContentRepository:
	return AttackScenario.repo()


func _world(biome: StringName = &"ruins", build: StringName = &"gun") -> World:
	var repo := _repo()
	return PlaygroundScenario.build(repo, build, repo.get_def(&"biomes", biome))


## The first usable wand card (one that levels) in item order.
func _wand_card(w: World) -> int:
	for k in w.item_tables.size():
		if (
			CardLevels.is_card(w, k)
			and ItemPool.usable(w, k)
			and BuildSlots.is_slot_item(w.item_tables[k])
		):
			return k
	return -1


func _ability(w: World, kind: int) -> int:
	for k in w.ability_tables.size():
		if w.ability_tables[k].kind == kind:
			return k
	return -1


# --- The room -----------------------------------------------------------------------------------------------------


func test_one_room_is_a_single_walled_room_of_four_by_four_cells() -> void:
	var f := FloorGenerator.one_room(7, Vector2i(4, 4))
	assert_eq(f.room_count(), 1)
	assert_eq(f.room_cells[0].size, Vector2i(4, 4))
	assert_eq(f.door_centers.size(), 0, "no doorway")
	assert_eq(f.item_spots.size(), 0)
	assert_eq(f.spawn_points[0].size(), 0)
	assert_true(f.rooms[0].has_point(f.start_pos))
	assert_gt(f.rooms[0].size.x, 40.0, "four cells wide")
	assert_gt(f.walls.size(), 3)


func test_one_room_is_the_same_for_a_seed() -> void:
	var a := FloorGenerator.one_room(7, Vector2i(4, 4))
	var b := FloorGenerator.one_room(7, Vector2i(4, 4))
	assert_eq(a.rooms[0], b.rooms[0])
	assert_eq(a.walls.size(), b.walls.size())


func test_the_room_spawns_nothing_and_keeps_the_player_inside() -> void:
	var w := _world()
	var room := w.floor_layout.rooms[0]
	var f := InputFrame.make(Vector2(1, 0), 0, 0, 0, 0)
	for t in 1200:  # 20 s walking into the +X wall
		w.step(f)
	assert_eq(w.actors.size(), 1, "no enemy spawns on its own")
	assert_true(room.has_point(w.player_pos()), "the walls hold")
	assert_false(w.player_dead())


func test_the_wand_has_every_slot() -> void:
	var w := _world()
	assert_eq(Wand.slots(w), Wand.MAX_SLOTS)


func test_a_biome_with_a_surface_lays_it_in_the_room() -> void:
	assert_null(_world(&"ruins").ice, "Ruins has no surface")
	var w := _world(&"frozen_shore")
	assert_not_null(w.ice)
	assert_gt(w.ice.rects.size(), 2, "ice patches in the one room")
	assert_gt(_world(&"starfall").ice.rects.size(), 2, "starglow pools")


# --- Dummies, enemies, bosses ------------------------------------------------------------------------------------


func test_an_endless_dummy_gets_its_hp_back_before_the_next_tick() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	var at := w.player_pos() + Vector2(5, 0)
	assert_true(pg.place_dummy_now(at))
	var i := w.actors.size() - 1
	assert_eq(w.actors.kinds[i], ActorStore.Kind.DUMMY)
	Damage.hit(w, i, 5000, 0, 0, w.take_root(), 0, at, at)
	assert_lt(w.actors.hp[i], w.actors.max_hp[i])
	pg.apply_pending()
	assert_eq(w.actors.hp[i], w.actors.max_hp[i])
	for t in 60:
		w.step(InputFrame.new())
	assert_eq(w.actors.pos(i), at, "it stands still")


func test_a_dummy_with_a_set_hp_dies() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	var at := w.player_pos() + Vector2(5, 0)
	assert_true(pg.place_dummy_now(at, 300))
	var i := w.actors.size() - 1
	assert_eq(w.actors.max_hp[i], 300)
	Damage.hit(w, i, 1000, 0, 0, w.take_root(), 0, at, at)
	pg.apply_pending()
	w.step(InputFrame.new())
	assert_eq(w.actors.size(), 1, "gone")


func test_nothing_is_placed_in_a_wall_or_outside_the_room() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	var room := w.floor_layout.rooms[0]
	assert_false(pg.place_dummy_now(Vector2(room.end.x + 0.1, room.get_center().y)))
	assert_false(pg.place_dummy_now(room.end + Vector2(20, 20)))
	assert_eq(w.actors.size(), 1)


func test_queued_commands_land_at_apply_pending() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	pg.place_dummy(w.player_pos() + Vector2(4, 0))
	assert_true(pg.has_pending())
	assert_eq(w.actors.size(), 1)
	assert_true(pg.apply_pending())
	assert_eq(w.actors.size(), 2)
	assert_false(pg.apply_pending(), "nothing left to run")


func test_any_enemy_and_any_boss_spawn_at_a_point() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	var at := w.player_pos() + Vector2(8, 0)
	assert_true(pg.place_enemy_now(ActorStore.Kind.CHARGER, at))
	assert_eq(w.actors.pos(w.actors.size() - 1), at)
	for b in w.boss_tables.size():
		# Two columns (v0.8.0 FB1: the final boss's bodies are on the list too).
		var spot := w.player_pos() + Vector2(-10 + (b % 2) * 5, -12 + (b / 2) * 5)
		assert_true(pg.place_boss_now(b, spot), "boss %d" % b)
	# v0.9.0 NB2: the Twin Wardens are one boss in two bodies (BossTwin), so their table places two.
	var bodies := w.boss_tables.size()
	for t in w.boss_tables:
		if t.id == &"twin_wardens":
			bodies += 1
	assert_eq(w.bosses.size(), bodies, "every boss, side by side")
	assert_eq(w.actors.size(), 2 + bodies, "a boss doesn't clear the room")


func test_delete_removes_what_is_under_the_point_never_the_player() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	var at := w.player_pos() + Vector2(5, 0)
	pg.place_dummy_now(at)
	assert_false(pg.remove_at_now(w.player_pos()), "the player stays")
	assert_true(pg.remove_at_now(at + Vector2(0.3, 0)))
	assert_eq(w.actors.size(), 1)
	assert_false(pg.remove_at_now(at), "nothing left there")


func test_deleting_a_boss_takes_it_out_of_the_boss_store() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	var at := w.player_pos() + Vector2(10, 0)
	pg.place_boss_now(0, at)
	assert_true(w.boss_alive())
	assert_true(pg.remove_at_now(at))
	assert_false(w.boss_alive())
	assert_eq(w.bosses.size(), 0)
	for t in 30:
		w.step(InputFrame.new())
	assert_eq(w.actors.size(), 1)


func test_clear_keeps_the_dummies_unless_asked() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	pg.place_dummy_now(w.player_pos() + Vector2(5, 0))
	pg.place_enemy_now(ActorStore.Kind.WARDEN, w.player_pos() + Vector2(-8, 0))
	assert_eq(pg.clear_now(false), 1)
	assert_eq(w.actors.kinds[1], ActorStore.Kind.DUMMY)
	assert_eq(pg.clear_now(true), 1)
	assert_eq(w.actors.size(), 1)


# --- Cards -------------------------------------------------------------------------------------------------------


func test_a_wand_card_goes_in_at_its_level_and_comes_out() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	var k := _wand_card(w)
	assert_gt(k, -1)
	assert_true(pg.grant_now(k, 3))
	assert_true(w.mod_slots.has(k))
	assert_eq(CardLevels.level(w, k), mini(3, CardLevels.max_level(w, k)))
	assert_true(pg.grant_now(k, 5))
	assert_eq(CardLevels.level(w, k), CardLevels.max_level(w, k), "v0.9.5 CLV: held at its cap")
	assert_true(pg.remove_card_now(k))
	assert_false(w.items_owned.has(k))
	assert_false(w.mod_slots.has(k))


func test_a_full_wand_takes_no_new_card() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	for k in w.item_tables.size():
		if (
			BuildSlots.is_slot_item(w.item_tables[k])
			and ItemPool.usable(w, k)
			and not w.items_owned.has(k)
			# v0.9.0 AS/AS2: a card of a full category replaces or asks; it never fills a new slot.
			and AttackSlots.full_category(w, k) == AttackSlots.FREE
		):
			if BuildSlots.full(w):
				assert_false(pg.grant_now(k), "no Swap in the Playground")
				assert_false(BuildSlots.swapping(w))
				assert_eq(w.mod_slots.size(), Wand.MAX_SLOTS)
				return
			assert_true(pg.grant_now(k))
	fail_test("not enough cards to fill the wand")


func test_an_ability_goes_in_at_a_level_and_down_again() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	var a := _ability(w, AbilityTable.Kind.ORBIT_BLADES)
	assert_gt(a, -1)
	var code := Offers.ability_code(a)
	assert_true(pg.grant_now(code, 4))
	assert_eq(Abilities.level_of(w, a), 4)
	assert_true(pg.grant_now(code, 2))
	assert_eq(Abilities.level_of(w, a), 2)
	assert_true(pg.remove_card_now(code))
	assert_false(Abilities.owned(w, a))


func test_the_weapon_stays() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	var weapon := w.ability_owned[0]
	assert_false(pg.remove_card_now(Offers.ability_code(weapon)))
	assert_true(Abilities.owned(w, weapon))


func test_a_stat_card_goes_in_and_out() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	var code := Offers.stat_code(0, 2)
	assert_true(pg.grant_now(code))
	assert_true(w.stat_cards.has(code))
	assert_true(pg.remove_card_now(code))
	assert_false(w.stat_cards.has(code))


func test_god_mode_keeps_the_player_unhurt() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	pg.god = true
	pg.apply_pending()
	var hp := w.actors.hp[0]
	var at := w.player_pos()
	Damage.hit(w, 0, 50, 0, 0, w.take_root(), 0, at, at)
	assert_eq(w.actors.hp[0], hp)


func test_the_catalog_lists_every_group_and_marks_what_is_held() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	var groups := {}
	for e: Dictionary in pg.catalog():
		groups[e["group"]] = true
		assert_ne(String(e["name_key"]), "", "a name for every row")
	for g in [
		PlaygroundApi.GROUP_WAND,
		PlaygroundApi.GROUP_ABILITY,
		PlaygroundApi.GROUP_PASSIVE,
		PlaygroundApi.GROUP_STAT
	]:
		assert_true(groups.has(g), String(g))
	var k := _wand_card(w)
	pg.grant_now(k, 4)
	var row: Dictionary = {}
	for e: Dictionary in pg.catalog():
		if e["code"] == k:
			row = e
	assert_true(row["held"])
	assert_eq(row["level"], mini(4, CardLevels.max_level(w, k)))
	var mine := pg.held()
	assert_eq(mine.size(), 1)
	assert_eq(mine[0]["code"], k)
	assert_true(mine[0]["levels"])


func test_the_starting_weapon_is_not_in_the_catalog() -> void:
	var w := _world()
	for e: Dictionary in PlaygroundApi.new(w).catalog():
		if Offers.type_of(e["code"]) == Offers.ABILITY:
			assert_eq(w.ability_tables[Offers.ability_of(e["code"])].start_weapon, 0)


func test_the_player_comes_back_after_a_death() -> void:
	var w := _world()
	var pg := PlaygroundApi.new(w)
	var at := w.player_pos()
	Damage.hit(w, 0, w.actors.max_hp[0] * 10, 0, 0, w.take_root(), 0, at, at)
	w.step(InputFrame.new())
	assert_true(w.player_dead())
	pg.apply_pending()
	assert_false(w.player_dead(), "back before the next tick")
	assert_eq(w.actors.hp[0], w.actors.max_hp[0])
	w.step(InputFrame.new())
	assert_false(w.player_dead())
