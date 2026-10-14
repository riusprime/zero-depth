class_name NemesisLab
extends RefCounted
## v0.8.0 FB3: the final arena with the Nemesis fighting (FinalLab's world, the fight jumped to its last body, as the
## dev panel and the Playground do), on a Blade or a Gun run, with wand cards granted first (they are read as it
## rises). Test-side only.

const LONG := 1 << 24


## The item index of card `id` (-1 when the content has none).
static func card(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


## Grants each [id, level] of `cards` as a found card would (the wand's slots, in order).
static func grant(w: World, cards: Array) -> void:
	for c: Array in cards:
		var idx := card(w, c[0])
		Offers.apply(w, idx)
		CardLevels.set_level(w, idx, int(c[1]))


## The arena of a `build` run (seed `seed_value`), `cards` granted, the hero held up (invulnerable), the Nemesis risen
## and acting. With `held` false the hero can be hurt.
static func world(
	seed_value: int, build: StringName = &"blade", cards: Array = [], held: bool = true
) -> World:
	var w := FinalLab.arena(FinalLab.run_state(seed_value, build))
	if held:
		w.actors.invuln[0] = LONG
	grant(w, cards)
	FinalLab.past_rise(w)
	FinalBoss.jump(w, 2)
	FinalLab.past_rise(w)
	return w


## The Nemesis's attack index of `id`.
static func attack(w: World, id: StringName) -> int:
	return BossAi.table_of(w, FinalLab.body(w)).attack_index(id)


## Starts attack `id` now (its windup) and returns its table.
static func start(w: World, id: StringName) -> BossAttackTable:
	var i := FinalLab.body(w)
	BossAi.start_attack(w, i, attack(w, id))
	return BossAi.attack_of(w, i)


## Steps until the attack in progress is `st` ticks into its active time (at most 600 ticks).
static func to_active(w: World, st: int = 0) -> void:
	var i := FinalLab.body(w)
	for k in 600:
		if w.actors.state[i] == EnemyAi.State.ACTIVE and w.actors.state_t[i] >= st:
			return
		w.step(InputFrame.new())


## The hostile shots on the floor drawn as `look`.
static func shots(w: World, look: StringName) -> Array[int]:
	var out: Array[int] = []
	for k in w.projectiles.size():
		if w.projectiles.team[k] != ActorStore.TEAM_PLAYER and w.projectiles.look[k] == look:
			out.append(k)
	return out


## A frame that dashes toward `dir` (and walks that way).
static func dash(dir: Vector2) -> InputFrame:
	var f := InputFrame.new()
	var d := dir.normalized()
	f.move = Vector2i(roundi(d.x * SimTick.MOVE_MAX), roundi(d.y * SimTick.MOVE_MAX))
	f.pressed = InputFrame.DASH
	return f
