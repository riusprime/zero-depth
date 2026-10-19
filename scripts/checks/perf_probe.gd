extends SceneTree
## v0.8.0 PF (owner O9): the frame-cost probe for the Gun's Spread + Split + Explosive build. It builds the
## Playground's World (PlaygroundScenario: the one 4 x 4 room), grants gun_spread, split_shot and shared_explosive at
## level 5 (and gun_twin with --twin), places endless dummies in front of the hero, holds Shoot at them and times,
## per tick:
##   sim    World.step (with the Playground's upkeep: the dummies' HP refill);
##   sync   WorldViewRoot.sync (the views reading the tick);
##   frame  every _process of the view's nodes, called by this probe once per tick (the probe turns their own
##          processing off and calls them itself, so each is timed; --fixed-fps 60 makes one frame one tick).
## Headless has no GPU: "frame" is the CPU side only (building the MultiMesh buffers, lights and decals); the GPU's
## draw cost is not in it. It counts, per tick: live player projectiles, launches, sim events, explosion bursts drawn,
## VFX sprites asked for and drawn, light requests and lights on, floor marks.
## v0.8.0 BL (BLADE_AUDIT B6): it also tallies the damage the dummies took (DpsTally, the Playground's DPS meter's
## count from the event log) and prints it as damage per second, overall and per dummy, with the top sources.
## --weapon=blade runs the Blade (Primary pressed every tick, the dummies 1.4-2.3 m away); --cards=a,b,c grants these
## cards (in this wand order) instead of the default build; --cards=none grants none (v0.8.0 GF1: the plain weapon).
## v0.8.0 PF2: it also counts the ticks where a capped attack's throw was cut short (alive_capped: Blade Storm's 36).
## v0.8.0 AO: and the rings alive (rings: the order rule's lightning circles too) and the ticks the ring cap held a
## launch back (rings_capped: WandRings.RINGS_MAX).
## Writes only under build/ (build/perf/perf_probe.txt) and prints the same report.
##   godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd [-- --twin] [-- --seconds=10]
##   [-- --dummies=6] [-- --level=5] [-- --sim-only] [-- --cap=N] [-- --weapon=blade] [-- --cards=a,b,c]
##   [-- --tag=name] [-- --on-aim]
## v0.8.0 FV (owner O87: "when a visual op build hits a horde of enemies the game lags"): --horde[=N] fills the room
## with N (default HORDE_DEFAULT) live Chargers that chase the hero, topped back up as they die (at most
## HORDE_REFILL a tick, at fixed places round the hero), grants HORDE_CARDS (Twin, Split, Explosive, a burn, chain
## lightning, kills that explode and spread the fire; --cards= still overrides), turns the aim round the hero
## (a full turn every 256 ticks) and makes the hero unhurtable. It adds the per-view sync breakdown
## (WorldViewRoot.profile_sync) and per tick: enemies alive, hits, damage events, kills, status applies, damage
## numbers thrown, actors flashing, enemies drawing statuses, and the effects layer's merged and status lights and
## thinned pieces. The counts are deterministic (fixed seed, fixed input); the timings only rank the hot spots here
## (cloud machines are noisy): the frame target is measured on the owner's PC.
##   godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --horde --seconds=10
##   (writes build/perf/perf_probe_horde.txt; on a GPU machine drop --headless to include the draw in wall time)

const OUT_DIR := "res://build/perf"
const WARMUP_TICKS := 60
const TARGET_MS := 12.0
## v0.8.0 FV: the horde mode's enemies alive, top-ups a tick and build (real card ids from data/items).
const HORDE_DEFAULT := 110
const HORDE_REFILL := 8
const HORDE_CARDS: Array[StringName] = [
	&"gun_twin",
	&"split_shot",
	&"shared_explosive",
	&"cinder_shot",
	&"static_chain",
	&"ember_core",
	&"wildfire",
]

