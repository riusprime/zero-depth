class_name BossNemesis
extends RefCounted
## v0.8.0 FB3 (owner O17: "the third model, the small black one … the nemesis of the main character … a fight where he
## mimics some of the movements of the main character and uh, has a mix of both a melee and range fight"; owner F6
## "Weapon + dash + 2-3 cards"; FINAL_BOSS.md F6, F7; SIM_CONTRACTS "The final boss"): the Nemesis, the final boss's
## last body, beside the boss framework (BossAi calls it in its phases). What it takes from the build is NemesisBuild's.
## - The record (tick phase 9, record): every tick it fights, the player's position goes into the fight's echo ring and
##   a dash the player starts is noted, to be answered dash_react_ticks later.
## - The dash (think, moves): a noted dash is answered on its tick when the Nemesis is free (moving or recovering, not
##   winding up or striking): the player's own dash (its distance over its ticks, its i-frames), the player's way (the
##   opposite way in the mirror stance). A dash that comes due mid-attack is dropped. It never hurts by itself.
## - The stance (think, moves; between attacks): ECHO walks the player's path echo_ticks behind (the echo ring), MIRROR
##   stands across the fight's centre from the player (FinalFight.home × 2 - the player), CLOSE closes in, BACK backs
##   off to back_off_m; a new stance from the ai stream (stance_weights) every stance_ticks; after a combo it backs off
##   (closes in with the weapon's combo, backs off and shoots). It always faces the player.
## - `mimic_combo` (a Blade run): `count` swings of the player's own combo steps in order (each its arc and reach as the
##   wand compiled them), mark_gap_ticks apart. Each follows the player (it steps in at the attack's speed) until
##   lock_ticks before it lands, then holds where it locked: combo_arc, drawn and hit alike.
## - `mimic_shots`: the run's ranged form: a Gun run's shot (every card on it: its count, spread, ring, back shot,
##   splits, size and speed, clamped), a Blade run's thrown slash (crescents): `volleys` of them gap_ticks apart down
##   the lines it locked lock_ticks before the first (shot_lines, drawn and fired alike).
## - `card_cast`: one of the strongest cards of the player's wand (NemesisCast): its arc (struck arc_strikes times,
##   mark_gap_ticks apart), its volley and its blast (a disc on the spot it locked), all tracked then locked for
##   lock_ticks, landing on its first active tick.
## - Fair: every strike shows locked for its lock before it lands; no shot appears within SAFE_M of the player's edge or
##   in a wall; volleys go through the hostile caps (BulletPatterns.room: shots a tick, shots alive) and stay within
##   BossTable.shots_max; no hit deals more than FinalFight.hit_cap. Pure: integer angles (Kin), the ai stream only for
##   the stance.

const S := EnemyAi.State
const M := BossAttackTable.Move
## STATUS_APPLY effect ids (views, sound): it dashes (amount: its dash ticks), it casts a card (amount: the card).
const EFFECT_DASH := &"nemesis_dash"
const EFFECT_CAST := &"nemesis_cast"
## No volley shot appears within this of the player's edge.
const SAFE_M := 1.0
const MUZZLE_M := 0.05
## A stance's walk stops this close to its point.
const ARRIVE_M := 0.3
## BossStore point of a card cast's blast (tracked, then locked).
const BLAST_PT := 0


## Actor i is a mimic body in a fight (BossTable.mimic).
static func is_mimic(w: World, i: int) -> bool:
	return w.final_fight != null and BossAi.table_of(w, i).mimic


static func is_move(move: int) -> bool:
	return move == M.MIMIC_COMBO or move == M.MIMIC_SHOTS or move == M.CARD_CAST


## The fan's shot k of n over `full` (1/4096 turns, the whole fan's width) centred on `aim` (Attacks.shot_offsets).
static func fan_angle(aim: int, k: int, n: int, full: int) -> int:
	if n <= 1:
		return aim & 4095
	var half := full / 2
	return (aim - half + 2 * half * k / (n - 1)) & 4095


