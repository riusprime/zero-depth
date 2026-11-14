extends GutTest
## The aim's pull toward an enemy (AimAssist): a tenth of the way inside a 12° cone, never a snap.

const CONE := 12.0


static func _at(deg: float, dist: float = 5.0) -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(deg)) * dist


static func _deg(v: Vector2) -> float:
	return rad_to_deg(v.angle())


func test_nothing_in_the_cone_leaves_the_aim_unchanged() -> void:
	var aim := Vector2(3, 0)
	assert_eq(AimAssist.pull(aim, PackedVector2Array([_at(31.0)]), 0.1, CONE), aim)
	assert_eq(AimAssist.pull(aim, PackedVector2Array(), 0.1, CONE), aim)


func test_an_enemy_six_degrees_off_turns_the_aim_by_a_tenth() -> void:
	var got := AimAssist.pull(Vector2(3, 0), PackedVector2Array([_at(6.0)]), 0.1, CONE)
	assert_almost_eq(_deg(got), 0.6, 1e-4)
	var below := AimAssist.pull(Vector2(3, 0), PackedVector2Array([_at(-6.0)]), 0.1, CONE)
	assert_almost_eq(_deg(below), -0.6, 1e-4, "toward it either side")


func test_the_pull_fades_to_nothing_over_the_outer_third_of_the_cone() -> void:
	var aim := Vector2(3, 0)
	var whole := AimAssist.pull(aim, PackedVector2Array([_at(8.0)]), 0.1, CONE)
	assert_almost_eq(_deg(whole), 0.8, 1e-4, "whole up to two thirds of the cone")
	var half := AimAssist.pull(aim, PackedVector2Array([_at(10.0)]), 0.1, CONE)
	assert_almost_eq(_deg(half), 0.5, 1e-4, "half the pull halfway through the fade")
	var edge := AimAssist.pull(aim, PackedVector2Array([_at(11.99)]), 1.0, CONE)
	assert_almost_eq(
		_deg(edge), 0.0, 0.05, "no jump as an enemy crosses the edge, even at full strength"
	)


func test_the_aim_distance_is_kept() -> void:
	var got := AimAssist.pull(Vector2(7, 0), PackedVector2Array([_at(6.0)]), 0.1, CONE)
	assert_almost_eq(got.length(), 7.0, 1e-4)


func test_full_strength_points_at_the_target() -> void:
	var got := AimAssist.pull(Vector2(3, 0), PackedVector2Array([_at(6.0)]), 1.0, CONE)
	assert_almost_eq(_deg(got), 6.0, 1e-4)


func test_two_enemies_the_nearer_by_angle_wins() -> void:
	var near_by_angle := _at(-4.0, 9.0)
	var near_by_distance := _at(10.0, 2.0)
	var got := AimAssist.pull(
		Vector2(3, 0), PackedVector2Array([near_by_distance, near_by_angle]), 0.1, CONE
	)
	assert_almost_eq(_deg(got), -0.4, 1e-4)


func test_a_tie_by_angle_takes_the_nearer_one() -> void:
	var far := Vector2(8, 1)  # exactly mirrored angles (slope 1/8, about 7.1°), so a true tie
	var near := Vector2(4, -0.5)
	var got := AimAssist.pull(Vector2(3, 0), PackedVector2Array([far, near]), 0.1, CONE)
	assert_almost_eq(_deg(got), -0.1 * rad_to_deg(atan2(1.0, 8.0)), 1e-4)


func test_strength_zero_leaves_the_aim_unchanged() -> void:
	var aim := Vector2(3, 0)
	assert_eq(AimAssist.pull(aim, PackedVector2Array([_at(6.0)]), 0.0, CONE), aim)


func test_an_enemy_behind_leaves_the_aim_unchanged() -> void:
	var aim := Vector2(3, 0)
	assert_eq(AimAssist.pull(aim, PackedVector2Array([_at(180.0), _at(174.0)]), 0.1, CONE), aim)


func test_an_enemy_out_of_range_leaves_the_aim_unchanged() -> void:
	var aim := Vector2(3, 0)
	assert_eq(AimAssist.pull(aim, PackedVector2Array([_at(6.0, 20.0)]), 0.1, CONE, 12.0), aim)


func test_the_shipped_numbers_are_a_tenth_inside_twelve_degrees() -> void:
	var def: AimAssistDefinition = SharedContent.repo().get_def(&"tuning", AimAssist.DEF_ID)
	assert_not_null(def, "data/tuning/aim_assist.tres is content")
	assert_eq(def.strength_percent, 10)
	assert_eq(def.cone_degrees, 12.0)
	assert_true(def.validate().is_empty())


func test_the_setting_off_leaves_the_aim_unchanged() -> void:
	var w := _world_with(ActorStore.Kind.CHARGER, _at(6.0))
	var profile := ProfileStore.new("")
	var assist := AimAssist.make(SharedContent.repo(), profile)
	var aim := Vector2(3, 0)
	assert_almost_eq(_deg(assist.assisted(aim, WorldReader.new(w))), 0.6, 1e-3, "on by default")
	profile.section("settings")[AimAssist.SETTING] = "off"
	assert_eq(assist.assisted(aim, WorldReader.new(w)), aim)


func test_bosses_count_as_targets() -> void:
	var w := _world_with(ActorStore.Kind.GATEKEEPER, _at(6.0))
	var got := AimAssist.make(null, null).assisted(Vector2(3, 0), WorldReader.new(w))
	assert_almost_eq(_deg(got), 0.6, 1e-3)


func test_critters_and_posts_are_not_targets() -> void:
	var critter: int = EnemyAi.CRITTERS[0]
	for kind: int in [critter, ActorStore.Kind.WIRE_POST]:
		var w := _world_with(kind, _at(6.0))
		var aim := Vector2(3, 0)
		var got := AimAssist.make(null, null).assisted(aim, WorldReader.new(w))
		assert_eq(got, aim, "kind %d is not a target" % kind)


func test_a_dead_enemy_is_not_a_target() -> void:
	var w := _world_with(ActorStore.Kind.CHARGER, _at(6.0))
	w.actors.dead[1] = 1
	var aim := Vector2(3, 0)
	assert_eq(AimAssist.make(null, null).assisted(aim, WorldReader.new(w)), aim)


## A bare kernel world (the hero alone) with one enemy-team actor of `kind` at `offset` from the hero.
func _world_with(kind: int, offset: Vector2) -> World:
	var w := KernelScenario.build(1, 0, 48, 120, 0)
	w.actors.add(999, kind, ActorStore.TEAM_ENEMY, w.player_pos() + offset, 0.4, 10, 0)
	return w
