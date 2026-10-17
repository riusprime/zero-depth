class_name FinalPace
extends RefCounted
## v0.8.0 N2 (owner O41, playtest 3: "a pretty intense fight that each phase takes 1-2 minutes 1 minute being the most
## op and longer if you are not op, oneshoting (killing a phase in seconds should never happen)"; O42 "it should mimic
## and nerf you into what he has so the match is even"; O52 "should only be at certain times not the whole fight, so
## on and off"; FINAL_BOSS.md "N2"; SIM_CONTRACTS "The final boss"): how long each body of the final boss lasts, and
## The Fallen's mimic windows. Two rules, both from the fight's damage meter (FinalFight, FinalBoss.measured), so the
## same inputs always give the same fight:
## - Its HP (BossTable.pace; hp_for): at the player's measured damage per second `dps` (the meter's last dps_seconds,
##   at least dps_min_seconds of them) a body lasts
##       time = pace_ref_ticks × sqrt(pace_ref_dps / dps), within pace_min_ticks .. pace_max_ticks
##   so HP = dps × time (× the Prism's window share). The base hero (dps ≈ pace_ref_dps) fights it about
##   pace_ref_ticks (2 min as shipped); 4× stronger about pace_min_ticks (1 min); weaker longer, never past
##   pace_max_ticks (3 min) at its own rate. The square root is why a stronger build is still quicker but never quick.
##   It is set as the body rises when the meter holds enough (the Prism, The Fallen: the seconds measured on the
##   Colossus), else the first tick it does (the Colossus: its first dps_min_seconds); then its HP keeps its fill.
## - The rate cap (cap_hit): every tick a paced body is in the fight (risen, not shattering) its bucket gains max HP /
##   pace_min_ticks (× 1000, integer), holding at most pace_burst_ticks of it; a player's hit takes at most what the
##   bucket holds. However the damage comes (procs, chains, splits), no build takes a body in under pace_min_ticks.
##   The world's own hits (owner 0: the dev panel's Kill boss) are not capped.
## - The Fallen's windows (BossTable.window_ticks > 0; window): one every window_every_ticks, window_ticks long, the
##   first window_first_ticks after its rise, each warned window_warn_ticks ahead (WARN). In a window it copies the
##   build (BossNemesis: your weapon, combo, shot, dash and cards; FinalFight.copying for the attack begun in it) and
##   pulls you to its level: your damage on it × nerf_permille (pace_ref_dps / the dps its HP was set from, at least
##   nerf_min_permille: the base hero's damage), your move speed at most the base (Stats.move_permille). Outside, it
##   fights with its own kit and you with yours.
## Pure: integer maths (64-bit), the integer square root (CatchUp.isqrt); no stream is drawn.

enum Mimic { OFF, WARN, ON }

## STATUS_APPLY effect ids for the views, the sound and the HUD: a window's warning begins, a window opens, it closes.
const EFFECT_WARN := &"fallen_warn"
const EFFECT_OPEN := &"fallen_open"
const EFFECT_CLOSE := &"fallen_close"


## The fight's current body table (null outside a fight).
static func table(w: World) -> BossTable:
	var f := w.final_fight
	if f == null or f.tables.is_empty():
		return null
	return w.boss_tables[f.tables[clampi(f.phase, 0, f.tables.size() - 1)]]


# --- the HP ---------------------------------------------------------------------------------------------------------


## The HP a paced body of table t gets at `dps_milli` (the measured damage per second × 1000): see the class doc.
static func hp_for(dps_milli: int, t: BossTable) -> int:
	if dps_milli <= 0:
		return clampi(t.hp, t.dps_hp_min, maxi(t.dps_hp_min, t.dps_hp_max))
	var time := seconds_at(dps_milli, t)
	var hp := dps_milli * time * t.window_permille / (SimTick.TICKS_PER_SECOND * 1000 * 1000)
	return clampi(hp, t.dps_hp_min, maxi(t.dps_hp_min, t.dps_hp_max))


