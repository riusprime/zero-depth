class_name TrainingRoom
extends RefCounted
## v0.10.5 O17 (owner P17, theory audit: Sylvester's accessibility and depth, Koster's safe place to learn patterns:
## "let's add a new room at the hub that serves this purpose, at the bottom that is empty, make it a bit smaller"):
## the Training Room's rules, apart from its nodes. The room is the Playground's World (PlaygroundScenario) in a
## smaller room (ROOM_CELLS), entered from the hub's south door; its top corner (the screen's top: the camera looks
## toward sim (-1, +1)) is the way back to the hub. Where things stand is read off the room's rect: the exit pad and the
## hero's start along the diagonal in from that corner, the terminal by the corner's right-hand wall, the endless dummy
## in the middle, spawned enemies on a ring round it on the far side from the door.
## What the terminal offers is what the player has met: enemy kinds the Codex knows, wand cards the Codex has seen.
## Nothing here writes the profile: no Codex, achievement, record, unlock or fragment (the Training Room never runs
## the run's recorders; test_training_room checks the profile is untouched).

## The room: 2 x 2 cells (about 25 x 21 m), a bit smaller than the hub's 32 m plaza.
const ROOM_CELLS := Vector2i(2, 2)
## The terminal's spawn counts, in its order.
const COUNTS: Array[int] = [1, 3, 8]
## Along the diagonal in from the top corner (m): the exit pad's middle, its reach, and the hero's start.
const EXIT_IN_M := 1.7
const EXIT_REACH_M := 1.0
const START_IN_M := 4.8
## The terminal: along the corner's right-hand wall (+x on the sim plane) and in from it (m); its half size (a solid
## square) and how near its edge the hero uses it.
const TERMINAL_ALONG_M := 5.0
const TERMINAL_IN_M := 1.5
const TERMINAL_HALF_M := 0.45
const TERMINAL_REACH_M := 1.3
## Spawned enemies stand on this ring round the dummy (m), spread over this arc (radians) on the far side.
const RING_M := 4.5
const SPREAD := 2.4


## The room's top corner on the sim plane (the screen's top).
static func corner(room: Rect2) -> Vector2:
	return Vector2(room.position.x, room.end.y)


## The way in from the top corner (the diagonal toward the room's middle on a square room).
static func inward() -> Vector2:
	return Vector2(1.0, -1.0).normalized()


static func exit_point(room: Rect2) -> Vector2:
	return corner(room) + inward() * EXIT_IN_M


static func start_point(room: Rect2) -> Vector2:
	return corner(room) + inward() * START_IN_M


static func terminal_point(room: Rect2) -> Vector2:
	return corner(room) + Vector2(TERMINAL_ALONG_M, -TERMINAL_IN_M)


static func dummy_point(room: Rect2) -> Vector2:
	return room.get_center()


## The hero at `pos` stands on the exit pad.
static func at_exit(room: Rect2, pos: Vector2) -> bool:
	return pos.distance_to(exit_point(room)) <= EXIT_REACH_M


## The hero at `pos` is near enough the terminal to use it.
static func at_terminal(room: Rect2, pos: Vector2) -> bool:
	var d := ((pos - terminal_point(room)).abs() - Vector2.ONE * TERMINAL_HALF_M).max(Vector2.ZERO)
	return d.length() <= TERMINAL_REACH_M


## Where `count` spawned enemies stand: on RING_M round the dummy, spread over SPREAD on the side away from the door
## (one alone stands straight across from it).
static func spawn_points(room: Rect2, count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var mid := dummy_point(room)
	var away := inward().angle()
	for k in count:
		var t := 0.0 if count <= 1 else (float(k) / (count - 1) - 0.5) * SPREAD
		if count >= 8:
			t = TAU * k / count  # a full ring
		out.append(mid + Vector2.from_angle(away + t) * RING_M)
	return out


## The enemy kinds the terminal offers: those of `choices` (PlaygroundApi.enemy_choices) the Codex has met.
static func known_enemies(
	choices: Array[Dictionary], codex: CodexStore, catalog: CodexCatalog
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in choices:
		var id := catalog.enemy_of_kind(int(c["kind"]))
		if id != &"" and codex.is_unlocked(&"enemies", id):
			out.append(c)
	return out


## The wand cards the terminal offers: the wand cards `api`'s build can take (PlaygroundApi.catalog, the wand group)
## that the Codex has seen, as {code, name_key, rarity}.
static func known_cards(api: PlaygroundApi, codex: CodexStore) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in api.catalog():
		if e["group"] != PlaygroundApi.GROUP_WAND:
			continue
		var id := api.world.item_tables[int(e["code"])].id
		if codex.is_unlocked(&"cards", id):
			out.append({"code": e["code"], "name_key": e["name_key"], "rarity": e["rarity"]})
	return out


## The last wand card in the build's slots (its code), or -1: the terminal's "remove a card".
static func last_wand_card(api: PlaygroundApi) -> int:
	var slots := api.world.mod_slots
	for k in range(slots.size() - 1, -1, -1):
		if Offers.type_of(slots[k]) == Offers.MOD:
			return slots[k]
	return -1
