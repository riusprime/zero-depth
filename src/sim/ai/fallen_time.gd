class_name FallenTime
extends RefCounted
## The Clockwork Judge's Time Wave as The Fallen remembers it (BossRemembered): no gears, no Rewind. As it begins the
## hero's weapon loses time_cut per mille (BossSlow, owned by The Fallen) and the wave's hour orbs are placed inside
## the round room (BossTime.place_orbs with the table's own orb numbers: orb_gap_m from the hero and from each
## other, each lasting time_ticks and returning its share as it is taken, BossPickups). It ends when no orb lies (all
## taken, or run out); whatever is still taken then comes back. The markers point at the orbs (JUDGE_ORB).
## Pure: the ai stream only (the orbs' spots, through BossTime).


static func begin(w: World, i: int, m: FallenRememberedTable) -> bool:
	var id := w.actors.ids[i]
	BossPickups.on_boss_gone(w, id)
	BossSlow.apply(w, id, m.time_cut)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, w.actors.ids[0], w.actors.pos(i))
	e.effect_id = BossTime.WAVE
	e.amount = m.time_cut
	var orbs := BossTime.place_orbs(w, i, m.time, 0, BossRemembered.inner_of(w))
	_point(w, id)
	return not orbs.is_empty()


## True once no orb of The Fallen's lies (tick phase 6, after the hero took the ones it touched).
static func step(w: World, i: int, _m: FallenRememberedTable) -> bool:
	var id := w.actors.ids[i]
	var left := BossPickups.count_of(w, id)
	if w.objectives.reasons.count(String(ObjectiveMarkers.JUDGE_ORB)) != left:
		_point(w, id)
	return left == 0


static func finish(w: World, i: int) -> void:
	finish_for(w, w.actors.ids[i])


## Its orbs go and what the wave took comes back.
static func finish_for(w: World, boss_id: int) -> void:
	BossPickups.on_boss_gone(w, boss_id)
	if w.bosses.aslow_boss == boss_id:
		BossSlow.clear(w)
	w.objectives.clear(ObjectiveMarkers.JUDGE_ORB)


static func _point(w: World, boss_id: int) -> void:
	var bs := w.bosses
	w.objectives.clear(ObjectiveMarkers.JUDGE_ORB)
	for k in bs.pk_x.size():
		if bs.pk_boss[k] == boss_id:
			w.objectives.point(ObjectiveMarkers.JUDGE_ORB, Vector2(bs.pk_x[k], bs.pk_y[k]))
