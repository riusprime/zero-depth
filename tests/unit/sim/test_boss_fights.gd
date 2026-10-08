extends GutTest
## A scripted player can damage and kill each boss, and kiting from afar meets the boss's answers (v0.3.0 BX, L17;
## v0.3.5 AI). Three scripted drivers, none with items, each with its HP raised so it lives to the end, each playing
## one starting build:
## - melee: walks to the boss and keeps pressing the swing (the four-slash combo) from up close, with a light push
##   toward the boss so it keeps facing it (melee goes the way the character faces, L29);
## - ranged near: holds 4-6 m from the boss's centre and keeps shooting;
## - ranged far: holds 9.5-10.5 m from the boss's edge (the far end of a bolt's range) and keeps shooting.
## v0.5.5 EC (owner P1, "not run bot tests, because they do not represent reality"): the fight-length bands
## (25-90 s melee, 25-120 s near) and the "far is 1.5x slower" ratio are gone; only the mechanics stay: the boss
## takes the hits and dies, far hits are deflected, and staying far is punished.

enum Bot { MELEE, RANGED_NEAR, RANGED_FAR }

const LIMIT_TICKS := 60 * 600
## v0.4.0 BO: the second boss of each pool (Warlord, Hive Lens, Foundry) too.
const BOSSES: Array[StringName] = [
	&"gatekeeper", &"brood_mother", &"siege_engine", &"warlord", &"hive_lens", &"foundry"
]


## Ticks for `bot` to kill boss `id` (seeded), or -1 if it didn't within LIMIT_TICKS. stats (optional) gets the hits
## that landed and how many were deflected (ranged armour) or struck the open weak point.
static func fight(id: StringName, bot: int, seed_value: int = 5, stats: Dictionary = {}) -> int:
	var w := BossLab.world(seed_value)
	var build: BuildDefinition = ContentRepository.load_all().get_def(
		&"build", &"blade" if bot == Bot.MELEE else &"gun"
	)
	ContentCompiler.apply_build(w.player, build)
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000
	var bid := w.spawn_boss(BossLab.table_index(w, id), Vector2(9, 0))
	var seq := 0
	for k in ["hits", "deflected", "exposed", "punished", "gap_closed"]:
		stats[k] = 0
	var punish := BossAi.table_of(w, w.actors.index_of(bid)).punish_attack
	var gap := BossAi.table_of(w, w.actors.index_of(bid)).gap_attack
	for t in LIMIT_TICKS:
		var i := w.actors.index_of(bid)
		if i < 0:
			return t
		var b := BossAi.entry_of(w, i)
		if w.actors.state[i] == EnemyAi.State.WINDUP and w.actors.state_t[i] == 1:
			if w.bosses.attack[b] == punish and w.bosses.step[b] == 0:
				stats["punished"] += 1
		# v0.3.5 AI (F3): the gap-closer, due this tick (the player out of reach for its time).
		var t_b := BossAi.table_of(w, i)
		var closing: bool = (
			w.actors.state[i] == EnemyAi.State.MOVE and w.bosses.gap_t[b] >= t_b.gap_ticks - 1
		)
		w.step(_frame(w, i, bot, t))
		i = w.actors.index_of(bid)
		if closing and i >= 0 and w.actors.state[i] == EnemyAi.State.WINDUP:
			if w.bosses.attack[BossAi.entry_of(w, i)] == gap:
				stats["gap_closed"] += 1
		for e in w.events_since(seq):
			seq = e.seq
			if e.kind == SimEvent.Kind.HIT and e.target_id == bid:
				stats["hits"] += 1
				if e.tags & SimEvent.TAG_DEFLECTED:
					stats["deflected"] += 1
				if e.tags & SimEvent.TAG_EXPOSED:
					stats["exposed"] += 1
	return -1


## The bot's input this tick: walk to its distance band around the boss, aim at it, attack.
static func _frame(w: World, i: int, bot: int, t: int) -> InputFrame:
	var to := w.actors.pos(i) - w.player_pos()
	var dist := Kin.length(to)
	var edge := dist - w.actors.radius[i]
	var near := 4.0
	var far := 6.0
	var held := InputFrame.SHOOT
	var pressed := 0
	match bot:
		Bot.MELEE:
			near = -99.0
			far = w.actors.radius[i] + 1.2
			held = 0
			pressed = InputFrame.PRIMARY if t % 6 == 0 else 0
		Bot.RANGED_FAR:
			near = w.actors.radius[i] + 9.5
			far = w.actors.radius[i] + 10.5
	var mv := Vector2i.ZERO
	if dist > 0.001:
		var dir := to / dist
		if dist > far:
			mv = Vector2i(roundi(dir.x * 127.0), roundi(dir.y * 127.0))
		elif dist < near:
			mv = Vector2i(roundi(-dir.x * 127.0), roundi(-dir.y * 127.0))
	if bot == Bot.MELEE and mv == Vector2i.ZERO and dist > 0.001:
		mv = Vector2i(roundi(to.x / dist * 40.0), roundi(to.y / dist * 40.0))  # keep facing the boss (L29)
	if edge < -50.0:
		mv = Vector2i.ZERO
	return InputFrame.make(mv, Kin.angle_of(to), int(dist * 100.0), held, pressed)


func test_melee_and_near_shooting_kill_every_boss() -> void:
	for id: StringName in BOSSES:
		for bot in [Bot.MELEE, Bot.RANGED_NEAR]:
			var s := {}
			var ticks := fight(id, bot, 5, s)
			var secs := float(ticks) / SimTick.TICKS_PER_SECOND
			print(
				(
					"BOSSFIGHT| %s %s ticks=%d seconds=%.1f hits=%d deflected=%d exposed=%d punished=%d"
					% [id, Bot.keys()[bot], ticks, secs, s.hits, s.deflected, s.exposed, s.punished]
				)
			)
			assert_gt(ticks, 0, "%s dies" % id)
			assert_gt(s.hits, 0, "%s takes hits" % id)


func test_kiting_from_afar_is_deflected_and_punished() -> void:
	for id: StringName in BOSSES:
		var s := {}
		var far := fight(id, Bot.RANGED_FAR, 5, s)
		print(
			(
				(
					"BOSSFIGHT| %s RANGED_FAR ticks=%d seconds=%.1f hits=%d deflected=%d punished=%d"
					+ " gap_closed=%d"
				)
				% [id, far, far / 60.0, s.hits, s.deflected, s.punished, s.gap_closed]
			)
		)
		assert_gt(s.deflected, 0, "%s: far hits are deflected" % id)
		# v0.3.5 AI (F3): the gap-closer (2 s out of reach) now usually answers a kiter before the punish (4 s far).
		assert_gt(s.punished + s.gap_closed, 0, "%s: staying far is punished" % id)
