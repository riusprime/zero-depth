# gdlint: disable=max-public-methods
class_name WorldReader
extends RefCounted
## The read-only face of World for presentation (EI-07). Presentation may name WorldReader, never World.
## It is a wide facade on purpose: one read method per thing a view needs.

const KIND_PLAYER := ActorStore.Kind.PLAYER
const KIND_CHARGER := ActorStore.Kind.CHARGER
const KIND_WARDEN := ActorStore.Kind.WARDEN
const KIND_NEEDLE := ActorStore.Kind.NEEDLE
## How a melee combo step moves the blade (SwingStep.Motion; swing_motion()).
const MOTION_SLASH_RIGHT_TO_LEFT := SwingStep.Motion.SLASH_RIGHT_TO_LEFT
const MOTION_SLASH_LEFT_TO_RIGHT := SwingStep.Motion.SLASH_LEFT_TO_RIGHT
const MOTION_THRUST := SwingStep.Motion.THRUST
const MOTION_SPIN := SwingStep.Motion.SPIN
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


## The arc of combo step `step` (-1 = the current swing's), for drawing: [half_arc, reach_m, own_radius_m]. Same
## numbers PlayerKit hits with (EI-07).
func swing_shape(step: int = -1) -> Array:
	var s := _step_index(step)
	return [_w.player.combo[s].half_arc, swing_reach_m(s), _w.player.radius_m]


## The current swing's length in ticks (its step's).
func swing_ticks() -> int:
	return PlayerKit.current_step(_w).ticks


## The current swing's step: how the blade moves (SwingStep.Motion), how long it takes to cross the arc, the tick
## it hits on.
func swing_motion() -> int:
	return PlayerKit.current_step(_w).motion


func swing_sweep_ticks() -> int:
	return PlayerKit.current_step(_w).sweep_ticks


func swing_active_tick() -> int:
	return PlayerKit.current_step(_w).active_tick


## Steps in the melee combo, and whether step `step` (-1 = the current swing's) is its finisher.
func combo_length() -> int:
	return _w.player.combo.size()


func is_finisher(step: int = -1) -> bool:
	return PlayerKit.is_finisher(_w, _step_index(step))


func _step_index(step: int) -> int:
	return step if step >= 0 else _w.combo_step


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


## 0 while fighting, 1 when the last wave is cleared, 2 when the player is dead.
func outcome() -> int:
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


## The reach of combo step `step` (-1 = the current one) with Long Edge applied: the same number PlayerKit hits
## with (EI-07).
func swing_reach_m(step: int = -1) -> float:
	return ItemEffects.swing_reach_m(_w, _step_index(step))


## Overcharge: a press now would start the charged swing (the finisher, with the four-slash combo).
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


## Twin Arc: an echo swing is pending, its angle and step, and the tick the last echo swung (-1 = never). The echo
## uses swing_shape(echo_step()) with this angle.
func echo_pending() -> bool:
	return _w.echo_t > 0


func echo_angle() -> int:
	return _w.echo_angle


func echo_step() -> int:
	return _w.echo_step


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
