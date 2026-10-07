# gdlint: disable=max-public-methods
class_name WorldReader
extends RefCounted
## The read-only face of World for presentation (EI-07). Presentation may name WorldReader, never World.
## It is a wide facade on purpose: one read method per thing a view needs.

const KIND_PLAYER := ActorStore.Kind.PLAYER
const KIND_CHARGER := ActorStore.Kind.CHARGER
const KIND_WARDEN := ActorStore.Kind.WARDEN
const KIND_NEEDLE := ActorStore.Kind.NEEDLE
## Item kinds, for views (presentation may not name ItemTable).
const ITEM_LONG_EDGE := ItemTable.Kind.LONG_EDGE
const ITEM_TWIN_ARC := ItemTable.Kind.TWIN_ARC
const ITEM_EMBER_EDGE := ItemTable.Kind.EMBER_EDGE
const ITEM_SPLINTER_SHOT := ItemTable.Kind.SPLINTER_SHOT
const ITEM_RAPID_COIL := ItemTable.Kind.RAPID_COIL
const ITEM_RICOCHET_CORE := ItemTable.Kind.RICOCHET_CORE
const ITEM_KINETIC_DASH := ItemTable.Kind.KINETIC_DASH
const ITEM_OVERCHARGE := ItemTable.Kind.OVERCHARGE
const ITEM_VAMPIRIC_CORE := ItemTable.Kind.VAMPIRIC_CORE
const ITEM_STATIC_CHAIN := ItemTable.Kind.STATIC_CHAIN
const ITEM_MOMENTUM := ItemTable.Kind.MOMENTUM
const ITEM_FROST_CORE := ItemTable.Kind.FROST_CORE
const ITEM_THORN_MANTLE := ItemTable.Kind.THORN_MANTLE
const ITEM_EXECUTIONER := ItemTable.Kind.EXECUTIONER
const ITEM_SWIFT_FEET := ItemTable.Kind.SWIFT_FEET
const ITEM_PHASE_STRIKE := ItemTable.Kind.PHASE_STRIKE
## Enemy AI states, for actor_state() (presentation animates from them; EnemyAi.State is the source).
const STATE_SPAWN := EnemyAi.State.SPAWN
const STATE_MOVE := EnemyAi.State.MOVE
const STATE_WINDUP := EnemyAi.State.WINDUP
const STATE_ACTIVE := EnemyAi.State.ACTIVE
const STATE_RECOVER := EnemyAi.State.RECOVER
## Run flow (v0.3.0 B): boss flow states, for views (BossFlow.State is the source).
const BOSS_WAITING := BossFlow.State.WAITING
const BOSS_FIGHT := BossFlow.State.FIGHT
const BOSS_OPEN := BossFlow.State.OPEN
const BOSS_EXITED := BossFlow.State.EXITED

var _w: World


func _init(world: World) -> void:
	_w = world


func tick() -> int:
	return _w.tick


func seed_value() -> int:
	return _w.seed_value


func player_pos() -> Vector2:
	return _w.player_pos()


func aim_angle() -> int:
	return _w.aim_angle


func is_dashing() -> bool:
	return _w.is_dashing()


func actor_count() -> int:
	return _w.actors.size()


func actor_pos(i: int) -> Vector2:
	return _w.actors.pos(i)


func actor_id(i: int) -> int:
	return _w.actors.ids[i]


func actor_team(i: int) -> int:
	return _w.actors.teams[i]


func actor_radius(i: int) -> float:
	return _w.actors.radius[i]


func actor_kind(i: int) -> int:
	return _w.actors.kinds[i]


func actor_hp(i: int) -> int:
	return _w.actors.hp[i]


func actor_max_hp(i: int) -> int:
	return _w.actors.max_hp[i]


func actor_dead(i: int) -> bool:
	return _w.actors.dead[i] == 1


func actor_facing(i: int) -> int:
	return _w.actors.facing[i]


func actor_invulnerable(i: int) -> bool:
	return _w.actors.invuln[i] > 0


func player_dead() -> bool:
	return _w.player_dead()


func swing_tick() -> int:
	return _w.swing_t


func swing_angle() -> int:
	return _w.swing_angle


func combo_step() -> int:
	return _w.combo_step


## The arc of the current swing, for drawing: [half_arc, reach_m, own_radius_m]. Same numbers PlayerKit hits with.
func swing_shape() -> Array:
	return [_w.player.swing_half_arc, swing_reach_m(), _w.player.radius_m]


