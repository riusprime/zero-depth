class_name Starbound
extends RefCounted
## v0.10.5 W3-P10b (owner W7, docs/roadmap/v0.10.5/W3_W7_LOOP_POWER_G1.md §B; SIM_CONTRACTS §8n): the Starbound cards,
## a card kind offered from loop 2 only, with both weapons, no level cap (each pick adds a stack; World.starbound,
## run-long, saved and hashed) and never in the shop. Their numbers are content (StarboundTable, per stack):
## - the offer (B0): a regular altar's offer gets one Starbound card with RewardTable.starbound_permille's chance for
##   the loop (20 % at loop 2, 30 % from loop 3), in place of one of its cards; drawn from a named stream of its own
##   per altar ("loot:starbound:<loop>:<floor>:<reward id>", derived from the floor's seed), so the loop-1 loot
##   stream and every loop-1 offer stay as they were (T3). Taking it is the normal pick (Rewards.choose).
## - B1 Arc Jump: the first direct hit of a root of yours (a weapon hit: no effect id, proc 100, melee or projectile;
##   one chain a root, World.starbound_jump_roots) jumps to the nearest living enemy within reach_m of the one just hit
##   that this chain hasn't hit (ties: the lower index), amount jumps a stack, each at share_permille of the jump before
##   (the first: of the hit before the struck enemy's own multipliers, W3-P10k). A jump hits but never jumps again
##   (EFFECT_ARC_JUMP: an already-scaled hit, Damage.hit, that feeds no status; each target applies its own
##   multipliers).
## - B2 Rising Edge: each crit of yours adds amount crit damage a stack, at most cap a stack, until the room is
##   cleared (Stats.crit_mult adds it past the crit-damage cap).
## - B3 Echo Cast: a root weapon attack repeats (the Gun Echo path: ModifierRuntime.queue_again, the REPEAT bit, a
##   repeat never repeats) with amount x stacks per mille: each whole 1000 a sure repeat, the rest the chance of one
##   more (one draw on "combat:starbound_echo:<tick>:<launch>"), at most cap repeats; the Blade's steps too.
## - B4 Fervour: each kill of yours adds amount haste a stack, at most cap a stack, until the room is cleared
##   (AttackRate adds it to the raw bonus, so it counts toward the overflow past the curve too).
## - B5 Detonation: an enemy you kill bursts for amount x stacks per mille of its max HP to the enemies within reach_m
##   of it (bosses and elites take share_permille of it); a burst that kills sets off the next; at most
##   BURSTS_PER_TICK bursts a tick, the rest dropped with one LIMIT event (EFFECT_BURST_CAP).
## - C6 Supernova (Constellations.SUPERNOVA): every stack counts twice (stacks(), the one read all five use).
## "The room is cleared": no living enemy in the hero's room (FloorLayout.room_of, its rect grown by
## Arenas.ROOM_MARGIN_M), with no arena or Lockdown sealed; checked each tick while a counter is above 0 (advance).
## W3-P10k: between rooms (a corridor, a doorway) no living enemy within CORRIDOR_CLEAR_M of the hero nor in a room
## whose grown rect holds the hero, so a walk down a corridor away from the fight resets the counters too.
## The view (V1-V3) reads the bursts and jumps of World.starbound_fx_* (never hashed). Integer maths; no randomness
## but the named streams above (EI-05).

