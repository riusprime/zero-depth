class_name PlayerRegen
extends RefCounted
## Out-of-combat regen (v0.3.0 PLAN L25, starting values): after PlayerTable.regen_delay_ticks (10 s) without
## dealing or taking damage, the player heals regen_permille (10 = 1 %) of max HP per second, plus
## World.regen_bonus_permille (the hook items and the gamble shrine raise). Integer only: each tick adds
## max HP x rate to World.regen_acc, and every REGEN_UNIT of it heals 1 HP. Any damage dealt or taken (hits and
## damage over time) restarts the wait and empties the accumulator. Runs in tick phase 8.

## One HP in the accumulator: per mille x ticks per second.
const REGEN_UNIT := 1000 * SimTick.TICKS_PER_SECOND


## Damage was applied (Damage._apply): if the player took it or dealt it, combat restarts the wait.
static func note_combat(w: World, target: int, owner_id: int) -> void:
	if target == 0 or owner_id == w.actors.ids[0]:
		w.build_state.combat_tick = w.tick
		w.build_state.regen_acc = 0


## The regen rate now, in per mille of max HP per second.
## The gamble shrine's REGEN wins add to it (v0.3.0 L19).
static func rate_permille(w: World) -> int:
	var gamble := Gamble.regen_bonus_permille(w) if w.gamble_table != null else 0
	return Curses.regen(w, maxi(0, w.player.regen_permille + w.regen_bonus_permille + gamble))


## Out of combat long enough to regenerate (whether or not HP is missing).
static func out_of_combat(w: World) -> bool:
	return w.tick - w.build_state.combat_tick >= w.player.regen_delay_ticks


## Healing right now: alive, hurt, out of combat, with a positive rate.
static func active(w: World) -> bool:
	var a := w.actors
	return (
		not w.player_dead() and a.hp[0] < a.max_hp[0] and rate_permille(w) > 0 and out_of_combat(w)
	)


static func advance(w: World) -> void:
	if not active(w):
		w.build_state.regen_acc = 0
		return
	var a := w.actors
	w.build_state.regen_acc += a.max_hp[0] * rate_permille(w)
	while w.build_state.regen_acc >= REGEN_UNIT and a.hp[0] < a.max_hp[0]:
		a.hp[0] += 1
		w.build_state.regen_acc -= REGEN_UNIT
		w.build_state.regen_tick = w.tick
	if a.hp[0] >= a.max_hp[0]:
		w.build_state.regen_acc = 0
