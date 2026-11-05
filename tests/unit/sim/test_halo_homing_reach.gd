extends GutTest
## v0.10.5 W3-S18 (owner, 2026-11-05, playtesting: "homing + halo is weird because the back attacks are too short in
## reach and do the curve but do not reach the enemy, we should increase the reach of halo a bit so attacks can get
## to hit front enemies if homing is active"): Halo alone keeps its half-length flight; with Homing (either order) its
## bolts fly 2.6x that, so the one fired backwards can turn round and reach an enemy in front. Mechanics only.

const W := preload("res://tests/support/mx4_world.gd")
## A Halo ring is four bolts; an enemy this far ahead is inside the back bolt's sight (Homing sees 8 m, and that bolt
## starts 0.6 m behind the hero and swings out 1.7 m) and beyond the half-length flight's U-turn.
const AHEAD_M := 5.0


func _bolt(ids: Array) -> AttackSpec:
	return Modifiers.bolt(W.world(&"gun", ids))


## Hits one Halo shot lands on a sturdy dummy `AHEAD_M` in front. `life` > 0 forces the old half-length flight.
func _hits(items: Array, life: int = 0) -> int:
	var w := W.world(&"gun", items, [[Vector2(AHEAD_M, 0.0), 20000]])
	if life > 0:
		Modifiers.bolt(w).life_ticks = life
	W.run(w, 1, 0, W.S)
	W.run(w, 90)
	return W.damage(w, &"").size()


func test_halo_alone_is_unchanged_and_homing_alone_too() -> void:
	var plain := _bolt([]).life_ticks
	assert_eq(_bolt([&"halo_shot"]).life_ticks, plain / 2, "Halo: half the flight")
	assert_eq(_bolt([&"gun_homing"]).life_ticks, plain, "Homing: the whole flight")


func test_with_homing_halo_flies_further_in_either_order() -> void:
	var plain := _bolt([]).life_ticks
	var want := plain / 2 * 2600 / 1000
	assert_eq(_bolt([&"halo_shot", &"gun_homing"]).life_ticks, want, "Halo then Homing")
	assert_eq(_bolt([&"gun_homing", &"halo_shot"]).life_ticks, want, "Homing then Halo")
	assert_gt(want, plain, "more than a plain shot's flight")


func test_all_four_halo_bolts_reach_the_enemy_in_front_only_with_the_extra_reach() -> void:
	var items := [&"halo_shot", &"gun_homing"]
	assert_eq(_hits(items), 4, "Halo + Homing: the back, side and front bolts all land")
	assert_lt(
		_hits(items, 20),
		4,
		"the same shot at Halo's old half-length flight: the back bolt falls short"
	)
	assert_lt(_hits([&"halo_shot"]), 4, "Halo alone: the back bolt flies away")
