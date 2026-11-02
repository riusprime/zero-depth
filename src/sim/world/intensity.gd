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
## timer ends (v0.10.5 O4: on time; intensity then drops to at most relax_level, and the first pack waits a build-up
## interval). PULL_BACK and QUIET send no new packs (sending()); the enemies out stay.
## v0.10.5 O4 (owner D46): every tick it reads the hero (read_standing: HP share and the kills of the last ~10 s of
## fighting). A STRUGGLING hero peaks lower (struggle_peak_level), its peak runs out faster, a quiet that begins while
## it struggles is longer (struggle_quiet_permille) and its packs are capped one smaller (pack_size); a STRONG one
## and one BETWEEN get the build-up as before. Besides that pack cap, nothing here touches what spawns or how strong:
## the curve, the tier, the curses and the catch-up do.


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
	count_kills(w, s, live)
	s.standing = read_standing(w, t, s)
	step_mode(w, t, s)


## The state machine (advance, after intensity moved).
static func step_mode(w: World, t: IntensityTable, s: IntensityState) -> void:
	match s.mode:
		IntensityState.Mode.BUILD_UP:
			var peak := (
				t.struggle_peak_level
				if s.standing == IntensityState.Standing.STRUGGLING
				else t.peak_level
			)
			if s.level >= peak:
				var rng := RngStream.derive(w.seed_value, "ai:intensity:%d" % s.cycle)
				s.mode = IntensityState.Mode.PEAK
				s.timer = rng.range_int(t.peak_ticks_min, t.peak_ticks_max)
				s.quiet_len = rng.range_int(t.quiet_ticks_min, t.quiet_ticks_max)
		IntensityState.Mode.PEAK:
			s.timer -= (
				t.struggle_peak_speed if s.standing == IntensityState.Standing.STRUGGLING else 1
			)
			if s.timer <= 0:
				s.mode = IntensityState.Mode.PULL_BACK
				s.timer = t.pull_back_max_ticks
		IntensityState.Mode.PULL_BACK:
			s.timer -= 1
			if s.timer <= 0 or near(w, t.pull_back_radius_m) <= t.pull_back_enemies:
				s.mode = IntensityState.Mode.QUIET
				if s.standing == IntensityState.Standing.STRUGGLING:  # v0.10.5 O4: a longer quiet
					s.quiet_len = SpawnTable.scale(s.quiet_len, t.struggle_quiet_permille)
				s.timer = s.quiet_len
		IntensityState.Mode.QUIET:
			# v0.10.5 O4 (D46's "not working"): the quiet ends on its drawn time. Before, it also waited for intensity to
			# fall to relax, which leftovers the hero can't reach never let happen: every quiet ran to its 20 s top.
			s.timer -= 1
			if s.timer > 0:
				return
			s.level = mini(s.level, t.relax_level)  # the build-up starts from relax at most
			s.mode = IntensityState.Mode.BUILD_UP
			s.cycle += 1
			# v0.10.5 O4: the room refills one pack at a time from what is left: the first pack waits a build-up interval
			# (the clock ran down to 0 during the quiet, and the cap's worth arrived in a burst).
			w.spawn_cd = maxi(w.spawn_cd, interval(w, w.spawner.interval_now(w.run_ticks)))


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


# --- v0.10.5 O4 (owner D46: "Read your state live") ---------------------------------------------------------------
## The kills since the last read into the window's slot for this second of fighting. Only while the director ran the
## tick before (`live`) and outside QUIET (no packs come, so a quiet would read as slow killing); kills in a gap (an
## arena, the boss room) or in a quiet are dropped. The first read on a floor (or of an older save) only syncs.
static func count_kills(w: World, s: IntensityState, live: bool) -> void:
	var fresh := maxi(0, w.kills - s.kill_seen)
	var first := s.kill_ring.size() != IntensityState.KILL_SLOTS
	s.kill_seen = w.kills
	if first:
		s.kill_ring.resize(IntensityState.KILL_SLOTS)
		s.kill_ring.fill(0)
		s.ring_ticks = 0
		return
	if not live or s.mode == IntensityState.Mode.QUIET:
		return
	var slot := (s.ring_ticks / SimTick.TICKS_PER_SECOND) % IntensityState.KILL_SLOTS
	if s.ring_ticks % SimTick.TICKS_PER_SECOND == 0:
		s.kill_ring[slot] = 0
	s.kill_ring[slot] += fresh
	s.ring_ticks += 1


## How the hero is doing now. STRUGGLING: HP under struggle_hp_permille of max, or a slow kill rate: once a full
## window of fighting is counted and at least slow_min_alive enemies are out, the window's kills under
## slow_kill_permille of the expected (the cap now × expected_kill_permille). STRONG: HP above strong_hp_permille and
## the window's kills at least the expected (before a full window, HP alone). Else BETWEEN.
static func read_standing(w: World, t: IntensityTable, s: IntensityState) -> int:
	var hp := w.actors.hp[0] * 1000
	var top := maxi(1, w.actors.max_hp[0])
	var full := s.ring_ticks >= IntensityState.KILL_SLOTS * SimTick.TICKS_PER_SECOND
	var expected := w.spawner.cap_now(w.floor_index, w.run_ticks) * t.expected_kill_permille  # kills × 1000
	var kills := s.window_kills() * 1000
	if hp < top * t.struggle_hp_permille:
		return IntensityState.Standing.STRUGGLING
	if (
		full
		and WaveDirector.enemies_alive(w) >= t.slow_min_alive
		and kills * 1000 < expected * t.slow_kill_permille
	):
		return IntensityState.Standing.STRUGGLING
	if hp > top * t.strong_hp_permille and (not full or kills >= expected):
		return IntensityState.Standing.STRONG
	return IntensityState.Standing.BETWEEN


## SpawnDirector._spawn_pack: mix row `entry`'s pack `size`; while the hero struggles, at most the row's largest pack
## (its fixed pack, or the floor's pack_max) less struggle_pack_cut, and at least 1.
static func pack_size(w: World, t: SpawnTable, entry: int, size: int) -> int:
	var it := table(w)
	if it == null or w.intensity.standing != IntensityState.Standing.STRUGGLING:
		return size
	var fixed := t.packs[entry] if entry < t.packs.size() else 0
	var largest := fixed if fixed > 0 else t.pack_max(w.floor_index)
	return maxi(1, mini(size, largest - it.struggle_pack_cut))