var _seconds := 10
var _twin := false
var _dummies := 6
var _level := 5
var _sim_only := false
## --cap=N: SimTuning.player_shots_max for this run (0: the shipped data/tuning/sim.tres).
var _cap := 0
## v0.8.0 BL: the weapon, the cards (empty: the default build) and the report's file tag.
var _weapon := &"gun"
var _cards: Array[StringName] = []
var _tag := ""
## v0.8.0 GF1: --on-aim puts the dummies on the aim line (4 m out, then 1.5 m apart), so one dummy takes every shot.
var _on_aim := false
## v0.8.0 FV: --horde's enemy count (0: off) and how many it has placed (its next spawn spot).
var _horde := 0
var _placed := 0
var _tally := DpsTally.new()
var _world: World
var _api: PlaygroundApi
var _reader: WorldReader
var _view: WorldViewRoot
var _procs: Array[Node] = []
## v0.8.0 FV: every node the probe has taken over (it turns them back on before each sync, so a view that turns its
## own nodes off, ActorViews' off-screen crowds, still decides which ones run; each runs once a tick).
var _adopted: Array[Node] = []
var _frame_in: InputFrame
var _tick_n := 0
var _total := 0
var _rows := {}  # metric -> Array of floats
var _keys := {}  # node instance id -> its report key
var _node_ms := {}  # class/name -> total ms over the measured ticks
var _report: PackedStringArray = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--twin":
			_twin = true
		elif a == "--sim-only":
			_sim_only = true
		elif a.begins_with("--seconds="):
			_seconds = int(a.get_slice("=", 1))
		elif a.begins_with("--dummies="):
			_dummies = int(a.get_slice("=", 1))
		elif a.begins_with("--level="):
			_level = int(a.get_slice("=", 1))
		elif a.begins_with("--cap="):
			_cap = int(a.get_slice("=", 1))
		elif a.begins_with("--weapon="):
			_weapon = StringName(a.get_slice("=", 1))
		elif a.begins_with("--cards="):
			for id in a.get_slice("=", 1).split(",", false):
				_cards.append(StringName(id))
		elif a == "--on-aim":
			_on_aim = true
		elif a.begins_with("--tag="):
			_tag = a.get_slice("=", 1)
		elif a == "--horde":
			_horde = HORDE_DEFAULT
		elif a.begins_with("--horde="):
			_horde = int(a.get_slice("=", 1))
	_total = WARMUP_TICKS + _seconds * 60
	var repo := ContentRepository.load_all()
	var run_def: RunDefinition = repo.get_def(&"run", &"three_floors")
	var biome: BiomeDefinition = repo.get_def(&"biomes", run_def.biomes[0])
	_world = PlaygroundScenario.build(repo, _weapon, biome)
	if _cap > 0 and &"player_shots_max" in _world.tuning:
		_world.tuning.set(&"player_shots_max", _cap)
	_api = PlaygroundApi.new(_world)
	_reader = WorldReader.new(_world)
	var cards: Array[StringName] = [&"gun_spread", &"split_shot", &"shared_explosive"]
	if _horde > 0:
		cards = HORDE_CARDS.duplicate()
		_api.god = true
		_dummies = 0
	if not _cards.is_empty():
		cards = _cards
	if _cards == [&"none"]:  # v0.8.0 GF1: the plain weapon, no cards (the Gun's base DPS)
		cards = []
	if _twin:
		cards.append(&"gun_twin")
	for id in cards:
		var ok := _api.grant_now(_item(id), _level)
		_line("grant %s L%d -> %s" % [id, _level, "ok" if ok else "FAILED"])
	var hero := _world.player_pos()
	for k in _dummies:
		var at := hero + Vector2(4.0 + 1.5 * (k / 3), -2.0 + 2.0 * (k % 3))
		if _weapon == &"blade":  # v0.8.0 BL: within a slash's reach
			at = hero + Vector2(1.4 + 0.9 * (k / 3), -1.0 + 1.0 * (k % 3))
		if _on_aim:
			at = hero + Vector2(4.0 + 1.5 * k, 0.0)  # the aim is angle 0 (+x)
		if not _api.place_dummy_now(at):
			_line("dummy %d at %s: no room" % [k, at])
	_horde_refill(_horde)
	_frame_in = InputFrame.make(Vector2i.ZERO, 0, 600, _button(), _button())
	if not _sim_only:
		_view = WorldViewRoot.new()
		_view.name = "WorldView"
		_view.stage.prop_style = biome.id
		_view.stage.mood = biome.mood
		_view.stage.look = biome.look
		if biome.look != null:
			_view.actors.enemy_tint = biome.look.enemy_tint
		root.add_child(_view)
		_view.profile_sync = _horde > 0
		var b := _reader.floor_bounds()
		var half := maxf(maxf(-b.position.x, b.end.x), maxf(-b.position.y, b.end.y))
		_view.setup(_reader, biome.palette, half + 4.0)
	_line(
		(
			"perf_probe: %s + %s, level %d, %d dummies, %d horde, %d s of %s (+%d warm-up ticks), %s"
			% [
				_weapon,
				", ".join(cards),
				_level,
				_dummies,
				_horde,
				_seconds,
				"Primary pressed" if _weapon == &"blade" else "held Shoot",
				WARMUP_TICKS,
				"sim only" if _sim_only else "sim + WorldView (headless: CPU side only)"
			]
		)
	)


