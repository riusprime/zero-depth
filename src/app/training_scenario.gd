class_name TrainingScenario
extends RefCounted
## v0.10.5 O17 (owner P17): the Training Room's World: the Playground's (PlaygroundScenario: the chosen weapon, every
## card table, enemies and bosses at floor 1's numbers, the wand's most slots, nothing that runs a floor) in a smaller
## room (TrainingRoom.ROOM_CELLS) with no ice, the hero's HP floored at 1 (World.player_hp_floor: the hero can't die
## there), the hero at the top corner it came in by, and the terminal standing solid by the wall (Solids). No run,
## save, Codex, achievement or record ever sees this World.

const HP_FLOOR := 1


static func build(repo: ContentRepository, build_id: StringName, biome: BiomeDefinition) -> World:
	var w := PlaygroundScenario.build(repo, build_id, biome, TrainingRoom.ROOM_CELLS, false)
	w.player_hp_floor = HP_FLOOR
	var room := room_of(w)
	w.actors.set_pos(0, TrainingRoom.start_point(room))
	w.solids.on = true
	w.solids.add_square(
		Solids.Kind.TERMINAL, 0, TrainingRoom.terminal_point(room), TrainingRoom.TERMINAL_HALF_M
	)
	return w


## The room's rect on the sim plane.
static func room_of(w: World) -> Rect2:
	return w.floor_layout.rooms[0]
