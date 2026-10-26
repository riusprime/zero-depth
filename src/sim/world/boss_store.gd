# gdlint: disable=max-public-methods
class_name BossStore
extends RefCounted
## The live bosses' own state (v0.3.0 C), beside their actor entry (which holds the position, HP, the AI state and
## its locks). Parallel arrays in ascending actor-id order; an entry leaves when its boss dies (World._remove_dead).
## Hashed only in a world that has boss tables, so the kernel golden is unchanged.

## Points a move may lock per boss (lanes' lengths, egg and shell spots).
const MAX_PTS := 8
const INT_FIELDS: Array[StringName] = [
	&"ids",
	&"table",
	&"phase",
	&"meter",
	&"stagger_t",
	&"attack",
	&"step",
	&"last_attack",
	&"entry",
	&"hit",
	&"span",
	&"far_t",
	&"exposed_t",
	&"chained",
	&"fight_t",
	&"close_t",
	&"hazard_cd",
	&"gap_t",
	&"dash_t",
	&"gate_t"
]
## v0.9.0 NB2: the twin pairs' fields (BossTwin), one entry per pair.
const TWIN_FIELDS: Array[StringName] = [
	&"twin_lead", &"twin_body", &"twin_angry", &"twin_anger_t", &"twin_burn_cd"
]