func swing_ticks() -> int:
	return _w.player.swing_ticks


func shooting() -> bool:
	return PlayerKit.shooting(_w)


func projectile_team(i: int) -> int:
	return _w.projectiles.team[i]


func utility() -> int:
	return _w.player.utility


func has_guard() -> bool:
	return _w.player.utility == PlayerTable.Utility.GUARD


func has_blink() -> bool:
	return _w.player.utility == PlayerTable.Utility.BLINK


func guarding() -> bool:
	return _w.guarding()


## The guard's half arc, the same number Damage checks.
func guard_half_arc() -> int:
	return _w.player.guard_half_arc


func blink_cooldown() -> int:
	return _w.blink_cd


func blink_cooldown_total() -> int:
	return _w.player.blink_cooldown_ticks


func blink_tick() -> int:
	return _w.blink_tick


func blink_from() -> Vector2:
	return _w.blink_from


func dash_cooldown() -> int:
	return _w.dash_cooldown_left


## The dash cooldown's full length (Swift Feet applied: the same number the dash uses).
func dash_cooldown_total() -> int:
	return ItemProcs.dash_cooldown_ticks(_w)


func player_radius() -> float:
	return _w.player.radius_m


func actor_state(i: int) -> int:
	return _w.actors.state[i]


## True while the enemy is spawning in, dazed or recovering (presentation cues).
func actor_spawning(i: int) -> bool:
	return EnemyAi.is_enemy_kind(_w.actors.kinds[i]) and _w.actors.state[i] == EnemyAi.State.SPAWN


func actor_recovering(i: int) -> bool:
	return EnemyAi.is_enemy_kind(_w.actors.kinds[i]) and _w.actors.state[i] == EnemyAi.State.RECOVER


## The enemy's telegraph, from the same function that resolves the attack (EI-07). {} when none.
func telegraph(i: int) -> Dictionary:
	return EnemyAi.telegraph(_w, i)


## A Warden's armour half-arcs (1/4096 turns either side of its facing): x = front, y = rear. (0, 0) for others.
func armour_half_arcs(i: int) -> Vector2i:
	var t := _w.enemy_table(_w.actors.kinds[i])
	return Vector2i(t.front_half_arc, t.rear_half_arc) if t != null else Vector2i.ZERO


## 0 while fighting, 1 when the last wave is cleared (or the run's last portal taken), 2 when the player is dead,
## 3 when the portal of a floor before the last was taken (the app loads the next floor).
func outcome() -> int:
	if _w.boss_flow != null and _w.boss_flow.exited():
		return 1 if _w.floor_index >= _w.floor_count else 3
	if _w.player_dead():
		return 2
	return 1 if _w.cleared else 0


func wave_number() -> int:
	return _w.wave_index + 1


func wave_count() -> int:
	return _w.encounter.waves.size() if _w.encounter != null else 0


func enemies_alive() -> int:
	return WaveDirector.enemies_alive(_w)


## The kind that killed the player (-1 if unknown) and the hit's SimEvent tags.
func killer_kind() -> int:
	return _w.killer_kind


func killer_tags() -> int:
	return _w.killer_tags


func player_hp() -> int:
	return _w.actors.hp[0]


func player_max_hp() -> int:
	return _w.actors.max_hp[0]


func freeze_ticks() -> int:
	return _w.freeze_ticks


func projectile_count() -> int:
	return _w.projectiles.size()


func projectile_pos(i: int) -> Vector2:
	return Vector2(_w.projectiles.pos_x[i], _w.projectiles.pos_y[i])


func projectile_vel(i: int) -> Vector2:
	return Vector2(_w.projectiles.vel_x[i], _w.projectiles.vel_y[i])


func projectile_id(i: int) -> int:
	return _w.projectiles.ids[i]


func wall_count() -> int:
	return _w.walls.size()


func wall(i: int) -> Obb:
	return _w.walls[i]


func last_event_seq() -> int:
	return _w.last_event_seq()


func events_since(after_seq: int) -> Array[SimEvent]:
	return _w.events_since(after_seq)


func snapshot() -> Dictionary:
	return _w.snapshot()


func state_hash() -> String:
	return _w.state_hash()


## Run time in seconds (counts while the player lives; 0 without a spawn director).
func run_seconds() -> float:
	return float(_w.run_ticks) / SimTick.TICKS_PER_SECOND