## Body i's attack may be picked now: its weapon is the run's, and a card cast's card is held. v0.8.0 N2 (owner O52):
## with mimic windows, outside a window it fights with its own kit (every attack but the card casts, whatever the
## run's weapon, and its own: weapon "own"); in a window only the run's weapon's and the cards, never its own.
static func allowed(w: World, atk: BossAttackTable) -> bool:
	var f := w.final_fight
	if f == null:
		return atk.move != M.CARD_CAST
	var t := FinalPace.table(w)
	if t != null and t.window_ticks > 0 and not FinalPace.copies(w):
		return atk.move != M.CARD_CAST
	if atk.weapon == BossAttackTable.WEAPON_OWN:
		return false
	if atk.weapon != BossAttackTable.WEAPON_ANY and atk.weapon != f.weapon:
		return false
	return atk.move != M.CARD_CAST or (atk.card >= 0 and atk.card < f.casts.size())


# --- tick phase 9: the record -------------------------------------------------------------------------------------


## FinalBoss.advance, while mimic body i fights (not shattering): the player's place into the echo, a dash begun this
## tick noted.
static func record(w: World, i: int) -> void:
	var f := w.final_fight
	if w.player_dead():
		return
	f.note_echo(w.player_pos())
	if w.dash_ticks_left > 0 and w.dash_ticks_left == w.player.dash_ticks:
		var d := w.dash_dir
		var n := Kin.length(d)
		f.dash_dir = d / n if n > 0.0001 else Kin.dir(w.actors.facing[0])
		f.dash_due = w.tick + BossAi.table_of(w, i).dash_react_ticks


# --- tick phase 3 -------------------------------------------------------------------------------------------------


## BossAi.think, first: the build read (an FB2 save's fight), a dash due, the stance's clock.
static func think(w: World, i: int, t: BossTable) -> void:
	var f := w.final_fight
	if not f.ready:
		NemesisBuild.prepare(w, i, t, false)
	var a := w.actors
	var free := a.state[i] == S.MOVE or a.state[i] == S.RECOVER
	if f.dash_due >= 0 and w.tick >= f.dash_due:
		f.dash_due = -1
		if free and f.dash_t == 0 and not w.player_dead() and FinalPace.copies(w):  # N2: in a window
			_dash(w, i)
	if a.state[i] == S.MOVE and f.dash_t == 0:
		f.stance_t -= 1
		if f.stance_t <= 0:
			_next_stance(w, t)


## True while body i dashes (it picks no attack meanwhile).
static func dashing(w: World, i: int) -> bool:
	return is_mimic(w, i) and w.final_fight.dash_t > 0


static func _dash(w: World, i: int) -> void:
	var f := w.final_fight
	var a := w.actors
	var d := f.dash_dir
	if f.stance == BossTable.STANCE_MIRROR:
		d = -d
	var ticks := maxi(1, w.player.dash_ticks)
	f.dash_t = ticks
	f.dash_vel = d * (w.player.dash_distance_m / ticks)
	a.invuln[i] = maxi(a.invuln[i], w.player.dash_iframe_ticks)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[i], a.ids[i], a.ids[i], a.pos(i))
	e.effect_id = EFFECT_DASH
	e.amount = ticks


## v0.8.0 N2: outside a mimic window it neither echoes nor mirrors the player (its own kit: close in or back off).
static func _next_stance(w: World, t: BossTable) -> void:
	var f := w.final_fight
	var weights := t.stance_weights
	if not FinalPace.copies(w):
		weights = weights.duplicate()
		weights[BossTable.STANCE_ECHO] = 0
		weights[BossTable.STANCE_MIRROR] = 0
	var pick := w.rng_ai.pick_weighted(weights)
	var fallback := BossTable.STANCE_ECHO if FinalPace.copies(w) else BossTable.STANCE_CLOSE
	f.stance = pick if pick >= 0 else fallback
	f.stance_t = maxi(1, t.stance_ticks)


## BossAi.think, as body i's attack ends (back to moving): after a combo it backs off.
static func after_attack(w: World, i: int, atk: BossAttackTable) -> void:
	if atk.move == M.MIMIC_COMBO and is_mimic(w, i):
		w.final_fight.stance = BossTable.STANCE_BACK
		w.final_fight.stance_t = maxi(1, BossAi.table_of(w, i).stance_ticks)


