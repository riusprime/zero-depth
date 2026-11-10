# gdlint: disable=max-file-lines
class_name EnemyAi
extends RefCounted
## The v0.1.0 behaviours (owner Q3, 2026-10-06): Charger, Warden, Needle. A Warden turns only while it
## walks: once it starts a slam it is committed, so baiting the slam opens its back (the way to flank it).
## Each enemy is a small state machine in ActorStore (state, state_t, facing, lock_*, cd, fire_cd, windup, pick).
## think() runs in tick phase 3, move() in phase 5, resolve() in phase 6. Every attack's area comes from one function
## here, which the telegraph view also draws (EI-07): charge_lane, locked_disc, burst_lines, bolt_lanes, rune_disc.
## Each windup's length is drawn per attack (the ai:enemy stream); aimed shots lead the
## player by its velocity and keep tracking until the last COMMIT_TICKS of the windup; a charge turns toward the
## player at a limited rate; the Needle's burst fans out; enemies spread around the player instead of stacking.
## Two new kinds: the Arc Caster (a fast bolt, a 3-bolt spread, a rune that erupts under you) and the Bomb Drone
## (lobs a bomb whose circle fills until it lands). The drone hovers only in the view: here it is a ground body.
## v0.4.0 EN, six horde kinds: the Swarmer (a tiny Charger whose charge is a short lunge bite), the Splitter (swipes a
## disc ahead of it; dies into Splitlings, which swipe too and never split), the Shield Bearer (blocks from the front,
## turns slowly, bashes a short lane), the Mender (keeps away and heals hurt allies through a beam, no attack), the
## Mine Layer (drops mines; Mines) and the Sniper (a 60-tick line, a hit down it, then a walk to a new spot). Their
## shapes: locked_disc, bash_lane, snipe_lane, Mines.telegraph.
## The Arc Caster's bolt and spread, the Lens
## Drone's burst and the Bomb Drone's bomb become slow fireball patterns (EnemyTable.patterns, fired by BulletPatterns
## with its caps and fairness rules): a fan of 3 plasma balls (narrow or wide), a ring of 6 orbs, a lobbed fireball
## that bursts into an X of 4. They draw no line or circle on the ground: their windup is a body cue only ("cast",
## and the Bomb Drone's flying fireball "lob", both "ground": false). The Needle, the Sniper, the melee kinds, the
## Arc Caster's rune, the Mine Layer and the Mender are unchanged.
## The Needle, the Sniper and the melee kinds keep their shapes but go "ground": false too.
## v0.8.0 P1 (owner O25, playtest 2: "The large ground-smashing enemy no longer displays its red circular attack
## warning"): the Warden's slam disc is drawn on the ground again, the third exception with the rune and the mines.

enum State { SPAWN, MOVE, WINDUP, ACTIVE, RECOVER }

## The Arc Caster's spells (ActorStore.pick).
enum Spell { BOLT, SPREAD, RUNE }

## How World's per-actor loops step a kind (role_of): a critter (CritterAi), a boss (BossAi), a normal enemy, other.
enum Role { OTHER, CRITTER, BOSS, ENEMY }

const STRAFE_PERMILLE := 600
## Kinds that keep a distance band (_keeps_away).
const KEEP_AWAY: Array[int] = [
	ActorStore.Kind.ARC_CASTER,
	ActorStore.Kind.BOMB_DRONE,
	ActorStore.Kind.MENDER,
	ActorStore.Kind.MINE_LAYER,
	ActorStore.Kind.SNIPER,
	ActorStore.Kind.RIFT_HUNTER,  # Circling 4-6 m away between Rift Steps
	ActorStore.Kind.CONDUIT,  # drifting 7-10 m away
	ActorStore.Kind.WIRE_WEAVER,  # The Weaver and the Thrower keep their band (RuinsRocks)
	ActorStore.Kind.STONE_THROWER,
	ActorStore.Kind.CINDER_PRIEST,  # Its band until it stands by its vent (CanyonShore)
	ActorStore.Kind.FROST_SPITTER,
]
## Aimed windups stop tracking the player this many ticks before they fire (starting value, as the bosses').
const COMMIT_TICKS := 12
## Enemies closer than this to each other push apart while they walk (starting value).
const SPREAD_RADIUS_M := 1.6
const SPREAD_WEIGHT := 1.2
## Melee walkers inside this distance swing out to the side their id picks, so a pack surrounds the player.
const FLANK_RANGE_M := 6.0
const FLANK_MIN_M := 2.0
const FLANK_PERMILLE := 450
## The sight line's half-width (sees_player): thin, so a doorway's edge does not hide a player in the opening.
const SIGHT_R_M := 0.05
## A charge touches the player within this much of contact: the collision pass (phase 5) has already pushed the
## two bodies exactly apart before the hit check (phase 6), so an exact test missed by a rounding error.
const CONTACT_SLOP_M := 0.02
## Each enemy re-plans its walk every this many ticks, on the phase of its id (it moves every tick).
## 4 -> 8, so a crowd's planning costs half its share a tick. The
## attack checks, windups, hits and telegraphs still run every tick (think's state machine); only the walk's plan
## slows down. Its wall check now runs on every plan: every 8 ticks, as before.
const PLAN_PERIOD := 8
## (owner, 2026-11-04, W3-S10: elites plan every 4 ticks again; PD's 8 kept for the crowd)
const ELITE_PLAN_PERIOD := 4
## v0.4.0 EN (starting values). A Sniper's line stops following the player this many ticks before it fires.
const SNIPE_COMMIT_TICKS := 24
## After a shot a Sniper walks, this much faster, to a spot 45-90 degrees around the player (1/4096 turns), until it
## is within RELOCATE_DONE_M of it or RELOCATE_MAX_TICKS have passed.
const RELOCATE_SPEED_PERMILLE := 1500
const RELOCATE_MIN_TURN := 512
const RELOCATE_MAX_TURN := 1024
const RELOCATE_DONE_M := 0.5
const RELOCATE_MAX_TICKS := 150
## A Mender without a patient looks for one every this many ticks (staggered by its id).
const MEND_SCAN_TICKS := 15
## A Splitter's halves appear this far to either side of where it died.
const SPLIT_OFFSET_M := 0.45
## PLAN H1; owner Q14: the five horde critters, one per biome, one rule set: no attack and no windup; they
## chase the hero straight (no flanking: "fast but dumb") and hurt by touch (_critter_touch), contact_damage at most
## every contact_cd_ticks (their own clock, ActorStore.cd). A touch counts within CRITTER_TOUCH_M of contact (the walk
## stops 0.1 m short of it, and the collision pass pushes the bodies apart).
const CRITTERS: Array[int] = [
	ActorStore.Kind.DUST_MITE,
	ActorStore.Kind.CAVE_BAT,
	ActorStore.Kind.EMBER_FLEA,
	ActorStore.Kind.ICE_CRAB,
	ActorStore.Kind.STAR_MOTE,
]
const CRITTER_TOUCH_M := 0.15
## ENEMIES.md V1-V5: each biome variant's base kind (behaviour_of).
const VARIANT_BASE := {
	ActorStore.Kind.RUBBLE_WARDEN: ActorStore.Kind.WARDEN,
	ActorStore.Kind.DIM_NEEDLE: ActorStore.Kind.NEEDLE,
	ActorStore.Kind.EMBER_CHARGER: ActorStore.Kind.CHARGER,
	ActorStore.Kind.FROST_CHARGER: ActorStore.Kind.CHARGER,
	ActorStore.Kind.SPLIT_SNIPER: ActorStore.Kind.SNIPER,
}
## The kinds the per-kind lookups below cover (every ActorStore.Kind; a kind past them takes the slow test).
const KIND_SLOTS := 256
## Bits of a kind's flags_of: each one a pure test of the kind alone.
const F_ELITE := 1  # EliteAi.is_elite_kind
const F_VARIANT := 2  # Variants.is_variant
const F_CANYON := 4  # CanyonShore.owns
const F_RUINS := 8  # RuinsRocks.takes
const F_CRITTER := 16  # is_critter
const F_KEEPS_AWAY := 32  # _keeps_away
const F_TURNS_SLOWLY := 64  # _turns_slowly (and armoured: the same test)
const F_CHARGES := 128  # _charges

