class_name TimedLab
extends RefCounted
## v0.9.0 TD: a run floor holding a timed door, for the sim and view tests: RunLab's floor (as Main builds it), then
## TimedDoor.setup with the chance forced to every floor, on the first run seed whose floor has a dead end that fits
## one. No horde (the spawner off), the hero unhurt.

const LONG := 1 << 24


static func world(first_seed: int = 1) -> World:
	var repo := ContentRepository.load_all()
	for s in range(first_seed, first_seed + 80):
		var lab := RunLab.new(repo, s, &"blade")
		var w := lab.floor_world()
		TimedDoor.setup(w, 1000, 900, w.player.move_speed)
		if w.timed != null:
			w.actors.invuln[0] = LONG
			w.spawner = null
			return w
	return null


## An interact press, standing still.
static func press() -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, 0, 1000, InputFrame.INTERACT, InputFrame.INTERACT)


## Stands the hero by switch k and presses (two ticks).
static func switch(w: World, k: int) -> void:
	w.actors.set_pos(0, w.floor_layout.timed_switches[k] + Vector2(0.3, 0.0))
	w.vel = Vector2.ZERO
	w.step(InputFrame.new())
	w.step(press())