## BossAi._lock: aimed at the player, from where it stands; a card's blast on the player.
## v0.8.0 N2: the attack copies the build when it begins in a mimic window (FinalFight.copying, kept to its end).
static func lock(w: World, i: int, b: int, _atk: BossAttackTable) -> void:
	if w.final_fight != null:
		w.final_fight.copying = FinalPace.copies(w)
	_follow(w, i)
	w.bosses.set_pt(b, BLAST_PT, w.player_pos())


## BossAi.think (WINDUP and ACTIVE): what is still tracking follows the player.
static func think_attack(w: World, i: int, b: int, atk: BossAttackTable, t: int) -> void:
	if w.player_dead():
		return
	match atk.move:
		M.MIMIC_COMBO:
			if combo_tracking(atk, t):
				_follow(w, i)
		_:
			if t < atk.windup_ticks - atk.lock_ticks:
				_follow(w, i)
				w.bosses.set_pt(b, BLAST_PT, w.player_pos())


static func _follow(w: World, i: int) -> void:
	var a := w.actors
	var aim := Kin.angle_of(w.player_pos() - a.pos(i))
	a.facing[i] = aim
	a.lock_a[i] = aim
	a.lock_x[i] = a.pos_x[i]
	a.lock_y[i] = a.pos_y[i]


# --- tick phase 5 -------------------------------------------------------------------------------------------------


## BossAi.move, first: true when the Nemesis moved itself (a dash, a stance's walk, a combo's step in).
static func moves(w: World, i: int, slow: float) -> bool:
	if not is_mimic(w, i):
		return false
	var f := w.final_fight
	var a := w.actors
	var s := a.state[i]
	if s == S.SPAWN or s == BossAi.GATE or s == FinalBoss.SHATTER or s == BossAi.STAGGERED:
		f.dash_t = 0
		return true
	if f.dash_t > 0:
		f.dash_t -= 1
		var v := f.dash_vel
		var len := Kin.length(v)
		if len > 0.0001:
			var run := EnemyAi.clear_run(w, a.pos(i), Kin.angle_of(v), len, a.radius[i])
			a.set_pos(i, a.pos(i) + v * (clampf(run, 0.0, len) / len))
		return true
	match s:
		S.MOVE:
			_walk(w, i, stance_point(w, i), slow)
		S.WINDUP, S.ACTIVE:
			var atk := BossAi.attack_of(w, i)
			if atk != null and atk.move == M.MIMIC_COMBO:
				_step_in(w, i, atk, slow)
	return true


## Where the stance walks to now.
static func stance_point(w: World, i: int) -> Vector2:
	var f := w.final_fight
	var t := BossAi.table_of(w, i)
	var p := w.player_pos()
	match f.stance:
		BossTable.STANCE_ECHO:
			return f.echo_at(t.echo_ticks, p)
		BossTable.STANCE_MIRROR:
			return f.home * 2.0 - p
		BossTable.STANCE_BACK:
			var away := w.actors.pos(i) - p
			var d := Kin.length(away)
			if d < 0.0001:
				away = Kin.dir((w.actors.facing[i] + 2048) & 4095)
				d = 1.0
			return p + away / d * t.back_off_m
	return p


static func _walk(w: World, i: int, to: Vector2, slow: float) -> void:
	var a := w.actors
	var b := BossAi.entry_of(w, i)
	var t := BossAi.table_of(w, i)
	var at := a.pos(i)
	var d := to - at
	var dist := Kin.length(d)
	var speed := t.speed * t.phase_speed_permille[w.bosses.phase[b]] / 1000.0 * slow
	if dist <= ARRIVE_M or speed <= 0.0 or w.player_dead():
		return
	a.set_pos(i, at + EnemyAi.steer(w, at, d / dist, a.radius[i]) * minf(speed, dist))