## The per-kind lookups, indexed by kind: each enemy's tick asks these tests many times, and a table read is cheaper
## than the Dictionary lookups, `in` scans and or-chains. Built once at load from the slow tests themselves (so they
## agree for every kind; test_enemy_ai checks it); they come from the code, not the world: nothing to hash or save.
static var _behaviour := _build_behaviour()
static var _flags := _build_flags()
## role_of by kind (World reads it in its loops).
static var roles := _build_roles()


static func is_enemy_kind(kind: int) -> bool:
	return kind >= ActorStore.Kind.CHARGER


## A horde critter (contact damage only).
static func is_critter(kind: int) -> bool:
	return (flags_of(kind) & F_CRITTER) != 0


## The F_* bits of a kind.
static func flags_of(kind: int) -> int:
	if (kind & -KIND_SLOTS) == 0:
		return _flags[kind]
	return _slow_flags(kind)


## The Role a kind is stepped as: the checks World's loops make, in their order.
static func role_of(kind: int) -> int:
	if (kind & -KIND_SLOTS) == 0:
		return roles[kind]
	return _slow_role(kind)


static func _slow_role(kind: int) -> int:
	if CritterAi.takes(kind):
		return Role.CRITTER
	if BossAi.is_boss_kind(kind):
		return Role.BOSS
	return Role.ENEMY if is_enemy_kind(kind) else Role.OTHER


static func _slow_behaviour(kind: int) -> int:
	if kind == ActorStore.Kind.LENS_DRONE:
		return ActorStore.Kind.NEEDLE
	return VARIANT_BASE.get(kind, CanyonShore.BASE.get(kind, kind))  # The Beetle and Turtle: a Warden


static func _slow_flags(kind: int) -> int:
	var base := _slow_behaviour(kind)
	var f := 0
	f |= F_ELITE if EliteAi.is_elite_kind(kind) else 0
	f |= F_VARIANT if Variants.is_variant(kind) else 0
	f |= F_CANYON if CanyonShore.owns(kind) else 0
	f |= F_RUINS if RuinsRocks.takes(kind) else 0
	f |= F_CRITTER if kind in CRITTERS else 0
	f |= F_KEEPS_AWAY if base in KEEP_AWAY else 0
	var slow_turn := base == ActorStore.Kind.WARDEN or kind == ActorStore.Kind.SHIELD_BEARER
	f |= F_TURNS_SLOWLY if slow_turn else 0
	var charges := (
		base == ActorStore.Kind.CHARGER
		or base == ActorStore.Kind.HATCHLING
		or base == ActorStore.Kind.SWARMER
	)
	f |= F_CHARGES if charges else 0
	return f


static func _build_behaviour() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(KIND_SLOTS)
	for k in KIND_SLOTS:
		out[k] = _slow_behaviour(k)
	return out


static func _build_flags() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(KIND_SLOTS)
	for k in KIND_SLOTS:
		out[k] = _slow_flags(k)
	return out


static func _build_roles() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(KIND_SLOTS)
	for k in KIND_SLOTS:
		out[k] = _slow_role(k)
	return out


## ENEMIES.md H2: enemy i flies low (the Cave Bat), so the floor's hazards never reach it: today the hero's
## ground mines (LaserMods: a flier never sets one off).
static func flies(w: World, i: int) -> bool:
	var t := w.enemy_table(w.actors.kinds[i])
	return t != null and t.flies


## The behaviour an actor kind runs: its own, except the Hive Lens's drones, which run the Needle's, and
## v0.11.0 O13a the biome variants, which run their base's (VARIANT_BASE; their twists: Variants).
static func behaviour_of(kind: int) -> int:
	if (kind & -KIND_SLOTS) == 0:
		return _behaviour[kind]
	return _slow_behaviour(kind)


## Chargers, the Brood Mother's hatchlings (a small Charger) and Swarmers run the charge (the Ember and
## Frost Chargers too).
static func _charges(kind: int) -> bool:
	return (flags_of(kind) & F_CHARGES) != 0


## Kinds that keep a distance band and shoot, lob, heal or lay mines from it (v0.3.5 AI, v0.4.0 EN).
static func _keeps_away(kind: int) -> bool:
	return (flags_of(kind) & F_KEEPS_AWAY) != 0


## Kinds that turn at a limited rate while they walk and hold their facing once they attack: a Warden's behaviour, or
## the Shield Bearer.
static func _turns_slowly(kind: int) -> bool:
	return (flags_of(kind) & F_TURNS_SLOWLY) != 0


## Kinds whose hits are softened or blocked by the direction they come from (Damage.target_mult): the slow turners.
static func armoured(kind: int) -> bool:
	return (flags_of(kind) & F_TURNS_SLOWLY) != 0


## The Mender: the target to kill first. The view marks it.
static func is_priority(kind: int) -> bool:
	return kind == ActorStore.Kind.MENDER


## True while actor i's windup aims a shot that still follows the player (it commits COMMIT_TICKS before it fires).
## A Sniper's line follows until SNIPE_COMMIT_TICKS before the shot.
static func tracking(w: World, i: int) -> bool:
	var a := w.actors
	var sniper := behaviour_of(a.kinds[i]) == ActorStore.Kind.SNIPER
	var commit := w.tuning.ai_snipe_commit_ticks if sniper else w.tuning.ai_commit_ticks
	if a.state[i] != State.WINDUP or a.state_t[i] >= a.windup[i] - commit:
		return false
	return (
		sniper
		or behaviour_of(a.kinds[i]) == ActorStore.Kind.NEEDLE
		or (a.kinds[i] == ActorStore.Kind.ARC_CASTER and a.pick[i] != Spell.RUNE)
		or a.kinds[i] == ActorStore.Kind.BOMB_DRONE
	)  # Its landing follows you until it commits