## The spawn director's tier (0 without one).
func tier() -> int:
	return _w.spawner.tier_at(_w.run_ticks) if _w.spawner != null else 0


## Enemies killed this run.
func kills() -> int:
	return _w.kills


# --- Items (v0.2.0 E) ---------------------------------------------------------------------------------------
## Owned items in pickup order, as indices into the item tables (item_kind / item_name_key read them).
func items_owned() -> PackedInt32Array:
	return _w.items_owned


func item_count() -> int:
	return _w.items_owned.size()


func has_item_kind(kind: int) -> bool:
	return _w.item_mods.has(kind)


## Number of compiled items (valid item indices are 0..item_table_count() - 1).
func item_table_count() -> int:
	return _w.item_tables.size()


func item_kind(item_index: int) -> int:
	return _w.item_tables[item_index].kind


func item_id(item_index: int) -> StringName:
	return _w.item_tables[item_index].id


## Locale keys (tr() them in the view).
func item_name_key(item_index: int) -> StringName:
	return _w.item_tables[item_index].name_key


func item_desc_key(item_index: int) -> StringName:
	return _w.item_tables[item_index].desc_key


func pickup_count() -> int:
	return _w.pickups.size()


func pickup_pos(i: int) -> Vector2:
	return _w.pickups.pos(i)


## The item index a pickup holds.
func pickup_item(i: int) -> int:
	return _w.pickups.item[i]


func pickup_id(i: int) -> int:
	return _w.pickups.ids[i]


## Walking within this distance of a pickup takes it.
func pickup_radius_m() -> float:
	return ItemEffects.PICKUP_RADIUS_M


## Ember Edge burn stacks on actor i (0 = not burning).
func burn_stacks(actor_i: int) -> int:
	return _w.actors.burn_stacks[actor_i]


## The swing's reach with Long Edge applied: the same number PlayerKit hits with (EI-07).
func swing_reach_m() -> float:
	return ItemEffects.swing_reach_m(_w)


## Overcharge: the next swing will be the Nth (charged) one.
func overcharge_ready() -> bool:
	return ItemEffects.overcharge_ready(_w)


## Overcharge: the current swing is the charged one.
func swing_overcharged() -> bool:
	return _w.swing_t > 0 and _w.swing_overcharged


## The tick the last Overcharge shockwave fired (-1 = never), and its radius.
func overcharge_tick() -> int:
	return _w.overcharge_tick


func shockwave_radius_m() -> float:
	return _w.item_mods.shockwave_radius_m


## Twin Arc: an echo swing is pending, its angle, and the tick the last echo swung (-1 = never). The echo uses
## swing_shape() with this angle.
func echo_pending() -> bool:
	return _w.echo_t > 0


func echo_angle() -> int:
	return _w.echo_angle


func echo_tick() -> int:
	return _w.echo_tick


## Kinetic Dash: the tick a dash last hit an enemy (-1 = never).
func dash_hit_tick() -> int:
	return _w.dash_hit_tick


## Ricochet Core: wall bounces a projectile has left, and the tick of its last bounce (-1 = none).
func projectile_bounces(i: int) -> int:
	return _w.projectiles.bounces[i]


func projectile_bounce_tick(i: int) -> int:
	return _w.projectiles.bounce_tick[i]


## Ticks between bolts while shooting (Rapid Coil applied).
func shot_period_ticks() -> int:
	return ItemEffects.shot_period_ticks(_w)


## The generated floor, for the stage and the gate (PLAN v0.2.0 F). False in the arena and kernel scenarios.
func has_floor() -> bool:
	return _w.floor_layout != null


func floor_bounds() -> Rect2:
	return _w.floor_layout.bounds if _w.floor_layout != null else Rect2()


## Room interiors of the generated floor (wall face to wall face), for the stage's ground.
func floor_room_count() -> int:
	return _w.floor_layout.rooms.size() if _w.floor_layout != null else 0


func floor_room(i: int) -> Rect2:
	return _w.floor_layout.rooms[i]


func portal_pos() -> Vector2:
	return _w.floor_layout.portal_pos if _w.floor_layout != null else Vector2.ZERO


func portal_angle() -> int:
	return _w.floor_layout.portal_angle if _w.floor_layout != null else 0