## A combo swing that still follows: it steps toward the player, stopping half the swing's reach from their edge.
static func _step_in(w: World, i: int, atk: BossAttackTable, slow: float) -> void:
	var a := w.actors
	var t := BossDodge.attack_ticks(w, i, atk)
	if w.player_dead() or atk.speed <= 0.0 or not combo_tracking(atk, t):
		return
	var at := a.pos(i)
	var to := w.player_pos() - at
	var dist := Kin.length(to)
	var reach: float = combo_arc(w, i, combo_strike_at(atk, t))[4]
	if dist <= a.radius[i] + w.player.radius_m + reach * 0.5 or dist <= 0.0001:
		return
	a.set_pos(i, at + EnemyAi.steer(w, at, to / dist, a.radius[i]) * minf(atk.speed * slow, dist))
	a.lock_x[i] = a.pos_x[i]
	a.lock_y[i] = a.pos_y[i]


# --- the combo ----------------------------------------------------------------------------------------------------


## The attack tick (BossDodge.attack_ticks) swing k lands on.
static func combo_strike_tick(atk: BossAttackTable, k: int) -> int:
	return atk.windup_ticks + k * atk.mark_gap_ticks


## The swing pending at attack tick t (0 .. count - 1).
static func combo_strike_at(atk: BossAttackTable, t: int) -> int:
	if t <= atk.windup_ticks:
		return 0
	var gap := maxi(1, atk.mark_gap_ticks)
	return mini(atk.count - 1, (t - atk.windup_ticks + gap - 1) / gap)


## True while the pending swing still follows the player at attack tick t.
static func combo_tracking(atk: BossAttackTable, t: int) -> bool:
	return t < combo_strike_tick(atk, combo_strike_at(atk, t)) - atk.lock_ticks


## [center, own_r, angle, half_arc, reach] of swing k where it locked: the player's combo step k (mod the combo), or the
## attack's own arc without one.
static func combo_arc(w: World, i: int, k: int) -> Array:
	var a := w.actors
	var atk := BossAi.attack_of(w, i)
	var f := w.final_fight
	var half := atk.half_arc
	var reach := atk.reach_m
	if f != null and f.copying and not f.combo_half.is_empty():  # v0.8.0 N2: your combo in a window
		var n := f.combo_half.size()
		half = f.combo_half[k % n]
		reach = f.combo_reach[k % n]
	return [Vector2(a.lock_x[i], a.lock_y[i]), a.radius[i], a.lock_a[i], half, reach]


# --- the shots ----------------------------------------------------------------------------------------------------


## The volley a `mimic_shots` fires: the run's shot (FinalFight.shot) when it has one, else the attack's own crescents
## (`count`, `spread` between two of them, CRESCENT_SPEED unless the attack sets speed_mps).
static func shot_cast(w: World, i: int, atk: BossAttackTable) -> NemesisCast:
	var f := w.final_fight
	if f != null and f.copying and f.shot != null and f.shot.has_volley():  # v0.8.0 N2: in a window
		return f.shot
	var t := BossAi.table_of(w, i)
	var c := NemesisCast.new()
	c.vol_count = clampi(atk.count, 1, t.shots_max)
	c.vol_spread = atk.spread * (c.vol_count - 1)
	c.vol_speed = clampf(
		atk.speed if atk.speed > 0.0 else NemesisBuild.CRESCENT_SPEED,
		t.shot_speed_min,
		t.shot_speed_max
	)
	c.vol_radius_m = clampf(
		atk.radius_m if atk.radius_m > 0.0 else NemesisBuild.CRESCENT_RADIUS_M,
		t.shot_radius_min_m,
		t.shot_radius_max_m
	)
	c.vol_life = maxi(10, int(t.shot_range_m / c.vol_speed))
	c.look = NemesisCast.LOOK_CRESCENT
	return c


## The card attack k casts (null when the build holds fewer cards).
static func card_of(w: World, atk: BossAttackTable) -> NemesisCast:
	var f := w.final_fight
	if f == null or atk.card < 0 or atk.card >= f.casts.size():
		return null
	if not f.copying and FinalPace.table(w) != null and FinalPace.table(w).window_ticks > 0:
		return null  # v0.8.0 N2: a card is cast only in a window
	return f.casts[atk.card]


