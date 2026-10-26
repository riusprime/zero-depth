class_name BossGates
extends RefCounted
## Phase gates (v0.5.5 Step DS; owner D7: "we have to make bosses harder not only matching in some way the HP to our
## damage"; SIM_CONTRACTS §11). Mechanics HP can't skip, on every boss: each phase after the first (the data's HP
## thresholds, 66 % and 33 % on all six bosses) opens with a gate.
## - The HP can't fall past the next gate in one burst: damage on a boss stops at the gate's HP (clamp; DoT too)
##   until the gate has run. Only the world's own hits (owner 0: the dev panel's Kill boss) pass.
## - When the HP reaches it, the boss enters GATE for GATE_TICKS: its attack stops, it stands still, and the view
##   shows the transition (WorldReader.boss_gate_permille: a shell around the boss and "PHASE SHIFT" on the boss
##   bar). It deals no damage meanwhile (no damage without a readable cause).
## - v0.9.5 BH1 (owner Q3, H1): the gate is the boss's kneel, the only pause left in a fight (bosses no longer
##   stagger): 1.0 s (sim tuning gate_seconds) in which it does nothing but can be hit (the gate's HP floor still
##   holds), and its core's steal window opens for rules.core_window_ticks (3 s) from the gate's first tick.
## - The gate brings adds: clamp(floor + gate − 1, ADDS_MIN, ADDS_MAX) of the floor's enemy kinds (the spawn mix
##   open now, else the mix's first kind; none in a world without spawning, such as the boss labs), round-robin, on
##   a ring around the boss; they rise with the normal spawn-in (SimTick.SPAWN_IN_TICKS, no acting, no damage) and
##   arrive scaled like any enemy (World.queue_enemy).
## - Then the new phase starts with its entry attack (its own telegraph); the phase's attacks are new or faster.
## Pure: no stream is drawn (kinds and spots are fixed by the gate), so the fight's other rolls stay where they were.

## The transition's length (1.0 s; starting value).
const GATE_TICKS := 60
const ADDS_MIN := 2
const ADDS_MAX := 4
## The adds stand this far from the boss's centre (pulled in by walls).
const ADD_RING_M := 3.2
const EFFECT := &"boss_phase_gate"


## Boss i's HP floor until its next gate has run: the next phase's threshold of its max HP, or 0 in its last phase.
static func floor_hp(w: World, i: int) -> int:
	var b := BossAi.entry_of(w, i)
	if b < 0:
		return 0
	var t: BossTable = w.boss_tables[w.bosses.table[b]]
	var next := w.bosses.phase[b] + 1
	if next >= t.phase_threshold.size():
		return 0
	return t.phase_threshold[next] * w.actors.max_hp[i] / 1000


## Damage._apply: `amount` on actor i, cut so a boss's HP stops at its next gate. Unchanged for anything else and for
## the world's own hits (owner 0).
## v0.8.0 FB1: a final boss's body before the last keeps 1 HP, whoever hits it (FinalBoss.clamp_damage).
static func clamp_damage(w: World, i: int, amount: int, owner_id: int) -> int:
	if i == 0 or not BossAi.is_boss_kind(w.actors.kinds[i]):
		return amount
	if w.final_fight != null:
		amount = FinalBoss.clamp_damage(w, i, amount, owner_id)  # v0.8.0 N2: the pace's cap
	if owner_id == 0:
		return amount
	var lo := floor_hp(w, i)
	if lo <= 0:
		return amount
	return mini(amount, maxi(0, w.actors.hp[i] - lo))


## BossAi._update_phase: boss i (entry b) reached phase `gate` (1 = the first gate): the transition starts, its
## attack and stagger stop, the adds are queued, and STATUS_APPLY (effect boss_phase_gate, amount = the gate) is
## emitted for the views.
static func begin(w: World, i: int, b: int, gate: int) -> void:
	var a := w.actors
	var bs := w.bosses
	bs.gate_t[b] = w.tuning.gate_ticks
	bs.attack[b] = -1
	bs.stagger_t[b] = 0
	bs.meter[b] = 0
	a.lock_len[i] = 0.0
	a.state[i] = BossAi.GATE
	a.state_t[i] = 0
	CoreTheft.on_phase_change(w, i)  # v0.9.5 BH1 (H1, Q3): the core's steal window opens (3 s)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[i], a.ids[i], a.ids[i], a.pos(i))
	e.effect_id = EFFECT
	e.amount = gate
	if BossTwin.is_twin(w, i):
		return  # v0.9.0 NB2: one boss, one set of adds (its boss's gate brings them)
	var kinds := add_kinds(w)
	if kinds.is_empty():
		return
	var n := adds_for(w.floor_index, gate, w.tuning.gate_adds_min, w.tuning.gate_adds_max)
	for k in n:
		var kind := kinds[(k + gate) % kinds.size()]
		var at := BossAi.spot(w, a.pos(i), k * 4096 / n + gate * 512, w.tuning.gate_add_ring_m)
		w.queue_enemy(kind, at)


## How many adds gate `gate` brings on floor f.
static func adds_for(f: int, gate: int, lo: int = ADDS_MIN, hi: int = ADDS_MAX) -> int:
	return clampi(f + gate - 1, lo, hi)


## Tick phase 3 (BossAi.think), during the gate: the clock runs down, then the boss fights again (its entry attack
## first).
static func advance(w: World, i: int, b: int) -> void:
	var bs := w.bosses
	bs.gate_t[b] -= 1
	if bs.gate_t[b] > 0:
		return
	bs.gate_t[b] = 0
	w.actors.state[i] = EnemyAi.State.MOVE
	w.actors.state_t[i] = 0
	w.actors.cd[i] = 0


## The kinds the adds come from: the floor's spawn mix open now (in mix order, once each), else the mix's first kind
## with a table; empty without spawning. Never a boss.
static func add_kinds(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	if w.spawner == null:
		return out
	for k in SpawnDirector.unlocked(w, w.spawner, w.run_ticks):
		var kind := w.spawner.kinds[k]
		if not out.has(kind) and not BossAi.is_boss_kind(kind):
			out.append(kind)
	if out.is_empty():  # nothing open yet (the floor's first seconds): the mix's first kind
		for kind in w.spawner.kinds:
			if w.enemy_table(kind) != null and not BossAi.is_boss_kind(kind):
				out.append(kind)
				break
	return out


## 0..1000: how far boss i's gate has run (0 when it isn't in one; the view).
static func progress(w: World, i: int) -> int:
	var b := BossAi.entry_of(w, i)
	if b < 0 or w.actors.state[i] != BossAi.GATE:
		return 0
	return clampi(
		(w.tuning.gate_ticks - w.bosses.gate_t[b]) * 1000 / maxi(1, w.tuning.gate_ticks), 0, 1000
	)
