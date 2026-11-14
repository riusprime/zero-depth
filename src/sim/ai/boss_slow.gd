class_name BossSlow
extends RefCounted
## The attack speed a boss takes from the hero: BossStore.aslow_cut per mille of the weapon's rate, taken by one boss
## (aslow_boss) and given back in parts (a pickup: BossPickups) or all at once.
## - It multiplies the weapon's rate last, after the curve and Heavy Hands (AttackRate.rate_at) and after a Gun form's
##   share of attack speed (AttackRate.shot_rate), so every weapon loses the whole cut: the Gun's period in every form
##   (the Laser and the Lance among them), the Blade's whole swing, the shot reserve and the cards' forecast. The
##   Blade's rate never falls under its table's floor (BladeTable.rate_min).
## - WEAPON_ONLY decides whether the auto abilities' periods (Stats.period) are spared; the spells' cooldowns never
##   read attack speed, so they are untouched either way.
## - A second cut while one holds keeps the larger; the newest boss owns it.
## - It ends with its boss (on_boss_gone), with the hero's death, and when the hero stands outside the sealed arena
##   (advance). Pure: no stream is drawn.

## True: the cut slows the weapon attack only. False: the auto abilities' attack-speed periods slow with it.
const WEAPON_ONLY := true
## The most a boss may take, per mille (the rate never reaches 0).
const MAX_CUT := 900
## How far outside the sealed arena's rectangle the hero's centre may stand before the cut is dropped.
const ARENA_SLACK_M := 1.0


## Boss `boss_id` takes `permille` of the hero's attack speed (the larger of this and what is already taken).
static func apply(w: World, boss_id: int, permille: int) -> void:
	var bs := w.bosses
	bs.aslow_cut = maxi(bs.aslow_cut, clampi(permille, 0, MAX_CUT))
	bs.aslow_boss = boss_id if bs.aslow_cut > 0 else -1


## Returns `permille` of it (at most what is taken); the last part ends it. The amount returned.
static func give_back(w: World, permille: int) -> int:
	var bs := w.bosses
	var back := clampi(permille, 0, bs.aslow_cut)
	bs.aslow_cut -= back
	if bs.aslow_cut <= 0:
		clear(w)
	return back


## Ends it.
static func clear(w: World) -> void:
	w.bosses.aslow_cut = 0
	w.bosses.aslow_boss = -1


## The attack speed taken now, per mille (0 = none).
static func cut(w: World) -> int:
	return w.bosses.aslow_cut


## Weapon rate `r` (per mille) under the cut: r x (1 - cut), rounded half up, at least 1.
static func weapon_rate(w: World, r: int) -> int:
	var c := w.bosses.aslow_cut
	return r if c <= 0 else maxi(1, (r * (1000 - c) + 500) / 1000)


## Tick phase 6 (BossSignatures.advance): the cut ends when its boss is gone, the hero is dead or has left the arena.
static func advance(w: World) -> void:
	var bs := w.bosses
	if bs.aslow_boss < 0:
		return
	var bi := w.actors.index_of(bs.aslow_boss)
	if bi < 0 or w.actors.dead[bi] == 1 or fight_over(w):
		clear(w)


## True when the hero is dead or stands outside the sealed arena: what a boss placed for the hero goes.
static func fight_over(w: World) -> bool:
	if w.player_dead():
		return true
	var r := w.bosses.arena
	return r.has_area() and not r.grow(ARENA_SLACK_M).has_point(w.player_pos())


## BossSignatures.on_boss_gone: what boss `boss_id` took comes back.
static func on_boss_gone(w: World, boss_id: int) -> void:
	if w.bosses.aslow_boss == boss_id:
		clear(w)
