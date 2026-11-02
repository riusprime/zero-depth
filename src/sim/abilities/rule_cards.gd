class_name RuleCards
extends RefCounted
## v0.10.5 O9 (theory audit P2; owner 2026-11-01 "let's use the pending cards as this"; docs/roadmap/v0.10.5/
## O9_RULE_CARDS.md): the seven rule stat cards that replace the flat stats, each Trigger -> Condition -> Payoff. Every
## hook is a no-op without its card (the stat at its BASE), so a world without one keeps its behaviour and hash.
## - VENT_MEND (ADD, replaces regen): you Vent -> an enemy is in the blast -> heal this share of max HP (once a Vent).
## - HEAT_SHIELD (CUT, replaces armour): you are hit -> you are Hot or hotter (an overheat too) -> x the stat taken.
## - ADRENALINE (ADD, replaces move speed): you kill -> the enemy was within the limit's metres -> + move speed for
##   RUSH_TICKS (refreshed, never stacked).
## - CLOSE_QUARTERS (ADD, replaces crit damage): your direct hit -> the enemy's edge is within the limit's metres of
##   you -> + damage.
## - THIRD_STRIKE (ADD, replaces area): you land an attack (Heat.overclock_counts: a swing, a bolt, a form's blast;
##   once per root) -> the third in a row, each within STRIKE_WINDOW_TICKS of the last -> that attack's hits + damage.
## - REFLEX (ADD, replaces cooldowns): you kill -> the dash is recharging -> this share of the dash's full cooldown
##   comes off (once per root, however many it kills).
## - SCAVENGER (ADD, replaces pickup range): you kill -> the killing hit crit -> + this share of the kill's shards.
## Loop rules (GAME_BLUEPRINT §D): no payoff is a hit, so none can trigger itself or another card; the heal is once
## per Vent (its cooldown is the window); the refund once per root.

## Adrenaline's burst: 1.5 s.
const RUSH_TICKS := 90
## Third Strike: the attacks in a row, and the most ticks between two of them.
const STRIKE_EVERY := 3
const STRIKE_WINDOW_TICKS := 60
const EFFECT_VENT_MEND := &"vent_mend"
const EFFECT_SCAVENGER := &"scavenger"
## AbilityState's O9 fields: a save from before O9 has none of them, and keeps their defaults (WorldSnapshot).
const SNAPSHOT_FIELDS: Array[StringName] = [
	&"rc_rush_until",
	&"rc_strike_n",
	&"rc_strike_last",
	&"rc_strike_root",
	&"rc_bonus_root",
	&"rc_reflex_root",
	&"rc_mend_tick",
]


static func _on(w: World, s: int) -> bool:
	return Stats.value(w, s) != Stats.BASE[s]


## The stat's value within its table's cap (0 without a table).
static func _capped(w: World, s: int) -> int:
	var t := Stats.table(w, s)
	if t == null:
		return 0
	var v := Stats.value(w, s)
	return mini(v, t.cap) if t.cap > 0 else v


## Damage.hit: a direct hit the player owns on enemy `target` (after the damage stats and crit): Close Quarters and
## Third Strike. Counts the attack for Third Strike first.
static func outgoing(
	w: World, target: int, amount: int, tags: int, root: int, effect_id: StringName
) -> int:
	if tags & SimEvent.TAG_DOT:
		return amount
	var bonus := 0
	if _on(w, Stats.Stat.CLOSE_QUARTERS) and close(w, target):
		bonus += _capped(w, Stats.Stat.CLOSE_QUARTERS)
	if _on(w, Stats.Stat.THIRD_STRIKE):
		_count_strike(w, root, tags, effect_id)
		if root != 0 and root == w.ab.rc_bonus_root:
			bonus += _capped(w, Stats.Stat.THIRD_STRIKE)
	if bonus <= 0:
		return amount
	return (amount * (1000 + bonus) + 500) / 1000


## Close Quarters' condition: enemy `target`'s edge is within the card's reach of the player.
static func close(w: World, target: int) -> bool:
	var t := Stats.table(w, Stats.Stat.CLOSE_QUARTERS)
	if t == null:
		return false
	var a := w.actors
	var d := Kin.length(a.pos(target) - w.player_pos()) - a.radius[target]
	return d <= t.limit_permille / 1000.0


