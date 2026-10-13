extends GutTest
## v0.7.0 audit C-12: Curses.total keeps its sums in World.curse_totals. Every way the held curses or the curse
## tables change (add, cleanse, the run's carry, a floor's curse tables, a save restored) must give the sums the
## plain loop over the held curses gives, even when the cache was filled before the change.

const IDS: Array[StringName] = [
	&"brittle", &"glass_heart", &"heavy_hands", &"swift_foes", &"price_gouge"
]


## The sum as Curses.total computed it before the cache: every held curse's matching effects.
func _plain(w: World, effect: int) -> int:
	var n := 0
	for c in w.curses_owned:
		if c >= w.ev.curses.size():
			continue
		var t := w.ev.curses[c]
		if t.effect == effect:
			n += t.amount
		if t.effect_2 == effect:
			n += t.amount_2
		if t.up_effect == effect:
			n += t.up_amount
	return n


func _totals(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for e in Curses.Effect.size():
		out.append(Curses.total(w, e))
	return out


func _check(w: World, label: String) -> void:
	for e in Curses.Effect.size():
		assert_eq(Curses.total(w, e), _plain(w, e), "%s: effect %d" % [label, e])


func test_add_and_cleanse_keep_the_sums() -> void:
	var w := EventLab.world(515)
	_check(w, "no curse")
	for id in IDS:
		Curses.add(w, EventLab.curse_index(w, id))
		_check(w, "after %s" % id)
	assert_gt(Curses.total(w, Curses.Effect.MAX_HP_CUT), 0, "Glass Heart is counted")
	Curses.cleanse(w)
	_check(w, "the latest lifted")
	Curses.cleanse(w, EventLab.curse_index(w, &"glass_heart"))
	_check(w, "Glass Heart lifted")
	assert_eq(Curses.total(w, Curses.Effect.MAX_HP_CUT), 0)


func test_the_run_carry_and_new_curse_tables_refresh_the_sums() -> void:
	var w := EventLab.world(515)
	for id in IDS:
		Curses.add(w, EventLab.curse_index(w, id))
	var want := _totals(w)
	var next := World.new(1, PlayerTable.starting_values())
	assert_eq(_totals(next), _totals(World.new(2, PlayerTable.starting_values())), "no tables yet")
	RunCarry.apply(next, RunCarry.take(w, 0))
	_check(next, "carried, before the floor's curse tables")
	Events.setup(next, [] as Array[EventTable], w.ev.curses, null)
	_check(next, "carried, with the curse tables")
	assert_eq(_totals(next), want, "the carried curses sum as they did")
	var fresh := EventLab.world(515, 1, &"blade", IDS)
	assert_eq(_totals(fresh), want, "a floor built with the carry sums the same")


func test_a_restored_save_sums_what_was_saved() -> void:
	var w := SaveLab.floor_world(88, 1)
	for id in IDS:
		Curses.add(w, EventLab.curse_index(w, id))
	var want := _totals(w)
	var snap := WorldSnapshot.take(w)
	var base := SaveLab.floor_world(88, 1)
	var stale := _totals(base)  # the base's cache is filled before the restore
	assert_ne(stale, want)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(restored)
	if restored == null:
		return
	_check(restored, "restored")
	assert_eq(_totals(restored), want, "the restored curses sum as they did")
	assert_eq(restored.state_hash(), w.state_hash(), "the cache is not part of the state")