## The attack button: the Gun's Shoot held, or the Blade's Primary pressed every tick (v0.8.0 BL).
func _button() -> int:
	return InputFrame.PRIMARY if _weapon == &"blade" else InputFrame.SHOOT


func _item(id: StringName) -> int:
	for k in _world.item_tables.size():
		if _world.item_tables[k].id == id:
			return k
	return -1


func _process(delta: float) -> bool:
	if _tick_n >= _total:
		_finish()
		return true
	var measured := _tick_n >= WARMUP_TICKS
	var t0 := Time.get_ticks_usec()
	_api.apply_pending()  # the endless dummies' refill, as SimDriver runs it before every tick
	_world.step(_frame_in)
	var t1 := Time.get_ticks_usec()
	var held := InputFrame.SHOOT if _weapon != &"blade" else 0
	var pressed := InputFrame.PRIMARY if _weapon == &"blade" else 0
	var aim := (_tick_n * 16) & 4095 if _horde > 0 else 0  # v0.8.0 FV: round the horde
	_frame_in = InputFrame.make(Vector2i.ZERO, aim, 600, held, pressed)
	if _horde > 0:  # topped up between ticks, outside the timed sim (as a wave's spawns would land)
		_horde_refill(HORDE_REFILL)
	if _tick_n == WARMUP_TICKS - 1:
		_tally.reset(_reader)  # v0.8.0 BL: the damage counted over the measured ticks only
	elif measured:
		_tally.observe(_reader)
	var sync_ms := 0.0
	var frame_ms := 0.0
	if _view != null:
		if _tick_n == WARMUP_TICKS:  # v0.8.0 FV: the per-view breakdown over the measured ticks only
			_view.sync_profile.clear()
		var live: Array[Node] = []
		for n in _adopted:  # v0.8.0 FV: back on, so ActorViews' sync can turn the far crowd off again
			if is_instance_valid(n):
				n.set_process(true)
				live.append(n)
		_adopted = live
		var t_sync := Time.get_ticks_usec()
		_view.sync()
		sync_ms = (Time.get_ticks_usec() - t_sync) / 1000.0
		# v0.8.0 FV: this tick's processing nodes only (before, a crowd avatar ActorViews turned back on was added
		# again every tick, so it ran once per tick it had been near: the frame cost grew with the run).
		_procs.clear()
		_adopt(_view)
		for n in _procs:
			if not is_instance_valid(n) or not n.is_inside_tree():
				continue
			var a := Time.get_ticks_usec()
			n.call(&"_process", delta)
			var ms := (Time.get_ticks_usec() - a) / 1000.0
			frame_ms += ms
			if measured:
				var key := _node_key(n)
				_node_ms[key] = float(_node_ms.get(key, 0.0)) + ms
	if measured:
		_add("sim_ms", (t1 - t0) / 1000.0)
		_add("sync_ms", sync_ms)
		_add("frame_ms", frame_ms)
		_add("total_ms", (t1 - t0) / 1000.0 + sync_ms + frame_ms)
		_count_tick()
	_tick_n += 1
	return false


