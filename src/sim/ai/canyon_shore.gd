class_name CanyonShore
extends RefCounted
## v0.11.0 O13c (PLAN M2; docs/roadmap/v0.11.0/ENEMIES.md R5-R8, approved 2026-11-07; owner Q22): the Red Canyon's and
## the Frozen Shore's signature enemies. Their numbers are their EnemyTable's (CanyonShoreCompiler, from
## data/enemies/<id>.tres; starting values); what they leave on the floor is World.canyon_shore (CanyonShoreState).
## Every hit here comes from no actor (Damage.hit owner 0, as an explosive barrel's), with its own effect id and recap
## line (the KILL_* causes, BossCauses.key), each warned on the floor for at least the telegraph minimum first. Pure.
## - R5 Kiln Beetle (Red Canyon): a slow armoured Warden (its slam, its slow turn, its front armour: BASE). Its view
##   glows brighter as its HP drops (the tell). When it dies, a burst of burst_radius_m stands where it fell and blows
##   burst_delay_ticks later (1 s: the warning is the burst's own circle): burst_damage to the hero and
##   burst_enemy_damage to every enemy in it. A beetle that fell on a lava vent (a Cinder Priest's) erupts it too.
## - R6 Cinder Priest (Red Canyon): no attack of its own. It keeps its distance band (EnemyAi.KEEP_AWAY) until the hero
##   is within its band and in sight; then it stands by a lava vent: a cooling vent within vent_reach_m if there is one
##   (a dead priest's), else a temporary vent it plants vent_reach_m toward the hero (pulled back toward itself, then
##   onto its own feet, until the spot is clear of walls and in a room). While it lives the vent erupts every
##   vent_period_ticks (3 s): a vent_radius_m fire column, vent_damage to the hero in it; its pulse (the telegraph, the
##   vent glowing in time with the priest's staff) runs the vent_warn_ticks before each eruption. When the priest dies
##   its vent stops at once and cools, and goes vent_linger_ticks later (a Kiln Beetle dying on it still blows it).
## - R7 Frost Spitter (Frozen Shore): keeps its band and lobs an ice blob at where the hero stands (tracked through the
##   windup until the commit, as the Bomb Drone's lob): the windup's telegraph is the blue arc from it to the landing
##   and the landing ring, and the blob flies flight_ticks along that arc. Landing it leaves a slick (the Frost
##   Charger's: World.variants, Variants.TRAIL_SLICK) of slick_radius_m for slick_ticks: on it the hero slides (keeps
##   its speed, turns slowly); enemies walk it as ground. The blob hurts nobody.
## - R8 Glacier Turtle (Frozen Shore): a Warden that turns slowly to face the hero. Its ice shell (shell_hp of its own)
##   takes every hit from its front arc (front_half_arc) instead of the turtle (Damage.hit: TAG_BLOCKED, the turtle
##   loses nothing); from the sides and behind, hits land as on a Warden. The hit that breaks the shell bursts it into
##   chunk_count chunks sliding away from the hit (straight on and CHUNK_SPREAD either side) at chunk_speed, slowing
##   (CHUNK_FRICTION) for chunk_ticks or until a wall: each hurts every enemy it touches once (chunk_damage) and the
##   hero once, but only after sliding for the telegraph minimum (CHUNK_ARM_TICKS).

