class_name EventState
extends RefCounted
## The floor's event rooms and the run's curse bookkeeping that is not carried (v0.5.0 EV; World.ev). The tables are
## the loadout (not hashed); everything else is hashed once touched (Events.hash_into). The curses you hold and the
## threat peak are World fields (curses_owned, threat_peak), carried by RunCarry.

## The loadout: compiled events, curses and rules (empty = no event rooms, no curses: older worlds hash as before).
var events: Array[EventTable] = []
var curses: Array[CurseTable] = []
var rules := EventRules.new()
## `loot:event` (rolls when a panel first opens, the cursed chest rolls, the ambush) and `ai:elite` (the elite
## curse's roll per spawn): sub-streams of loot and ai (SIM_CONTRACTS §5), so no older draw moves.
var rng: RngStream
var rng_elite: RngStream

## The pedestals, parallel arrays in placement order: id, where, room, event index, Events.State, rolled (0/1), and
## per choice (Events.MAX_CHOICES each, flattened) the rolled card code (-1 = none) and curse (-1 = none).
var ids := PackedInt32Array()
var pos_x := PackedFloat32Array()
var pos_y := PackedFloat32Array()
var room := PackedInt32Array()
var event := PackedInt32Array()
var state := PackedInt32Array()
var rolled := PackedInt32Array()
var roll_card := PackedInt32Array()
var roll_curse := PackedInt32Array()
## The pedestal whose panel is open (an index), or -1: while >= 0 the world waits.
var open := -1
## Ambush Cache in progress: its pedestal (-1 none) and the pack's actor ids. Wandering Drone: its pedestal, ticks
## held inside the ring, ticks needed and the shards per floor it pays.
var ambush := -1
var ambush_ids := PackedInt32Array()
var defend := -1
var defend_ticks := 0
var defend_total := 0
var defend_reward := 0
## Overclock Vent's reward for this floor (per mille of Overclock damage).
var overclock_bonus := 0
## Elite actor ids alive (an Ambush pack, or spawns under an elite curse).
var elite_ids := PackedInt32Array()
## Cursed chest offers: reward id, the cursed card's slot and its curse.
var cursed_ids := PackedInt32Array()
var cursed_slot := PackedInt32Array()
var cursed_curse := PackedInt32Array()
## For the views: the last choice taken (tick, pedestal, choice), a refused pick, a curse gained (tick, curse), a
## curse lifted (tick, curse) and an ambush or defence finished (tick, pedestal).
var result_tick := -1
var result_pedestal := -1
var result_choice := -1
var denied_tick := -1
var curse_tick := -1
var curse_last := -1
var cleanse_tick := -1
var cleanse_last := -1
var done_tick := -1
var done_pedestal := -1
## Dev runs only (DebugApi): the next chest offer rolled is cursed.
var force_curse := false


func size() -> int:
	return ids.size()


func pos(k: int) -> Vector2:
	return Vector2(pos_x[k], pos_y[k])


func add(id: int, at: Vector2, p_room: int, p_event: int) -> void:
	ids.append(id)
	pos_x.append(at.x)
	pos_y.append(at.y)
	room.append(p_room)
	event.append(p_event)
	state.append(Events.State.READY)
	rolled.append(0)
	for c in Events.MAX_CHOICES:
		roll_card.append(-1)
		roll_curse.append(-1)


func touched(w: World) -> bool:
	return (
		not ids.is_empty()
		or not w.curses_owned.is_empty()
		or w.threat_peak > 0
		or w.deep_threat > 0
		or rng != null
	)


func hash_into(h: StateHasher) -> void:
	for s in [rng, rng_elite]:
		h.add_int(s.state if s != null else 0)
	for a in [ids, room, event, state, rolled, roll_card, roll_curse]:
		h.add_ints(a)
	h.add_f32s(pos_x)
	h.add_f32s(pos_y)
	for v in [open, ambush, defend, defend_ticks, defend_total, defend_reward, overclock_bonus]:
		h.add_int(v)
	for a in [ambush_ids, elite_ids, cursed_ids, cursed_slot, cursed_curse]:
		h.add_ints(a)
	for v in [result_tick, result_pedestal, result_choice, denied_tick, curse_tick, curse_last]:
		h.add_int(v)
	for v in [cleanse_tick, cleanse_last, done_tick, done_pedestal, 1 if force_curse else 0]:
		h.add_int(v)
