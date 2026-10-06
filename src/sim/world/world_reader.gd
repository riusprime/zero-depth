# gdlint: disable=max-public-methods
class_name WorldReader
extends RefCounted
## The read-only face of World for presentation (EI-07). Presentation may name WorldReader, never World.
## It is a wide facade on purpose: one read method per thing a view needs.

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
	return [_w.player.swing_half_arc, _w.player.swing_reach_m, _w.player.radius_m]


func swing_ticks() -> int:
	return _w.player.swing_ticks


func charge_permille() -> int:
	return PlayerKit.charge_permille(_w)


func charging() -> bool:
	return PlayerKit.charging(_w)


func projectile_team(i: int) -> int:
	return _w.projectiles.team[i]


func projectile_full_charge(i: int) -> bool:
	return (_w.projectiles.tags[i] & SimEvent.TAG_FULL_CHARGE) != 0


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
