extends GutTest
## The dodge-first fights' "track, then lock" circles, with the attack forced (BossLab.start) instead of rolled: the
## Brood Mother's Leap and the first circle of the Siege Engine's Barrage. Each locks where the player stands, holds
## there until it strikes, misses a player who walks out after the lock, and hits one who stands. The e2e
## test_e2e_boss_dodge files show the same in the real game. (The Gatekeeper's Fist Slam: test_boss_markers.gd.)

const LONG := 1 << 20
## The player's start, 7 m from the boss on +x; walking out goes on along +x, away from it.
const AT := Vector2(7, 0)
## 7.2 m/s, as test_boss_markers walks out.
const WALK := Vector2(0.12, 0)


func _fight(id: StringName) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id, Vector2.ZERO)
	w.actors.set_pos(0, AT)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


## The locked circle in telegraph `tg` of a `move` attack: [centre, radius, tracked (a Leap's)], else [] (not locked
## yet). For a Barrage (MOVE_MARKS) its first circle; for a Leap the landing circle, locked while she winds up.
func _locked(tg: Dictionary, move: int, state: int) -> Array:
	if tg.is_empty() or tg.get("move", -1) != move:
		return []
	if move == WorldReader.MOVE_LEAP:
		if not tg.get("locked", false) or state != WorldReader.STATE_WINDUP:
			return []
		return [tg["center"], tg["radius"], tg.get("tracked", false)]
	var first: Dictionary = tg["items"][0]
	return [first["center"], first["radius"], true] if first["locked"] else []


## 1: the circle locked at `center` still stands there; -1: it has struck (gone); 0: it is there but moved.
func _held(tg: Dictionary, move: int, center: Vector2) -> int:
	if tg.is_empty() or tg.get("move", -1) != move:
		return -1
	if move == WorldReader.MOVE_LEAP:
		return 1 if tg["center"] == center else 0
	for item: Dictionary in tg["items"]:  # the Barrage's later circles track on; the locked one keeps its centre
		if item["center"] == center and item["locked"]:
			return 1
	return -1


func _check(id: StringName, attack_id: StringName, move: int) -> void:
	for stay: bool in [true, false]:
		var s := _fight(id)
		var w: World = s[0]
		var aid: int = s[1]
		var reader := WorldReader.new(w)
		BossLab.start(w, w.actors.index_of(aid), attack_id)
		var lock := []
		for t in 600:  # the player stands while it tracks
			var i := w.actors.index_of(aid)
			lock = _locked(reader.telegraph(i), move, w.actors.state[i])
			if not lock.is_empty():
				break
			w.step(InputFrame.new())
		assert_false(lock.is_empty(), "%s: it locked" % attack_id)
		if lock.is_empty():
			return
		var center: Vector2 = lock[0]
		var radius: float = lock[1]
		if move == WorldReader.MOVE_LEAP:
			assert_true(lock[2], "%s: the circle tracked the player" % attack_id)
		assert_lt(
			w.player_pos().distance_to(center),
			0.3,
			"%s: it locked where the player stood" % attack_id
		)
		var seq := w.last_event_seq()
		var hit := false
		var struck := false
		for t in 240:
			if not stay:
				w.actors.set_pos(0, w.player_pos() + WALK)  # after the lock only
			w.step(InputFrame.new())
			for ev in w.events_since(seq):
				seq = ev.seq
				if (
					ev.kind == SimEvent.Kind.HIT
					and ev.target_id == w.actors.ids[0]
					and ev.owner_id == aid
					and ev.tags & SimEvent.TAG_AREA
				):
					hit = true
			var j := w.actors.index_of(aid)
			var held := _held(reader.telegraph(j) if j >= 0 else {}, move, center)
			assert_ne(held, 0, "%s: the circle holds where it locked (tick %d)" % [attack_id, t])
			if held != 1:
				struck = true
				break
		assert_true(struck, "%s: it struck" % attack_id)
		if stay:
			assert_true(hit, "%s: a player who stands is hit" % attack_id)
		else:
			assert_gt(
				w.player_pos().distance_to(center), radius, "%s: the player walked out" % attack_id
			)
			assert_false(hit, "%s: and the locked circle missed" % attack_id)


func test_walking_out_of_the_brood_mothers_locked_leap_dodges_it() -> void:
	_check(&"brood_mother", &"leap", WorldReader.MOVE_LEAP)


func test_walking_out_of_the_siege_engines_first_locked_barrage_circle_dodges_it() -> void:
	_check(&"siege_engine", &"barrage", WorldReader.MOVE_MARKS)