## The cast attack `atk` makes now (a card's, or the run's shot), or null.
static func cast_of(w: World, i: int, atk: BossAttackTable) -> NemesisCast:
	if atk.move == M.CARD_CAST:
		return card_of(w, atk)
	if atk.move == M.MIMIC_SHOTS:
		return shot_cast(w, i, atk)
	return null


## The lines a volley of `c` aimed where body i locked would fly down: one per shot, from its muzzle, as long as its
## flight unless a wall stops it.
static func shot_lines(w: World, i: int, c: NemesisCast) -> Array[Obb]:
	var a := w.actors
	var from := Vector2(a.lock_x[i], a.lock_y[i])
	var out: Array[Obb] = []
	for ang in c.angles(a.lock_a[i]):
		var at := from + Kin.dir(ang) * (a.radius[i] + c.vol_radius_m + MUZZLE_M)
		var run := EnemyAi.clear_run(w, at, ang, c.vol_speed * c.vol_life, c.vol_radius_m)
		out.append(AttackShapes.lane(at, ang, maxf(run, 0.01), c.vol_radius_m))
	return out


## Fires a volley of `c` from where body i locked, down its locked aim: each shot fair (not within SAFE_M of the
## player's edge, not in a wall) and under the hostile caps; each carries `attack` (the recap's cause). Returns how many
## were queued.
static func fire_volley(w: World, i: int, c: NemesisCast, damage: int, attack: int) -> int:
	var a := w.actors
	var from := Vector2(a.lock_x[i], a.lock_y[i])
	var safe := SAFE_M + w.player.radius_m
	var p := w.player_pos()
	var n := 0
	for ang in c.angles(a.lock_a[i]):
		var dir := Kin.dir(ang)
		var at := from + dir * (a.radius[i] + c.vol_radius_m + MUZZLE_M)
		var d := at - p
		if d.x * d.x + d.y * d.y < safe * safe:
			continue
		if not EnemyAi.clear_of_walls(w, at, c.vol_radius_m):
			continue
		if not BulletPatterns.room(w):
			var e := w.emit_event(SimEvent.Kind.LIMIT, a.ids[i], a.ids[i], a.ids[i], from)
			e.effect_id = BulletPatterns.EFFECT_CAP
			e.amount = BulletPatterns.MAX_SHOTS_PER_TICK
			break
		w.queue_projectile(
			a.ids[i],
			ActorStore.TEAM_ENEMY,
			at,
			dir * c.vol_speed,
			damage,
			c.vol_radius_m,
			c.vol_life,
			SimEvent.TAG_PROJECTILE
		)
		w.set_pending_look(c.look)
		w.set_pending_cause(attack)
		n += 1
	return n


# --- tick phase 6 -------------------------------------------------------------------------------------------------


## BossAi.resolve for the Nemesis's moves.
static func resolve(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	var p := w.player_pos()
	var pr := w.player.radius_m
	match atk.move:
		M.MIMIC_COMBO:
			var gap := maxi(1, atk.mark_gap_ticks)
			if st % gap != 0 or st / gap >= atk.count:
				return
			w.bosses.hit[b] = 0
			var c := combo_arc(w, i, st / gap)
			if AttackShapes.arc_touches(c[0], c[1], c[2], c[3], c[4], p, pr):
				_hit(w, i, b, NemesisBuild.damage_of(w, atk), SimEvent.TAG_MELEE, c[0])
		M.MIMIC_SHOTS:
			if st % maxi(1, atk.gap_ticks) != 0 or st / maxi(1, atk.gap_ticks) >= atk.volleys:
				return
			fire_volley(
				w, i, shot_cast(w, i, atk), NemesisBuild.damage_of(w, atk), w.bosses.attack[b]
			)
		M.CARD_CAST:
			_resolve_card(w, i, b, atk, st)


static func _resolve_card(w: World, i: int, b: int, atk: BossAttackTable, st: int) -> void:
	var c := card_of(w, atk)
	if c == null:
		return
	var p := w.player_pos()
	var pr := w.player.radius_m
	var dmg := NemesisBuild.damage_of(w, atk, c.damage_permille)
	if st == 0:
		var id := w.actors.ids[i]
		var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, w.actors.pos(i))
		e.effect_id = EFFECT_CAST
		e.amount = atk.card
		if c.has_volley():
			fire_volley(w, i, c, dmg, w.bosses.attack[b])
		if c.has_blast():
			w.bosses.hit[b] = 0
			var at := w.bosses.pt(b, BLAST_PT)
			if AttackShapes.disc_touches(at, c.blast_m, p, pr):
				_hit(w, i, b, dmg, SimEvent.TAG_AREA, at)
	var gap := maxi(1, atk.mark_gap_ticks)
	if c.has_arc() and st % gap == 0 and st / gap < c.arc_strikes:
		w.bosses.hit[b] = 0
		var arc := card_arc(w, i, c)
		if AttackShapes.arc_touches(arc[0], arc[1], arc[2], arc[3], arc[4], p, pr):
			_hit(w, i, b, dmg, SimEvent.TAG_MELEE, arc[0])