## Third Strike's count: a new attack (root) landing counts once; a gap past the window restarts the row; the third
## makes its root the bonus root and restarts the row.
static func _count_strike(w: World, root: int, tags: int, effect_id: StringName) -> void:
	var s := w.ab
	if root == 0 or root == s.rc_strike_root or not Heat.overclock_counts(tags, effect_id):
		return
	s.rc_strike_root = root
	if s.rc_strike_last >= 0 and w.tick - s.rc_strike_last <= STRIKE_WINDOW_TICKS:
		s.rc_strike_n += 1
	else:
		s.rc_strike_n = 1
	s.rc_strike_last = w.tick
	if s.rc_strike_n >= STRIKE_EVERY:
		s.rc_strike_n = 0
		s.rc_bonus_root = root


## Damage.hit: Heat Shield's multiplier on a hit the player takes, per mille (1000 unless Hot with the card).
static func taken_permille(w: World) -> int:
	if not _on(w, Stats.Stat.HEAT_SHIELD) or Heat.tier_of(w) < Heat.TIER_HOT:
		return 1000
	var t := Stats.table(w, Stats.Stat.HEAT_SHIELD)
	var v := Stats.value(w, Stats.Stat.HEAT_SHIELD)
	return maxi(v, t.cap) if t != null and t.cap > 0 else v


## Damage._apply: the player killed enemy `target` with a hit tagged `tags` in root `root`: Adrenaline, Reflex and
## Scavenger.
static func on_kill(w: World, target: int, tags: int, root: int) -> void:
	var a := w.actors
	if _on(w, Stats.Stat.ADRENALINE):
		var t := Stats.table(w, Stats.Stat.ADRENALINE)
		var d := Kin.length(a.pos(target) - w.player_pos()) - a.radius[target]
		if t != null and d <= t.limit_permille / 1000.0:
			w.ab.rc_rush_until = w.tick + RUSH_TICKS
	if _on(w, Stats.Stat.REFLEX) and w.dash_cooldown_left > 0 and root != w.ab.rc_reflex_root:
		w.ab.rc_reflex_root = root
		var cut := (ItemProcs.dash_cooldown_ticks(w) * _capped(w, Stats.Stat.REFLEX) + 500) / 1000
		w.dash_cooldown_left = maxi(0, w.dash_cooldown_left - cut)
	if _on(w, Stats.Stat.SCAVENGER) and tags & SimEvent.TAG_CRIT:
		var base := Rewards.shards_for_kill(w, a.kinds[target])
		var bonus := (base * _capped(w, Stats.Stat.SCAVENGER) + 500) / 1000
		bonus = Affinities.shards(w, Stats.shards(w, bonus))
		if bonus > 0:
			w.shards += bonus
			var me := a.ids[0]
			var e := w.emit_event(SimEvent.Kind.SHARDS, a.ids[target], me, me, a.pos(target))
			e.amount = bonus
			e.effect_id = EFFECT_SCAVENGER


## Adrenaline's move-speed bonus now, per mille (0 outside the burst).
static func rush_permille(w: World) -> int:
	if w.tick >= w.ab.rc_rush_until or not _on(w, Stats.Stat.ADRENALINE):
		return 0
	return _capped(w, Stats.Stat.ADRENALINE)


## Heat.vent, before the blast: Vent Mend's condition, a live enemy touching the blast's disc (false without the card).
static func vent_hits(w: World, center: Vector2, radius: float) -> bool:
	if not _on(w, Stats.Stat.VENT_MEND):
		return false
	var a := w.actors
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
			continue
		if AttackShapes.disc_touches(center, radius, a.pos(i), a.radius[i]):
			return true
	return false


## Heat.vent, after the blast: Vent Mend heals its share of max HP (at least 1), never past the max; a HEAL event.
static func vent_mend(w: World) -> void:
	var a := w.actors
	if w.player_dead():
		return
	var want := maxi(1, (a.max_hp[0] * _capped(w, Stats.Stat.VENT_MEND) + 500) / 1000)
	var applied := maxi(0, mini(want, a.max_hp[0] - a.hp[0]))
	a.hp[0] += applied
	w.ab.rc_mend_tick = w.tick
	var e := w.emit_event(SimEvent.Kind.HEAL, a.ids[0], a.ids[0], a.ids[0], w.player_pos())
	e.amount = want
	e.amount_applied = applied
	e.effect_id = EFFECT_VENT_MEND
