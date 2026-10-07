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


func dash_cooldown_total() -> int:
	return _w.player.dash_cooldown_ticks


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


## [half_arc] of a Warden's shield, or 0.
func shield_half_arc(i: int) -> int:
	var t := _w.enemy_table(_w.actors.kinds[i])
	return t.shield_half_arc if t != null else 0


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