static func think(w: World, i: int) -> void:
	var a := w.actors
	var kind := a.kinds[i]  # Read once: an actor's kind never changes
	var f := flags_of(kind)
	if (f & F_ELITE) != 0:  # The elite archetypes run their own (its walk is plan's)
		EliteAi.think(w, i)
		return
	var planning := posmod(w.tick, PLAN_PERIOD) == posmod(a.ids[i], PLAN_PERIOD)  # plans_now, not an elite
	if planning:  # The staggered plan (before the frozen check: a thawed enemy has a fresh one)
		if w.phase_probe != null:  # The perf probe's phase timer (null in play)
			w.phase_probe.begin(&"ai.plan")
		plan(w, i)
		if w.phase_probe != null:
			w.phase_probe.end(&"ai.plan")
	if (f & F_VARIANT) != 0:  # The Rubble Warden's crust falls at half HP
		Variants.on_think(w, i)
	if (f & F_CANYON) != 0:  # A Cinder Priest takes or plants its vent
		CanyonShore.on_think(w, i)
	# Engines: frozen holds still; a spell stun (no call while no spell holds anyone)
	if a.frozen_t[i] > 0 or (not w.spell_hold_id.is_empty() and Spells.held_still(w, i)):
		return
	var t := w.enemy_table(kind)
	a.state_t[i] += 1
	if a.cd[i] > 0:
		a.cd[i] -= 1
	if (f & F_RUINS) != 0:  # The Ruins and Night Rocks signatures
		RuinsRocks.think(w, i, t, planning)
		return
	if a.state[i] >= BossSignatures.EGG:  # An egg waits, hatches or bursts
		BossSignatures.egg_think(w, i)
		return
	if (f & F_CRITTER) != 0:  # Rises in, then only walks (its touch is resolve's)
		if a.state[i] == State.SPAWN and a.state_t[i] >= w.tuning.spawn_in_ticks:
			enter_state(a, i, State.MOVE)
		elif a.state[i] == State.MOVE and planning:
			a.facing[i] = Kin.angle_of(w.player_pos() - a.pos(i))
		return
	if kind == ActorStore.Kind.GRAVITY_NODE:  # StarfallKinds.is_node: it floats in place and never attacks
		if a.state[i] == State.SPAWN and a.state_t[i] >= w.tuning.spawn_in_ticks:
			enter_state(a, i, State.MOVE)
		return
	var alive := not w.player_dead()
	match a.state[i]:
		State.SPAWN:
			if a.state_t[i] >= w.tuning.spawn_in_ticks:
				enter_state(a, i, State.MOVE)
		State.MOVE:
			var to_player := w.player_pos() - a.pos(i)
			var dist := Kin.length(to_player)
			var beh := behaviour_of(kind)
			# A Needle backs off before it shoots; the others attack as soon as they're in range.
			var too_close := beh == ActorStore.Kind.NEEDLE and dist < t.flee_distance_m
			var attack := alive and a.cd[i] == 0 and dist <= t.attack_range_m and not too_close
			# v0.9.0 (owner 2026-10-23: "when there are closed rooms the enemies can attack from outside, that should not
			# happen"): no attack starts without a clear line to the player (walls, sealed doorways' barriers).
			attack = attack and sees_player(w, a.pos(i))
			# A walker faces the player on its plan ticks and as it attacks; the slow turners (Warden,
			# Shield Bearer) turn every tick (their facing is their armour).
			if (f & F_TURNS_SLOWLY) != 0:
				a.facing[i] = Kin.turn_toward(a.facing[i], Kin.angle_of(to_player), t.turn_rate)
			elif attack or planning:
				a.facing[i] = Kin.angle_of(to_player)
			if kind == ActorStore.Kind.MENDER:
				_mend(w, i)  # Heals instead of attacking.
				return
			if beh == ActorStore.Kind.SNIPER and a.pick[i] == 1:
				_end_relocation(w, a, i)
			if attack and _may_attack(w, i):
				_start_windup(w, i, Kin.angle_of(to_player))
		State.WINDUP:
			if tracking(w, i) and alive:
				_aim(w, i)
			if a.state_t[i] >= a.windup[i]:
				if StarfallKinds.is_warper(a.kinds[i]) and StarfallKinds.cancel(w, i):
					return  # The hero on the star: no blink, the Warper stunned
				enter_state(a, i, State.ACTIVE)
				a.fire_cd[i] = 0
		State.ACTIVE:
			var done := false
			var pat := pattern_of(w, i)
			if pat != null:  # A pattern attack runs until its last wave
				if a.state_t[i] >= maxi(t.active_ticks, pat.duration_ticks()):
					enter_state(a, i, State.RECOVER)
				return
			match behaviour_of(a.kinds[i]):
				ActorStore.Kind.CHARGER, ActorStore.Kind.HATCHLING, ActorStore.Kind.SWARMER:
					done = a.lock_len[i] <= 0.0
				ActorStore.Kind.NEEDLE:
					done = a.fire_cd[i] >= t.burst_count and a.state_t[i] >= t.active_ticks
				_:
					done = a.state_t[i] >= t.active_ticks
			if done:
				enter_state(a, i, State.RECOVER)
		State.RECOVER:
			if a.state_t[i] >= t.recover_ticks:
				enter_state(a, i, State.MOVE)
				a.cd[i] = t.cooldown_ticks
				if behaviour_of(a.kinds[i]) == ActorStore.Kind.SNIPER:
					_plan_relocation(w, i)


## Whether a horde kind may start its attack now (v0.4.0 EN; always true for the others): a Shield Bearer only at a
## player in front of it, a Mine Layer below its mine count, a Sniper once it has relocated.
static func _may_attack(w: World, i: int) -> bool:
	var a := w.actors
	match behaviour_of(a.kinds[i]):
		ActorStore.Kind.SHIELD_BEARER:
			var aim := Kin.angle_of(w.player_pos() - a.pos(i))
			return Kin.angle_diff(aim, a.facing[i]) <= w.enemy_table(a.kinds[i]).front_half_arc
		ActorStore.Kind.MINE_LAYER:
			return Mines.count_of(w, a.ids[i]) < w.enemy_table(a.kinds[i]).max_mines
		ActorStore.Kind.SNIPER:
			return a.pick[i] == 0
	return true


## A relocating Sniper is done once within RELOCATE_DONE_M of its spot or after RELOCATE_MAX_TICKS.
static func _end_relocation(w: World, a: ActorStore, i: int) -> void:
	var near := Kin.length(Vector2(a.lock_x[i], a.lock_y[i]) - a.pos(i)) <= RELOCATE_DONE_M
	if near or a.state_t[i] >= w.tuning.ai_relocate_max_ticks:
		a.pick[i] = 0