## The signatures that walk, turn and hit as a base (EnemyAi.behaviour_of).
const BASE := {
	ActorStore.Kind.KILN_BEETLE: ActorStore.Kind.WARDEN,
	ActorStore.Kind.GLACIER_TURTLE: ActorStore.Kind.WARDEN,
}
const BURST_EFFECT := &"kiln_burst"
const VENT_EFFECT := &"cinder_vent"
const CHUNK_EFFECT := &"ice_chunk"
## World.killer_attack when one of these killed the hero (no actor's attack), and their recap lines.
const KILL_BURST := -7101
const KILL_VENT := -7102
const KILL_CHUNK := -7103
const CAUSE_BURST := &"CAUSE_KILN_BURST"
const CAUSE_VENT := &"CAUSE_CINDER_VENT"
const CAUSE_CHUNK := &"CAUSE_ICE_CHUNK"
const MAX_BURSTS := 32
const MAX_VENTS := 24
const MAX_BLOBS := 32
const MAX_CHUNKS := 48
## A priest stands still within this much of its vent's edge (m) and walks back past it.
const STAND_M := 1.2
## A vent's spot keeps this clear of walls (m), and a priest that fell within this of a vent's edge fell on it.
const VENT_CLEAR_M := 0.6
const ON_VENT_M := 0.5
## A chunk's radius (m), its slowing per tick (its speed times this), the turn either side of the middle one (1/4096
## turns), and the ticks it slides before it may hurt the hero (the telegraph minimum).
const CHUNK_RADIUS_M := 0.35
const CHUNK_FRICTION := 0.97
const CHUNK_SPREAD := 384
const CHUNK_ARM_TICKS := SimTick.MIN_TELEGRAPH_TICKS


static func owns(kind: int) -> bool:
	return kind >= ActorStore.Kind.KILN_BEETLE and kind <= ActorStore.Kind.GLACIER_TURTLE


# --- Phase 3: the priest's vent -----------------------------------------------------------------------------
## EnemyAi.think: a walking Cinder Priest without a vent takes or plants one once the hero is within its band and in
## sight.
static func on_think(w: World, i: int) -> void:
	var a := w.actors
	if a.kinds[i] != ActorStore.Kind.CINDER_PRIEST or a.state[i] != EnemyAi.State.MOVE:
		return
	var s := w.canyon_shore
	if s.vent_of(a.ids[i]) >= 0 or w.player_dead():
		return
	var t := w.enemy_table(a.kinds[i])
	var at := a.pos(i)
	var to := w.player_pos() - at
	if Kin.length(to) > t.keep_distance_m or not EnemyAi.sees_player(w, at):
		return
	var first := w.tick + t.vent_period_ticks
	var dmg := EnemyAi.powered(w, i, t.vent_damage)
	for k in s.vent_count():  # a cooling vent near it: its own now
		if s.vent_until[k] >= 0 and Kin.length(s.vent_pos(k) - at) <= t.vent_reach_m:
			s.vent_owner[k] = a.ids[i]
			s.vent_until[k] = -1
			s.vent_next[k] = first
			s.vent_period[k] = t.vent_period_ticks
			s.vent_warn[k] = t.vent_warn_ticks
			s.vent_damage[k] = dmg
			s.vent_r[k] = t.vent_radius_m
			return
	if s.vent_count() >= MAX_VENTS:
		return
	var spot := plant_spot(w, at, Kin.angle_of(to), t.vent_reach_m)
	s.add_vent(spot, t.vent_radius_m, a.ids[i], first, t.vent_period_ticks, t.vent_warn_ticks, dmg)


## Where a priest at `at` plants its vent: `reach` along `angle` (toward the hero), else two thirds and a third of it,
## else its own feet; each spot clear of walls and in a room.
static func plant_spot(w: World, at: Vector2, angle: int, reach: float) -> Vector2:
	for share: float in [1.0, 0.66, 0.33]:
		var q := at + Kin.dir(angle) * (reach * share)
		var in_room := w.floor_layout == null or w.floor_layout.room_of(q) >= 0
		if in_room and EnemyAi.clear_of_walls(w, q, VENT_CLEAR_M):
			return q
	return at


## EnemyAi._walk_dir for a Cinder Priest: with a vent, back to it (or still by it); else `fallback` (its band's walk).
static func priest_walk(w: World, i: int, fallback: Vector2) -> Vector2:
	var s := w.canyon_shore
	var k := s.vent_of(w.actors.ids[i])
	if k < 0:
		return fallback
	var to := s.vent_pos(k) - w.actors.pos(i)
	var d := Kin.length(to)
	if d <= s.vent_r[k] + STAND_M or d <= 0.0001:
		return Vector2.ZERO
	return to / d


