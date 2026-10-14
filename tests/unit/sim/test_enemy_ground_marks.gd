extends GutTest
## v0.8.0 TG (owner O4, Q3 "only things landing at range"): per normal enemy kind, which of its telegraphs are drawn
## on the ground ("ground" missing or true in EnemyAi.telegraph). Only the Arc Caster's rune and the Mine Layer's
## armed mines; every other kind still hands the view a telegraph (shape and timing, for the forecasts, the parity
## tests and the readable-cause recap), marked "ground": false so its body tells the windup. Elites follow their kind.

const K := ActorStore.Kind
const TICKS := 1800

## [kind, where it starts, the ground marks it may draw ("shape/style"), a shape it must still telegraph].
const TABLE := [
	[K.CHARGER, Vector2(3, 0), [], &"lane"],
	[K.HATCHLING, Vector2(3, 0), [], &"lane"],
	[K.SWARMER, Vector2(2, 0), [], &"lane"],
	[K.SPLITTER, Vector2(1.2, 0), [], &"disc"],
	[K.SPLITLING, Vector2(1.0, 0), [], &"disc"],
	[K.SHIELD_BEARER, Vector2(1.8, 0), [], &"lane"],
	[K.WARDEN, Vector2(1.5, 0), [], &"disc"],
	[K.SNIPER, Vector2(12, 0), [], &"lane"],
	[K.NEEDLE, Vector2(8, 0), [], &"lanes"],
	[K.ARC_CASTER, Vector2(-8, 0), ["disc/rune"], &"disc"],
	[K.MINE_LAYER, Vector2(0, 6), ["discs/mine"], &"discs"],
	[K.BOMB_DRONE, Vector2(6, 0), [], &"lob"],
	[K.LENS_DRONE, Vector2(7, 0), [], &"cast"],
	[K.MENDER, Vector2(4, 0), [], &""],
]


## Runs one enemy of `kind` against a player that can't die (walking onto any mine so it arms) and returns
## [ground marks seen ("shape/style"), every shape seen].
func _marks(kind: int, at: Vector2, elite: bool) -> Array:
	var w := CombatLab.world()
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	var id := w.add_enemy(kind, at)
	if elite:
		Curses.make_elite(w, w.actors.index_of(id))
		assert_true(Curses.is_elite(w, id), "kind %d made elite" % kind)
	var ground := {}
	var shapes := {}
	for t in TICKS:
		if w.mines.size() > 0:
			w.actors.set_pos(0, w.mines.pos(0))  # step on the mine so it arms
		w.step(InputFrame.new())
		w.actors.hp[0] = w.actors.max_hp[0]
		var i := w.actors.index_of(id)
		if i < 0:
			break
		var tg := EnemyAi.telegraph(w, i)
		if tg.is_empty():
			continue
		shapes[tg["shape"]] = true
		if tg.get("ground", true):
			ground["%s/%s" % [tg["shape"], tg.get("style", &"")]] = true
	return [ground.keys(), shapes]


func test_only_the_arc_casters_rune_and_the_mine_layers_mines_mark_the_ground() -> void:
	for spec: Array in TABLE:
		var got := _marks(spec[0], spec[1], false)
		var ground: Array = got[0]
		ground.sort()
		assert_eq(ground, spec[2], "kind %d: its ground marks" % spec[0])
		if spec[3] != &"":
			assert_true((got[1] as Dictionary).has(spec[3]), "kind %d still telegraphs" % spec[0])


func test_elites_follow_their_kind() -> void:
	for spec: Array in TABLE:
		if spec[2].is_empty() and spec[3] != &"":
			var got := _marks(spec[0], spec[1], true)
			assert_eq(got[0], [], "elite kind %d: no ground mark" % spec[0])
			assert_true((got[1] as Dictionary).has(spec[3]), "elite kind %d telegraphs" % spec[0])


func test_the_body_cue_kinds_keep_the_shape_and_timing_the_hit_uses() -> void:
	# The telegraph without its ground mark is still the hit's own shape, filling 0..1000 over the windup.
	var w := CombatLab.world()
	w.actors.hp[0] = 1 << 20
	var id := w.add_enemy(K.CHARGER, Vector2(3, 0))
	var last := -1
	for t in 900:
		w.step(InputFrame.new())
		var i := w.actors.index_of(id)
		if w.actors.state[i] != EnemyAi.State.WINDUP:
			if last >= 0:
				break
			continue
		var tg := EnemyAi.telegraph(w, i)
		assert_false(tg["ground"])
		assert_true(tg["obb"] is Obb, "the lane the charge runs down")
		assert_gte(int(tg["progress"]), last, "it fills")
		last = int(tg["progress"])
	assert_gt(last, 900, "filled to the strike")
