class_name DpsTally
extends RefCounted
## v0.7.5 PG (owner N20, docs/tools/PLAYGROUND.md): the Playground's DPS meter, counted from the sim's event log. Every
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
var _bucket := PackedInt64Array()
var _stamp := PackedInt32Array()
var _last_seq := -1


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
	by_source[source] = int(by_source.get(source, 0)) + amount
	var k := tick % WINDOW_TICKS
	if _stamp[k] != tick:
		_stamp[k] = tick
		_bucket[k] = 0
	_bucket[k] += amount


## Damage per second over the last WINDOW_TICKS up to `now` (or since the first hit, when that is sooner).
func dps_recent(now: int) -> float:
	if first_tick < 0:
		return 0.0
	var sum := 0
	for k in WINDOW_TICKS:
		if _stamp[k] > now - WINDOW_TICKS and _stamp[k] <= now:
			sum += _bucket[k]
	var span := mini(WINDOW_TICKS, now - first_tick + 1)
	return float(sum) * SimTick.TICKS_PER_SECOND / maxi(span, 1)


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
	first_tick = -1
	last_tick = -1
	by_source = {}
	_stamp.fill(-1)
	if reader != null:
		_last_seq = reader.last_event_seq()