## A Sniper's next spot: around the player by 45-90 degrees (a side drawn from ai:enemy), in the middle
## of its distance band. pick = 1 while it walks there.
static func _plan_relocation(w: World, i: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var p := w.player_pos()
	var turn := w.rng_enemy.range_int(RELOCATE_MIN_TURN, RELOCATE_MAX_TURN)
	if w.rng_enemy.chance_permille(500):
		turn = -turn
	var ang := (Kin.angle_of(a.pos(i) - p) + turn) & 4095
	var spot := p + Kin.dir(ang) * ((t.keep_min_m + t.keep_distance_m) * 0.5)
	a.lock_x[i] = spot.x
	a.lock_y[i] = spot.y
	a.pick[i] = 1


## The Mender: keeps its patient (pick) while it is alive, hurt and within heal_range_m, else looks for
## the most hurt ally in range every MEND_SCAN_TICKS; heals it heal_amount every heal_period_ticks (HEAL event).
static func _mend(w: World, i: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var j := a.index_of(a.pick[i]) if a.pick[i] > 0 else -1
	if j >= 0 and (a.dead[j] == 1 or a.hp[j] >= a.max_hp[j] or not _near(a, i, j, t.heal_range_m)):
		j = -1
	if j < 0 and (w.tick + a.ids[i]) % w.tuning.ai_mend_scan_ticks == 0:
		j = _patient(w, i, t.heal_range_m)
	if j < 0:
		a.pick[i] = 0
		return
	if a.pick[i] != a.ids[j]:
		a.pick[i] = a.ids[j]
		a.cd[i] = t.heal_period_ticks  # a new beam takes a full period to land its first heal
	if a.cd[i] > 0:
		return
	a.cd[i] = t.heal_period_ticks
	var add := mini(t.heal_amount, a.max_hp[j] - a.hp[j])
	a.hp[j] += add
	var e := w.emit_event(SimEvent.Kind.HEAL, a.ids[i], a.ids[i], a.ids[j], a.pos(j))
	e.amount = add
	e.amount_applied = add


static func _near(a: ActorStore, i: int, j: int, r: float) -> bool:
	var d := a.pos(j) - a.pos(i)
	return absf(d.x) <= r and absf(d.y) <= r and Kin.length(d) <= r


## The most hurt (lowest HP share) normal enemy within r of Mender i, other than itself; -1 when none is hurt.
static func _patient(w: World, i: int, r: float) -> int:
	var a := w.actors
	var best := -1
	var best_share := 1000
	for j in range(1, a.size()):
		if j == i or a.dead[j] == 1 or a.hp[j] >= a.max_hp[j] or not is_enemy_kind(a.kinds[j]):
			continue
		if BossAi.is_boss_kind(a.kinds[j]) or not _near(a, i, j, r):
			continue
		var share := a.hp[j] * 1000 / maxi(1, a.max_hp[j])
		if share < best_share:
			best = j
			best_share = share
	return best


## A dying Splitter splits into split_count Splitlings beside where it fell (they arrive in phase 9).
static func on_death(w: World, i: int) -> void:
	var a := w.actors
	if CanyonShore.owns(a.kinds[i]):  # A Kiln Beetle's burst, a Cinder Priest's vent cools
		CanyonShore.on_death(w, i)
	var t := w.enemy_table(a.kinds[i])
	if t == null or t.split_count <= 0 or w.enemy_table(ActorStore.Kind.SPLITLING) == null:
		return
	var side := Kin.dir((a.facing[i] + 1024) & 4095)
	for k in t.split_count:
		var off := (k - (t.split_count - 1) * 0.5) * 2.0 * SPLIT_OFFSET_M
		w.queue_enemy(ActorStore.Kind.SPLITLING, a.pos(i) + side * off)


static func move(w: World, i: int) -> void:
	var a := w.actors
	var kind := a.kinds[i]  # Read once: an actor's kind never changes
	var f := flags_of(kind)
	var t := w.enemy_table(kind)
	var at := a.pos(i)
	# Items: a Frost Core slow scales both the walk and the charge (1.0 when not slowed).
	var slow := ItemProcs.slow_factor(w, i)
	if (f & F_RUINS) != 0 and RuinsRocks.moves(w, i, t, slow):  # The Ruins and Night Rocks walk their own
		return
	var state := a.state[i]
	var hovering := kind == ActorStore.Kind.BOMB_DRONE and state == State.WINDUP
	if kind == ActorStore.Kind.GRAVITY_NODE:  # It holds its spot
		StarfallKinds.hold(w, i)
		return
	var beh := behaviour_of(kind)
	if state == State.MOVE and beh == ActorStore.Kind.SNIPER and a.pick[i] == 1:
		_relocate(w, i, t, slow)
		return
	if state == State.MOVE or hovering:
		# The walk follows the last plan (every PLAN_PERIOD ticks); a melee walker still stops the
		# tick it touches the player.
		var dir := Vector2(a.plan_x[i], a.plan_y[i])
		if dir == Vector2.ZERO or w.player_dead():
			return
		if (
			beh != ActorStore.Kind.NEEDLE
			and (f & F_KEEPS_AWAY) == 0
			and Kin.length(w.player_pos() - at) <= t.radius_m + w.player.radius_m + 0.1
		):
			return
		a.set_pos(i, at + dir * (t.speed * slow))
	elif state == State.ACTIVE:
		if (f & F_CHARGES) != 0 and a.lock_len[i] > 0.0:
			# The charge bends toward the player, at most charge_turn a tick.
			if t.charge_turn > 0 and not w.player_dead():
				var want := Kin.angle_of(w.player_pos() - at)
				a.lock_a[i] = Kin.turn_toward(a.lock_a[i], want, t.charge_turn)
				a.facing[i] = a.lock_a[i]
			var step := minf(t.charge_speed * slow, a.lock_len[i])
			a.lock_len[i] -= step
			a.set_pos(i, at + Kin.dir(a.lock_a[i]) * step)
			if t.trail != Variants.TRAIL_NONE:  # The Ember and Frost Chargers' trails
				Variants.on_charge_step(w, i, t)


## Where enemy i would walk this tick before the spread push and walls (ZERO = stand still): toward the player,
## a Needle backing off or strafing, the keep-away kinds holding their band, melee walkers flanking.
static func _walk_dir(w: World, i: int, t: EnemyTable) -> Vector2:
	var a := w.actors
	var to := w.player_pos() - a.pos(i)
	var dist := Kin.length(to)
	if dist <= 0.0001 or w.player_dead():
		return Vector2.ZERO
	var dir := to / dist
	if a.kinds[i] == ActorStore.Kind.CINDER_PRIEST and w.canyon_shore.touched:  # By its vent
		var by := CanyonShore.priest_walk(w, i, Vector2.INF)
		if by != Vector2.INF:
			return by
	var side := 1.0 if a.ids[i] % 2 == 0 else -1.0
	if behaviour_of(a.kinds[i]) == ActorStore.Kind.NEEDLE:
		if dist < t.flee_distance_m:
			dir = -dir
		elif dist <= t.keep_distance_m + 1.0:
			dir = Vector2(-dir.y, dir.x) * side * (w.tuning.ai_strafe_permille / 1000.0)
	elif _keeps_away(a.kinds[i]):
		if dist < t.keep_min_m:
			dir = -dir
		elif dist <= t.keep_distance_m:
			dir = Vector2(-dir.y, dir.x) * side * (w.tuning.ai_strafe_permille / 1000.0)
	elif dist <= t.radius_m + w.player.radius_m + 0.1:
		return Vector2.ZERO
	elif (
		not is_critter(a.kinds[i])  # A critter runs straight at you
		and dist > w.tuning.ai_flank_min_m
		and dist < w.tuning.ai_flank_range_m
	):
		dir = _unit(dir + Vector2(-dir.y, dir.x) * side * (w.tuning.ai_flank_permille / 1000.0))
	return dir


## Whether enemy i re-plans this tick. Each enemy re-plans every PLAN_PERIOD ticks, on the phase its
## id gives (id % PLAN_PERIOD), so a crowd's planning is spread evenly over the ticks; it still moves every tick.
static func plans_now(w: World, i: int) -> bool:
	var period := ELITE_PLAN_PERIOD if EliteAi.is_elite_kind(w.actors.kinds[i]) else PLAN_PERIOD
	return posmod(w.tick, period) == posmod(w.actors.ids[i], period)


## The walk, planned every PLAN_PERIOD ticks (tick phase 3, before anything moves) and followed every
## tick by move(): the way _walk_dir picks, pushed off the enemies near it (through the actor grid World built this
## tick) and, while a wall blocks the straight walk, along the flow field instead. The wall check (it sweeps the line
## to the player) runs on every plan since v0.10.5 PD (it ran every other plan of 4 ticks: the same 8-tick rate).
static func plan(w: World, i: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var at := a.pos(i)
	var dir := _walk_dir(w, i, t)
	if dir != Vector2.ZERO:
		var reach := Vector2(w.tuning.ai_spread_radius_m, w.tuning.ai_spread_radius_m)
		var push := _spread_over(w, i, w.actors_near(Rect2(at - reach, reach * 2.0)))
		dir = _unit(dir + push * w.tuning.ai_spread_weight) * Kin.length(dir)
		a.plan_block[i] = 1 if _blocked(w, at, dir, t.radius_m) else 0
		if a.plan_block[i] == 1:
			var flow := w.nav.direction(at)
			if flow != Vector2.ZERO:
				dir = flow * Kin.length(dir)
	a.plan_x[i] = dir.x
	a.plan_y[i] = dir.y


## A Sniper walking to its next spot, RELOCATE_SPEED_PERMILLE of its speed.
static func _relocate(w: World, i: int, t: EnemyTable, slow: float) -> void:
	var a := w.actors
	var at := a.pos(i)
	var to := Vector2(a.lock_x[i], a.lock_y[i]) - at
	var d := Kin.length(to)
	if d <= 0.0001:
		return
	var step := minf(t.speed * slow * w.tuning.ai_relocate_speed_permille / 1000.0, d)
	a.set_pos(i, at + steer(w, at, to / d, t.radius_m) * step)


## The push that keeps enemy i off the other normal enemies near it: the sum, over each one closer than
## SPREAD_RADIUS_M, of the direction away from it weighted by how close it is (0 when alone).
static func spread_push(w: World, i: int) -> Vector2:
	var every := PackedInt32Array()
	for j in range(1, w.actors.size()):
		every.append(j)
	return _spread_over(w, i, every)


## spread_push over the candidates `js` (ascending actor indices; any superset of the enemies near i gives the same
## sum, added in the same order).
static func _spread_over(w: World, i: int, js: PackedInt32Array) -> Vector2:
	var a := w.actors
	var at := a.pos(i)
	var push := Vector2.ZERO
	var spread := w.tuning.ai_spread_radius_m
	var far := spread + 0.001
	# The columns read through locals (a store lookup per read was most of the loop's cost in a surge's
	# packed crowd), with the same values and arithmetic in the same order.
	var px := a.pos_x
	var py := a.pos_y
	var dead := a.dead
	var kinds := a.kinds
	for j in js:
		# The cheap distance test first (with a margin over rounding; the tests below repeat it exactly).
		if absf(px[j] - at.x) >= far or absf(py[j] - at.y) >= far:
			continue
		if j == 0 or j == i or dead[j] == 1 or kinds[j] < ActorStore.Kind.CHARGER:
			continue
		var d := at - Vector2(px[j], py[j])
		if absf(d.x) >= spread or absf(d.y) >= spread:
			continue
		var l := Kin.length(d)
		if l >= spread:
			continue
		if l <= 0.0001:  # stacked exactly: the higher id steps aside, along +x or -x
			push += Vector2(1.0 if a.ids[i] > a.ids[j] else -1.0, 0.0)
			continue
		push += d / l * (1.0 - l / spread)
	return push


static func _unit(v: Vector2) -> Vector2:
	var l := Kin.length(v)
	return v / l if l > 0.0001 else Vector2.ZERO


static func resolve(w: World, i: int) -> void:
	var a := w.actors
	if a.state[i] == BossSignatures.EGG_BURST and not Engines.frozen(w, i):
		BossSignatures.egg_burst(w, i)  # A phase-3 egg bursts into its acid star
		return
	var f := flags_of(a.kinds[i])
	if (f & F_ELITE) != 0:  # An elite's contact, plain attack and ability
		EliteAi.resolve(w, i)
		return
	if (f & F_CRITTER) != 0:  # A critter hurts by touch
		_critter_touch(w, i)
		return
	if (f & F_RUINS) != 0:  # The Ruins and Night Rocks signatures
		RuinsRocks.resolve(w, i)
		return
	if a.state[i] != State.ACTIVE or w.player_dead() or Engines.frozen(w, i):
		return
	var t := w.enemy_table(a.kinds[i])
	var p := w.player_pos()
	var pr := w.player.radius_m
	var pat := pattern_of(w, i)
	if pat != null:  # v0.7.5 EF
		_resolve_pattern(w, i, t, pat)
		return
	match behaviour_of(a.kinds[i]):
		ActorStore.Kind.CHARGER, ActorStore.Kind.HATCHLING, ActorStore.Kind.SWARMER:
			var reach := t.radius_m + pr + CONTACT_SLOP_M
			if a.fire_cd[i] == 0 and Kin.length(p - a.pos(i)) <= reach:
				a.fire_cd[i] = 1
				_hit_player(w, i, t.damage, SimEvent.TAG_MELEE)
		ActorStore.Kind.WARDEN:
			if a.state_t[i] == 0:
				var disc := locked_disc(w, i)
				if AttackShapes.disc_touches(disc[0], disc[1], p, pr):
					_hit_player(w, i, t.damage, SimEvent.TAG_AREA)
		ActorStore.Kind.NEEDLE:
			if a.fire_cd[i] < t.burst_count and a.state_t[i] % t.burst_gap_ticks == 0:
				var k := a.fire_cd[i]
				a.fire_cd[i] += 1
				var ang := burst_angle(t, a.lock_a[i], k)
				_fire(w, i, ang, t.bolt_speed, t.bolt_radius_m, t.bolt_life_ticks, t.damage)
				if a.kinds[i] == ActorStore.Kind.DIM_NEEDLE:  # Dark until near (Variants)
					w.set_pending_look(Variants.DIM_LOOK)
				BossRicochet.arm_turret(w, i)  # Phase 3's turrets ricochet too
		ActorStore.Kind.ARC_CASTER:  # the rune (its bolt and spread are patterns, above)
			if a.state_t[i] == 0 and a.pick[i] == Spell.RUNE:
				var d := rune_disc(w, i)
				if AttackShapes.disc_touches(d[0], d[1], p, pr):
					_hit_player(w, i, t.damage, SimEvent.TAG_AREA, d[0])
		_:
			if a.state_t[i] == 0:
				_resolve_horde(w, i, t, p, pr)


## The pattern enemy i is firing now (EnemyTable.patterns: the Arc Caster's by its spell,
## the others' first), or null (every other kind, and the Arc Caster's rune).
static func pattern_of(w: World, i: int) -> BulletPatternTable:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	if t == null or t.patterns.is_empty():
		return null
	var k := a.pick[i] if a.kinds[i] == ActorStore.Kind.ARC_CASTER else 0
	return t.patterns[k] if k >= 0 and k < t.patterns.size() else null


## A pattern attack's active tick st. Each wave tick fires its wave toward the locked aim: from the body
## (the fans, the ring), or, for a lobbed BURST, from where it lands (lock_x / lock_y) once it has flown lob_ticks;
## the landing fireball itself hurts within land_radius_m (no circle is drawn for it: the flying fireball is the
## cue, "lob"). Damage is the attack's (floor-scaled by RunState), powered by the danger tier and the catch-up.
static func _resolve_pattern(w: World, i: int, t: EnemyTable, pat: BulletPatternTable) -> void:
	var a := w.actors
	var st := a.state_t[i]
	var burst := pat.kind == BulletPatternTable.Kind.BURST
	var target := Vector2(a.lock_x[i], a.lock_y[i])
	if burst and st == pat.lob_ticks:
		if AttackShapes.disc_touches(target, pat.land_radius_m, w.player_pos(), w.player.radius_m):
			_hit_player(w, i, t.damage, SimEvent.TAG_AREA, target)
	var k := BulletPatterns.wave_at(pat, st)
	if k >= 0:
		fire_wave(w, i, t, pat, k)


## Wave k of enemy i's pattern pat toward its locked aim: from its body, or from a lobbed BURST's landing.
static func fire_wave(w: World, i: int, t: EnemyTable, pat: BulletPatternTable, k: int) -> void:
	var a := w.actors
	var burst := pat.kind == BulletPatternTable.Kind.BURST
	var target := Vector2(a.lock_x[i], a.lock_y[i])
	var origin := target if burst else a.pos(i)
	var r := 0.0 if burst else a.radius[i] + pat.radius_m + BulletPatterns.MUZZLE_M
	BulletPatterns.fire(w, i, pat, k, origin, a.lock_a[i], r, powered(w, i, t.damage))


## The horde kinds' hits, on their active tick.
static func _resolve_horde(w: World, i: int, t: EnemyTable, p: Vector2, pr: float) -> void:
	match behaviour_of(w.actors.kinds[i]):
		ActorStore.Kind.SPLITTER, ActorStore.Kind.SPLITLING:
			var d := locked_disc(w, i)
			if AttackShapes.disc_touches(d[0], d[1], p, pr):
				_hit_player(w, i, t.damage, SimEvent.TAG_MELEE)
		ActorStore.Kind.SHIELD_BEARER:
			if Collide.circle_vs_obb(p, pr, bash_lane(w, i)) != Vector2.ZERO:
				_hit_player(w, i, t.damage, SimEvent.TAG_MELEE)
		ActorStore.Kind.SNIPER:  # A Split Sniper's three branches too (one hit at most)
			for lane in snipe_lanes(w, i):
				if Collide.circle_vs_obb(p, pr, lane) != Vector2.ZERO:
					_hit_player(w, i, t.damage, SimEvent.TAG_PROJECTILE)
					break
		ActorStore.Kind.MINE_LAYER:
			Mines.drop(w, i)
		ActorStore.Kind.FROST_SPITTER:  # Its ice blob leaves (CanyonShore)
			CanyonShore.throw_blob(w, i)
		ActorStore.Kind.STAR_WARPER:  # It blinks onto its star and strikes round it
			if w.actors.state_t[i] == 0:
				var star := StarfallKinds.blink(w, i)
				if AttackShapes.disc_touches(star, t.strike_radius_m, p, pr):
					_hit_player(w, i, t.damage, SimEvent.TAG_MELEE, star)


static func _fire(
	w: World, i: int, angle: int, speed: float, r: float, life: int, damage: int
) -> void:
	var a := w.actors
	var dir := Kin.dir(angle)
	var muzzle := Vector2(a.lock_x[i], a.lock_y[i]) + dir * (a.radius[i] + r + 0.05)
	w.queue_projectile(
		a.ids[i],
		ActorStore.TEAM_ENEMY,
		muzzle,
		dir * speed,
		powered(w, i, damage),
		r,
		life,
		SimEvent.TAG_PROJECTILE
	)


## Where to walk: `dir` when the straight line to the player is clear of walls (for a body of radius r), or
## else along the flow field (NavField). A Needle backing off or strafing (dir not toward the player) keeps dir
## unless a wall is right in front of it.
static func steer(w: World, at: Vector2, dir: Vector2, r: float) -> Vector2:
	if _blocked(w, at, dir, r):
		var flow := w.nav.direction(at)
		return flow * Kin.length(dir) if flow != Vector2.ZERO else dir
	return dir


## Whether a wall blocks a body of radius r walking `dir` from `at`: the whole line to the player when dir heads
## toward it, else the next metre. Walls come from the grid, not a sweep over every wall.
static func _blocked(w: World, at: Vector2, dir: Vector2, r: float) -> bool:
	var target := w.player_pos()
	var toward := Kin.length(target - at) > 0.0 and (target - at).dot(dir) > 0.0
	var probe := target if toward else at + dir * 1.0
	for k in w.walls_along(at, probe, r):
		if Collide.sweep_vs_obb(at, probe, r, w.walls[k]) >= 0.0:
			return true
	return not w.solids.is_empty() and w.solids.blocks(at, probe, r)  # v0.9.5 SB2


## The lane a Charger is about to run: its body's path from where it stands to its body's front at the end of
## the run (cut short by walls), as wide as its body.
static func charge_lane(w: World, i: int) -> Obb:
	var a := w.actors
	return AttackShapes.lane(
		Vector2(a.lock_x[i], a.lock_y[i]),
		a.lock_a[i],
		maxf(a.lock_len[i], 0.0) + a.radius[i],
		a.radius[i]
	)


## The rest of a charge in progress: from where the body is now along its (steered) heading, to its
## front at the end of the run. The view keeps drawing it, so a charge that bends shows where it is going.
static func running_lane(w: World, i: int) -> Obb:
	var a := w.actors
	return AttackShapes.lane(a.pos(i), a.lock_a[i], a.lock_len[i] + a.radius[i], a.radius[i])


## [center, radius] of a locked disc: where enemy i locked its attack, slam_radius_m wide. A Warden's slam and a
## Splitter's or Splitling's swipe (reach_m ahead of it when it wound up) are this disc (the Bomb Drone's
## bomb was too, until v0.7.5 EF made it a lobbed fireball).
static func locked_disc(w: World, i: int) -> Array:
	var a := w.actors
	return [Vector2(a.lock_x[i], a.lock_y[i]), w.enemy_table(a.kinds[i]).slam_radius_m]


## Shot k of `count` fanned `step` apart around `aim`: centred, k = 0 in the middle when count is odd.
static func fan_angle(aim: int, k: int, count: int, step: int) -> int:
	return (aim + (2 * k - (count - 1)) * step / 2) & 4095


## The angle of shot k of a Needle's burst: the first down the middle, then one to each side.
static func burst_angle(t: EnemyTable, aim: int, k: int) -> int:
	var off := (k + 1) / 2 * (1 if k % 2 == 1 else -1)
	return (aim + off * t.burst_spread) & 4095


## The lines a Needle's burst flies down (one per shot), as wide as its bolts, each cut short by walls.
static func burst_lines(w: World, i: int) -> Array[Obb]:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var out: Array[Obb] = []
	var seen := PackedInt32Array()
	var bent := not StarfallKinds.nodes(w).is_empty()
	for k in t.burst_count:
		var ang := burst_angle(t, a.lock_a[i], k)
		if seen.has(ang):
			continue
		seen.append(ang)
		if bent:  # A Gravity Node near: the path the bolt will fly (StarfallKinds.bend, as the sweep)
			var dir := Kin.dir(ang)
			var muzzle := (
				Vector2(a.lock_x[i], a.lock_y[i]) + dir * (a.radius[i] + t.bolt_radius_m + 0.05)
			)
			out.append_array(
				StarfallKinds.bent_lanes(
					w, muzzle, dir * t.bolt_speed, t.bolt_life_ticks, t.bolt_radius_m
				)
			)
			continue
		out.append(_shot_lane(w, i, ang, t.bolt_speed * t.bolt_life_ticks, t.bolt_radius_m))
	return out


## The Arc Caster's bolt line, or its spread's lines, cut short by walls. no longer drawn
## or fired (its bolt and spread are slow fireball fans with no ground line); kept for tools that read the lanes.
static func bolt_lanes(w: World, i: int) -> Array[Obb]:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var out: Array[Obb] = []
	if a.pick[i] == Spell.SPREAD:
		for k in t.spread_count:
			var ang := fan_angle(a.lock_a[i], k, t.spread_count, t.spread_angle)
			out.append(
				_shot_lane(w, i, ang, t.spread_speed * t.spread_life_ticks, t.spread_radius_m)
			)
	else:
		out.append(_shot_lane(w, i, a.lock_a[i], t.bolt_speed * t.bolt_life_ticks, t.bolt_radius_m))
	return out


static func _shot_lane(w: World, i: int, angle: int, length: float, r: float) -> Obb:
	var a := w.actors
	var start := Vector2(a.lock_x[i], a.lock_y[i]) + Kin.dir(angle) * a.radius[i]
	return AttackShapes.lane(start, angle, maxf(clear_run(w, start, angle, length, r), 0.01), r)


## [center, radius] of the Arc Caster's rune: where the player stood when it was cast.
static func rune_disc(w: World, i: int) -> Array:
	var a := w.actors
	return [Vector2(a.lock_x[i], a.lock_y[i]), w.enemy_table(a.kinds[i]).rune_radius_m]


## A Shield Bearer's bash: a lane from its centre along its locked facing, reach_m past its body.
static func bash_lane(w: World, i: int) -> Obb:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	return AttackShapes.lane(
		Vector2(a.lock_x[i], a.lock_y[i]), a.lock_a[i], a.radius[i] + t.reach_m, t.lane_half_m
	)


## A Sniper's line: reach_m from its muzzle along its aim, lane_half_m wide, cut short by walls.
static func snipe_lane(w: World, i: int) -> Obb:
	var t := w.enemy_table(w.actors.kinds[i])
	return _shot_lane(w, i, w.actors.lock_a[i], t.reach_m, t.lane_half_m)


## The lanes a Sniper's shot hits (its line; a Split Sniper's line and branches: Variants.split_lanes).
static func snipe_lanes(w: World, i: int) -> Array[Obb]:
	if w.actors.kinds[i] == ActorStore.Kind.SPLIT_SNIPER:
		return Variants.split_lanes(w, i)
	return [snipe_lane(w, i)]


## What the view draws for actor i: {} or {"shape": &"lane"|&"lanes"|&"disc", ..., "progress": 0..1000}. The new
## kinds add "style": &"bolt" or &"rune".
## A pattern enemy's windup is {"shape": &"cast", "ground": false, "progress", "look"} (its body
## winds up; nothing on the ground), and a Bomb Drone's fireball in the air {"shape": &"lob", "ground": false, "from",
## "to", "progress" (0..1000 of the flight), "look"}. TelegraphViews draws no "ground": false telegraph.
## The melee kinds' lanes and discs (Charger / Hatchling /
## Swarmer windup and running lane, Splitter / Splitling disc, Shield Bearer bash, Warden slam), the Sniper's line and
## the Needle's lanes keep their shape and timings (forecasts, parity, the readable-cause recap) but are "ground":
## false: the avatar's body shows the windup. Only the Arc Caster's rune and the Mine Layer's mines stay on the
## ground among normal enemies (elites too: the rule is by kind). Bosses are BossAi's and unchanged.
## And the Warden's slam disc ("ground": true), which its body also tells (the overhead slam).
static func telegraph(w: World, i: int) -> Dictionary:
	var a := w.actors
	if BossAi.is_boss_kind(a.kinds[i]):
		return BossAi.telegraph(w, i)  # Bosses.
	if not is_enemy_kind(a.kinds[i]):
		return {}
	if EliteAi.is_elite_kind(a.kinds[i]):
		return EliteAi.telegraph(w, i)  # The slam's circle, the rift mark, the beam's line
	if RuinsRocks.takes(a.kinds[i]):
		return RuinsRocks.telegraph(w, i)  # The cable, the dart, the slam, the landing
	if a.state[i] == State.ACTIVE and _charges(a.kinds[i]) and a.lock_len[i] > 0.0:
		return {"shape": &"lane", "ground": false, "obb": running_lane(w, i), "progress": 1000}
	if a.kinds[i] == ActorStore.Kind.MINE_LAYER:
		return Mines.telegraph(w, a.ids[i])  # Its armed mines; the drop itself hurts nobody
	if a.state[i] == State.ACTIVE:
		return lob_telegraph(w, i)
	if a.state[i] != State.WINDUP:
		return {}
	var progress := clampi(a.state_t[i] * 1000 / maxi(1, a.windup[i]), 0, 1000)
	var pat := pattern_of(w, i)
	if pat != null:  # No ground line; the body's own windup
		return {"shape": &"cast", "ground": false, "progress": progress, "look": pat.look}
	match behaviour_of(a.kinds[i]):
		ActorStore.Kind.CHARGER, ActorStore.Kind.HATCHLING, ActorStore.Kind.SWARMER:
			return {
				"shape": &"lane", "ground": false, "obb": charge_lane(w, i), "progress": progress
			}
		ActorStore.Kind.SPLITTER, ActorStore.Kind.SPLITLING:
			var s := locked_disc(w, i)
			return {
				"shape": &"disc",
				"ground": false,
				"center": s[0],
				"radius": s[1],
				"progress": progress
			}
		ActorStore.Kind.SHIELD_BEARER:
			return {
				"shape": &"lane",
				"ground": false,
				"obb": bash_lane(w, i),
				"progress": progress,
				"style": &"bash"
			}
		ActorStore.Kind.SNIPER:
			if a.kinds[i] == ActorStore.Kind.SPLIT_SNIPER:  # The line and its three branches
				return {
					"shape": &"lanes",
					"ground": false,
					"obbs": snipe_lanes(w, i),
					"progress": progress,
					"style": &"snipe"
				}
			return {
				"shape": &"lane",
				"ground": false,
				"obb": snipe_lane(w, i),
				"progress": progress,
				"style": &"snipe"
			}
		ActorStore.Kind.WARDEN:  # Its red circle is back on the ground
			var d := locked_disc(w, i)
			return {
				"shape": &"disc",
				"ground": true,
				"center": d[0],
				"radius": d[1],
				"progress": progress
			}
		ActorStore.Kind.STAR_WARPER:  # The star and the disc its strike covers
			var sd := StarfallKinds.star_disc(w, i)
			return {
				"shape": &"disc",
				"ground": true,
				"center": sd[0],
				"radius": sd[1],
				"progress": progress,
				"style": &"star",
				"star_r": w.enemy_table(a.kinds[i]).mark_radius_m
			}
		ActorStore.Kind.NEEDLE:
			return {
				"shape": &"lanes", "ground": false, "obbs": burst_lines(w, i), "progress": progress
			}
		ActorStore.Kind.ARC_CASTER:
			if a.pick[i] == Spell.RUNE:
				var r := rune_disc(w, i)
				return {
					"shape": &"disc",
					"center": r[0],
					"radius": r[1],
					"progress": progress,
					"style": &"rune"
				}
		ActorStore.Kind.FROST_SPITTER:  # The blue arc and the landing ring
			return CanyonShore.spitter_telegraph(w, i, progress)
	return {}


## A lobbed fireball in the air (a BURST pattern's flight, until it lands), else {}.
static func lob_telegraph(w: World, i: int) -> Dictionary:
	var a := w.actors
	var pat := pattern_of(w, i)
	if pat == null or pat.kind != BulletPatternTable.Kind.BURST or a.state_t[i] > pat.lob_ticks:
		return {}
	return {
		"shape": &"lob",
		"ground": false,
		"from": a.pos(i),
		"to": Vector2(a.lock_x[i], a.lock_y[i]),
		"progress": clampi(a.state_t[i] * 1000 / maxi(1, pat.lob_ticks), 0, 1000),
		"look": pat.look
	}


static func _start_windup(w: World, i: int, aim: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	enter_state(a, i, State.WINDUP)
	a.lock_x[i] = a.pos_x[i]
	a.lock_y[i] = a.pos_y[i]
	a.lock_a[i] = aim
	a.lock_len[i] = 0.0
	a.pick[i] = 0
	# The windup's length is drawn per attack, never under the data's telegraph.
	a.windup[i] = t.windup_ticks
	if t.windup_max_ticks > t.windup_ticks:
		a.windup[i] = w.rng_enemy.range_int(t.windup_ticks, t.windup_max_ticks)
	match behaviour_of(a.kinds[i]):
		ActorStore.Kind.CHARGER, ActorStore.Kind.HATCHLING, ActorStore.Kind.SWARMER:
			a.lock_len[i] = clear_run(w, a.pos(i), aim, t.charge_distance_m, t.radius_m)
		ActorStore.Kind.NEEDLE, ActorStore.Kind.SNIPER:
			_aim(w, i)
		ActorStore.Kind.STAR_WARPER:  # Its star beside the hero (StarfallKinds)
			var star := StarfallKinds.mark_spot(w, i)
			a.lock_x[i] = star.x
			a.lock_y[i] = star.y
		ActorStore.Kind.SPLITTER, ActorStore.Kind.SPLITLING:
			var c := a.pos(i) + Kin.dir(aim) * t.reach_m
			a.lock_x[i] = c.x
			a.lock_y[i] = c.y
		ActorStore.Kind.SHIELD_BEARER:
			a.lock_a[i] = a.facing[i]  # it bashes the way its shield faces
		ActorStore.Kind.ARC_CASTER:
			a.pick[i] = maxi(0, w.rng_enemy.pick_weighted(t.spell_weights))
			if a.pick[i] == Spell.RUNE:
				a.windup[i] = t.rune_windup_ticks
				a.lock_x[i] = w.player_pos().x
				a.lock_y[i] = w.player_pos().y
			else:
				_aim(w, i)
		ActorStore.Kind.BOMB_DRONE:
			_aim(w, i)  # The landing follows the player until it commits
		ActorStore.Kind.FROST_SPITTER:  # Its blob lands where you stand (tracked to the commit)
			_aim(w, i)


## Points actor i's shot at where the player will be when it arrives: the player's position plus its
## velocity for the shot's flight time, capped at lead_max_ticks; or where a dash in progress ends.
## A pattern is led at its own (slow) speed; a Bomb Drone's lob lands where the player stands (no lead,
## as the bosses' tracked markers), its X turned to the line of the throw.
static func _aim(w: World, i: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	if a.kinds[i] == ActorStore.Kind.FROST_SPITTER:  # v0.11.0 O13c
		CanyonShore.aim_blob(w, i)
		return
	if a.kinds[i] == ActorStore.Kind.BOMB_DRONE:
		var p := w.player_pos()
		a.lock_x[i] = p.x
		a.lock_y[i] = p.y
		a.lock_a[i] = Kin.angle_of(p - a.pos(i))
		a.facing[i] = a.lock_a[i]
		return
	var pat := pattern_of(w, i)
	var speed := t.spread_speed if a.pick[i] == Spell.SPREAD else t.bolt_speed
	if pat != null:
		speed = pat.speed
	a.lock_a[i] = lead_angle(w, a.pos(i), speed, t.lead_max_ticks)
	a.facing[i] = a.lock_a[i]


## The angle from `from` to the player led by its velocity for a shot at `speed` (metres per tick). A dashing
## player is aimed at where the dash ends (the same read as the bosses', BossChallenge.dash_landing).
static func lead_angle(w: World, from: Vector2, speed: float, max_ticks: int) -> int:
	if w.is_dashing() and not w.player_dead():
		return Kin.angle_of(BossChallenge.dash_landing(w) - from)
	var p := w.player_pos()
	var ticks := 0
	if speed > 0.0:
		ticks = mini(int(Kin.length(p - from) / speed), max_ticks)
	return Kin.angle_of(p + w.vel * ticks - from)


## How far a circle of radius r can travel from `from` along `angle` (up to `length`) before a wall: the one rule
## for the enemies' and the bosses' lanes (audit G-10).
static func clear_run(w: World, from: Vector2, angle: int, length: float, r: float) -> float:
	var to := from + Kin.dir(angle) * length
	var best := 1.0
	for k in w.walls_along(from, to, r):  # The grid cells along the run, not every wall
		var hit := Collide.sweep_vs_obb(from, to, r, w.walls[k])
		if hit >= 0.0 and hit < best:
			best = hit
	return length * best


## True when a circle of radius r at `at` touches no wall. The wall grid gives an ascending superset of the walls that
## can touch it (rebuilt on every wall change), so this is the every-wall test without the sweep (audit G-10).
static func clear_of_walls(w: World, at: Vector2, r: float) -> bool:
	for k in w.walls_near(Rect2(at.x - r, at.y - r, r * 2.0, r * 2.0)):
		if Collide.circle_vs_obb(at, r, w.walls[k]) != Vector2.ZERO:
			return false
	return true


## Whether a thin line from `at` to the player crosses no wall. Sealed doorways'
## barriers are walls (World.add_barrier), so an enemy outside a shut room neither starts an attack nor lands one.
static func sees_player(w: World, at: Vector2) -> bool:
	var p := w.player_pos()
	for k in w.walls_along(at, p, SIGHT_R_M):
		if Collide.sweep_vs_obb(at, p, SIGHT_R_M, w.walls[k]) >= 0.0:
			return false
	return true


## Enemy i's hit on the player (the elites' too: EliteAi), stopped by a wall between `from` and it.
static func hit_player(w: World, i: int, amount: int, tags: int, from := Vector2.INF) -> void:
	_hit_player(w, i, amount, tags, from)


static func _hit_player(w: World, i: int, amount: int, tags: int, from := Vector2.INF) -> void:
	var a := w.actors
	var at := a.pos(i) if from == Vector2.INF else from
	if not sees_player(w, at):  # A swing or slam begun before a doorway shut stops on it
		return
	Damage.hit(
		w, 0, powered(w, i, amount), a.ids[i], a.ids[i], w.take_root(), tags, at, w.player_pos()
	)


## Enemy i's attack damage scaled by the danger tier it arrived in (ActorStore.power, per mille).
static func powered(w: World, i: int, amount: int) -> int:
	var pm := w.actors.power[i]
	return amount if pm == 1000 or pm <= 0 else SpawnTable.scale(amount, pm)


## Actor i enters state s (its state clock restarts); the bosses' too (BossAi).
static func enter_state(a: ActorStore, i: int, s: int) -> void:
	a.state[i] = s
	a.state_t[i] = 0


## PLAN H1; owner Q14: "contact damage, ~6-10 HP, fast but dumb": a walking critter touching the hero hurts
## it for its damage (the authored contact_damage, floor-scaled; powered by its tier, as every enemy hit), then waits
## contact_cd_ticks before its next touch.
## Readable by its body (no telegraph, as an elite's touch: ReadableCause); its recap line is EndPanel's.
static func _critter_touch(w: World, i: int) -> void:
	var a := w.actors
	if a.state[i] != State.MOVE or a.cd[i] > 0 or w.player_dead() or Engines.frozen(w, i):
		return
	var t := w.enemy_table(a.kinds[i])
	if t == null or t.damage <= 0:
		return
	var reach := t.radius_m + w.player.radius_m + CRITTER_TOUCH_M
	if Kin.length(w.player_pos() - a.pos(i)) > reach:
		return
	a.cd[i] = t.contact_cd_ticks
	_hit_player(w, i, t.damage, SimEvent.TAG_MELEE)
