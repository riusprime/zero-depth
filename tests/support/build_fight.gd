class_name BuildFight
extends RefCounted
## v0.8.0 BV (owner O91: "Compare multiplication, charged-hit, remnant-control, returning-attack and status builds
## using reproducible combat scenarios. Track damage, projectile rate, proc rate and time-to-kill; distinguish 60
## projectiles/sec from 60 weapon casts/sec"; docs/roadmap/v0.8.0/BALANCE_PASS.md "BV: validation"): one scripted
## fight of a build, headless at 60 Hz. Shared by scripts/checks/build_fights.gd and
## tests/unit/application/test_balance_tools.gd.
##
## The arena: the Playground's World (PlaygroundScenario: one walled 4 x 4-cell room, floor 1's tables, every wand slot,
## no spawning, rewards or catch-up), the hero unhurtable (PlaygroundApi.god; the dummies never shoot anyway).
## - PACK: 12 dummies (PlaygroundApi.place_dummy_now) of `pack_hp` each (default: the Charger's floor-1 HP) in a fixed
##   4 x 3 grid ahead of the hero (Gun: 4.5-8.1 m out, 1.2 m apart; Blade: 1.6-4.3 m out, 0.9 m apart). A dead one
##   comes back at its spot RESPAWN_TICKS later, so on-kill effects keep counting; the pack's time to kill is the tick
##   the 12 first dummies are all dead. The reference fight for "exceptional" (DPS over the whole fight).
## - BOSS: one dummy of `boss_hp` (default: World.boss_tables[0]'s HP, a floor-1 boss without scaling) 5 m (Gun) or
##   1.6 m (Blade) ahead: single-target DPS and its time to kill, or none within the fight.
## The hero's input (one InputFrame a tick): the aim at the nearest live dummy; the Gun holds Shoot and stands still;
## the Blade presses Primary every tick and walks toward the nearest dummy (its facing, which a slash follows, points
## at it). With `dash`: a dash every DASH_EVERY ticks (the Gun strafes left/right, the Blade dashes at the target).
## Counted from the event stream and the world each tick:
## - damage: every DAMAGE event the player owns on another body (DpsTally, the Playground's meter);
## - casts: weapon casts (Gun: a tick where shot_cd was set back to the period, PlayerKit/GunForms fire: it rose, or
##   stayed 1 for a 1-tick period; Blade: a new swing_root);
## - projectiles: player projectiles that appeared this tick (a projectile id not alive the tick before: one born and
##   gone inside one tick is missed); peak: most player projectiles alive at once;
## - procs: status applications (STATUS_APPLY), remnant activations (REMNANT_ACTIVATE) and child hits (HIT events at
##   depth >= 1: trigger casts', hooks' and repeats' hits); LIMIT events by effect id (launch cap, alive cap, rings).

enum Mode { PACK, BOSS }

const RESPAWN_TICKS := 60
const DASH_EVERY := 90
const PACK_COLS := 4
const PACK_ROWS := 3

## The named builds: weapon, cards (wand order), and whether the hero dashes. The five archetypes (BALANCE_PASS.md
## "BV"), Twin/Echo/attack-speed singles, Dodge Imprint, and a plain weapon each.
const BUILDS := {
	"gun_baseline": [&"gun", [], false],
	"blade_baseline": [&"blade", [], false],
	# v0.9.0 TW: Split in the retired Spread's place.
	"gun_multiplication": [&"gun", [&"gun_twin", &"split_shot", &"halo_shot"], false],
	"blade_multiplication": [&"blade", [&"echo_slash", &"double_slash", &"split_wave"], false],
	"gun_charged": [&"gun", [&"gun_charge", &"gun_big_shot"], false],
	"blade_charged": [&"blade", [&"heavy"], false],
	"gun_remnant":
	[
		&"gun",
		[&"shared_faultline", &"shared_gravity_stitch", &"shared_stress_mark", &"mut_grand_finale"],
		false
	],
	"blade_remnant":
	[&"blade", [&"shared_faultline", &"shared_stress_mark", &"mut_grand_finale"], false],
	"gun_returning": [&"gun", [&"boomerang"], false],
	"blade_returning": [&"blade", [&"blade_storm"], false],
	"gun_status": [&"gun", [&"ember_core", &"frost_core", &"venom_core"], false],
	"blade_status": [&"blade", [&"ember_core", &"frost_core", &"venom_core"], false],
	"gun_twin": [&"gun", [&"gun_twin"], false],
	"gun_echo": [&"gun", [&"gun_echo"], false],
	"gun_rapid_fire": [&"gun", [&"gun_rapid_fire"], false],
	"blade_flurry": [&"blade", [&"flurry"], false],
	"blade_dodge_imprint": [&"blade", [&"long_shadow", &"echo_slash"], true],
}
## The order build_fights.gd runs them in.
const ORDER: Array[String] = [
	"gun_baseline",
	"gun_multiplication",
	"gun_charged",
	"gun_remnant",
	"gun_returning",
	"gun_status",
	"gun_twin",
	"gun_echo",
	"gun_rapid_fire",
	"blade_baseline",
	"blade_multiplication",
	"blade_charged",
	"blade_remnant",
	"blade_returning",
	"blade_status",
	"blade_flurry",
	"blade_dodge_imprint",
]