## The boss's actor id, and its index in World.boss_tables.
var ids := PackedInt32Array()
var table := PackedInt32Array()
## Current phase (index into the table's phases).
var phase := PackedInt32Array()
## Stagger meter in milli-points, and ticks of stagger left (0 = not staggered).
var meter := PackedInt32Array()
var stagger_t := PackedInt32Array()
## The attack in progress (-1 = none), its stage (a leap's count, a burrow's stage), and the last attack started.
var attack := PackedInt32Array()
var step := PackedInt32Array()
var last_attack := PackedInt32Array()
## The entry attack waiting to start (-1 = none), set when a phase begins.
var entry := PackedInt32Array()
## 1 once this attack (or this leap) has hit the player: one hit per attack.
var hit := PackedInt32Array()
## A rail sweep's signed span (1/4096 turns), from its start angle (the actor's lock_a).
var span := PackedInt32Array()
## Boss challenge (v0.3.0 BX; BossChallenge): ticks the player has stayed beyond the punish distance; ticks the weak
## point stays open; 1 while the attack in progress is a follow-up (it can't chain again); ticks fought (after the
## rise); ticks since the arena began closing (0 = not yet); ticks until the closing band may hurt again.
var far_t := PackedInt32Array()
var exposed_t := PackedInt32Array()
var chained := PackedInt32Array()
var fight_t := PackedInt32Array()
var close_t := PackedInt32Array()
var hazard_cd := PackedInt32Array()
## v0.3.5 AI (owner F3): ticks the player has stayed out of reach (the gap-closer's clock), and ticks the last dash's
## landing point (dash_x, dash_y) stays the target of aimed attacks (0 = none).
var gap_t := PackedInt32Array()
var dash_t := PackedInt32Array()
## v0.5.5 DS (D7): ticks left of a phase gate's transition (BossGates; 0 = none).
var gate_t := PackedInt32Array()
var dash_x := PackedFloat32Array()
var dash_y := PackedFloat32Array()
## The boss room's interior (wall face to wall face) the closing band creeps in from; empty = no closing arena (the
## run flow sets it when the door seals).
var arena := Rect2()
## Locked points, MAX_PTS per boss: [x, y] spots, or a lane's length in x.
var pts_x := PackedFloat32Array()
var pts_y := PackedFloat32Array()
## v0.8.0 BS1 (owner O5; BossSignatures): the signature mechanics' standing pieces, lists of their own (not per
## boss entry; each names its boss's actor id). Empty until a fight raises one, and hashed only then, so every
## fight before BS1 hashes as before (WorldSnapshot.ADDED_SINCE_V05 lists them: an older save has none).
## S1, the Gatekeeper's stone pillars: centre, half side (metres), the tick each rose and the tick it sinks. Each is
## also a wall (World.walls, as a barrier) while it stands.
var pillar_x := PackedFloat32Array()
var pillar_y := PackedFloat32Array()
var pillar_h := PackedFloat32Array()
var pillar_from := PackedInt32Array()
var pillar_until := PackedInt32Array()
var pillar_boss := PackedInt32Array()
## S2, the Warlord's javelins stuck in the floor: where each stopped, the angle it flew out along (1/4096 turns),
## its boss's actor id, the boss attack that threw it, the tick it stuck and the tick it flies back.
var jav_x := PackedFloat32Array()
var jav_y := PackedFloat32Array()
var jav_a := PackedInt32Array()
var jav_boss := PackedInt32Array()
var jav_attack := PackedInt32Array()
var jav_from := PackedInt32Array()
var jav_back := PackedInt32Array()
## v0.8.0 BS2 (owner O5; S6), the Foundry's molten floor: each piece an axis-aligned box (centre, half sizes in
## metres), the tick it was laid and the tick it cools, its boss's actor id and the attack that laid it.
var lava_x := PackedFloat32Array()
var lava_y := PackedFloat32Array()
var lava_hx := PackedFloat32Array()
var lava_hy := PackedFloat32Array()
var lava_from := PackedInt32Array()
var lava_until := PackedInt32Array()
var lava_boss := PackedInt32Array()
var lava_attack := PackedInt32Array()
## S6, the meltdown (one per boss at most, for good): its boss's actor id and attack, the tick the outer ring first
## melted and the radius it melted to then, the room's centre, and the exit its cool bridge reaches (melt_exit 1; 0 =
## no exit, no bridge).
var melt_boss := PackedInt32Array()
var melt_attack := PackedInt32Array()
var melt_from := PackedInt32Array()
var melt_r0 := PackedFloat32Array()
var melt_x := PackedFloat32Array()
var melt_y := PackedFloat32Array()
var melt_ex := PackedFloat32Array()
var melt_ey := PackedFloat32Array()
var melt_exit := PackedInt32Array()
## S6: ticks until molten floor (lava or the melt) may burn the player again (0 while none is down).
var burn_cd := 0
## v0.9.0 NB1 (BossTide): the signature's cadence, one entry per live boss that has one (the Tidecaller): its actor
## id and the tick its signature is next due. Empty for every other boss, and hashed only while an entry exists
## (WorldSnapshot.ADDED_SINCE_V05: an older save has none).
var sig_boss := PackedInt32Array()
var sig_due := PackedInt32Array()
## v0.9.0 NB2 (BossTwin): the twin bosses, one entry per pair alive (the Twin Wardens): the boss's actor id (its
## bar, its defeat) and its twin's, the body angry now (its actor id, 0 = neither) and the ticks its anger has left,
## and the ticks until the chain may burn the player again. Empty for every other boss, and hashed only while a pair
## lives (WorldSnapshot.ADDED_SINCE_V05: an older save has none).
var twin_lead := PackedInt32Array()
var twin_body := PackedInt32Array()
var twin_angry := PackedInt32Array()
var twin_anger_t := PackedInt32Array()
var twin_burn_cd := PackedInt32Array()
## v0.9.0 NB3 (BossJudge): the Clockwork Judge's echo. echo_boss is the actor id of the Judge recording (-1 = none);
## echo_x/echo_y the player's last positions, oldest first (one every echo_gap_ticks, at most echo_points); path_x,
## path_y the echo locked as it started (the points left after the safe spot) and path_k each one's step (it strikes
## on active tick path_k × echo_gap_ticks). Hashed only while a Judge records (WorldSnapshot.ADDED_SINCE_V05: an
## older save has none).
var echo_boss := -1
var echo_x := PackedFloat32Array()
var echo_y := PackedFloat32Array()
var path_x := PackedFloat32Array()
var path_y := PackedFloat32Array()
var path_k := PackedInt32Array()
## v0.9.0 NB4 (BossShade): the Lantern Shade's light. shade_boss is the Shade's actor id (-1 = none); shade_dark 1 while
## a Lights Out has the room snuffed; shade_at the tick its next Lights Out snuffs the room and relights the lanterns
## (-1 = none pending) and shade_from the tick that Lights Out began; NB4b: shade_until the tick the dark lifts (-1 =
## not dark, or a table with no dark_hold_ticks: dark until the Shade dies); lamp_x/lamp_y the room's edge lanterns
## and lamp_t each one's lit ticks left (0 = out). Hashed only while a Shade lives (WorldSnapshot.ADDED_SINCE_V05: an
## older save has none).
var shade_boss := -1
var shade_dark := 0
var shade_at := -1
var shade_from := -1
var shade_until := -1
var lamp_x := PackedFloat32Array()
var lamp_y := PackedFloat32Array()
var lamp_t := PackedInt32Array()
## v0.9.5 BH4 (BossStream): the Tidecaller's streams. One entry per live boss with them (its actor id, the tick its next
## ring is due, the rings fired and the tick its next waves form), and one per crossing wave on the floor (its boss's
## actor id, its wave attack, the tick it formed, the way it travels (1/4096 turns), 1 once it has hit the player,
## the middle of its starting line on the wall, its length, and how far its middle travels). Hashed only while any
## exists
## (WorldSnapshot.ADDED_SINCE_V05: an older save has none).
var str_boss := PackedInt32Array()
var str_ring_due := PackedInt32Array()
var str_ring_n := PackedInt32Array()
var str_wave_due := PackedInt32Array()
var wv_boss := PackedInt32Array()
var wv_atk := PackedInt32Array()
var wv_from := PackedInt32Array()
var wv_dir := PackedInt32Array()
var wv_hit := PackedInt32Array()
var wv_x := PackedFloat32Array()
var wv_y := PackedFloat32Array()
var wv_len := PackedFloat32Array()
var wv_run := PackedFloat32Array()


