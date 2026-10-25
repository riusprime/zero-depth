class_name CrackLab
extends RefCounted
## v0.9.0 DX: run floors for the destructibles' sim and view tests: RunLab's floor (as Main builds it) with
## Breakables.setup, the cracked wall forced on (`crack`, the first run seed whose floor has a dead end that fits one)
## or off, and the props as the data places them. No horde (the spawner off), the hero unhurt unless a test says.

const LONG := 1 << 24


static func rules(crack: bool) -> SecretRules:
	var r := SecretRules.new()
	r.crack_permille = 1000 if crack else 0
	return r


static func world(build: StringName = &"blade", crack: bool = true, first_seed: int = 1) -> World:
	var repo := ContentRepository.load_all()
	for s in range(first_seed, first_seed + 80):
		var lab := RunLab.new(repo, s, build)
		var w := lab.floor_world()
		Breakables.setup(w, rules(crack))
		if w.breakables == null or (crack and not w.breakables.has_crack()):
			continue
		w.actors.invuln[0] = LONG
		w.spawner = null
		return w
	return null


## A spot on the cracked wall's host side, `m` metres out from its face, and the angle (1/4096 turns) toward it.
static func before_wall(w: World, m: float) -> Vector2:
	var f := w.floor_layout
	var host := f.crack_host
	var into := 1.0 if f.door_rooms[f.crack_door].x == host else -1.0
	var back := Kin.dir(f.door_angles[f.crack_door]) * -into
	return f.door_centers[f.crack_door] + back * (f.door_depths[f.crack_door] * 0.5 + m)


static func toward_wall(w: World) -> int:
	var f := w.floor_layout
	return Kin.angle_of(f.door_centers[f.crack_door] - before_wall(w, 1.0))


## Stands the hero `m` out from the wall, facing it.
static func face_wall(w: World, m: float) -> void:
	w.actors.set_pos(0, before_wall(w, m))
	w.vel = Vector2.ZERO
	w.build_state.facing_angle = toward_wall(w)


## Presses `button` once aimed at the wall (one tick), then waits `after` ticks.
static func press(w: World, button: int, after: int) -> void:
	var a := toward_wall(w)
	w.step(InputFrame.make(Vector2i.ZERO, a, 300, button, button))
	for k in after:
		w.step(InputFrame.make(Vector2i.ZERO, a, 300, 0, 0))


## One Skill use at the wall from `m` out, once it is ready (the cooldown waited out first).
static func skill(w: World, m: float = 1.2) -> void:
	for k in 600:
		if PlayerSkill.ready(w):
			break
		w.step(InputFrame.new())
	face_wall(w, m)
	press(w, InputFrame.SKILL, 40)