## v0.8.0 FV: places Chargers round the hero until the horde is back to `_horde` alive, at most `most` now. Spots
## walk a golden-angle spiral between 3 m and the room's edge (deterministic); a blocked spot is skipped.
func _horde_refill(most: int) -> void:
	if _horde <= 0:
		return
	var b := _reader.floor_bounds()
	var hero := _world.player_pos()
	var reach := maxf(
		(
			minf(
				minf(hero.x - b.position.x, b.end.x - hero.x),
				minf(hero.y - b.position.y, b.end.y - hero.y)
			)
			- 1.0
		),
		4.0
	)
	var want := mini(_horde - _reader.enemies_alive(), most)
	var tries := 0
	while want > 0 and tries < most * 4:
		tries += 1
		_placed += 1
		var a := _placed * 2.39996
		var r := 3.0 + fposmod(_placed * 0.618034, 1.0) * (reach - 3.0)
		if _api.place_enemy_now(ActorStore.Kind.CHARGER, hero + Vector2(cos(a), sin(a)) * r):
			want -= 1


## Takes over the processing of every view node with a script _process (new ones too: avatars appear on a sync).
func _adopt(n: Node) -> void:
	if n.is_processing() and n.get_script() != null and n.has_method(&"_process"):
		n.set_process(false)
		_procs.append(n)
		if not n.has_meta(&"perf_probe_adopted"):
			n.set_meta(&"perf_probe_adopted", true)
			_adopted.append(n)
	for c in n.get_children():
		_adopt(c)


func _node_key(n: Node) -> String:
	var id := n.get_instance_id()
	if not _keys.has(id):
		_keys[id] = _key_of(n)
	return _keys[id]


static func _key_of(n: Node) -> String:
	var s: Script = n.get_script()
	var cls := s.get_global_name() if s != null else &""
	return String(cls) if cls != &"" else String(n.name)


func _count_tick() -> void:
	var live := 0
	for i in _reader.projectile_count():
		if _reader.projectile_team(i) == 0:
			live += 1
	_add("projectiles", live)
	var launches := _world.launch_count if _world.launch_tick == _world.tick - 1 else 0
	_add("launches", launches)
	_add("events", _world.last_event_seq() - _world.tick_seq0)
	if &"shot_tick" in _world:  # v0.8.0 PF's sim cap: 1 on a tick where a bolt found no room
		var capped: bool = (
			_world.get(&"shot_tick") == _world.tick - 1
			and int(_world.get(&"shot_count")) > _world.tuning.get(&"player_shots_max")
		)
		_add("shots_capped", 1.0 if capped else 0.0)
	var cut := 0.0  # v0.8.0 PF2: 1 on a tick where a capped attack's throw was cut short (AttackSpec.alive_max)
	var ring_cut := 0.0  # v0.8.0 AO: 1 on a tick where the ring cap held a launch back (WandRings.RINGS_MAX)
	var tally := {&"hits": 0, &"damage": 0, &"kills": 0, &"status_applies": 0, &"damage_numbers": 0}
	var player_id := _reader.actor_id(0)
	for e in _world.events_since(_world.tick_seq0):
		if e.kind == SimEvent.Kind.LIMIT and e.effect_id == Attacks.EFFECT_ALIVE_CAP:
			cut = 1.0
		if e.kind == SimEvent.Kind.LIMIT and e.effect_id == WandRings.EFFECT_RING_CAP:
			ring_cut = 1.0
		match e.kind:
			SimEvent.Kind.HIT:
				tally[&"hits"] += 1
			SimEvent.Kind.DAMAGE:
				tally[&"damage"] += 1
				# DamageNumbers' own filter: the player's non-DoT hits on others.
				if (
					e.owner_id == player_id
					and e.target_id != player_id
					and not (e.tags & SimEvent.TAG_DOT)
					and e.amount > 0
				):
					tally[&"damage_numbers"] += 1
			SimEvent.Kind.KILL:
				tally[&"kills"] += 1
			SimEvent.Kind.STATUS_APPLY:
				tally[&"status_applies"] += 1
	if _horde > 0:
		_add("enemies", _reader.enemies_alive())
		for k: StringName in tally:
			_add(String(k), tally[k])
	_add("alive_capped", cut)
	_add("rings", _world.ab.ring_pos.size())  # v0.8.0 AO: the rings alive (and waiting) this tick
	_add("rings_capped", ring_cut)
	if _view == null:
		return
	var vfx := _view.attack_forms.vfx
	if vfx == null:
		return
	for m: StringName in [&"bursts_asked", &"bursts_drawn", &"sprites_asked"]:
		if m in vfx:
			_add(String(m), vfx.get(m))
	var drawn := 0
	for id: StringName in vfx.pools:
		drawn += vfx.used(id)
	_add("sprites_drawn", drawn)
	if vfx.has_method(&"lights_asked"):
		_add("lights_asked", vfx.call(&"lights_asked"))
	_add("lights_on", vfx.lights_on())
	_add("decals", vfx.marks())
	_add("form_effects", _view.attack_forms.effect_count())
	_add("form_meshes", _view.attack_forms.meshes_drawn())
	if _horde > 0:  # v0.8.0 FV
		for m: StringName in [
			&"lights_merged", &"status_lights_asked", &"status_lights_dropped", &"pieces_thinned"
		]:
			if m in vfx:
				_add(String(m), vfx.get(m))
		_add("flashing", (_view.actors.get(&"_flash") as Dictionary).size())
		_add("status_drawn", (_view.status_fx.get(&"_on") as Dictionary).size())


