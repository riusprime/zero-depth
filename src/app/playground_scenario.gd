class_name PlaygroundScenario
extends RefCounted
## v0.7.5 PG (owner N20, docs/tools/PLAYGROUND.md): the Playground's World. One walled 4 x 4-cell room
## (FloorGenerator.one_room: the extra-large footprint, the start hall's open floor), the chosen build's player and
## weapon, every table a run's floor has (enemies and bosses at floor 1's numbers, every card, the heat), and nothing
## that runs a floor: no spawning, gate, portal, rewards, shop, events or catch-up. The wand has its most slots.

const CELLS := Vector2i(4, 4)
const SEED := 4404
## A run floor past the wand's last step, so the wand has every slot (Wand.slots by World.run_floor_index).
const WAND_FLOOR := 99
## Ice or starglow patches in the room (always: this is where the owner tries the surface).
const SURFACE_PATCHES := Vector2i(5, 7)


static func build(repo: ContentRepository, build_id: StringName, biome: BiomeDefinition) -> World:
	var table := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(table, repo.get_def(&"build", build_id))
	var map := RunContentCompiler.compile_map(repo.get_def(&"map", &"floor"))
	var layout := FloorGenerator.one_room(SEED, CELLS, map)
	var w := World.new(SEED, table, layout.start_pos)
	w.set_walls(layout.walls)
	w.floor_layout = layout
	w.set_enemy_tables(ContentCompiler.compile_enemies(repo))
	w.set_item_tables(ContentCompiler.compile_items(repo))
	w.set_combo_tables(ContentCompiler.compile_combos(repo))
	# v0.8.0 FB1: and the final boss's bodies after them (PlaygroundApi.summon_final).
	var bosses := ContentCompiler.compile_bosses(repo)
	bosses.append_array(ContentCompiler.compile_final_bosses(repo, final_run(repo)))
	w.set_boss_tables(bosses)
	w.floor_index = 1
	w.run_floor = WAND_FLOOR
	w.wand_table = WandCompiler.from_repo(repo)
	w.blade_table = BladeCompiler.from_repo(repo)
	w.slot_table = WandCompiler.slots(repo, w.item_tables)  # v0.9.0 AS
	w.pair_table = WandCompiler.pairs(repo)  # v0.9.5 EE3
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	w.dummy_speed = 0.0  # the dummies stand still and never shoot (dummy_fire_period stays 0)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	w.tuning = RunContentCompiler.compile_sim_tuning(repo.get_def(&"tuning", &"sim"))
	lay_surface(w, biome)
	return w


## v0.8.0 FB1: the run's table (its final boss: the bodies, the shatter, the name).
static func final_run(repo: ContentRepository) -> RunTable:
	return ContentCompiler.compile_run(repo.get_def(&"run", Main.RUN_ID))


## The biome's surface in the room. IcePatches keeps patches out of a floor's start hall and lays them in only part
## of the rooms; the Playground's one room is its start hall, so it is laid as an ordinary room that always draws,
## with more patches for its size.
static func lay_surface(w: World, biome: BiomeDefinition) -> void:
	w.ice = null
	var field := BiomeCompiler.compile_surface(biome)
	if field == null:
		return
	field.room_share_permille = 1000
	field.patches_min = SURFACE_PATCHES.x
	field.patches_max = SURFACE_PATCHES.y
	var layout := w.floor_layout
	layout.start_room = -1
	layout.portal_room = -1
	IcePatches.place(w, field)
	layout.start_room = 0
	layout.portal_room = 0


## The biomes the Playground offers: the run's, in its order, with their names. (v0.9.0 HB: moved here from Main.)
static func biomes(repo: ContentRepository) -> Array:
	var out := []
	var run_def: RunDefinition = repo.get_def(&"run", Main.RUN_ID)
	for id: StringName in run_def.biomes:
		out.append(
			{"id": id, "name_key": (repo.get_def(&"biomes", id) as BiomeDefinition).name_key}
		)
	return out


## The DPS meter's source names: an effect id -> the name key of the card, ability, combo or curse with that id, and
## the statuses' own names. (v0.9.0 HB: moved here from Main.)
static func source_names(repo: ContentRepository) -> Dictionary:
	var out := {
		&"bleed": &"UI_PG_SRC_BLEED",
		&"bleed_burst": &"UI_PG_SRC_BLEED",
		&"shock": &"UI_PG_SRC_SHOCK",
		&"frost": &"UI_PG_SRC_FROST",
		&"venom": &"UI_PG_SRC_POISON",
	}
	for cat: StringName in [&"items", &"ability", &"combos", &"curses"]:
		for d: Resource in repo.all_of(cat):
			if &"id" in d and &"name_key" in d and not out.has(d.get(&"id")):
				out[d.get(&"id")] = d.get(&"name_key")
	return out
