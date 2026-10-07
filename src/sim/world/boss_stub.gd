class_name BossStub
extends RefCounted
## STUB, replaced by workstream C (v0.3.0 PLAN, "Bosses"). It stands behind the boss contract the run flow (B) codes
## against, so the boss room, the sealed door and the portal work before the real bosses land:
##   World.spawn_boss(boss_table_index: int, pos: Vector2) -> int   (the boss's actor id)
##   World.boss_alive() -> bool
##   SimEvent.Kind.BOSS_DEFEATED, emitted once when the boss dies
## The stand-in is a Warden with HP_MULT times its HP, remembered in World.boss_id. It ignores boss_table_index.
## C: replace the bodies of World.spawn_boss / World.boss_alive, emit BOSS_DEFEATED from the boss code, then delete
## this file and the BossStub.advance call in BossFlow.advance.

const HP_MULT := 12


static func spawn(w: World, _boss_table_index: int, pos: Vector2) -> int:
	var kind := ActorStore.Kind.WARDEN
	var id := w.add_enemy(kind, pos)
	var i := w.actors.index_of(id)
	var hp := w.enemy_table(kind).hp * HP_MULT
	w.actors.hp[i] = hp
	w.actors.max_hp[i] = hp
	w.boss_id = id
	return id


static func alive(w: World) -> bool:
	if w.boss_id == 0:
		return false
	var i := w.actors.index_of(w.boss_id)
	return i >= 0 and w.actors.dead[i] == 0


## Emits BOSS_DEFEATED on the tick the stand-in is gone (once).
static func advance(w: World) -> void:
	if w.boss_id != 0 and not alive(w):
		w.emit_event(SimEvent.Kind.BOSS_DEFEATED, w.boss_id, w.boss_id, w.boss_id, w.player_pos())
		w.boss_id = 0