func _add(metric: String, v: float) -> void:
	if not _rows.has(metric):
		_rows[metric] = []
	(_rows[metric] as Array).append(v)


func _finish() -> void:
	_line("metric          avg       p95       max")
	for m: String in _rows:
		var a: Array = _rows[m]
		var sorted := a.duplicate()
		sorted.sort()
		var sum := 0.0
		for v: float in a:
			sum += v
		var p95: float = sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))]
		_line(
			(
				"%-14s %8.3f  %8.3f  %8.3f"
				% [m, sum / maxf(a.size(), 1), p95, sorted[sorted.size() - 1]]
			)
		)
	if not _node_ms.is_empty():
		var n := float((_rows["sim_ms"] as Array).size())
		var keys := _node_ms.keys()
		keys.sort_custom(func(x: String, y: String) -> bool: return _node_ms[x] > _node_ms[y])
		_line("frame cost by node (ms per tick, avg):")
		for k in keys.slice(0, 12):
			_line("  %-24s %8.3f" % [k, float(_node_ms[k]) / n])
	if _view != null and not _view.sync_profile.is_empty():  # v0.8.0 FV: --horde
		var n := float((_rows["sim_ms"] as Array).size())
		var prof: Dictionary = _view.sync_profile
		var keys := prof.keys()
		keys.sort_custom(func(x: StringName, y: StringName) -> bool: return prof[x] > prof[y])
		_line("sync cost by view (ms per tick, avg):")
		for k in keys.slice(0, 12):
			_line("  %-24s %8.3f" % [k, float(prof[k]) / n])
	var now := _world.tick - 1
	var secs := float(_total - WARMUP_TICKS) / SimTick.TICKS_PER_SECOND
	var dps := float(_tally.total) / maxf(secs, 0.001)
	_line(
		(
			"damage: %d over %.1f s -> %.1f per s (%.1f per s per dummy; DpsTally overall %.1f)"
			% [_tally.total, secs, dps, dps / maxf(_dummies, 1), _tally.dps_overall(now)]
		)
	)
	var ranked := _tally.ranked()
	for pair: Array in ranked.slice(0, 8):
		_line(
			"  %-24s %10d  %5.1f %%" % [pair[0], pair[1], 100.0 * pair[1] / maxf(_tally.total, 1)]
		)
	var total: Array = _rows["total_ms"]
	var sum := 0.0
	for v: float in total:
		sum += v
	var avg := sum / maxf(total.size(), 1)
	_line(
		(
			"verdict: avg %.2f ms per tick+frame against %.1f ms -> %s"
			% [avg, TARGET_MS, "within" if avg <= TARGET_MS else "OVER"]
		)
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var tag := "twin" if _twin else ("horde" if _horde > 0 else "base")
	if _tag != "":
		tag = _tag
	if _sim_only:
		tag += "_sim"
	var f := FileAccess.open(OUT_DIR + "/perf_probe_%s.txt" % tag, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_report) + "\n")
	if _view != null:
		_view.queue_free()
	quit(0)


func _line(s: String) -> void:
	print(s)
	_report.append(s)
