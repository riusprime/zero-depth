class_name FireRhythm
extends RefCounted
## v0.8.0 MR (owner O91: "Rework Rapid Fire/Flurry into distinct sustained-fire/burst rhythms"; WAND.md G14, B8): the
## rhythm cards' extra rate, read when the attack fires and counted into its raw rate bonus (the one the attack-speed
## curve takes in: ItemEffects.shot_period_ticks, BladeForms.step add it to the spec's rate_bonus_permille). The
## rhythms are data on the spec (AttackSpec.ramp_*, burst_*); their state is ModifierState's (ramp_n, ramp_tick,
## burst_n, burst_free: hashed and saved with it). One clock, no randomness (EI-03, EI-05).
## - Rapid Fire (sustained fire): each shot within ramp_reset_ticks of the one before is one more in the streak; the
##   gap after the streak's nth shot comes ramp_permille × (n − 1) faster, at most ramp_cap_permille. A pause longer
##   than ramp_reset_ticks starts the streak over.
## - Flurry (a burst): a swing that starts burst_pause_ticks or more after the last swing ended is the burst's first;
##   the first burst_swings swings of a burst come burst_permille faster, the rest at the base rate.


## The extra rate bonus (per mille) of the Gun's next gap, after the shot just fired (0 without a ramp).
static func shot_bonus(w: World, spec: AttackSpec) -> int:
	var m := w.mx
	if spec.ramp_permille <= 0 or m.ramp_n <= 1 or w.tick - m.ramp_tick > spec.ramp_reset_ticks:
		return 0
	return mini(spec.ramp_permille * (m.ramp_n - 1), maxi(0, spec.ramp_cap_permille))


## A shot was fired now (PlayerKit._fire_bolt): one more in Rapid Fire's streak, or the first of a new one.
static func on_shot(w: World) -> void:
	var spec := Modifiers.bolt(w)
	if spec == null or spec.ramp_permille <= 0:
		return
	var m := w.mx
	var on := m.ramp_n > 0 and w.tick - m.ramp_tick <= spec.ramp_reset_ticks
	var cap := maxi(0, spec.ramp_cap_permille)
	var top := 1 + (cap + spec.ramp_permille - 1) / spec.ramp_permille  # past the cap the count stops
	m.ramp_n = mini(m.ramp_n + 1, top) if on else 1
	m.ramp_tick = w.tick


## The extra rate bonus (per mille) of combo step spec `spec`'s swing now (0 outside Flurry's burst).
static func swing_bonus(w: World, spec: AttackSpec) -> int:
	if spec.burst_swings <= 0 or spec.burst_permille == 0:
		return 0
	var n := w.mx.burst_n
	return spec.burst_permille if n >= 1 and n <= spec.burst_swings else 0


## A swing started now (PlayerKit.advance; w.combo_step is its step): its place in Flurry's burst, and the tick it
## ends (the next swing's pause is counted from there).
static func on_swing(w: World) -> void:
	var spec := Modifiers.step(w, w.combo_step)
	if spec == null or spec.burst_swings <= 0:
		return
	var m := w.mx
	if m.burst_n == 0 or w.tick - m.burst_free >= spec.burst_pause_ticks:
		m.burst_n = 1
	else:
		m.burst_n = mini(m.burst_n + 1, spec.burst_swings + 1)
	m.burst_free = w.tick + Stats.swing_end(w, PlayerKit.current_step(w))
