class_name SpecForms
extends RefCounted
## v0.6.0 MX4 (docs/design/MODIFIER_ENGINE.md §2, the M-list): what Modifiers does to a spec's sizes when its form
## changes, the per-form "range" a modifier scales, a hook child's starting sizes, and the ability merges (mirror).
## Compile-time only (the specs are rebuilt on every compile; nothing here runs in a tick). No randomness, no trig.
##
## A form change keeps the attack's reach: the range it had (an arc's reach, a bolt's flight, a burst's or ring's
## radius) becomes the new form's (a bolt that becomes a ring rings out to half its flight: Shock Circles' "at half
## range"), clamped to sizes each form reads well at. These are starting values the owner tunes by play.

const FORM := AttackSpec.Form
## A hook's bolt when its op names no speed or flight (12 m/s, 0.5 s), and an arc's half width (45°).
const BOLT_SPEED := 0.2
const BOLT_TICKS := 30
const BOLT_RADIUS_M := 0.15
const CRESCENT_RADIUS_M := 0.35
const HALF_ARC := 512
## A full circle's half width (1/4096 turns): an arc with directions = circle sweeps all round.
const FULL_HALF_ARC := 2048


## The spec's range in metres: an arc's, a beam's, a lob's or an orbiter's reach; a bolt's flight (speed × life); a
## ring's, a burst's or a zone's radius.
static func range_of(s: AttackSpec) -> float:
	match s.form:
		FORM.BOLT:
			return s.speed * s.life_ticks
		FORM.RING, FORM.BURST, FORM.ZONE:
			return s.radius_m
	return s.reach_m


## Scales the spec's range by `permille` (Short Fuse ×0.6, Halo Shot ×0.5): the field range_of reads.
static func scale_range(s: AttackSpec, permille: float) -> void:
	match s.form:
		FORM.BOLT:
			s.life_ticks = maxi(1, int(s.life_ticks * permille / 1000.0))
		FORM.RING, FORM.BURST, FORM.ZONE:
			s.radius_m = s.radius_m * permille / 1000.0
		_:
			s.reach_m = s.reach_m * permille / 1000.0


## `s` becomes form `to`, keeping its range (see the class doc). Its other fields (payload, pattern, hooks) stay.
static func change_form(s: AttackSpec, to: int) -> void:
	var from := s.form
	var r := range_of(s)
	s.form = to
	if to == from:
		return
	var long := from == FORM.BOLT or from == FORM.BEAM or from == FORM.LOB
	match to:
		FORM.ARC:
			s.reach_m = clampf(r * 0.4 if long else r, 1.2, 3.5)
			if s.half_arc <= 0:
				s.half_arc = HALF_ARC
		FORM.BOLT:
			if s.speed <= 0.0:
				s.speed = BOLT_SPEED
			s.life_ticks = maxi(6, int(ceil(clampf(r, 4.0, 14.0) / s.speed)))
			s.radius_m = CRESCENT_RADIUS_M if from == FORM.ARC else BOLT_RADIUS_M
		FORM.RING:
			s.radius_m = clampf(r * 0.5 if long else r, 1.5, 6.0)
			s.life_ticks = Modifiers.RING_TICKS
		FORM.BURST:
			s.radius_m = clampf(r * 0.5 if long else r, 1.0, 4.0)
		FORM.ZONE:
			s.radius_m = clampf(r * 0.3 if long else r, 1.0, 3.0)
			s.life_ticks = Modifiers.HOOK_ZONE_TICKS
			s.period_ticks = Modifiers.HOOK_ZONE_GAP
		FORM.BEAM:
			s.reach_m = clampf(r, 2.0, 8.0)
			if s.radius_m <= 0.0 or not long:
				s.radius_m = BOLT_RADIUS_M
			s.count = maxi(1, s.count)
			s.seek = false
		FORM.LOB:
			s.reach_m = clampf(r, 2.0, 8.0)
			s.radius_m = 1.5
			s.life_ticks = Modifiers.HOOK_LOB_TICKS
		FORM.ORBITER:
			s.reach_m = 1.5
			s.radius_m = CRESCENT_RADIUS_M
			s.count = maxi(1, s.count)


## A hook child's starting sizes for its form, from its op's radius and reach (Modifiers._hook): the lingering
## forms' times, and (MX4) a bolt's speed and flight, an arc's width; a bolt hook of an arc is a crescent as wide as
## the arc (Echo Slash: "a projectile copy of the arc").
static func hook_base(c: AttackSpec, parent: AttackSpec) -> void:
	match c.form:
		FORM.LOB:
			c.life_ticks = Modifiers.HOOK_LOB_TICKS
		FORM.ZONE:
			c.life_ticks = Modifiers.HOOK_ZONE_TICKS
			c.period_ticks = Modifiers.HOOK_ZONE_GAP
		FORM.RING:
			c.life_ticks = Modifiers.RING_TICKS
		FORM.ORBITER:
			c.count = maxi(1, c.count)
		FORM.BOLT:
			c.speed = BOLT_SPEED
			c.life_ticks = int(ceil(c.reach_m / c.speed)) if c.reach_m > 0.0 else BOLT_TICKS
			if c.radius_m <= 0.0:
				c.radius_m = BOLT_RADIUS_M
			if parent.form == FORM.ARC:
				c.half_arc = parent.half_arc
		FORM.ARC:
			c.half_arc = HALF_ARC


## After every stage: an arc whose directions are a circle sweeps all round.
static func settle(s: AttackSpec) -> void:
	if s.form == FORM.ARC and s.directions == AttackSpec.DIR_CIRCLE:
		s.half_arc = FULL_HALF_ARC


## The ability merges (after Modifiers.inherit): mirror 1 (Mirror Drone) copies the weapon's form (a Gun's shot
## pattern and behaviour; a Blade's arc as a crescent bolt as wide as the arc) and every one of its hooks; mirror 2
## (Blade Orbit) takes every hook of the weapon, the ones that fire as an attack launches or ends firing on each
## touch instead.
static func mirror(s: AttackSpec, root: AttackSpec) -> void:
	if root == null or s.mirror <= 0:
		return
	if s.mirror == 1:
		if root.form == FORM.BOLT:
			for f: StringName in [
				&"count",
				&"spread",
				&"damage_permille",
				&"directions",
				&"back_permille",
				&"aim_offset",
				&"bounces",
				&"pierce",
				&"homing",
				&"returns",
				&"orbit_ticks",
			]:
				s.set(f, root.get(f))
			s.radius_m = maxf(s.radius_m, root.radius_m)
		else:
			s.half_arc = root.half_arc
			s.radius_m = maxf(s.radius_m, CRESCENT_RADIUS_M)
		s.repeat_delay_ticks = root.repeat_delay_ticks
		s.repeat_damage_permille = root.repeat_damage_permille
	if s.depth >= Modifiers.MAX_DEPTH:
		return
	for h in root.hooks:
		if s.hooks.has(h):
			continue
		var t := h.trigger
		if s.mirror == 2 and (t == AttackSpec.Trigger.ON_END or t == AttackSpec.Trigger.ON_LAUNCH):
			var k := AttackHook.new()
			k.id = h.id
			k.trigger = AttackSpec.Trigger.ON_HIT
			k.every = h.every
			k.damage = h.damage
			k.damage_permille = h.damage_permille
			k.delay_ticks = h.delay_ticks
			k.when = h.when
			k.child = h.child
			s.hooks.append(k)
		elif s.mirror == 1 or t == AttackSpec.Trigger.ON_HIT or t == AttackSpec.Trigger.ON_KILL:
			s.hooks.append(h)