const ARC_JUMP := 0
const RISING_EDGE := 1
const ECHO_CAST := 2
const FERVOUR := 3
const DETONATION := 4
const COUNT := 5
## Offered from this loop on.
const FROM_LOOP := 2
const EFFECT_ARC_JUMP := &"starbound_arc_jump"
const EFFECT_DETONATION := &"starbound_detonation"
const EFFECT_BURST_CAP := &"starbound_burst_cap"
const BURSTS_PER_TICK := 24
## W3-P10k: Arc Jump remembers this many roots that already jumped (one chain a root; its hits come close together).
const JUMP_ROOTS_MAX := 16
## W3-P10k: a hero between rooms (a corridor) has cleared the room once no living enemy is within this many metres
## (a starting value), nor in a room whose edge (grown by Arenas.ROOM_MARGIN_M) the hero stands in (a doorway).
const CORRIDOR_CLEAR_M := 10.0
## W3-P10k: Echo Cast's merged damage is kept within this (an int32 shot's damage).
const ECHO_CARRY_MAX := 1 << 30
## Echo Cast's first repeat this many ticks after the attack (0.17 s), each next ModifierRuntime.REPEAT_GAP_TICKS later.
const ECHO_DELAY_TICKS := 10
const STREAM_OFFER := "loot:starbound"
const STREAM_ECHO := "combat:starbound_echo"
## The view's log (World.starbound_fx_*): a burst, a jump; kept this many entries at most.
const FX_BURST := 0
const FX_JUMP := 1
const FX_MAX := 96


static func enabled(w: World) -> bool:
	return w.starbound_tables.size() == COUNT


static func table(w: World, k: int) -> StarboundTable:
	return w.starbound_tables[k] if k >= 0 and k < w.starbound_tables.size() else null


## Card k's picks (its stacks as taken).
static func picks(w: World, k: int) -> int:
	return w.starbound[k] if k >= 0 and k < w.starbound.size() else 0


## Card k's stacks in play: its picks, twice with Supernova (C6). Every rule reads this.
static func stacks(w: World, k: int) -> int:
	var n := picks(w, k)
	if n > 0 and Constellations.has(w, Constellations.SUPERNOVA):
		return n * 2
	return n


## Card k is taken (BuildSlots, the pick): one more stack.
static func take(w: World, k: int) -> void:
	if k < 0 or k >= COUNT:
		return
	if w.starbound.size() < COUNT:
		w.starbound.resize(COUNT)
	w.starbound[k] += 1


# --- The offer (B0) -----------------------------------------------------------------------------------------------
## The chance per mille that a regular altar's offer holds a Starbound card now (0 before loop 2).
static func offer_permille(w: World) -> int:
	if w.loop < FROM_LOOP or not enabled(w):
		return 0
	var by := w.reward_table.starbound_permille
	if by.is_empty():
		return 0
	return by[mini(w.loop - FROM_LOOP, by.size() - 1)]


## The Starbound card (its index) reward i's offer gets, or -1. Pure: its own named stream for this altar, drawn the
## same however often it is asked (the e2e reads it before opening the altar).
static func offer_card(w: World, i: int) -> int:
	var chance := offer_permille(w)
	if chance <= 0 or i < 0 or i >= w.rewards.size():
		return -1
	var stream := "%s:%d:%d:%d" % [STREAM_OFFER, w.loop, w.floor_index, w.rewards.ids[i]]
	var rng := RngStream.derive(w.seed_value, stream)
	if rng.range_int(0, 999) >= chance:
		return -1
	var wts := PackedInt32Array()
	for t in w.starbound_tables:
		wts.append(t.weight)
	return Offers.pick(rng, wts)


## Offers.roll, regular altar i's fresh offer `out`: its Starbound card (offer_card) in place of the last card that
## is neither its leading fresh ability, the only compatible card nor a jackpot card (appended to a short offer).
static func into_offer(w: World, i: int, out: PackedInt32Array) -> PackedInt32Array:
	var k := offer_card(w, i)
	if k < 0 or out.is_empty():
		return out
	var code := Offers.starbound_code(k)
	if out.size() < w.reward_table.offer_size:
		out.append(code)
		return out
	out[_slot(w, i, out)] = code
	return out


static func _slot(w: World, i: int, out: PackedInt32Array) -> int:
	var first := 1 if out.size() > 1 and Offers.type_of(out[0]) == Offers.ABILITY else 0
	var fits := 0
	for c in out:
		if LootPacing.compatible(w, c):
			fits += 1
	for k in range(out.size() - 1, first - 1, -1):
		if LootPacing.is_jackpot(w, w.rewards.ids[i], out[k]):
			continue
		if fits != 1 or not LootPacing.compatible(w, out[k]):
			return k
	return out.size() - 1


