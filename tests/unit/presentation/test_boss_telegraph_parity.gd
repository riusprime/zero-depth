extends GutTest
## PRESENTATION §4 / EI-07 for the bosses (v0.3.0 C): the drawn telegraph is the hit area. For each new shape (ring,
## lanes, arc, discs, sweep, and the leap's and the burrow's discs), a player standing still just inside the drawn
## shape (grown by the player's radius) is hit, and one just outside is not. The telegraph is read from
## WorldReader.telegraph, as the view reads it.

const EPS := 0.04


## Boss `id` at the origin, its aim locked on `aim_at`; then the player stands at `stand` while it attacks.
## Returns [hit, telegraph]: the drawn shape at the windup's start (for a burrow: its eruption mark).
func _attack(id: StringName, attack_id: StringName, aim_at: Vector2, stand: Vector2) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id)
	var aid := w.actors.ids[i]
	var reader := WorldReader.new(w)
	w.actors.set_pos(0, aim_at)
	BossLab.start(w, i, attack_id)
	var tg := reader.telegraph(i)
	for t in 400:
		var j := w.actors.index_of(aid)
		if j < 0 or w.actors.state[j] == EnemyAi.State.RECOVER:
			break
		var now := reader.telegraph(j)
		if tg["shape"] == &"ripple" and not now.is_empty() and now["shape"] == &"disc":
			tg = now
		w.actors.set_pos(0, stand)
		w.step(InputFrame.new())
	for t in 120:  # bolts still in flight
		if w.projectiles.size() == 0:
			break
		w.actors.set_pos(0, stand)
		w.step(InputFrame.new())
	return [CombatLab.player_damage(w).size() > 0, tg]


func _pr() -> float:
	return PlayerTable.starting_values().radius_m


func test_gatekeeper_ring() -> void:
	var pr := _pr()
	var tg: Dictionary = _attack(&"gatekeeper", &"fist_slam", Vector2(3, 0), Vector2(3, 0))[1]
	assert_eq(tg["shape"], &"ring")
	var inner: float = tg["inner"]
	var outer: float = tg["outer"]
	for d in [inner - pr - EPS, inner - pr + EPS, 3.0, outer + pr - EPS, outer + pr + EPS]:
		var got: Array = _attack(&"gatekeeper", &"fist_slam", Vector2(3, 0), Vector2(0, d))
		var drawn: bool = d + pr >= inner and d - pr <= outer
		assert_eq(got[0], drawn, "distance %.2f: hit iff inside the drawn ring" % d)


func _in_any_lane(obbs: Array, p: Vector2, r: float) -> bool:
	for o: Obb in obbs:
		if Collide.circle_vs_obb(p, r - 0.0001, o) != Vector2.ZERO:
			return true
	return false


func test_gatekeeper_lanes() -> void:
	var pr := _pr()
	var tg: Dictionary = _attack(&"gatekeeper", &"shock_lanes", Vector2(8, 0), Vector2(8, 0))[1]
	var obbs: Array = tg["obbs"]
	assert_eq(obbs.size(), 3)
	var side: Obb = obbs[2]
	# Points across the upper lane at 8 m, and between the lanes.
	var c := side.center + side.axis_u * 1.0
	for off in [0.0, side.half.y + pr - EPS, side.half.y + pr + EPS, -side.half.y - pr - EPS, 2.0]:
		var p: Vector2 = c + side.axis_v * off
		var got: Array = _attack(&"gatekeeper", &"shock_lanes", Vector2(8, 0), p)
		assert_eq(
			got[0], _in_any_lane(obbs, p, pr), "offset %.2f: hit iff inside a drawn lane" % off
		)


func test_gatekeeper_sweep_arc() -> void:
	var pr := _pr()
	var tg: Dictionary = _attack(&"gatekeeper", &"sweep", Vector2(2.5, 0), Vector2(2.5, 0))[1]
	assert_eq(tg["shape"], &"arc")
	var edge: float = tg["own_r"] + tg["reach"]
	for p: Vector2 in [
		Vector2(edge + pr - EPS, 0),
		Vector2(edge + pr + EPS, 0),
		Vector2(0.2, 2.0),
		Vector2(-2.6, 0.3)
	]:
		var got: Array = _attack(&"gatekeeper", &"sweep", Vector2(2.5, 0), p)
		var drawn := AttackShapes.arc_touches(
			tg["center"], tg["own_r"], tg["angle"], tg["half_arc"], tg["reach"], p, pr
		)
		assert_eq(got[0], drawn, "%s: hit iff inside the drawn arc" % p)