## [center, own_r, angle, half_arc, reach] of card `c`'s arc where it locked.
static func card_arc(w: World, i: int, c: NemesisCast) -> Array:
	var a := w.actors
	return [Vector2(a.lock_x[i], a.lock_y[i]), a.radius[i], a.lock_a[i], c.arc_half, c.arc_reach_m]


## Hits the player with `amount` (the build's, already capped), once per strike (BossStore.hit).
static func _hit(w: World, i: int, b: int, amount: int, tags: int, from: Vector2) -> void:
	if w.bosses.hit[b] == 1:
		return
	w.bosses.hit[b] = 1
	var a := w.actors
	Damage.hit(w, 0, amount, a.ids[i], a.ids[i], w.take_root(), tags, from, w.player_pos())
	if w.player_dead() and w.killer_attack < 0:
		w.killer_attack = w.bosses.attack[b]


# --- reads --------------------------------------------------------------------------------------------------------


## What the view draws for the Nemesis's attack (BossAi.telegraph): a combo swing as the Colossus's (an &"arc",
## "tracked", "locked", "striking", "strike", "strikes"); a volley's lines as &"lanes" (tracked, then locked); a card as
## &"marks" whose items are its arc (&"arc"), its volley's lines (&"lanes") and its blast (&"disc"), with "card" (its
## id), "card_index" and "striking" on the tick it lands (and each arc repeat's).
static func telegraph(w: World, i: int, b: int, atk: BossAttackTable) -> Dictionary:
	var a := w.actors
	var windup := a.state[i] == S.WINDUP
	var t := BossDodge.attack_ticks(w, i, atk)
	match atk.move:
		M.MIMIC_COMBO:
			var k := combo_strike_at(atk, t)
			var t0 := 0 if k == 0 else combo_strike_tick(atk, k - 1)
			var span := maxi(1, combo_strike_tick(atk, k) - t0)
			var c := combo_arc(w, i, k)
			return {
				"shape": &"arc",
				"center": c[0],
				"own_r": c[1],
				"angle": c[2],
				"half_arc": c[3],
				"reach": c[4],
				"progress": clampi((t - t0) * 1000 / span, 0, 1000),
				"move": atk.move,
				"tracked": true,
				"locked": not combo_tracking(atk, t),
				"strike": k,
				"strikes": atk.count,
				"striking": t == combo_strike_tick(atk, k),
			}
		M.MIMIC_SHOTS:
			var st := a.state_t[i]
			var gap := maxi(1, atk.gap_ticks)
			if not windup and st >= (atk.volleys - 1) * gap + 1:
				return {}
			return {
				"shape": &"lanes",
				"obbs": shot_lines(w, i, shot_cast(w, i, atk)),
				"progress": clampi(t * 1000 / maxi(1, atk.windup_ticks), 0, 1000),
				"move": atk.move,
				"tracked": true,
				"locked": not windup or t >= atk.windup_ticks - atk.lock_ticks,
			}
	return _card_telegraph(w, i, b, atk, t, windup)


