class_name PlayerKit
extends RefCounted
## The player's primary (PLAN v0.1.0 Step 2): press = swing (a 3-hit combo), keep holding = charge,
## release = a bolt. Runs in tick phase 4. All numbers come from PlayerTable (starting values).

const PRIMARY_SLOT := 0


static func advance(w: World) -> void:
	var t := w.player
	var held_primary := (w.held_buttons & InputFrame.PRIMARY) != 0
	var can_attack := not w.guarding() and not w.is_dashing()
	# Swing in progress: hit on its active tick, then end and open the combo window.
	if w.swing_t > 0:
		if w.swing_t == t.swing_active_tick:
			_resolve_swing(w)
		w.swing_t += 1
		if w.swing_t > t.swing_ticks:
			w.swing_t = 0
			w.combo_window = t.combo_window_ticks
	elif w.combo_window > 0:
		w.combo_window -= 1
	# A buffered press starts the next swing as soon as the current one ends.
	if w.swing_t == 0 and can_attack and w.input_buffer[PRIMARY_SLOT] > 0:
		w.input_buffer[PRIMARY_SLOT] = 0
		w.combo_step = (w.combo_step + 1) % t.swing_damage.size() if w.combo_window > 0 else 0
		w.combo_window = 0
		w.swing_t = 1
		w.swing_angle = w.aim_angle
		w.swing_root = w.take_root()
		w.primary_hold = 1 if held_primary else 0
	elif held_primary and w.primary_hold > 0:
		w.primary_hold += 1
	elif not held_primary and w.primary_hold > 0:
		if w.primary_hold > t.charge_start_ticks and can_attack:
			_fire_bolt(w)
		w.primary_hold = 0


static func charging(w: World) -> bool:
	return w.primary_hold > w.player.charge_start_ticks


## 0..1000 per mille of a full charge.
static func charge_permille(w: World) -> int:
	var t := w.player
	if not charging(w):
		return 0
	var span := maxi(1, t.charge_full_ticks - t.charge_start_ticks)
	return clampi((w.primary_hold - t.charge_start_ticks) * 1000 / span, 0, 1000)


static func swing_hits(w: World, i: int) -> bool:
	var t := w.player
	return AttackShapes.arc_touches(
		w.player_pos(),
		t.radius_m,
		w.swing_angle,
		t.swing_half_arc,
		t.swing_reach_m,
		w.actors.pos(i),
		w.actors.radius[i]
	)


static func _resolve_swing(w: World) -> void:
	var a := w.actors
	var dmg: int = w.player.swing_damage[w.combo_step]
	var landed := false
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1 or not swing_hits(w, i):
			continue
		var got := Damage.hit(
			w,
			i,
			dmg,
			a.ids[0],
			a.ids[0],
			w.swing_root,
			SimEvent.TAG_MELEE,
			w.player_pos(),
			a.pos(i)
		)
		landed = landed or got > 0
	if landed:
		w.add_freeze(w.player.swing_hitstop_ticks)


static func _fire_bolt(w: World) -> void:
	var t := w.player
	var c := charge_permille(w)
	var dmg := t.bolt_min_damage + (t.bolt_max_damage - t.bolt_min_damage) * c / 1000
	var tags := SimEvent.TAG_PROJECTILE | (SimEvent.TAG_FULL_CHARGE if c >= 1000 else 0)
	var dir := Kin.dir(w.aim_angle)
	var muzzle := w.player_pos() + dir * (t.radius_m + t.bolt_radius_m + 0.05)
	w.queue_projectile(
		w.actors.ids[0],
		ActorStore.TEAM_PLAYER,
		muzzle,
		dir * t.bolt_speed,
		dmg,
		t.bolt_radius_m,
		t.bolt_life_ticks,
		tags
	)
