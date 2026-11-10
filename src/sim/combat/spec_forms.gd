class_name SpecForms
extends RefCounted
## docs/design/MODIFIER_ENGINE.md §2, the M-list: what Modifiers does to a spec's sizes when its form
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


## v0.10.5 W3-S18 (owner, 2026-11-05, playtesting: "homing + halo is weird because the back attacks are too short in
## reach and do the curve but do not reach the enemy, we should increase the reach of halo a bit so attacks can get to
## hit front enemies if homing is active"): a Halo bolt has half the Gun's flight (20 of 40 ticks, 5.4 m). Homing turns
## it 102/4096 of a turn a tick (540 deg/s), a circle of radius 1.72 m, so the U-turn alone is half a circle: 20 ticks,
## the whole flight, and the bolt dies facing the enemy. A pursuit from straight behind needs 42 ticks to reach an
## enemy 6 m ahead (the back bolt keeps sight, HOME_M 8 m, of enemies up to about 5.5 m ahead: it starts 0.6 m behind
## the hero and swings 1.7 m out). So with Homing, Halo's halved range is scaled by `halo_homing_permille` (2600: 20 ->
## 52 ticks, 14 m, a margin over the 42-45 the pursuit needs). Without Homing Halo keeps its half range. Run after
## every card, so the order of the two cards does not matter; spent once.
static func halo_homing_reach(s: AttackSpec) -> void:
	var p := s.halo_homing_permille
	s.halo_homing_permille = 0
	if p > 0 and s.homing > 0 and s.form == FORM.BOLT:
		scale_range(s, p)


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
## forms' times, and a bolt's speed and flight, an arc's width; a bolt hook of an arc is a crescent as wide as
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