# --- The Frost Spitter's blob ---------------------------------------------------------------------------------
## EnemyAi._aim for a Frost Spitter: the landing is where the hero stands (no lead), facing it.
static func aim_blob(w: World, i: int) -> void:
	var a := w.actors
	var p := w.player_pos()
	a.lock_x[i] = p.x
	a.lock_y[i] = p.y
	a.lock_a[i] = Kin.angle_of(p - a.pos(i))
	a.facing[i] = a.lock_a[i]


## EnemyAi resolve (its active tick): the blob leaves for the locked landing.
static func throw_blob(w: World, i: int) -> void:
	var s := w.canyon_shore
	if s.blob_count() >= MAX_BLOBS:
		return
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	s.add_blob(
		a.pos(i),
		Vector2(a.lock_x[i], a.lock_y[i]),
		t.slick_radius_m,
		w.tick,
		w.tick + t.flight_ticks,
		a.ids[i],
		t.slick_ticks,
		t.slick_permille
	)


## The Frost Spitter's windup telegraph: the blue arc from it to the landing and the landing ring (EI-07: the landing
## throw_blob uses).
static func spitter_telegraph(w: World, i: int, progress: int) -> Dictionary:
	var a := w.actors
	return {
		"shape": &"ice_arc",
		"ground": false,  # (CanyonShoreViews draws it, in the pack's frost)
		"from": a.pos(i),
		"to": Vector2(a.lock_x[i], a.lock_y[i]),
		"radius": w.enemy_table(a.kinds[i]).slick_radius_m,
		"progress": progress
	}


# --- The Glacier Turtle's shell -------------------------------------------------------------------------------
## Damage.hit: whether turtle `target`'s shell takes a hit of `amount` from `from` (its front arc, the shell standing);
## the hit that breaks it bursts it into chunks.
static func shell_takes(w: World, target: int, from: Vector2, amount: int) -> bool:
	var a := w.actors
	if a.kinds[target] != ActorStore.Kind.GLACIER_TURTLE or from == a.pos(target):
		return false
	var t := w.enemy_table(a.kinds[target])
	if t == null or t.shell_hp <= 0:
		return false
	var s := w.canyon_shore
	var hp := s.shell_of(a.ids[target], t.shell_hp)
	if hp <= 0:
		return false
	var to_from := Kin.angle_of(from - a.pos(target))
	if Kin.angle_diff(to_from, a.facing[target]) > t.front_half_arc:
		return false
	hp = maxi(0, hp - amount)
	s.set_shell(a.ids[target], hp)
	if hp == 0:
		_break_shell(w, target, from, t)
	return true


## Whether turtle i's shell still stands (the view).
static func shell_on(w: World, i: int) -> bool:
	var t := w.enemy_table(w.actors.kinds[i])
	return (
		w.actors.kinds[i] == ActorStore.Kind.GLACIER_TURTLE
		and t != null
		and w.canyon_shore.shell_of(w.actors.ids[i], t.shell_hp) > 0
	)


static func _break_shell(w: World, i: int, from: Vector2, t: EnemyTable) -> void:
	var a := w.actors
	var s := w.canyon_shore
	var at := a.pos(i)
	var away := Kin.angle_of(at - from)
	var reach := a.radius[i] + CHUNK_RADIUS_M + 0.05
	var dmg := EnemyAi.powered(w, i, t.chunk_damage)
	for k in t.chunk_count:
		if s.chunk_count() >= MAX_CHUNKS:
			return
		var ang := (away + (k - (t.chunk_count - 1) / 2) * CHUNK_SPREAD) & 4095
		var q := at + Kin.dir(ang) * reach
		if EnemyAi.clear_of_walls(w, q, CHUNK_RADIUS_M):
			s.add_chunk(
				q, Kin.dir(ang) * t.chunk_speed, w.tick, w.tick + t.chunk_ticks, dmg, a.ids[i]
			)


