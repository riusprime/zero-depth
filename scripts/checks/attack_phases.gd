extends SceneTree
## The hero's attacks against a horde: what each part of the sim's attack phases costs a tick. It is the frame probe's
## heavy scene without the renderer: the Playground's room (the Gun, red_canyon), N real enemies kept alive in a ring
## 7-12 m round the hero (the frame probe's top-up), the frame probe's --heavy build granted through PlaygroundApi as
## the Playground does, FightBot moving and aiming with the fire button held every tick, and the hero kept alive.
## Per tick it times World.step and every phase and sub-phase World.phase_probe reports (probe-only: it changes no
## outcome), and prints ms mean / p99 / max for each. The outcome is a hash chain of World.state_hash and the
## projectiles every 60 ticks: the same before and after a speed-up.
## --calls=1 also times the helpers a landed hero hit calls (microseconds a call, CALL_REPS calls each, on the world as
## the run left it, against a burning enemy when there is one). They only read the world.
## Writes nothing tracked; paste the output into evidence by hand.
##   godot --headless --path . -s scripts/checks/attack_phases.gd [-- --enemies=60] [-- --ticks=1800] [-- --calls=1]

const BIOME := &"red_canyon"
const BOT_SEED := 20261010
const CALL_REPS := 20000
const KINDS: Array[int] = [
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.NEEDLE,
	ActorStore.Kind.WARDEN,
	ActorStore.Kind.ARC_CASTER,
	ActorStore.Kind.BOMB_DRONE
]
## The frame probe's build (scripts/checks/frame_probe.gd BUILD_KEYS at level 3, HEAVY_KEYS at HEAVY_LEVEL).
const BUILD_KEYS: Array[StringName] = [
	&"ITEM_GUN_GLAIVE",
	&"ITEM_GUN_RING",
	&"ITEM_SPLIT_SHOT",
	&"ITEM_EMBER_CORE",
	&"ITEM_STORM_CORE",
]
const HEAVY_KEYS: Array[StringName] = [
	&"ITEM_GUN_TWIN",
	&"ITEM_HALO_SHOT",
	&"ITEM_GUN_RAPID_FIRE",
	&"ITEM_WILDFIRE",
	&"ITEM_CHAIN_BLAST",
	&"ITEM_GUN_RUNE_EXPLOSION",
]
const HEAVY_LEVEL := 5

var _spawned := 0


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var w := _measure(
		ContentRepository.load_all(), int(args.get("--enemies", 60)), int(args.get("--ticks", 1800))
	)
	if args.has("--calls"):
		_calls(w)
	quit(0)


func _measure(repo: ContentRepository, n: int, ticks: int) -> World:
	var w := PlaygroundScenario.build(repo, &"gun", repo.get_def(&"biomes", BIOME))
	var api := PlaygroundApi.new(w)
	var granted: PackedStringArray = []
	for e: Dictionary in api.catalog():
		if BUILD_KEYS.has(e["name_key"]) and api.grant_now(e["code"], 3):
			granted.append(String(e["name_key"]))
	for e: Dictionary in api.catalog():
		if HEAVY_KEYS.has(e["name_key"]) and api.grant_now(e["code"], HEAVY_LEVEL):
			granted.append(String(e["name_key"]))
	var bot := FightBot.new(BOT_SEED)
	var timer := PerfBreakdown.PhaseTimer.new()
	w.phase_probe = timer
	var samples := {&"step": []}
	var chain := StateHasher.new()
	var proj_sum := 0
	for t in ticks:
		var alive := 0
		for i in range(1, w.actors.size()):
			if w.actors.dead[i] == 0 and EnemyAi.is_enemy_kind(w.actors.kinds[i]):
				alive += 1
		_top_up(w, api, n - alive, t)
		if not w.player_dead():
			w.actors.hp[0] = w.actors.max_hp[0]
		var frame := bot.frame(w)
		frame.held |= InputFrame.SHOOT  # Fires all the time, as the frame probe holds the button
		timer.reset()
		var t0 := Time.get_ticks_usec()
		w.step(frame)
		(samples[&"step"] as Array).append((Time.get_ticks_usec() - t0) / 1000.0)
		for k: StringName in timer.us:
			if not samples.has(k):  # A phase first seen now cost 0 on the ticks before
				var z := []
				z.resize(t)
				z.fill(0.0)
				samples[k] = z
			(samples[k] as Array).append(int(timer.us[k]) / 1000.0)
		for k: StringName in samples:  # A phase that didn't run this tick costs 0
			if (samples[k] as Array).size() == t:
				(samples[k] as Array).append(0.0)
		proj_sum += w.projectiles.size()
		if t % 60 == 59:
			chain.add_string(w.state_hash())
			w.projectiles.hash_into(chain)
	w.phase_probe = null
	print("cards=%s" % ", ".join(granted))
	print(
		(
			"enemies=%d ticks=%d spawned=%d mean_projectiles=%.1f"
			% [n, ticks, _spawned, float(proj_sum) / ticks]
		)
	)
	var keys: Array = samples.keys()
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for k: StringName in keys:
		var a: Array = samples[k]
		var s := a.duplicate()
		s.sort()
		var sum := 0.0
		for v in a:
			sum += v
		print(
			(
				"  %-20s mean %7.3f  p99 %7.3f  max %7.3f ms"
				% [k, sum / a.size(), s[int(a.size() * 0.99)], s[a.size() - 1]]
			)
		)
	print("  outcome_hash %s  final_tick_hash %s" % [chain.finish_hex(), w.state_hash()])
	return w