func size() -> int:
	return ids.size()


func add(id: int, table_index: int) -> int:
	for f in INT_FIELDS:
		var ai: PackedInt32Array = get(f)
		ai.append(0)
		set(f, ai)
	for k in MAX_PTS:
		pts_x.append(0.0)
		pts_y.append(0.0)
	dash_x.append(0.0)
	dash_y.append(0.0)
	var b := ids.size() - 1
	ids[b] = id
	table[b] = table_index
	attack[b] = -1
	last_attack[b] = -1
	entry[b] = -1
	return b


## The entry for an actor id, or -1. Ids are ascending (bosses are added in spawn order), so one binary search.
func index_of(id: int) -> int:
	var k := ids.bsearch(id)
	return k if k < ids.size() and ids[k] == id else -1


func pt(b: int, k: int) -> Vector2:
	return Vector2(pts_x[b * MAX_PTS + k], pts_y[b * MAX_PTS + k])


func set_pt(b: int, k: int, p: Vector2) -> void:
	pts_x[b * MAX_PTS + k] = p.x
	pts_y[b * MAX_PTS + k] = p.y


func remove(b: int) -> void:
	for f in INT_FIELDS:
		var ai: PackedInt32Array = get(f)
		ai.remove_at(b)
		set(f, ai)
	for k in MAX_PTS:
		pts_x.remove_at(b * MAX_PTS)
		pts_y.remove_at(b * MAX_PTS)
	dash_x.remove_at(b)
	dash_y.remove_at(b)