# --- The rules ----------------------------------------------------------------------------------------------------
## Damage.hit: a hit of the player's landed on actor `i` (got > 0): `carried` its amount before i's own multipliers
## (W3-P10k: after the damage stat and the crit; no weak spot, Hunter's Sky, boss challenge or matchup of i's, and not
## clamped to its HP), its tags, effect and proc. A crit counts for Rising Edge; the first direct hit (a weapon hit) of
## a root jumps (Arc Jump: one chain a root, as every proc).
static func on_player_hit(
	w: World, i: int, carried: int, tags: int, effect_id: StringName, proc_pct: int, root: int
) -> void:
	if tags & SimEvent.TAG_CRIT and stacks(w, RISING_EDGE) > 0:
		w.starbound_crits = mini(w.starbound_crits + 1, _count_cap(w, RISING_EDGE))
	var direct := (
		effect_id == &""
		and proc_pct >= 100
		and (tags & SimEvent.TAG_DOT) == 0
		and (tags & (SimEvent.TAG_MELEE | SimEvent.TAG_PROJECTILE)) != 0
	)
	if direct and stacks(w, ARC_JUMP) > 0 and _first_of_root(w, root):
		_arc_jump(w, i, carried, root)


## W3-P10k: true the first time root `root` asks (it is remembered, the last JUMP_ROOTS_MAX roots); root 0 always.
static func _first_of_root(w: World, root: int) -> bool:
	if root == 0:
		return true
	if w.starbound_jump_roots.has(root):
		return false
	if w.starbound_jump_roots.size() >= JUMP_ROOTS_MAX:
		w.starbound_jump_roots.remove_at(0)
	w.starbound_jump_roots.append(root)
	return true


## B1: up to amount x stacks jumps from actor i, each at share_permille of the one before.
static func _arc_jump(w: World, i: int, dealt: int, root: int) -> void:
	var t := table(w, ARC_JUMP)
	if t == null:
		return
	var a := w.actors
	var pid := a.ids[0]
	var hit := PackedInt32Array([i])
	var from := a.pos(i)
	var d := dealt
	for n in t.amount * stacks(w, ARC_JUMP):
		d = d * t.share_permille / 1000
		if d <= 0:
			return
		var next := _nearest(w, from, t.reach_m, hit)
		if next < 0:
			return
		hit.append(next)
		var to := a.pos(next)
		_fx(w, FX_JUMP, from, to)
		Damage.hit(w, next, d, pid, pid, root, 0, from, to, EFFECT_ARC_JUMP)
		from = to


## The nearest living enemy to `from` whose body is within `reach` and not in `skip` (ties: the lower index), or -1.
static func _nearest(w: World, from: Vector2, reach: float, skip: PackedInt32Array) -> int:
	var a := w.actors
	var best := -1
	var best_d := 0.0
	for c in w.aoe_candidates(from, reach):
		if a.dead[c] == 1 or a.teams[c] == ActorStore.TEAM_PLAYER or skip.has(c):
			continue
		var d := Kin.length(a.pos(c) - from)
		if d > reach + a.radius[c]:
			continue
		if best < 0 or d < best_d:
			best = c
			best_d = d
	return best


## Damage._apply: the player killed actor i (in chain `root`): Fervour counts it, Detonation bursts it.
static func on_kill(w: World, i: int, root: int) -> void:
	if stacks(w, FERVOUR) > 0:
		w.starbound_kills = mini(w.starbound_kills + 1, _count_cap(w, FERVOUR))
	var n := stacks(w, DETONATION)
	var t := table(w, DETONATION)
	if n <= 0 or t == null:
		return
	var dmg := w.actors.max_hp[i] * t.amount * n / 1000
	if dmg <= 0:
		return
	w.sb_burst_pos.append(w.actors.pos(i))
	w.sb_burst_dmg.append(dmg)
	w.sb_burst_root.append(root)
	if w.sb_draining:
		return  # a burst's own kill: the chain below takes it next
	w.sb_draining = true
	var k := 0
	while k < w.sb_burst_pos.size():
		_burst(w, t, w.sb_burst_pos[k], w.sb_burst_dmg[k], w.sb_burst_root[k])
		k += 1
	w.sb_burst_pos.clear()
	w.sb_burst_dmg.clear()
	w.sb_burst_root.clear()
	w.sb_draining = false


