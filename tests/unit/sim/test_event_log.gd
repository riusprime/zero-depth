extends GutTest
## World.events_since: every logged event with seq > after_seq, oldest first (a binary search into the log).


func _linear(w: World, after_seq: int) -> Array[int]:
	var out: Array[int] = []
	for e in w.events_since(-1):
		if e.seq > after_seq:
			out.append(e.seq)
	return out


func _seqs(events: Array[SimEvent]) -> Array[int]:
	var out: Array[int] = []
	for e in events:
		out.append(e.seq)
	return out


func test_events_since_returns_the_newer_events_in_order() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	assert_eq(w.events_since(0).size(), 0, "an empty log")
	var first := w.last_event_seq()
	for k in 7:
		w.emit_event(SimEvent.Kind.SPAWN, k, k, k, Vector2.ZERO)
	var last := w.last_event_seq()
	for after in range(first - 2, last + 3):
		assert_eq(_seqs(w.events_since(after)), _linear(w, after), "after %d" % after)
	assert_eq(w.events_since(last).size(), 0)
	assert_eq(w.events_since(first).size(), 7)


func test_events_since_after_the_log_is_trimmed() -> void:
	var w := World.new(4, PlayerTable.starting_values())
	for k in World.EVENT_LOG_CAP + World.EVENT_LOG_TRIM + 5:
		w.emit_event(SimEvent.Kind.SPAWN, k, k, k, Vector2.ZERO)
	var all := w.events_since(-1)
	assert_lt(all.size(), World.EVENT_LOG_CAP + World.EVENT_LOG_TRIM + 5, "the oldest were trimmed")
	var oldest := all[0].seq
	var last := w.last_event_seq()
	for after in [0, oldest - 1, oldest, oldest + 1, last - 3, last - 1, last]:
		assert_eq(_seqs(w.events_since(after)), _linear(w, after), "after %d" % after)
