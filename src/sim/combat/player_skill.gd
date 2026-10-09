class_name PlayerSkill
extends RefCounted
## The Vent and Skill buttons (v0.3.5 K; owner F1, F18). Runs in tick phase 4 after PlayerKit; the skill's movement
## runs in phase 5 (World._move_and_collide), so walls stop it as they stop a dash.
## - Vent (InputFrame.VENT): Hot or hotter, the heat goes out as the vent blast (Heat.vent) and resets to 0; under
##   Hot (or overheated, or in a world without heat) nothing happens but a cold click (KitState.cold_tick).
## - Skill (InputFrame.SKILL): the build's second ability (PlayerTable.skill; none outside a build). It starts when
##   ready (cooldown over, no swing, dash or guard, not overheated) and commits: until it ends no swing, shot, dash
##   or blink starts. Its cooldown counts from the press.
##   - Lunge Cleave (Blade): lunge_m along the facing over lunge_ticks, then a fan (half_arc, reach_m) for damage
##     x the build's melee factor, melee + skill tags, with the finisher's kind of hit-stop when it lands.
##   - Scatter Blast (Gun): `pellets` rays over the cone toward the aim, each stopping at the first wall or enemy
##     within range_m; damage per pellet x the build's bolt factor; each enemy hit (not a boss) is knocked back;
##     the user steps back recoil_m.
##   A use that lands adds its heat once (Heat.on_hit), and every use emits SKILL_USED (amount = SkillTable.Kind).
## v0.6.0 MX1: the hit itself launches the Skill's compiled spec (Modifiers.skill, Attacks.launch); its shape tests
## are Attacks' (the forecast reads the same ones, EI-07). No v0.5 item targets the Skill, so it is unchanged.

const TAGS_CLEAVE := SimEvent.TAG_MELEE | SimEvent.TAG_SKILL
const TAGS_PELLET := SimEvent.TAG_PROJECTILE | SimEvent.TAG_SKILL


## World._buffer_presses: Vent and Skill presses wait up to INPUT_BUFFER_TICKS, as the other buttons.
static func buffer(w: World, pressed: int) -> void:
	if pressed & InputFrame.SKILL:
		w.kit.skill_buffer = SimTick.INPUT_BUFFER_TICKS
	if pressed & InputFrame.VENT:
		w.kit.vent_buffer = SimTick.INPUT_BUFFER_TICKS


## World._age_buffer.
static func age(w: World) -> void:
	if w.kit.skill_buffer > 0:
		w.kit.skill_buffer -= 1
	if w.kit.vent_buffer > 0:
		w.kit.vent_buffer -= 1


## A skill is running: the user is committed to it.
static func busy(w: World) -> bool:
	return w.kit.skill_t > 0


## Tick phase 4 (after PlayerKit.advance; never while the player is dead).
static func advance(w: World) -> void:
	var k := w.kit
	if k.vent_buffer > 0:
		k.vent_buffer = 0
		_vent(w)
	if k.skill_cd > 0:
		k.skill_cd -= 1
	var t := w.player.skill
	if t == null:
		k.skill_buffer = 0
		return
	if k.skill_t > 0:
		k.skill_t += 1
		if k.skill_t > t.move_ticks():
			k.skill_t = 0
			if t.kind == SkillTable.Kind.LUNGE_CLEAVE:
				_cleave(w, t)
		return
	if k.skill_buffer > 0 and ready(w):
		k.skill_buffer = 0
		_start(w, t)


## The skill would start on a press now: the build has one, its cooldown is over and nothing else holds the user.
static func ready(w: World) -> bool:
	return (
		w.player.skill != null
		and w.kit.skill_cd == 0
		and w.kit.skill_t == 0
		and w.swing_t == 0
		and not w.is_dashing()
		and not w.guarding()
		and not w.player_dead()
		and Heat.can_attack(w)
		and not Curses.stunned(w)
	)  # v0.6.0 CU: Brittle


static func _vent(w: World) -> void:
	var pid := w.actors.ids[0]
	var heat := Heat.points(w)
	if Heat.vent(w):
		var e := w.emit_event(SimEvent.Kind.VENT, pid, pid, pid, w.player_pos())
		e.amount = heat
	else:
		w.kit.cold_tick = w.tick
		w.emit_event(SimEvent.Kind.VENT_COLD, pid, pid, pid, w.player_pos())


static func _start(w: World, t: SkillTable) -> void:
	var k := w.kit
	k.skill_t = 1
	k.skill_cd = Stats.cooldown(w, t.cooldown_ticks)  # v0.4.0 BS: the cooldowns stat
	k.skill_root = w.take_root()
	k.skill_tick = w.tick
	k.skill_from = w.player_pos()
	var lunge := t.kind == SkillTable.Kind.LUNGE_CLEAVE
	k.skill_angle = PlayerBuild.melee_angle(w) if lunge else w.aim_angle
	var pid := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.SKILL_USED, pid, pid, pid, k.skill_from)
	e.root_id = k.skill_root
	e.amount = t.kind
	Curses.on_ability_use(w)  # v0.6.0 CU: Blood Price
	if not lunge:
		_blast(w, t)


## The skill moves the user this tick (phase 5): the lunge, or the step back.
static func moving(w: World) -> bool:
	var t := w.player.skill
	return t != null and w.kit.skill_t > 0 and w.kit.skill_t <= t.move_ticks()


## This tick's step (phase 5; walls resolve it after, as a dash's).
static func move_step(w: World) -> Vector2:
	var t := w.player.skill
	return Kin.dir(w.kit.skill_angle) * (t.move_m() / t.move_ticks())