## B5: one burst at `at` for `dmg` (bosses and elites share_permille of it), within the tick's cap.
static func _burst(w: World, t: StarboundTable, at: Vector2, dmg: int, root: int) -> void:
	if w.starbound_burst_tick != w.tick:
		w.starbound_burst_tick = w.tick
		w.starbound_bursts = 0
	w.starbound_bursts += 1
	var a := w.actors
	var pid := a.ids[0]
	if w.starbound_bursts > BURSTS_PER_TICK:
		if w.starbound_bursts == BURSTS_PER_TICK + 1:
			var lim := w.emit_event(SimEvent.Kind.LIMIT, pid, pid, pid, at)
			lim.effect_id = EFFECT_BURST_CAP
			lim.amount = BURSTS_PER_TICK
		return
	_fx(w, FX_BURST, at, at)
	var targets := PackedInt32Array()
	for c in w.aoe_candidates(at, t.reach_m):
		if a.dead[c] == 1 or a.teams[c] == ActorStore.TEAM_PLAYER:
			continue
		if AttackShapes.disc_touches(at, t.reach_m, a.pos(c), a.radius[c]):
			targets.append(c)
	for c in targets:
		if a.dead[c] == 1:
			continue
		var d := dmg
		if BossAi.is_boss_kind(a.kinds[c]) or _elite(w, c):
			d = maxi(1, d * t.share_permille / 1000)
		Damage.hit(w, c, d, pid, pid, root, 0, at, a.pos(c), EFFECT_DETONATION)


static func _elite(w: World, i: int) -> bool:
	if EliteAi.is_elite_kind(w.actors.kinds[i]):
		return true
	return w.elites != null and w.elites.ids.has(w.actors.ids[i])


