extends GutTest
## Out-of-combat regen (v0.3.0 PLAN L25; workstream P): after 10 s without dealing or taking damage, 1 % of max HP a
## second; any damage stops it; World.regen_bonus_permille raises it and rides the run carry.

const P := InputFrame.PRIMARY


func _f(held: int = 0, pressed: int = 0) -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, 0, 300, held, pressed)


func _idle(w: World, n: int) -> void:
	for i in n:
		w.step(_f())


# --- Regen ---------------------------------------------------------------------------------------------------
func _hurt_world() -> World:
	var w := World.new(3, PlayerTable.starting_values())
	w.actors.hp[0] = 50
	return w


func test_regen_waits_10_s_then_heals_1_percent_a_second() -> void:
	var w := _hurt_world()
	Damage.hit(w, 0, 0, 0, 0, 0, 0, Vector2.ZERO, Vector2.ZERO)  # zero damage is not combat
	assert_eq(w.build_state.combat_tick, -1)
	w.build_state.combat_tick = 0  # combat on tick 0
	w.actors.invuln[0] = 0
	_idle(w, 599)
	assert_eq(w.actors.hp[0], 50, "nothing for 10 s")
	assert_false(PlayerRegen.active(w))
	_idle(w, 1)
	assert_true(PlayerRegen.active(w), "out of combat at 10 s")
	_idle(w, 60 * 10)
	assert_eq(w.actors.hp[0], 60, "1 % of 100 a second: +10 HP in 10 s")


func test_regen_stops_on_damage_taken_and_dealt() -> void:
	var w := _hurt_world()
	w.add_dummy(Vector2(1.2, 0), 0.35, 500)
	w.dummy_speed = 0.0
	_idle(w, 600 + 120)
	var hp := w.actors.hp[0]
	assert_eq(hp, 52, "healing")
	w.step(_f(0, P))  # deal damage
	_idle(w, 20)
	assert_eq(w.build_state.combat_tick > 600, true, "dealing damage is combat")
	var after := w.actors.hp[0]
	_idle(w, 300)
	assert_eq(w.actors.hp[0], after, "no regen within 10 s of dealing damage")
	_idle(w, 600)
	assert_gt(w.actors.hp[0], after, "it resumes")
	var before := w.actors.hp[0]
	w.actors.invuln[0] = 0
	Damage.hit(w, 0, 5, 99, 99, 99, 0, Vector2(1, 0), Vector2.ZERO)  # take damage
	assert_eq(w.build_state.combat_tick, w.tick, "taking damage is combat")
	assert_eq(w.build_state.regen_acc, 0, "the accumulator empties")
	_idle(w, 120)
	assert_eq(w.actors.hp[0], before - 5, "no regen right after a hit")


func test_regen_stops_at_full_hp_and_never_overheals() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	w.actors.hp[0] = 99
	_idle(w, 600 + 600)
	assert_eq(w.actors.hp[0], 100)
	assert_eq(w.build_state.regen_acc, 0)
	assert_false(PlayerRegen.active(w))


func test_regen_bonus_hook_raises_the_rate() -> void:
	var w := _hurt_world()
	w.regen_bonus_permille = 20  # +2 % a second (an item or the gamble shrine)
	_idle(w, 600 + 60 * 5)
	assert_eq(w.actors.hp[0], 50 + 15, "3 % of 100 a second for 5 s")


func test_regen_bonus_rides_the_run_carry() -> void:
	var w := _hurt_world()
	w.regen_bonus_permille = 15
	var carry := RunCarry.take(w, 0)
	var next := World.new(4, PlayerTable.starting_values())
	RunCarry.apply(next, carry)
	assert_eq(next.regen_bonus_permille, 15)


func test_regen_is_in_the_hash() -> void:
	var a := _hurt_world()
	var b := _hurt_world()
	_idle(a, 650)
	_idle(b, 650)
	assert_eq(a.state_hash(), b.state_hash())
	b.regen_bonus_permille = 1
	assert_ne(a.state_hash(), b.state_hash(), "the bonus hashes")
	b.regen_bonus_permille = 0
	b.build_state.regen_acc += 1
	assert_ne(a.state_hash(), b.state_hash(), "the accumulator hashes")