## The ticks a paced body of table t lasts at `dps_milli`: pace_ref_ticks × sqrt(ref / dps), clamped.
static func seconds_at(dps_milli: int, t: BossTable) -> int:
	var root := CatchUp.isqrt(t.pace_ref_dps * 1000000000 / maxi(1, dps_milli))  # sqrt(ref / dps) per mille
	return clampi(t.pace_ref_ticks * root / 1000, t.pace_min_ticks, t.pace_max_ticks)


## The meter's damage per second × 1000 for table t ([dps_milli, seconds]; 0 when fewer than dps_min_seconds held).
static func measured_milli(w: World, t: BossTable) -> int:
	var m := FinalBoss.measured(w, t)
	if m[1] <= 0 or m[1] < t.dps_min_seconds:
		return 0
	return m[0] * 1000 / m[1]


## FinalBoss._spawn: a paced body rises; its HP from the meter when it holds enough.
static func rise(w: World, i: int, t: BossTable) -> void:
	var f := w.final_fight
	f.paced = false
	f.pace_dps = 0
	f.pace_budget = 0
	f.copying = false
	if t.pace:
		_try_set(w, i, t)


## Sets body i's HP from the meter (keeping its fill) once it holds enough.
static func _try_set(w: World, i: int, t: BossTable) -> void:
	var f := w.final_fight
	var dps := measured_milli(w, t)
	if dps <= 0:
		return
	var a := w.actors
	var hp := hp_for(dps, t)
	var fill := a.hp[i] * 1000 / maxi(1, a.max_hp[i])
	a.max_hp[i] = hp
	a.hp[i] = clampi(hp * fill / 1000, 1, hp)
	f.paced = true
	f.pace_dps = dps


## FinalBoss.advance, every tick body i fights (not shattering): its HP once the meter holds enough, its bucket, The
## Fallen's window cues.
static func advance(w: World, i: int, t: BossTable) -> void:
	var f := w.final_fight
	var a := w.actors
	if a.state[i] == EnemyAi.State.SPAWN or a.dead[i] == 1:
		return
	if t.pace:
		if not f.paced:
			_try_set(w, i, t)
		var rate := rate_milli(a.max_hp[i], t)
		f.pace_budget = mini(f.pace_budget + rate, rate * maxi(1, t.pace_burst_ticks))
	if t.mimic and t.window_ticks > 0:
		_cue(w, i, t)


## The bucket's gain a tick (× 1000) for a body of `max_hp`.
static func rate_milli(max_hp: int, t: BossTable) -> int:
	return maxi(1, max_hp * 1000 / maxi(1, t.pace_min_ticks))


## BossGates.clamp_damage (through FinalBoss.clamp_damage): the player's hit of `amount` on the body: The Fallen's
## window pulls it to its level, the bucket caps it (and pays for it). Owner 0 (the world's own) goes through.
static func cap_hit(w: World, amount: int, owner_id: int) -> int:
	var f := w.final_fight
	var t := table(w)
	if owner_id == 0 or t == null or amount <= 0:
		return amount
	if window(w) == Mimic.ON:
		amount = maxi(1, amount * nerf_permille(w, t) / 1000)
	if not t.pace:
		return amount
	amount = mini(amount, f.pace_budget / 1000)
	f.pace_budget -= amount * 1000
	return amount


# --- The Fallen's windows ---------------------------------------------------------------------------------------------


## The window now (OFF, WARN or ON); OFF outside a fight, before the body's rise ends, while it shatters, once won.
static func window(w: World) -> int:
	return window_at(w, w.tick)