# --- Phase 9: deaths ---------------------------------------------------------------------------------------------
## EnemyAi.on_death: a Kiln Beetle's burst stands where it fell; a Cinder Priest's vent cools.
static func on_death(w: World, i: int) -> void:
	var a := w.actors
	var s := w.canyon_shore
	match a.kinds[i]:
		ActorStore.Kind.KILN_BEETLE:
			if s.burst_count() >= MAX_BURSTS:
				return
			var t := w.enemy_table(a.kinds[i])
			s.add_burst(
				a.pos(i),
				t.burst_radius_m,
				w.tick,
				w.tick + t.burst_delay_ticks,
				EnemyAi.powered(w, i, t.burst_damage),
				EnemyAi.powered(w, i, t.burst_enemy_damage)
			)
		ActorStore.Kind.CINDER_PRIEST:
			var k := s.vent_of(a.ids[i])
			if k >= 0:
				_cool(w, k)


static func _cool(w: World, k: int) -> void:
	var s := w.canyon_shore
	var t := w.enemy_table(ActorStore.Kind.CINDER_PRIEST)
	s.vent_next[k] = -1
	s.vent_until[k] = w.tick + (t.vent_linger_ticks if t != null else 0)


# --- Phase 6: the bursts, the vents, the blobs, the chunks --------------------------------------------------------
static func advance(w: World) -> void:
	_advance_vents(w)
	_advance_bursts(w)
	_advance_blobs(w)
	_advance_chunks(w)


static func _advance_vents(w: World) -> void:
	var s := w.canyon_shore
	var gone := PackedInt32Array()
	for k in s.vent_count():
		if s.vent_until[k] >= 0:
			if w.tick >= s.vent_until[k]:
				gone.append(k)
			continue
		var oi := w.actors.index_of(s.vent_owner[k])
		if oi < 0:  # its priest left without dying (it cools as at a death)
			_cool(w, k)
			continue
		if w.tick >= s.vent_next[k]:
			s.vent_next[k] += s.vent_period[k]
			erupt(w, k)
	s.remove(&"vent", gone)


## Vent k erupts now: its column hurts the hero in it.
static func erupt(w: World, k: int) -> void:
	var s := w.canyon_shore
	s.vent_last[k] = w.tick
	var c := s.vent_pos(k)
	var p := w.player_pos()
	if w.player_dead() or not AttackShapes.disc_touches(c, s.vent_r[k], p, w.player.radius_m):
		return
	Damage.hit(w, 0, s.vent_damage[k], 0, 0, w.take_root(), SimEvent.TAG_AREA, c, p, VENT_EFFECT)
	if w.player_dead():
		w.killer_attack = KILL_VENT


## Vent k's pulse now: 0 outside its warning, else 1..1000 through the vent_warn ticks before its next eruption (the
## telegraph the view draws, and the priest's staff keeps time with).
static func vent_pulse(w: World, k: int) -> int:
	var s := w.canyon_shore
	if s.vent_next[k] < 0:
		return 0
	var left := s.vent_next[k] - w.tick
	if left > s.vent_warn[k] or s.vent_warn[k] <= 0:
		return 0
	return clampi((s.vent_warn[k] - left) * 1000 / s.vent_warn[k], 1, 1000)


static func _advance_bursts(w: World) -> void:
	var s := w.canyon_shore
	var gone := PackedInt32Array()
	for k in s.burst_count():
		if w.tick >= s.burst_due[k]:
			gone.append(k)
			_blow(w, k)
	s.remove(&"burst", gone)


## Burst k blows: the hero and every enemy in it are hurt, and a vent it stands on erupts.
static func _blow(w: World, k: int) -> void:
	var s := w.canyon_shore
	var a := w.actors
	var c := s.burst_pos(k)
	var r := s.burst_r[k]
	var root := w.take_root()
	for j in a.size():
		if a.dead[j] == 1 or not AttackShapes.disc_touches(c, r, a.pos(j), a.radius[j]):
			continue
		if j != 0 and not EnemyAi.is_enemy_kind(a.kinds[j]):
			continue
		var amount := s.burst_hero[k] if j == 0 else s.burst_enemy[k]
		Damage.hit(w, j, amount, 0, 0, root, SimEvent.TAG_AREA, c, a.pos(j), BURST_EFFECT)
		if j == 0 and a.dead[0] == 1:
			w.killer_attack = KILL_BURST
	for v in s.vent_count():
		if Kin.length(s.vent_pos(v) - c) <= s.vent_r[v] + ON_VENT_M:
			erupt(w, v)