func hash_into(h: StateHasher) -> void:
	for f in INT_FIELDS:
		h.add_ints(get(f))
	h.add_f32s(pts_x)
	h.add_f32s(pts_y)
	h.add_f32s(dash_x)
	h.add_f32s(dash_y)
	for v in [arena.position.x, arena.position.y, arena.size.x, arena.size.y]:
		h.add_f32(v)
	if pillar_x.size() + jav_x.size() > 0:
		_hash_signatures(h)
	if lava_x.size() + melt_boss.size() > 0:  # v0.8.0 BS2: only while molten floor is down
		_hash_molten(h)
	if not sig_boss.is_empty():  # v0.9.0 NB1: only while a boss with a cadence lives
		h.add_int(-2)
		h.add_ints(sig_boss)
		h.add_ints(sig_due)
	if not twin_lead.is_empty():  # v0.9.0 NB2: only while a twin pair lives
		h.add_int(-3)
		for f: StringName in TWIN_FIELDS:
			h.add_ints(get(f))
	if echo_boss >= 0:  # v0.9.0 NB3: only while a Clockwork Judge records
		h.add_int(-4)
		h.add_int(echo_boss)
		h.add_f32s(echo_x)
		h.add_f32s(echo_y)
		h.add_f32s(path_x)
		h.add_f32s(path_y)
		h.add_ints(path_k)
	if shade_boss >= 0:  # v0.9.0 NB4: only while a Lantern Shade lives
		h.add_int(-5)
		h.add_ints(PackedInt32Array([shade_boss, shade_dark, shade_at, shade_from, shade_until]))
		h.add_f32s(lamp_x)
		h.add_f32s(lamp_y)
		h.add_ints(lamp_t)
	if not str_boss.is_empty() or not wv_boss.is_empty():  # v0.9.5 BH4: only while a Tidecaller's streams run
		h.add_int(-6)
		for f: StringName in [&"str_boss", &"str_ring_due", &"str_ring_n", &"str_wave_due"]:
			h.add_ints(get(f))
		for f: StringName in [&"wv_boss", &"wv_atk", &"wv_from", &"wv_dir", &"wv_hit"]:
			h.add_ints(get(f))
		for f: StringName in [&"wv_x", &"wv_y", &"wv_len", &"wv_run"]:
			h.add_f32s(get(f))


## v0.9.5 BH4: the stream entry of boss `boss_id`, or -1.
func str_of(boss_id: int) -> int:
	return str_boss.find(boss_id)


## v0.9.5 BH4: a new stream entry for boss `boss_id` (rings and waves due at the given ticks).
func add_stream(boss_id: int, ring_due: int, wave_due: int) -> int:
	str_boss.append(boss_id)
	str_ring_due.append(ring_due)
	str_ring_n.append(0)
	str_wave_due.append(wave_due)
	return str_boss.size() - 1


## v0.9.5 BH4: removes stream entry k.
func remove_stream(k: int) -> void:
	for f: StringName in [&"str_boss", &"str_ring_due", &"str_ring_n", &"str_wave_due"]:
		var ai: PackedInt32Array = get(f)
		ai.remove_at(k)
		set(f, ai)


## v0.9.5 BH4: removes crossing wave k.
func remove_wave(k: int) -> void:
	for f: StringName in [&"wv_boss", &"wv_atk", &"wv_from", &"wv_dir", &"wv_hit"]:
		var ai: PackedInt32Array = get(f)
		ai.remove_at(k)
		set(f, ai)
	for f: StringName in [&"wv_x", &"wv_y", &"wv_len", &"wv_run"]:
		var af: PackedFloat32Array = get(f)
		af.remove_at(k)
		set(f, af)


## v0.9.0 NB4: forgets the Lantern Shade's light (its boss gone: the room relights).
func clear_shade() -> void:
	shade_boss = -1
	shade_dark = 0
	shade_at = -1
	shade_from = -1
	shade_until = -1
	lamp_x = PackedFloat32Array()
	lamp_y = PackedFloat32Array()
	lamp_t = PackedInt32Array()


## v0.9.0 NB3: forgets the Clockwork Judge's echo (its boss gone).
func clear_echo() -> void:
	echo_boss = -1
	echo_x = PackedFloat32Array()
	echo_y = PackedFloat32Array()
	path_x = PackedFloat32Array()
	path_y = PackedFloat32Array()
	path_k = PackedInt32Array()


## v0.8.0 BS2 (S6): the lava, the meltdown and the burn clock.
func _hash_molten(h: StateHasher) -> void:
	for f in [lava_x, lava_y, lava_hx, lava_hy, melt_r0, melt_x, melt_y, melt_ex, melt_ey]:
		h.add_f32s(f)
	for f in [
		lava_from, lava_until, lava_boss, lava_attack, melt_boss, melt_attack, melt_from, melt_exit
	]:
		h.add_ints(f)
	h.add_int(burn_cd)


