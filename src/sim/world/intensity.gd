class_name Intensity
extends RefCounted
## The intensity director (v0.8.0 Step N5; owner O58, Left 4 Dead's AI director: "It doesn't change how hard the game
## hits. It changes when."; SIM_CONTRACTS §11). Runs inside SpawnDirector.advance, so only on ordinary floor spawning:
## a sealed arena, the Overrun, a boss room and a world without the table (SpawnTable.intensity) never run it. Each
## tick it runs (World.intensity, an IntensityState; intensity in milli, 0..1000000):
## - a hit: the hero's HP fell since the tick before by d: + d × hit_full_hp_gain / max HP (any HP lost counts);
## - close: an enemy (alive) within close_radius_m: + close_gain_per_tick;
## - a kill: an enemy dying within close_radius_m (World._remove_dead, on_death): + close_kill_gain;
## - calm: ticks since the last hit or close enemy; once calm_ticks, − drain_per_tick a tick (never below 0);
## then the state: BUILD_UP → PEAK at peak_level (its length and the quiet's drawn from the `ai:intensity:<cycle>`
## stream, derived from the world's seed); PEAK → PULL_BACK when its timer ends; PULL_BACK → QUIET when at most
## pull_back_enemies are within pull_back_radius_m or pull_back_max_ticks pass; QUIET → BUILD_UP (cycle + 1) when its
## timer ends and intensity is at most relax_level, or at the latest quiet_ticks_max after it began (enemies that stay
## close and keep intensity up never make the quiet longer than its range; intensity then drops to relax_level, so
## the build-up starts from there). PULL_BACK and QUIET send no new packs (sending()); the enemies out
## stay. Nothing here touches what spawns or how strong: the curve, the tier, the curses and the catch-up do.


static func table(w: World) -> IntensityTable:
	return w.spawner.intensity if w.spawner != null else null


## True while the director lets new packs come (always without the table).
static func sending(w: World) -> bool:
	if table(w) == null:
		return true
	var m := w.intensity.mode
	return m == IntensityState.Mode.BUILD_UP or m == IntensityState.Mode.PEAK


## The interval to the next pack: the curve's `base`, × build_interval_permille while building up (the ramp toward
## the peak: the packs come sooner, never more at once and never stronger; the cap is the curve's).
static func interval(w: World, base: int) -> int:
	var t := table(w)
	if t == null or w.intensity.mode != IntensityState.Mode.BUILD_UP:
		return base
	return maxi(1, SpawnTable.scale(base, t.build_interval_permille))


## One tick of the director (SpawnDirector.advance, tick phase 9, before the pack check).
static func advance(w: World) -> void:
	var t := table(w)
	if t == null:
		return
	var s := w.intensity
	var hp := w.actors.hp[0]
	var live := s.seen_tick == w.tick - 1  # paused (an arena, the boss room) or new: no gain from the gap
	var hit := false
	if live and hp < s.last_hp:
		var lost := s.last_hp - hp
		s.level += lost * t.hit_full_hp_gain / maxi(1, w.actors.max_hp[0])
		hit = true
	s.last_hp = hp
	s.seen_tick = w.tick
	var close := near(w, t.close_radius_m) > 0
	if close:
		s.level += t.close_gain_per_tick
	if hit or close:
		s.calm = 0
	else:
		s.calm += 1
		if s.calm >= t.calm_ticks:
			s.level -= t.drain_per_tick
	s.level = clampi(s.level, 0, IntensityTable.TOP)
	step_mode(w, t, s)


## The state machine (advance, after intensity moved).
static func step_mode(w: World, t: IntensityTable, s: IntensityState) -> void:
	match s.mode:
		IntensityState.Mode.BUILD_UP:
			if s.level >= t.peak_level:
				var rng := RngStream.derive(w.seed_value, "ai:intensity:%d" % s.cycle)
				s.mode = IntensityState.Mode.PEAK
				s.timer = rng.range_int(t.peak_ticks_min, t.peak_ticks_max)
				s.quiet_len = rng.range_int(t.quiet_ticks_min, t.quiet_ticks_max)
		IntensityState.Mode.PEAK:
			s.timer -= 1
			if s.timer <= 0:
				s.mode = IntensityState.Mode.PULL_BACK
				s.timer = t.pull_back_max_ticks
		IntensityState.Mode.PULL_BACK:
			s.timer -= 1
			if s.timer <= 0 or near(w, t.pull_back_radius_m) <= t.pull_back_enemies:
				s.mode = IntensityState.Mode.QUIET
				s.timer = s.quiet_len
		IntensityState.Mode.QUIET:
			s.timer -= 1  # past 0 it counts the overtime (negative)
			if s.timer > 0:
				return
			var late := s.quiet_len - s.timer >= t.quiet_ticks_max
			if s.level <= t.relax_level or late:
				s.level = mini(s.level, t.relax_level)  # a late end starts the build-up from relax
				s.mode = IntensityState.Mode.BUILD_UP
				s.cycle += 1


## World._remove_dead: enemy i dies; within close_radius_m of the hero it adds close_kill_gain (only while the director
## ran the tick before: a kill in a sealed arena or the boss room counts nothing).
static func on_death(w: World, i: int) -> void:
	var t := table(w)
	if t == null or w.intensity.seen_tick != w.tick - 1:
		return
	if Kin.length(w.actors.pos(i) - w.player_pos()) <= t.close_radius_m:
		w.intensity.level = mini(w.intensity.level + t.close_kill_gain, IntensityTable.TOP)


## Alive enemies within r of the hero.
static func near(w: World, r: float) -> int:
	var p := w.player_pos()
	var n := 0
	for i in range(1, w.actors.size()):
		if (
			EnemyAi.is_enemy_kind(w.actors.kinds[i])
			and w.actors.dead[i] == 0
			and Kin.length(w.actors.pos(i) - p) <= r
		):
			n += 1
	return n