## True while the player stands in the clear square in front of the sealed gate.
func at_gate() -> bool:
	return _w.floor_layout != null and _w.floor_layout.portal_front().has_point(_w.player_pos())


## What a wall is, for drawing it: 0 a structural wall (the room edges and partitions), 1 a cover slab, 2 not drawn
## (the gate's footprint, which the gate itself shows). Without a floor: the first 4 walls are edges.
func wall_class(i: int) -> int:
	var f := _w.floor_layout
	if f == null:
		return 0 if i < 4 else 1
	if i < f.slab_first:
		return 0
	return 1 if i < f.walls.size() else 2


# --- Items, the second eight (v0.2.0 J) ---------------------------------------------------------------------
## Vampiric Core: the tick it last healed (-1 = never), and HP it can still heal in the current cap window.
func heal_tick() -> int:
	return _w.heal_tick


func heal_cap_left() -> int:
	return ItemProcs.heal_cap_left(_w)


## Static Chain: the tick of the last jump (-1 = never), its ends, and whether the next landed bolt chains.
func chain_tick() -> int:
	return _w.chain_tick


func chain_from() -> Vector2:
	return _w.chain_from


func chain_to() -> Vector2:
	return _w.chain_to


func chain_ready() -> bool:
	return ItemProcs.chain_ready(_w)


## Momentum: an empowered swing is waiting, and the current swing is empowered.
func momentum_ready() -> bool:
	return _w.momentum_t > 0


func swing_momentum() -> bool:
	return _w.swing_t > 0 and _w.swing_momentum


## Frost Core: actor i is slowed.
func actor_slowed(i: int) -> bool:
	return _w.actors.slow_t[i] > 0


## Thorn Mantle: the tick the last ring was released (-1 = never).
func thorn_tick() -> int:
	return _w.thorn_tick


## Executioner: actor i is below the threshold, so your hits on it deal extra (false without the item).
func in_execute_range(i: int) -> bool:
	return ItemProcs.in_execute_range(_w, i)


## Swift Feet: the player's top speed in metres per second.
func move_speed_mps() -> float:
	return ItemProcs.move_speed(_w) * SimTick.TICKS_PER_SECOND


## Phase Strike: the tick it last discharged (-1 = never), and its ring's radius.
func phase_tick() -> int:
	return _w.phase_tick


func phase_radius_m() -> float:
	return _w.item_mods.phase_radius_m


# --- Run flow (v0.3.0 B) -----------------------------------------------------------------------------------


## This floor's number in the run (1-based) and the run's floor count.
func floor_index() -> int:
	return _w.floor_index


func floor_count() -> int:
	return _w.floor_count


func has_boss_room() -> bool:
	return _w.floor_layout != null and _w.floor_layout.boss_room >= 0 and _w.boss_flow != null


func boss_room() -> int:
	return _w.floor_layout.boss_room if _w.floor_layout != null else -1


## The boss door: centre on the wall line, the direction into the boss room, the gap's width, and the half
## thickness of the wall it sits in.
func boss_door_center() -> Vector2:
	return _w.floor_layout.boss_door_center


func boss_door_angle() -> int:
	return _w.floor_layout.boss_door_angle


func boss_door_width() -> float:
	return _w.floor_layout.boss_door_width


func boss_door_half_thickness() -> float:
	var o := _w.floor_layout.boss_door_wall
	return minf(o.half.x, o.half.y) if o != null else 0.4


## The door has shut behind the player (the boss fight began).
func boss_door_sealed() -> bool:
	return _w.boss_flow != null and _w.boss_flow.door_sealed()


func boss_state() -> int:
	return _w.boss_flow.state if _w.boss_flow != null else BOSS_WAITING


## The gate's portal is active: the boss is dead, and walking in leaves the floor.
func portal_active() -> bool:
	return _w.boss_flow != null and _w.boss_flow.portal_active()


## The tick the portal opened (-1 = not yet).
func portal_opened_tick() -> int:
	return _w.boss_flow.opened_tick if _w.boss_flow != null else -1


func boss_alive() -> bool:
	return _w.boss_alive()


## The boss's actor id (0 = none, or dead; the boss contract's stand-in tracks it in World.boss_id).
func boss_id() -> int:
	return _w.boss_id


## How far p is past the boss door's line, into the boss room (negative on the host side).
func boss_door_depth(p: Vector2) -> float:
	return _w.floor_layout.boss_door_depth(p) if _w.floor_layout != null else 0.0