static func _advance_blobs(w: World) -> void:
	var s := w.canyon_shore
	var gone := PackedInt32Array()
	for k in s.blob_count():
		if w.tick < s.blob_land[k]:
			continue
		gone.append(k)
		var v := w.variants
		if v.trail_count() >= Variants.MAX_TRAILS:
			v.remove_trails(PackedInt32Array([0]))
		v.add_trail(
			Variants.TRAIL_SLICK,
			Vector2(s.blob_tx[k], s.blob_ty[k]),
			s.blob_r[k],
			w.tick,
			w.tick + s.blob_ticks[k],
			0,
			s.blob_ease[k],
			0,
			s.blob_owner[k]
		)
	s.remove(&"blob", gone)


static func _advance_chunks(w: World) -> void:
	var s := w.canyon_shore
	var a := w.actors
	var gone := PackedInt32Array()
	for k in s.chunk_count():
		var at := s.chunk_pos(k)
		var vel := Vector2(s.chunk_vx[k], s.chunk_vy[k])
		var to := at + vel
		if w.tick >= s.chunk_until[k] or not EnemyAi.clear_of_walls(w, to, CHUNK_RADIUS_M):
			gone.append(k)
			continue
		s.chunk_x[k] = to.x
		s.chunk_y[k] = to.y
		s.chunk_vx[k] = vel.x * CHUNK_FRICTION
		s.chunk_vy[k] = vel.y * CHUNK_FRICTION
		var armed := w.tick - s.chunk_born[k] >= CHUNK_ARM_TICKS
		for j in a.size():
			if a.dead[j] == 1 or a.ids[j] == s.chunk_owner[k]:
				continue
			if (j == 0 and not armed) or (j != 0 and not EnemyAi.is_enemy_kind(a.kinds[j])):
				continue
			if not AttackShapes.disc_touches(to, CHUNK_RADIUS_M, a.pos(j), a.radius[j]):
				continue
			if s.chunk_hit(s.chunk_serial[k], a.ids[j]):
				continue
			s.note_hit(s.chunk_serial[k], a.ids[j])
			Damage.hit(
				w,
				j,
				s.chunk_damage[k],
				0,
				0,
				w.take_root(),
				SimEvent.TAG_AREA,
				at,
				to,
				CHUNK_EFFECT
			)
			if j == 0 and a.dead[0] == 1:
				w.killer_attack = KILL_CHUNK
	s.remove(&"chunk", gone)


## The recap line for a death World.killer_attack names here, or &"".
static func cause_key(w: World) -> StringName:
	match w.killer_attack:
		KILL_BURST:
			return CAUSE_BURST
		KILL_VENT:
			return CAUSE_VENT
		KILL_CHUNK:
			return CAUSE_CHUNK
	return &""


## The warning each of these hits shows before it can hurt (ticks; ReadableCause checks it is the minimum or more).
static func warning_ticks(w: World, effect: StringName) -> int:
	match effect:
		BURST_EFFECT:
			var b := w.enemy_table(ActorStore.Kind.KILN_BEETLE)
			return b.burst_delay_ticks if b != null else 0
		VENT_EFFECT:
			var p := w.enemy_table(ActorStore.Kind.CINDER_PRIEST)
			return p.vent_warn_ticks if p != null else 0
		CHUNK_EFFECT:
			return CHUNK_ARM_TICKS
	return 0


static func cause_of_effect(effect: StringName) -> StringName:
	match effect:
		BURST_EFFECT:
			return CAUSE_BURST
		VENT_EFFECT:
			return CAUSE_VENT
		CHUNK_EFFECT:
			return CAUSE_CHUNK
	return &""
