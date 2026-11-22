class_name DpsTally
extends RefCounted
## The Playground's DPS meter, counted from the sim's event log. Every
## DAMAGE event the player owns on another body counts its `amount_applied` (the HP it really took): the basic attack,
## child spells and triggers, abilities, procs and damage over time alike. A source is the event's effect id (the
## card, ability or engine that made it; none = the basic attack). Reads only; nothing here changes an outcome.

## The recent window: the last 5 seconds.
const WINDOW_TICKS := 300
const BASIC := &"basic"

var total := 0
## The tick of the first hit counted since the last reset (-1: none yet), and of the last.
var first_tick := -1
var last_tick := -1
## Damage per source (effect id, or BASIC).
var by_source := {}
## Counted each time a hit is added or the tally resets (the meter writes its source lines again only then).
var revision := 0
var _bucket := PackedInt64Array()
var _stamp := PackedInt32Array()
var _last_seq := -1
## The recent window's damage for the window ending at `_win_end`, kept as hits come in and the window moves, so
## dps_recent adds the ticks that entered and takes off the ones that left instead of reading all WINDOW_TICKS
## slots each frame. Kept only once the window starts at tick 0 or later (before, an empty slot's stamp, -1, would
## be inside it); -1: not kept.
var _win_end := -1
var _win_sum := 0


func _init() -> void:
	_bucket.resize(WINDOW_TICKS)
	_stamp.resize(WINDOW_TICKS)
	_stamp.fill(-1)


## Counts the events since the last read.
func observe(reader: WorldReader) -> void:
	var player_id := reader.actor_id(0)
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.DAMAGE or e.owner_id != player_id or e.target_id == player_id:
			continue
		if e.amount_applied > 0:
			add(e.tick, source_of(e), e.amount_applied)


static func source_of(e: SimEvent) -> StringName:
	return BASIC if e.effect_id == &"" else e.effect_id


func add(tick: int, source: StringName, amount: int) -> void:
	if first_tick < 0:
		first_tick = tick
	last_tick = maxi(last_tick, tick)
	total += amount
	revision += 1
	by_source[source] = int(by_source.get(source, 0)) + amount
	var k := tick % WINDOW_TICKS
	if _stamp[k] != tick:
		if _in_window(_stamp[k]):
			_win_sum -= _bucket[k]
		_stamp[k] = tick
		_bucket[k] = 0
	_bucket[k] += amount
	if _in_window(tick):
		_win_sum += amount


## Damage per second over the last WINDOW_TICKS up to `now` (or since the first hit, when that is sooner).
func dps_recent(now: int) -> float:
	if first_tick < 0:
		return 0.0
	var sum := _window_sum(now)
	var span := mini(WINDOW_TICKS, now - first_tick + 1)
	return float(sum) * SimTick.TICKS_PER_SECOND / maxi(span, 1)


## The damage of the slots stamped in (now - WINDOW_TICKS, now]: moved from the kept window when it is a little
## behind `now`, else read from every slot.
func _window_sum(now: int) -> int:
	var from := _win_end
	if from < WINDOW_TICKS or now < from or now - from >= WINDOW_TICKS or now < WINDOW_TICKS:
		var sum := 0
		for k in WINDOW_TICKS:
			if _stamp[k] > now - WINDOW_TICKS and _stamp[k] <= now:
				sum += _bucket[k]
		_win_end = now if now >= WINDOW_TICKS else -1
		_win_sum = sum
		return sum
	for t in range(from + 1, now + 1):  # Entered: a slot stamped with the tick itself holds its damage
		var k := t % WINDOW_TICKS
		if _stamp[k] == t:
			_win_sum += _bucket[k]
		k = (t - WINDOW_TICKS) % WINDOW_TICKS  # Left: the tick a window earlier, if its slot still holds it
		if _stamp[k] == t - WINDOW_TICKS:
			_win_sum -= _bucket[k]
	_win_end = now
	return _win_sum


func _in_window(tick: int) -> bool:
	return _win_end >= 0 and tick > _win_end - WINDOW_TICKS and tick <= _win_end


## Damage per second from the first hit to `now`.
func dps_overall(now: int) -> float:
	if first_tick < 0:
		return 0.0
	return float(total) * SimTick.TICKS_PER_SECOND / maxi(now - first_tick + 1, 1)


## Seconds from the first hit to `now`.
func seconds(now: int) -> float:
	return 0.0 if first_tick < 0 else float(now - first_tick + 1) / SimTick.TICKS_PER_SECOND


## The sources by damage, highest first, as [source, amount] pairs.
func ranked() -> Array:
	var out := []
	for s: StringName in by_source:
		out.append([s, by_source[s]])
	out.sort_custom(
		func(a: Array, b: Array) -> bool:
			return a[1] > b[1] or (a[1] == b[1] and String(a[0]) < String(b[0]))
	)
	return out


## Starts again from now: what happened before is not counted.
func reset(reader: WorldReader = null) -> void:
	total = 0
	revision += 1
	_win_end = -1
	_win_sum = 0
	first_tick = -1
	last_tick = -1
	by_source = {}
	_stamp.fill(-1)
	if reader != null:
		_last_seq = reader.last_event_seq()