# --- Lunge Cleave -------------------------------------------------------------------------------------------
## True if the cleave fan at `center` facing `angle` touches a circle (p, r): the hit and the view's forecast
## (WorldReader.skill_hits) use this one function (EI-07).
static func cleave_touches(w: World, center: Vector2, angle: int, p: Vector2, r: float) -> bool:
	return Attacks.arc_touches(w, Modifiers.skill(w), center, angle, p, r)  # area: Attacks.arc_reach_m


static func _cleave(w: World, _t: SkillTable) -> void:
	var k := w.kit
	var spec := Modifiers.skill(w)
	var center := w.player_pos()
	k.hit_tick = w.tick
	k.hit_pos = center
	var dmg := Gamble.melee_damage(w, PlayerBuild.melee_damage(w, spec.damage))
	var ctx := AttackContext.make(center, k.skill_angle, dmg, k.skill_root, TAGS_CLEAVE, &"")
	if Attacks.launch(w, spec, ctx):
		w.add_freeze(spec.hitstop_ticks)


# --- Scatter Blast ------------------------------------------------------------------------------------------
## Where along pellet `ang`'s path from `center` it first touches a circle (p, r): 0..1, or -1 if it never does.
## The hit and the view's forecast (WorldReader.skill_hits) use this one function (EI-07).
static func pellet_touches(w: World, center: Vector2, ang: int, p: Vector2, r: float) -> float:
	return Attacks.ray_touches(w, Modifiers.skill(w), center, ang, p, r)


static func _blast(w: World, t: SkillTable) -> void:
	var k := w.kit
	var spec := Modifiers.skill(w)
	var origin := w.player_pos()
	k.hit_tick = w.tick
	k.hit_pos = origin
	k.pellet_ends = PackedVector2Array()
	var ctx := AttackContext.make(origin, k.skill_angle, 0, k.skill_root, TAGS_PELLET, &"")
	# The bolt factor's remainder carries pellet to pellet, so each landed pellet takes its damage then (as v0.5).
	ctx.damage_fn = func() -> int:
		return Gamble.shot_damage(w, PlayerBuild.bolt_damage(w, spec.damage))
	ctx.on_ray = func(end: Vector2) -> void: k.pellet_ends.append(end)
	ctx.on_landed = func(target: int) -> void: _knock(w, target, origin, t)
	Attacks.launch(w, spec, ctx)


static func _knock(w: World, i: int, origin: Vector2, t: SkillTable) -> void:
	var k := w.kit
	var a := w.actors
	if BossAi.is_boss_kind(a.kinds[i]) or k.knock_ids.has(a.ids[i]) or t.knockback_ticks <= 0:
		return
	var away := a.pos(i) - origin
	var len := Kin.length(away)
	k.knock_ids.append(a.ids[i])
	k.knock_dirs.append(away / len if len > 0.0 else Kin.dir(k.skill_angle))
	k.knock_left.append(t.knockback_ticks)


## Tick phase 5, after the enemies move and before walls and bodies resolve: each knocked enemy slides its share.
static func push(w: World) -> void:
	var k := w.kit
	if k.knock_ids.is_empty():
		return
	var t := w.player.skill
	var step := t.knockback_m / t.knockback_ticks if t != null else 0.0
	for j in range(k.knock_ids.size() - 1, -1, -1):
		var i := w.actors.index_of(k.knock_ids[j])
		if i >= 0 and w.actors.dead[i] == 0 and step > 0.0:
			w.actors.set_pos(i, w.actors.pos(i) + k.knock_dirs[j] * step)
			k.knock_left[j] -= 1
		else:
			k.knock_left[j] = 0
		if k.knock_left[j] <= 0:
			k.knock_ids.remove_at(j)
			k.knock_dirs.remove_at(j)
			k.knock_left.remove_at(j)


## True if the skill, used now from `center` toward `angle`, would reach actor `i` with nothing else in the way
## (WorldReader.skill_hits): the cleave's fan, or any pellet's path.
static func would_hit(w: World, i: int, center: Vector2, angle: int) -> bool:
	var t := w.player.skill
	if t == null:
		return false
	var p := w.actors.pos(i)
	var r := w.actors.radius[i]
	if t.kind == SkillTable.Kind.LUNGE_CLEAVE:
		return cleave_touches(w, center, angle, p, r)
	var spec := Modifiers.skill(w)
	for ang in AttackShapes.pellet_angles(angle, spec.spread / 2, spec.count):
		if pellet_touches(w, center, ang, p, r) >= 0.0:
			return true
	return false


## The reads the views need (WorldReader.skill_state; {} without a skill).
static func read(w: World) -> Dictionary:
	var t := w.player.skill
	if t == null:
		return {}
	var k := w.kit
	var spec := Modifiers.skill(w)  # v0.6.0 MX1: the view draws the compiled spec
	return {
		"kind": t.kind,
		"cooldown": k.skill_cd,
		"cooldown_total": Stats.cooldown(w, t.cooldown_ticks),
		"ready": ready(w),
		"running": k.skill_t,
		"move_ticks": t.move_ticks(),
		"angle": k.skill_angle,
		"tick": k.skill_tick,
		"from": k.skill_from,
		"hit_tick": k.hit_tick,
		"hit_pos": k.hit_pos,
		"pellet_ends": k.pellet_ends,
		"half_arc": spec.half_arc,
		"reach_m": Attacks.arc_reach_m(w, spec),
		"half_cone": spec.spread / 2,
		"range_m": spec.reach_m,
		"pellets": spec.count,
		"lunge_m": t.lunge_m,
	}