## v0.8.0 BS1: the pillars and javelins, only while any stands (and a sentinel between the two lists).
func _hash_signatures(h: StateHasher) -> void:
	h.add_f32s(pillar_x)
	h.add_f32s(pillar_y)
	h.add_f32s(pillar_h)
	h.add_ints(pillar_from)
	h.add_ints(pillar_until)
	h.add_ints(pillar_boss)
	h.add_int(-1)
	h.add_f32s(jav_x)
	h.add_f32s(jav_y)
	for f in [jav_a, jav_boss, jav_attack, jav_from, jav_back]:
		h.add_ints(f)


## v0.8.0 BS1: removes pillar k.
func remove_pillar(k: int) -> void:
	for f: StringName in [&"pillar_x", &"pillar_y", &"pillar_h"]:
		var af: PackedFloat32Array = get(f)
		af.remove_at(k)
		set(f, af)
	for f: StringName in [&"pillar_from", &"pillar_until", &"pillar_boss"]:
		var ai: PackedInt32Array = get(f)
		ai.remove_at(k)
		set(f, ai)


## v0.8.0 BS2: removes lava piece k.
func remove_lava(k: int) -> void:
	for f: StringName in [&"lava_x", &"lava_y", &"lava_hx", &"lava_hy"]:
		var af: PackedFloat32Array = get(f)
		af.remove_at(k)
		set(f, af)
	for f: StringName in [&"lava_from", &"lava_until", &"lava_boss", &"lava_attack"]:
		var ai: PackedInt32Array = get(f)
		ai.remove_at(k)
		set(f, ai)


## v0.8.0 BS2: removes meltdown k.
func remove_melt(k: int) -> void:
	for f: StringName in [&"melt_r0", &"melt_x", &"melt_y", &"melt_ex", &"melt_ey"]:
		var af: PackedFloat32Array = get(f)
		af.remove_at(k)
		set(f, af)
	for f: StringName in [&"melt_boss", &"melt_attack", &"melt_from", &"melt_exit"]:
		var ai: PackedInt32Array = get(f)
		ai.remove_at(k)
		set(f, ai)


## v0.9.0 NB1: the cadence entry of boss `boss_id`, or -1.
func sig_of(boss_id: int) -> int:
	return sig_boss.find(boss_id)


## v0.9.0 NB1: removes cadence entry k.
func remove_sig(k: int) -> void:
	sig_boss.remove_at(k)
	sig_due.remove_at(k)


## v0.9.0 NB2: the twin pair actor `id` is in (as the boss or its twin), or -1.
func twin_of(id: int) -> int:
	var k := twin_lead.find(id)
	return k if k >= 0 else twin_body.find(id)


## v0.9.0 NB2: a new twin pair (boss `lead`, twin `body`), calm, its chain ready.
func add_twin(lead: int, body: int) -> void:
	for f: StringName in TWIN_FIELDS:
		var ai: PackedInt32Array = get(f)
		ai.append(0)
		set(f, ai)
	twin_lead[twin_lead.size() - 1] = lead
	twin_body[twin_body.size() - 1] = body


## v0.9.0 NB2: removes twin pair k.
func remove_twin(k: int) -> void:
	for f: StringName in TWIN_FIELDS:
		var ai: PackedInt32Array = get(f)
		ai.remove_at(k)
		set(f, ai)


## v0.8.0 BS1: removes javelin k.
func remove_javelin(k: int) -> void:
	for f: StringName in [&"jav_x", &"jav_y"]:
		var af: PackedFloat32Array = get(f)
		af.remove_at(k)
		set(f, af)
	for f: StringName in [&"jav_a", &"jav_boss", &"jav_attack", &"jav_from", &"jav_back"]:
		var ai: PackedInt32Array = get(f)
		ai.remove_at(k)
		set(f, ai)