static func window_at(w: World, tick: int) -> int:
	var f := w.final_fight
	var t := table(w)
	if t == null or not t.mimic or f.won or f.shatter_t > 0 or t.window_ticks <= 0:
		return Mimic.OFF
	var i := FinalBoss.body_index(w)
	if i < 0 or w.actors.dead[i] == 1 or w.actors.state[i] == EnemyAi.State.SPAWN:
		return Mimic.OFF
	var u := (
		tick - f.phase_tick - w.tuning.boss_intro_ticks - t.window_first_ticks + t.window_warn_ticks
	)
	if u < 0:
		return Mimic.OFF
	var c := u % maxi(1, t.window_every_ticks)
	if c < t.window_warn_ticks:
		return Mimic.WARN
	if c < t.window_warn_ticks + t.window_ticks:
		return Mimic.ON
	return Mimic.OFF


## True when the mimic body copies the build now: in a window, or always when its table has no windows (FB3).
static func copies(w: World) -> bool:
	var t := table(w)
	if t == null or not t.mimic:
		return false
	return t.window_ticks <= 0 or window(w) == Mimic.ON


## The player's damage on The Fallen in a window, per mille: pace_ref_dps over the dps its HP was set from (the base
## hero's level), at least nerf_min_permille, at most 1000.
static func nerf_permille(w: World, t: BossTable) -> int:
	var dps := w.final_fight.pace_dps
	if dps <= 0:
		dps = measured_milli(w, t)
	if dps <= 0:
		return 1000
	return clampi(t.pace_ref_dps * 1000000 / dps, t.nerf_min_permille, 1000)


## Stats.move_permille: in a window the player's move speed is at most the base.
static func move_cap(w: World, permille: int) -> int:
	if w.final_fight == null or permille <= 1000 or window(w) != Mimic.ON:
		return permille
	return 1000


## [ticks left in the current state, its length] (OFF: to the next warning).
static func window_clock(w: World) -> Array[int]:
	var f := w.final_fight
	var t := table(w)
	if t == null or not t.mimic or t.window_ticks <= 0 or f.shatter_t > 0:
		return [0, 0]
	var u := (
		w.tick
		- f.phase_tick
		- w.tuning.boss_intro_ticks
		- t.window_first_ticks
		+ t.window_warn_ticks
	)
	if u < 0:
		return [-u, t.window_first_ticks - t.window_warn_ticks]
	var every := maxi(1, t.window_every_ticks)
	var c := u % every
	if c < t.window_warn_ticks:
		return [t.window_warn_ticks - c, t.window_warn_ticks]
	if c < t.window_warn_ticks + t.window_ticks:
		return [t.window_warn_ticks + t.window_ticks - c, t.window_ticks]
	return [every - c, every - t.window_warn_ticks - t.window_ticks]


## Emits the window's cues on the tick each state begins (views, sound, HUD).
static func _cue(w: World, i: int, _t: BossTable) -> void:
	var now := window(w)
	var before := window_at(w, w.tick - 1)
	if now == before:
		return
	var effect := EFFECT_CLOSE
	if now == Mimic.WARN:
		effect = EFFECT_WARN
	elif now == Mimic.ON:
		effect = EFFECT_OPEN
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, w.actors.pos(i))
	e.effect_id = effect
	e.amount = now


## The fight's pace for the views and the HUD (WorldReader.final_pace): {} or {"paced", "dps" (the measured damage
## per second it was set from), "seconds" (how long it lasts at that rate), "budget" (damage it may take now),
## "window" (Mimic), "window_left", "window_len" (ticks), "nerf" (per mille, in a window), "copying"}.
static func state(w: World) -> Dictionary:
	var f := w.final_fight
	var t := table(w)
	if t == null:
		return {}
	var clock := window_clock(w)
	var win := window(w)
	return {
		"paced": f.paced,
		"dps": f.pace_dps / 1000,
		"seconds": seconds_at(f.pace_dps, t) / SimTick.TICKS_PER_SECOND if f.paced else 0,
		"budget": f.pace_budget / 1000,
		"window": win,
		"window_left": clock[0],
		"window_len": clock[1],
		"nerf": nerf_permille(w, t) if win == Mimic.ON else 1000,
		"copying": f.copying,
	}