func test_gatekeeper_charge_lane() -> void:
	var pr := _pr()
	var tg: Dictionary = _attack(&"gatekeeper", &"charge", Vector2(8, 0), Vector2(8, 0))[1]
	var o: Obb = tg["obb"]
	for d in [0.0, o.half.y + pr - EPS, o.half.y + pr + EPS, 3.0]:
		var p := Vector2(8, d)
		var got: Array = _attack(&"gatekeeper", &"charge", Vector2(8, 0), p)
		assert_eq(got[0], _in_any_lane([o], p, pr), "lateral %.2f: hit iff inside the lane" % d)


func test_brood_leap_disc() -> void:
	var pr := _pr()
	var tg: Dictionary = _attack(&"brood_mother", &"leap", Vector2(7, 0), Vector2(7, 0))[1]
	assert_eq(tg["shape"], &"disc")
	var r: float = tg["radius"]
	for d in [0.0, r + pr - EPS, r + pr + EPS]:
		var got: Array = _attack(&"brood_mother", &"leap", Vector2(7, 0), Vector2(7, d))
		assert_eq(got[0], d <= r + pr, "offset %.2f: hit iff inside the drawn disc" % d)


func test_brood_burrow_erupts_where_it_marked() -> void:
	var pr := _pr()
	for start in [3.0, 16.0]:
		var got: Array = _attack(&"brood_mother", &"burrow", Vector2(start, 0), Vector2(start, 0))
		var tg: Dictionary = got[1]
		assert_eq(tg["shape"], &"disc", "the eruption is marked")
		var p := Vector2(start, 0)
		var inside := AttackShapes.disc_touches(tg["center"], tg["radius"], p, pr)
		assert_eq(got[0], inside, "from %.0f m: hit iff inside the mark" % start)
	assert_true(
		_attack(&"brood_mother", &"burrow", Vector2(3, 0), Vector2(3, 0))[0], "near: caught"
	)
	assert_false(
		_attack(&"brood_mother", &"burrow", Vector2(16, 0), Vector2(16, 0))[0],
		"far: it falls short"
	)


func _in_any_disc(tg: Dictionary, p: Vector2, r: float) -> bool:
	for c: Vector2 in tg["centers"]:
		if AttackShapes.disc_touches(c, tg["radius"], p, r):
			return true
	return false


func test_discs_brood_barrage_deploy() -> void:
	var pr := _pr()
	for spec in [
		[&"brood_mother", &"brood"], [&"siege_engine", &"barrage"], [&"siege_engine", &"deploy"]
	]:
		var tg: Dictionary = _attack(spec[0], spec[1], Vector2(6, 0), Vector2(6, 0))[1]
		assert_eq(tg["shape"], &"discs")
		var c: Vector2 = (tg["centers"] as PackedVector2Array)[0]
		var r: float = tg["radius"]
		for off in [0.0, r + pr - EPS, r + pr + EPS]:
			var p: Vector2 = c + c.normalized() * off  # away from the body, which pushes
			var got: Array = _attack(spec[0], spec[1], Vector2(6, 0), p)
			assert_eq(got[0], _in_any_disc(tg, p, pr), "%s %s: hit iff inside" % spec)


func test_siege_rail_sweep() -> void:
	var pr := _pr()
	var tg: Dictionary = _attack(&"siege_engine", &"rail_sweep", Vector2(8, 0), Vector2(8, 0))[1]
	assert_eq(tg["shape"], &"sweep")
	var reach: float = tg["own_r"] + tg["reach"]
	for p: Vector2 in [
		Vector2(8, 0),
		Vector2(reach + pr - EPS, 0),
		Vector2(reach + pr + EPS, 0),
		Vector2(-6, 0),
		Vector2(4, 4),
		Vector2(0, -6)
	]:
		var got: Array = _attack(&"siege_engine", &"rail_sweep", Vector2(8, 0), p)
		var drawn := AttackShapes.span_touches(
			tg["center"], tg["own_r"], tg["start"], tg["span"], tg["reach"], p, pr
		)
		assert_eq(got[0], drawn, "%s: hit iff inside the drawn sweep" % p)


func test_siege_bolt_fan_lines() -> void:
	var pr := _pr()
	var tg: Dictionary = _attack(&"siege_engine", &"bolt_fan", Vector2(8, 0), Vector2(8, 0))[1]
	var obbs: Array = tg["obbs"]
	assert_eq(obbs.size(), 7)
	var mid: Obb = obbs[3]
	var c := mid.center
	for off in [0.0, mid.half.y + pr - EPS, 0.6]:
		var p: Vector2 = c + mid.axis_v * off
		var got: Array = _attack(&"siege_engine", &"bolt_fan", Vector2(8, 0), p)
		assert_eq(got[0], _in_any_lane(obbs, p, pr), "offset %.2f: hit iff on a drawn line" % off)
