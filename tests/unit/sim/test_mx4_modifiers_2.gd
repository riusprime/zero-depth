extends GutTest
## v0.6.0 MX4 (PLAN v0.5.5 M16–M30; docs/design/MODIFIER_ENGINE.md): each modifier's rewrite and its effect in a
## scripted scenario (v0.10.5 O1: the cards of M16-M30 are retired, two tests remain). Mechanics
## only: no bot, no balance (owner P1).

const W := preload("res://tests/support/mx4_world.gd")
const FORM := AttackSpec.Form
const TRIG := AttackSpec.Trigger


## Audit G-19: an arc's snap searches its own reach, not the homing bolts' 8 m; within 8 m nothing changes.
func test_m18_an_arc_snaps_as_far_as_its_reach() -> void:
	var w := W.world(&"blade", [], [[Vector2(9.0, 3.0), 2000]])
	W.run(w, 1)  # tick phase 3 builds the actor grid
	var at := w.actors.pos(1)
	var want := Kin.angle_of(at)
	assert_eq(ProjectileMoves.snap_angle(w, Vector2.ZERO, 0, 12.0), want, "9.5 m away, 12 m reach")
	assert_eq(ProjectileMoves.snap_angle(w, Vector2.ZERO, 0, 9.0), 0, "out of a 9 m reach")
	assert_eq(
		ProjectileMoves.snap_angle(w, at - Vector2(0, 4), 0, 6.0),
		Kin.angle_of(Vector2(0, 4)),
		"4 m away, 6 m reach"
	)


## v0.8.0 RM (owner O91): Long Shadow / Afterimage is Dodge Imprint (the same id): the dash spec keeps where it began
## and the next attack is cast from there (test_remnant_cards.gd); no queued copy.
func test_m19_long_shadow_is_dodge_imprint() -> void:
	var w := W.world(&"blade", [&"long_shadow"], [[Vector2(-1.2, 0.0), 2000]])
	assert_null(W.hook_of(Modifiers.dash(w), &"long_shadow"))
	assert_true(Modifiers.dash(w).has_tag(&"moment"))
	W.run(w, 1, W.D, 0, 2048, Vector2i(SimTick.MOVE_MAX, 0))
	assert_eq(w.mx.q_key.size(), 0, "nothing waits")
	assert_eq(w.mx.imprint_at, Vector2.ZERO, "where the dash began")
	assert_gt(w.mx.imprint_until, w.tick, "for a while after it")