static func _card_telegraph(
	w: World, i: int, b: int, atk: BossAttackTable, t: int, windup: bool
) -> Dictionary:
	var c := card_of(w, atk)
	if c == null:
		return {}
	var st := t - atk.windup_ticks
	var gap := maxi(1, atk.mark_gap_ticks)
	var locked := not windup or t >= atk.windup_ticks - atk.lock_ticks
	var progress := clampi(t * 1000 / maxi(1, atk.windup_ticks), 0, 1000)
	var items: Array[Dictionary] = []
	var arcs_left := c.has_arc() and (windup or st < (c.arc_strikes - 1) * gap + 1)
	if arcs_left:
		var arc := card_arc(w, i, c)
		var item := {
			"shape": &"arc",
			"center": arc[0],
			"own_r": arc[1],
			"angle": arc[2],
			"half_arc": arc[3],
			"reach": arc[4],
		}
		items.append(item)
	if windup and c.has_volley():
		items.append({"shape": &"lanes", "obbs": shot_lines(w, i, c)})
	if windup and c.has_blast():
		items.append({"shape": &"disc", "center": w.bosses.pt(b, BLAST_PT), "radius": c.blast_m})
	var striking := (
		not windup and (st == 0 or (c.has_arc() and st % gap == 0 and st / gap < c.arc_strikes))
	)
	if items.is_empty() and not striking:
		return {}
	for item in items:
		item["locked"] = locked
		item["progress"] = 1000 if not windup else progress
	var out := {
		"shape": &"marks",
		"items": items,
		"progress": progress,
		"move": atk.move,
		"tracked": true,
		"locked": locked,
		"card": c.card_id,
		"card_index": atk.card,
		"striking": striking,
	}
	if striking:
		out["strike_items"] = _strike_items(w, i, b, c, st == 0)
	return out


## The parts landing this tick (the views' strikes): the arc, and on the first active tick the blast.
static func _strike_items(w: World, i: int, b: int, c: NemesisCast, first: bool) -> Array:
	var out := []
	if c.has_arc():
		var arc := card_arc(w, i, c)
		(
			out
			. append(
				{
					"shape": &"arc",
					"center": arc[0],
					"own_r": arc[1],
					"angle": arc[2],
					"half_arc": arc[3],
					"reach": arc[4],
				}
			)
		)
	if first and c.has_blast():
		out.append({"shape": &"disc", "center": w.bosses.pt(b, BLAST_PT), "radius": c.blast_m})
	return out


## The Nemesis for the views (WorldReader.nemesis): {} or {"weapon" (&"blade" or &"gun"), "stance" (BossTable
## .STANCE_*), "dashing", "dash_dir" (its way, m per tick), "echo" (where the echo walks to), "mirror" (the mirrored
## point), "hit", "hit_cap", "cards" ([NemesisCast.read()...]), "casting" (the card index being cast, -1 none),
## "cast_progress" (0..1000 of its windup)}.
static func state(w: World, i: int) -> Dictionary:
	if i < 0 or not is_mimic(w, i):
		return {}
	var f := w.final_fight
	var t := BossAi.table_of(w, i)
	var cards := []
	for c in f.casts:
		cards.append(c.read())
	var casting := -1
	var progress := 0
	var atk := BossAi.attack_of(w, i)
	var s := w.actors.state[i]
	if atk != null and atk.move == M.CARD_CAST and (s == S.WINDUP or s == S.ACTIVE):
		casting = atk.card
		progress = (
			clampi(w.actors.state_t[i] * 1000 / maxi(1, atk.windup_ticks), 0, 1000)
			if s == S.WINDUP
			else 1000
		)
	return {
		"weapon": &"gun" if f.weapon == BossAttackTable.WEAPON_GUN else &"blade",
		"stance": f.stance,
		"dashing": f.dash_t > 0,
		"dash_dir": f.dash_vel,
		"echo": f.echo_at(t.echo_ticks, w.player_pos()),
		"mirror": f.home * 2.0 - w.player_pos(),
		"hit": f.hit,
		"hit_cap": f.hit_cap,
		"cards": cards,
		"casting": casting,
		"cast_progress": progress,
	}