var pack_hp := 0
var boss_hp := 0

var _repo: ContentRepository
var _biome: BiomeDefinition


func _init(repo: ContentRepository) -> void:
	_repo = repo
	var run_def: RunDefinition = repo.get_def(&"run", RunSaver.RUN_ID)
	_biome = repo.get_def(&"biomes", run_def.biomes[0])


## Named build `name` at `level` as tokens ("m:<id>:<level>", LootSampler.tokens' form).
static func named_tokens(name: String, level: int) -> PackedStringArray:
	var out := PackedStringArray()
	for id: StringName in BUILDS[name][1]:
		out.append("m:%s:%d" % [id, level])
	return out


## One fight (class doc). `tokens`: the build (LootSampler.tokens' form). Returns the counts, the catch-up read and the
## world's final hash; "missing" lists the tokens that could not be granted.
func fight(
	weapon: StringName, tokens: PackedStringArray, mode: int, seconds: float, dash: bool = false
) -> Dictionary:
	var w := PlaygroundScenario.build(_repo, weapon, _biome)
	var api := PlaygroundApi.new(w)
	api.god = true
	var reader := WorldReader.new(w)
	var out := {"missing": grant_tokens(w, api, tokens)}
	out.merge(catch_up(w))
	var hero := w.player_pos()
	var blade := weapon == &"blade"
	var spots := PackedVector2Array()
	var hp := pack_hp if pack_hp > 0 else w.enemy_table(ActorStore.Kind.CHARGER).hp
	if mode == Mode.BOSS:
		hp = boss_hp if boss_hp > 0 else w.boss_tables[0].hp
		spots.append(hero + (Vector2(1.6, 0.0) if blade else Vector2(5.0, 0.0)))
	else:
		for k in PACK_COLS * PACK_ROWS:
			var col := k / PACK_ROWS
			var row := k % PACK_ROWS
			if blade:
				spots.append(hero + Vector2(1.6 + 0.9 * col, -0.9 + 0.9 * row))
			else:
				spots.append(hero + Vector2(4.5 + 1.2 * col, -1.2 + 1.2 * row))
	var live := PackedInt32Array()  # the dummy id at each spot (-1: none placed)
	var dead_at := PackedInt32Array()
	var first := {}  # the first wave's ids still alive
	for at in spots:
		var ok := api.place_dummy_now(at, hp)
		var id := w.actors.ids[w.actors.size() - 1] if ok else -1
		live.append(id)
		dead_at.append(-1)
		if id >= 0:
			first[id] = true
	out["placed"] = first.size()
	out["hp"] = hp
	var tally := DpsTally.new()
	var c := {
		"casts": 0,
		"projectiles": 0,
		"peak": 0,
		"status": 0,
		"remnant": 0,
		"child_hits": 0,
		"kills": 0,
		"limits": {},
	}
	var seen_proj := {}
	var ttk := -1
	var total := int(round(seconds * SimTick.TICKS_PER_SECOND))
	var last_seq := w.last_event_seq()
	var frame := _input(w, reader, blade, dash, 0)
	for t in total:
		var cd := w.shot_cd
		var root := w.swing_root
		api.apply_pending()
		w.step(frame)
		if blade:
			c["casts"] += 1 if w.swing_root != root else 0
		elif w.shot_cd > cd or (cd == 1 and w.shot_cd == 1):  # set to the period (>= 1) after it ran out
			c["casts"] += 1
		var now_proj := {}
		for i in reader.projectile_count():
			if reader.projectile_team(i) != 0:
				continue
			var pid := reader.projectile_id(i)
			now_proj[pid] = true
			if not seen_proj.has(pid):
				c["projectiles"] += 1
		seen_proj = now_proj
		c["peak"] = maxi(c["peak"], now_proj.size())
		for e in w.events_since(last_seq):
			last_seq = e.seq
			match e.kind:
				SimEvent.Kind.STATUS_APPLY:
					c["status"] += 1
				SimEvent.Kind.REMNANT_ACTIVATE:
					c["remnant"] += 1
				SimEvent.Kind.HIT:
					c["child_hits"] += 1 if e.depth > 0 else 0
				SimEvent.Kind.KILL:
					c["kills"] += 1
					first.erase(e.target_id)
				SimEvent.Kind.LIMIT:
					var lim: Dictionary = c["limits"]
					lim[String(e.effect_id)] = int(lim.get(String(e.effect_id), 0)) + 1
		tally.observe(reader)
		if ttk < 0 and not first.is_empty():
			var any := false
			for id: int in first:
				var i := reader.actor_index(id)
				any = any or (i >= 0 and not reader.actor_dead(i))
			if not any:
				first.clear()
		if ttk < 0 and first.is_empty() and out["placed"] > 0:
			ttk = t + 1
			if mode == Mode.BOSS:
				break
		if mode == Mode.PACK:
			_respawn(w, api, reader, spots, live, dead_at, hp)
		frame = _input(w, reader, blade, dash, t + 1)
	var ticks := maxi(1, w.tick)
	out.merge(c)
	out["ticks"] = ticks
	out["damage"] = tally.total
	out["dps"] = float(tally.total) * SimTick.TICKS_PER_SECOND / ticks
	out["ttk_ticks"] = ttk
	out["sources"] = tally.by_source
	out["hash"] = w.state_hash()
	return out


