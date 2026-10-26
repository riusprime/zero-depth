class_name StressMarks
extends RefCounted
## v0.9.5 SM (owner Q14 a: "per enemy within 6 m, a random screen side, x2 once from within 45 degrees, 8 s per enemy,
## bosses carry 4 marks; no levels"). While the hero holds the Stress Mark card, every enemy near the hero shows one
## weak side (a boss, all four): up, right, down or left on the screen (the camera is fixed). A hit of the hero's that
## comes FROM within the half angle of a marked side deals the card's multiplier once and breaks that side; the
## enemy (a boss: that side) then waits the cooldown. The side is drawn from the named stream `combat:stress`.
## Damage-over-time ticks, chains and shrapnel never count. The numbers are the card's (ItemDefinition.mark_*).

const STREAM := "combat:stress"
## The four screen sides as angles (1/4096 turn) on the sim plane, for the iso camera's yaw of 45 degrees
## (IsoRig.YAW_DEG; a test pins them to it): up = away from the camera, then clockwise.
const SIDE_ANGLES: Array[int] = [1536, 512, 3584, 2560]
const UP := 0
const RIGHT := 1
const DOWN := 2
const LEFT := 3
const SIDE_COUNT := 4
const IGNORED_TAGS := SimEvent.TAG_DOT | SimEvent.TAG_CHAIN | SimEvent.TAG_SHRAPNEL


## The unit vector pointing from an enemy out to screen side `side` (0 up, 1 right, 2 down, 3 left).
static func side_dir(side: int) -> Vector2:
	return Kin.dir(SIDE_ANGLES[side])


## The item index of the held Stress Mark card, or -1.
static func card(w: World) -> int:
	for idx in w.items_owned:
		if w.item_tables[idx].mark_radius_m > 0.0:
			return idx
	return -1


## The sides marked on actor `i` (bit mask; 0 when none).
static func mask_of(w: World, i: int) -> int:
	if w.stress == null:
		return 0
	var e := w.stress.entry(w.actors.ids[i])
	return 0 if e < 0 else w.stress.mask[e]


static func advance(w: World) -> void:
	var s := w.stress
	var idx := card(w)
	if idx < 0:
		if s != null and not s.ids.is_empty():
			s.clear()  # the card is gone: so are its marks
		return
	var t := w.item_tables[idx]
	if s == null:
		s = StressState.new()
		s.rng = RngStream.derive(w.seed_value, STREAM)
		w.stress = s
	var a := w.actors
	for e in range(s.ids.size() - 1, -1, -1):
		var k := a.index_of(s.ids[e])
		if k < 0 or a.dead[k] == 1:
			s.remove_at(e)
	var r2 := t.mark_radius_m * t.mark_radius_m
	var hero := a.pos(0)
	for i in range(1, a.size()):
		if a.teams[i] != ActorStore.TEAM_ENEMY or a.dead[i] == 1:
			continue
		if a.pos(i).distance_squared_to(hero) > r2:
			continue
		var boss := BossAi.is_boss_kind(a.kinds[i])
		var e := s.entry(a.ids[i])
		if e < 0:
			e = s.add(a.ids[i])
		if boss:
			for side in mini(SIDE_COUNT, t.mark_boss_marks):
				if s.mask[e] & (1 << side) == 0 and s.cd[e * 4 + side] <= w.tick:
					s.mask[e] |= 1 << side
		elif s.mask[e] == 0 and s.cd[e * 4] <= w.tick:
			s.mask[e] = 1 << s.rng.range_int(0, SIDE_COUNT - 1)


## The damage of a hit of the hero's on enemy `target` once a marked side is struck: `amount` times the card's
## multiplier, and that side breaks (STRESS_BREAK, amount = the extra damage, amount_applied = the side). `from` is
## where the attack came from, `at` where it landed. Returns `amount` unchanged when nothing is struck.
static func on_hit(
	w: World, target: int, amount: int, tags: int, from: Vector2, at: Vector2, effect_id: StringName
) -> int:
	var s := w.stress
	if s == null or amount <= 0 or tags & IGNORED_TAGS or effect_id == Stats.EFFECT_OVERKILL:
		return amount
	var a := w.actors
	var e := s.entry(a.ids[target])
	if e < 0 or s.mask[e] == 0:
		return amount
	var idx := card(w)
	if idx < 0:
		return amount
	var t := w.item_tables[idx]
	var to_origin := from - at if tags & SimEvent.TAG_PROJECTILE else from - a.pos(target)
	if to_origin.length_squared() < 0.000001:
		to_origin = from - a.pos(target)
		if to_origin.length_squared() < 0.000001:
			return amount
	var ang := Kin.angle_of(to_origin)
	var half := int(t.mark_half_angle_deg * 4096.0 / 360.0 + 0.5)
	for side in SIDE_COUNT:
		if s.mask[e] & (1 << side) == 0 or Kin.angle_diff(ang, SIDE_ANGLES[side]) > half:
			continue
		s.mask[e] &= ~(1 << side)
		var slot := side if BossAi.is_boss_kind(a.kinds[target]) else 0
		s.cd[e * 4 + slot] = w.tick + t.mark_cooldown_ticks
		var boosted := amount * t.mark_mult_permille / 1000
		var ev := w.emit_event(
			SimEvent.Kind.STRESS_BREAK, a.ids[0], a.ids[0], a.ids[target], a.pos(target)
		)
		ev.amount = boosted - amount
		ev.amount_applied = side
		return boosted
	return amount
