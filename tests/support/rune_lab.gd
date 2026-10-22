class_name RuneLab
extends RefCounted
## v0.9.0 RA: a run floor holding a rune puzzle, for the sim and view tests: RunLab's floor (as Main builds it), the
## timed door tried on every floor (`with_timed`), then RuneAlignment.setup with the chance forced to every floor, on
## the first run seed whose floor has a dead end that fits one. No horde (the spawner off), the hero unhurt.

const LONG := 1 << 24


static func world(first_seed: int = 1, with_timed: bool = false) -> World:
	var repo := ContentRepository.load_all()
	for s in range(first_seed, first_seed + 80):
		var lab := RunLab.new(repo, s, &"blade")
		var w := lab.floor_world()
		if with_timed:
			TimedDoor.setup(w, 1000, 900, w.player.move_speed)
			if w.timed == null:
				continue
		RuneAlignment.setup(w, 1000)
		if w.runes != null:
			w.actors.invuln[0] = LONG
			w.spawner = null
			return w
	return null


## An interact press, standing still.
static func press() -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, 0, 1000, InputFrame.INTERACT, InputFrame.INTERACT)


## Stands the hero by pillar k and presses once (two ticks).
static func turn(w: World, k: int) -> void:
	w.actors.set_pos(0, w.floor_layout.rune_pillars[k] + Vector2(0.3, 0.0))
	w.vel = Vector2.ZERO
	w.step(InputFrame.new())
	w.step(press())


## Turns every pillar to its target (the fewest presses). Returns the presses made.
static func solve(w: World) -> int:
	var n := 0
	for k in w.runes.pillars.size():
		var e := w.runes.pillars[k]
		while w.interactables.state[e] != w.runes.target[k]:
			turn(w, k)
			n += 1
	return n