## Grants `tokens` in order (PlaygroundApi.grant_now: as a found card, then its level). Returns those that failed.
static func grant_tokens(
	w: World, api: PlaygroundApi, tokens: PackedStringArray
) -> PackedStringArray:
	var missing := PackedStringArray()
	for tok in tokens:
		var p := tok.split(":")
		var ok := false
		if p.size() >= 2 and p[0] == "s":
			ok = api.grant_now(int(p[1]))
		elif p.size() >= 3 and p[0] == "m":
			var idx := _item(w, StringName(p[1]))
			ok = idx >= 0 and not w.item_tables[idx].retired and api.grant_now(idx, int(p[2]))
		elif p.size() >= 3 and p[0] == "a":
			var a := _ability(w, StringName(p[1]))
			ok = a >= 0 and api.grant_now(Offers.ability_code(a), int(p[2]))
		if not ok:
			missing.append(tok)
	return missing


## The build's hidden catch-up (CatchUp, data/scaling/catch_up.tres) as if it were held on floors 1-3 of loop 1 at
## threat 0: P, the floor's enemy multiplier m and the boss's (per mille). The table is set only for the read.
func catch_up(w: World) -> Dictionary:
	var t := ContentCompiler.compile_catch_up(_repo.get_def(&"scaling", &"catch_up"))
	w.catch_up_table = t
	var p := CatchUp.power(w)
	w.catch_up_table = null
	var m := PackedInt32Array()
	var mb := PackedInt32Array()
	for f in range(1, 4):
		var e := CatchUpTable.at_floor(t.expected_permille, f)
		m.append(CatchUp.multiplier(p, e, CatchUp.cap_at(t.cap_permille, t, f, 0)))
		var be := CatchUpTable.at_floor(t.boss_expected_permille, f)
		mb.append(CatchUp.multiplier(p, be, CatchUp.cap_at(t.boss_cap_permille, t, f, 0)))
	return {"p": p, "m": m, "m_boss": mb}


## The next tick's input (class doc).
static func _input(w: World, reader: WorldReader, blade: bool, dash: bool, t: int) -> InputFrame:
	var hero := w.player_pos()
	var target := _nearest(reader, hero)
	var to := (target - hero) if target != Vector2.INF else Vector2.RIGHT
	var aim := Kin.angle_of(to)
	var dist := int(clampf(to.length() * 100.0, 0.0, SimTick.AIM_DIST_MAX_CM))
	var move := Vector2i.ZERO
	var held := 0 if blade else InputFrame.SHOOT
	var pressed := InputFrame.PRIMARY if blade else 0
	if blade and target != Vector2.INF:
		var d := to.normalized()
		move = Vector2i(roundi(d.x * 127.0), roundi(d.y * 127.0))
	if dash and t % DASH_EVERY == DASH_EVERY / 2:
		pressed |= InputFrame.DASH
		if not blade:
			var side := (
				Vector2(-to.y, to.x).normalized() * (1.0 if (t / DASH_EVERY) % 2 == 0 else -1.0)
			)
			move = Vector2i(roundi(side.x * 127.0), roundi(side.y * 127.0))
	return InputFrame.make(move, aim, dist, held, pressed)


## The nearest live non-player body's position, or Vector2.INF.
static func _nearest(reader: WorldReader, hero: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for i in range(1, reader.actor_count()):
		if reader.actor_dead(i) or reader.actor_team(i) == reader.actor_team(0):
			continue
		var d := (reader.actor_pos(i) - hero).length_squared()
		if d < best_d:
			best_d = d
			best = reader.actor_pos(i)
	return best


## A pack dummy dead for RESPAWN_TICKS comes back at its spot (a new dummy of the same HP).
static func _respawn(
	w: World,
	api: PlaygroundApi,
	reader: WorldReader,
	spots: PackedVector2Array,
	live: PackedInt32Array,
	dead_at: PackedInt32Array,
	hp: int
) -> void:
	for k in spots.size():
		if live[k] < 0:
			continue
		var i := reader.actor_index(live[k])
		if i >= 0 and not reader.actor_dead(i):
			continue
		if dead_at[k] < 0:
			dead_at[k] = w.tick
		elif w.tick - dead_at[k] >= RESPAWN_TICKS and api.place_dummy_now(spots[k], hp):
			live[k] = w.actors.ids[w.actors.size() - 1]
			dead_at[k] = -1


static func _item(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


static func _ability(w: World, id: StringName) -> int:
	for k in w.ability_tables.size():
		if w.ability_tables[k].id == id:
			return k
	return -1