## Tops the horde up by `missing` enemies on a ring round the hero, kinds in turn (as frame_probe._top_up).
func _top_up(w: World, api: PlaygroundApi, missing: int, t: int) -> void:
	var p := w.player_pos()
	var tries := 0
	while missing > 0 and tries < 180:
		tries += 1
		var ang := float(tries * 137) * 0.0174533 + float(t) * 0.01
		var dist := 7.0 + float((tries * 53) % 6)
		if api.place_enemy_now(
			KINDS[_spawned % KINDS.size()], p + Vector2(cos(ang), sin(ang)) * dist
		):
			_spawned += 1
			missing -= 1


## The read-only helpers of Damage.hit's multipliers, a call each, CALL_REPS times.
func _calls(w: World) -> void:
	var tgt := -1
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 0 and EnemyAi.is_enemy_kind(w.actors.kinds[i]):
			if tgt < 0 or w.actors.burn_stacks[i] > 0:
				tgt = i
			if w.actors.burn_stacks[i] > 0:
				break
	if tgt < 0:
		print("calls: no live enemy")
		return
	var pid := w.actors.ids[0]
	var fire := ElementStack.FIRE
	print(
		(
			"calls (us a call, %d calls; enemy %d, burning %s):"
			% [CALL_REPS, tgt, w.actors.burn_stacks[tgt] > 0]
		)
	)
	_time("empty", func() -> void: pass)
	_time("Stats.damage_permille", func() -> void: Stats.damage_permille(w))
	_time("Stats.crit_chance", func() -> void: Stats.crit_chance(w))
	_time("Stats.crit_mult", func() -> void: Stats.crit_mult(w))
	_time("RuleCards.outgoing", func() -> void: RuleCards.outgoing(w, tgt, 10, 0, 1, &""))
	_time("ItemProcs.execute_mult", func() -> void: ItemProcs.execute_mult(w, tgt, pid))
	_time("Engines.attacker_mult", func() -> void: Engines.attacker_mult(w, tgt, pid))
	_time("ModifierRuntime.resonance", func() -> void: ModifierRuntime.resonance_mult(w, tgt, pid))
	_time("Heat.attacker_mult", func() -> void: Heat.attacker_mult(w, tgt, pid, 0, &""))
	_time("ElementLevelsFsf.attacker", func() -> void: ElementLevelsFsf.attacker_mult(w, tgt, pid))
	_time("ElementLevelsFsf.level", func() -> void: ElementLevelsFsf.level(w, 0))
	_time("ElementStack.mult", func() -> void: ElementStack.mult(w, tgt, fire))
	_time("ElementStack.falloff", func() -> void: ElementStack.falloff_permille(w, tgt, fire))
	_time("ElementStack.level_permille", func() -> void: ElementStack.level_permille(w, fire))
	_time("Damage.target_mult", func() -> void: Damage.target_mult(w, tgt, Vector2.ZERO))
	_time("World.enemies_near 3 m", func() -> void: w.enemies_near(w.player_pos(), 3.0))


func _time(label: String, f: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	for k in CALL_REPS:
		f.call()
	print("  %-28s %7.3f" % [label, float(Time.get_ticks_usec() - t0) / CALL_REPS])
