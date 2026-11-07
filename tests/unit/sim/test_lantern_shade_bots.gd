extends GutTest
## v0.11.0 O4 (owner Q10 a; PLAN L6; TEST_MATRIX: a scripted bot beats a boss two ways): the Lantern Shade's whole
## fight, its real compiled table (BossLab: no sealed room, the lanterns round where it rose), the hero never dying (its
## HP refilled each tick: these bots test the damage and the lever, not the dodge) and landing a HIT_AMOUNT hit every
## HIT_EVERY ticks (Damage.hit, as a shot would). Two bots:
## - lanterns: walks onto the lit lantern nearest it (or the nearest one, lighting it) and stands on it; the Shade
##   follows it into the pool (150 %);
## - ignore: keeps KITE_M from the Shade (outside its own 3.5 m light, inside the ranged armour's full range) on the
##   side farthest from every lantern, never lighting one (40 % in the dark, 100 % in the light).
## Both win; the lantern bot wins sooner. Every hit outside a phase gate lands (no window of 0 damage). Prints both
## fight lengths (raw) for the evidence.

const HIT_EVERY := 6
const HIT_AMOUNT := 10
const KITE_M := 6.2
const CAP := 60 * 600
const LONG := 1 << 20


## Plays the fight with `bot` ("lanterns" or "ignore"). Returns {"ticks", "dead", "zero" (hits outside a gate or the
## rise that removed no HP while the Shade lived), "dim", "lit", "full" (hits by multiplier), "hash"}.
func _fight(bot: String, seed_value: int = 3) -> Dictionary:
	var w := BossLab.world(seed_value)
	var i0 := BossLab.ready_boss(w, &"lantern_shade", Vector2.ZERO)
	var aid := w.actors.ids[i0]
	var me := w.actors.ids[0]
	w.actors.set_pos(0, Vector2(KITE_M, 0.0))
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	var out := {"ticks": 0, "dead": false, "zero": 0, "dim": 0, "lit": 0, "full": 0}
	var side := Vector2(1, 0)
	for k in CAP:
		var i := w.actors.index_of(aid)
		if i < 0 or w.actors.dead[i] == 1:
			out["dead"] = true
			break
		var c := w.actors.pos(i)
		if bot == "lanterns":
			w.actors.set_pos(0, _lantern_spot(w))
		else:
			side = _far_side(w, c, side)
			w.actors.set_pos(0, c + side * KITE_M)
		w.actors.hp[0] = LONG
		w.actors.invuln[0] = 0
		if k % HIT_EVERY == 0 and w.actors.invuln[i] == 0 and w.actors.state[i] != BossAi.GATE:
			var pm := BossShade.light_permille(w, i)
			var hp := w.actors.hp[i]
			var at := w.actors.pos(i)
			var got := Damage.hit(w, i, HIT_AMOUNT, me, me, w.take_root(), 0, w.actors.pos(0), at)
			if got <= 0 and hp > 0 and w.actors.state[i] != BossAi.GATE:
				out["zero"] += 1
			if pm < 1000:
				out["dim"] += 1
			elif pm > 1000:
				out["lit"] += 1
			else:
				out["full"] += 1
		w.step(InputFrame.new())
		out["ticks"] = k + 1
	out["hash"] = w.state_hash()
	return out


## The lantern bot's spot: the lit lantern nearest it, else the nearest lantern (stepping on it lights it).
func _lantern_spot(w: World) -> Vector2:
	var bs := w.bosses
	var p := w.player_pos()
	var best := p
	var best_d := INF
	for pass_lit in [true, false]:
		for k in bs.lamp_x.size():
			if pass_lit and (k >= bs.lamp_t.size() or bs.lamp_t[k] <= 0):
				continue
			var at := Vector2(bs.lamp_x[k], bs.lamp_y[k])
			if at.distance_to(p) < best_d:
				best_d = at.distance_to(p)
				best = at
		if best_d < INF:
			return best
	return best


## The ignore bot's side of the Shade: of 16 headings, the one whose spot KITE_M out is farthest from every lantern
## (kept while still clear of their reach, so it does not jitter).
func _far_side(w: World, c: Vector2, keep: Vector2) -> Vector2:
	if _lamp_gap(w, c + keep * KITE_M) > 3.0:
		return keep
	var best := keep
	var best_gap := -1.0
	for n in 16:
		var d := Vector2.RIGHT.rotated(TAU * n / 16.0)
		var gap := _lamp_gap(w, c + d * KITE_M)
		if gap > best_gap:
			best_gap = gap
			best = d
	return best


func _lamp_gap(w: World, p: Vector2) -> float:
	var bs := w.bosses
	var gap := INF
	for k in bs.lamp_x.size():
		gap = minf(gap, p.distance_to(Vector2(bs.lamp_x[k], bs.lamp_y[k])))
	return gap


func test_two_bots_beat_it_the_lantern_one_sooner() -> void:
	var lanterns := _fight("lanterns")
	var ignore := _fight("ignore")
	gut.p("O4 lanterns bot: %s" % str(lanterns))
	gut.p("O4 ignore bot: %s" % str(ignore))
	assert_true(lanterns["dead"], "the lantern bot beats it")
	assert_true(ignore["dead"], "the bot that ignores the lanterns beats it too")
	assert_lt(int(lanterns["ticks"]), int(ignore["ticks"]), "the lanterns are the faster way")
	assert_gt(int(lanterns["lit"]), 0, "the lantern bot lured it into a lit pool")
	assert_gt(int(ignore["dim"]), 0, "the other one hit it in the dark")
	assert_eq(int(ignore["lit"]), 0, "and never lit a lantern")
	assert_eq(int(lanterns["zero"]), 0, "no window where a hit does nothing")
	assert_eq(int(ignore["zero"]), 0, "not even in the dark")


func test_the_fight_is_deterministic() -> void:
	var a := _fight("ignore", 5)
	var b := _fight("ignore", 5)
	assert_eq(a["hash"], b["hash"], "two runs agree")
	assert_eq(a["ticks"], b["ticks"])
