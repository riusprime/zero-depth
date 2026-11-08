class_name Relics
extends RefCounted
## v0.11.0 O14b (owner Q-O14b "Both"; OWNER_QUESTIONS §J N1): the relics, run-long passives held outside the wand
## (RelicDefinition; World.relic_tables, compiled at setup). World.relics holds one entry per relic in RELICS order
## once one is taken (empty before: hashed only then): 0 not held, else 1 + the times its rule fired this run. The
## run's carry keeps it from floor to floor and across loops (RunCarry.FIELDS), so "once a run" holds.
## - CITY_HEART (the pedestal in the hidden room under the Hollow Crown's throne, HeartRoom.press_pedestal): while it
##   has a use left, a hit that would kill the hero instead leaves them at saved_hp (Damage._apply asks save()), and a
##   shock ring of ring_radius_m pulses from them (pulse()): ring_damage to every living enemy it touches (EFFECT_RING,
##   as a splash: not scaled again by the hero's stats). The second killing blow kills. World.relic_pulse_tick and
##   relic_pulse_pos are the last ring's (the views' heart flash and ring). OWNER-PENDING PLACEHOLDER (N1).
## Pure: no stream is drawn.

const CITY_HEART := 0
const EFFECT_RING := &"relic_city_heart_ring"


## The compiled table of relic `k`, or null when the world's content lacks it.
static func table(w: World, k: int) -> RelicTable:
	return w.relic_tables[k] if k >= 0 and k < w.relic_tables.size() else null


## Whether the hero holds relic `k`.
static func held(w: World, k: int) -> bool:
	return k >= 0 and k < w.relics.size() and w.relics[k] > 0


## The times relic `k` fired this run (0 when not held).
static func spent(w: World, k: int) -> int:
	return maxi(0, w.relics[k] - 1) if held(w, k) else 0


## Whether relic `k` is held with a use left.
static func ready(w: World, k: int) -> bool:
	var t := table(w, k)
	return t != null and held(w, k) and spent(w, k) < t.uses


## The hero takes relic `k` (a pedestal). False when already held or unknown to the content.
static func take(w: World, k: int) -> bool:
	if table(w, k) == null or held(w, k):
		return false
	if w.relics.size() < w.relic_tables.size():
		w.relics.resize(w.relic_tables.size())
	w.relics[k] = 1
	return true


## Damage._apply, on a hit that would kill the hero: the HP to leave them at (a relic's use is spent), or -1 when no
## held relic saves them.
static func save(w: World) -> int:
	if w.relics.is_empty() or not ready(w, CITY_HEART):
		return -1
	w.relics[CITY_HEART] += 1
	w.relic_pulse_tick = w.tick
	w.relic_pulse_pos = w.player_pos()
	return table(w, CITY_HEART).saved_hp


## Damage._apply, after the saved blow landed: the City's Heart's shock ring from the hero.
static func pulse(w: World) -> void:
	var t := table(w, CITY_HEART)
	if t == null or t.ring_damage <= 0:
		return
	var a := w.actors
	var me := a.ids[0]
	var at := w.relic_pulse_pos
	var root := w.take_root()
	for j in range(1, a.size()):
		if a.dead[j] == 1 or a.teams[j] == ActorStore.TEAM_PLAYER:
			continue
		if AttackShapes.disc_touches(at, t.ring_radius_m, a.pos(j), a.radius[j]):
			Damage.hit(w, j, t.ring_damage, me, me, root, 0, at, a.pos(j), EFFECT_RING)


static func hash_into(w: World, h: StateHasher) -> void:
	h.add_ints(w.relics)
	h.add_int(w.relic_pulse_tick)
	h.add_f32(w.relic_pulse_pos.x)
	h.add_f32(w.relic_pulse_pos.y)