## B3, Attacks.launch: root weapon attack `spec` launched with `ctx` (depth 0, not a repeat nor a back copy) repeats.
static func echo_cast(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	var n := stacks(w, ECHO_CAST)
	var t := table(w, ECHO_CAST)
	if n <= 0 or t == null:
		return
	var total := t.amount * n
	var reps := mini(total / 1000, t.cap)
	var rest := total % 1000
	if reps < t.cap and rest > 0:
		var stream := "%s:%d:%d" % [STREAM_ECHO, w.tick, w.launch_count]
		if RngStream.derive(w.seed_value, stream).range_int(0, 999) < rest:
			reps += 1
	if reps > 0:
		ModifierRuntime.queue_again(w, spec, ctx, reps, ECHO_DELAY_TICKS)


## W3-P10k (B3; the class doc of ShotCap: shots past it merge and keep the damage): an Echo Cast repeat with no shot
## room left keeps its volley's damage `dmg` (raw, before the hit's multipliers) for the next own shot (take_echo).
static func carry_echo(w: World, dmg: int) -> void:
	w.starbound_echo_carry = mini(w.starbound_echo_carry + maxi(0, dmg), ECHO_CARRY_MAX)


## The merged Echo Cast damage, taken by the player's own next shot (Attacks._bolts, WandRings.launch), emptied.
static func take_echo(w: World) -> int:
	var d := w.starbound_echo_carry
	w.starbound_echo_carry = 0
	return d


## The crit-damage bonus now, per mille (B2: Stats.crit_mult adds it).
static func crit_bonus(w: World) -> int:
	return _ramp(w, RISING_EDGE, w.starbound_crits)


## The haste bonus now, per mille of raw attack speed (B4: AttackRate adds it).
static func haste_bonus(w: World) -> int:
	if w.starbound.is_empty():
		return 0
	return _ramp(w, FERVOUR, w.starbound_kills)


## Card k's bonus after `count` crits or kills: min(count x amount, cap) a stack.
static func _ramp(w: World, k: int, count: int) -> int:
	var n := stacks(w, k)
	var t := table(w, k)
	if n <= 0 or t == null or count <= 0:
		return 0
	return mini(count * t.amount, t.cap) * n


## The most crits or kills that still add (cap / amount, rounded up), so the counter stays small.
static func _count_cap(w: World, k: int) -> int:
	var t := table(w, k)
	if t == null or t.amount <= 0:
		return 0
	return (t.cap + t.amount - 1) / t.amount


## Tick phase 9 (after the arenas): a cleared room resets Rising Edge's crits and Fervour's kills.
static func advance(w: World) -> void:
	if (w.starbound_crits > 0 or w.starbound_kills > 0) and room_cleared(w):
		w.starbound_crits = 0
		w.starbound_kills = 0


## No living enemy in the hero's room, and no arena or Lockdown sealed. W3-P10k: between rooms, no living enemy within
## CORRIDOR_CLEAR_M of the hero nor in a room whose grown rect holds the hero (a doorway).
static func room_cleared(w: World) -> bool:
	if w.arenas.sealed() or (w.lockdown != null and w.lockdown.sealed()):
		return false
	var a := w.actors
	var rects: Array[Rect2] = []
	var near := -1.0
	var me := w.player_pos()
	var whole := w.floor_layout == null or w.floor_layout.rooms.is_empty()
	if not whole:
		var room := w.floor_layout.room_of(me)
		if room >= 0:
			rects.append(w.floor_layout.rooms[room].grow(Arenas.ROOM_MARGIN_M))
		else:
			near = CORRIDOR_CLEAR_M
			for r in w.floor_layout.rooms:
				if r.grow(Arenas.ROOM_MARGIN_M).has_point(me):
					rects.append(r.grow(Arenas.ROOM_MARGIN_M))
	for i in range(1, a.size()):
		if a.dead[i] != 0 or a.teams[i] == ActorStore.TEAM_PLAYER:
			continue
		var p := a.pos(i)
		if whole or (near >= 0.0 and Kin.length(p - me) <= near + a.radius[i]):
			return false
		for r in rects:
			if r.has_point(p):
				return false
	return true


## The view's log: a burst at `from` or a jump from `from` to `to`, this tick (the oldest dropped past FX_MAX).
static func _fx(w: World, kind: int, from: Vector2, to: Vector2) -> void:
	if w.starbound_fx_kind.size() >= FX_MAX:
		w.starbound_fx_kind.remove_at(0)
		w.starbound_fx_tick.remove_at(0)
		w.starbound_fx_from.remove_at(0)
		w.starbound_fx_to.remove_at(0)
	w.starbound_fx_kind.append(kind)
	w.starbound_fx_tick.append(w.tick)
	w.starbound_fx_from.append(from)
	w.starbound_fx_to.append(to)


static func hash_into(w: World, h: StateHasher) -> void:
	h.add_ints(w.starbound)
	for v in [w.starbound_crits, w.starbound_kills, w.starbound_burst_tick, w.starbound_bursts]:
		h.add_int(v)
	h.add_ints(w.starbound_jump_roots)  # v0.10.5 W3-P10k
	h.add_int(w.starbound_echo_carry)


## For the HUD and the pick (WorldReader.starbound): each card's id, picks, stacks in play, and the room counters.
static func read(w: World) -> Dictionary:
	var cards: Array[Dictionary] = []
	for k in w.starbound_tables.size():
		(
			cards
			. append(
				{
					"id": w.starbound_tables[k].id,
					"picks": picks(w, k),
					"stacks": stacks(w, k),
				}
			)
		)
	return {
		"cards": cards,
		"crits": w.starbound_crits,
		"kills": w.starbound_kills,
		"crit_bonus": crit_bonus(w),
		"haste_bonus": haste_bonus(w),
	}
