extends GutTest
## A scripted player kills each boss within a time band (PLAN v0.3.0 C: aim for a 60-120 s fight for a player with a
## few items). The bot has no items and never stops shooting: it holds 5 m from the boss, aims at it and fires every
## shot period (the player's starting kit: 4 damage per 0.12 s, about 33 per second). Its HP is raised so it lives to
## the end; only the time is measured. A real player keeps up far less than 100% of this (dodging, repositioning),
## so the bot's time is a floor: the band below is the perfect-uptime band, 30-90 s.

const BAND_MIN_S := 30.0
const BAND_MAX_S := 90.0
const LIMIT_TICKS := 60 * 240


## Ticks for the bot to kill boss `id` (seeded), or -1 if it didn't within LIMIT_TICKS.
static func fight(id: StringName, seed_value: int = 5) -> int:
	var w := BossLab.world(seed_value)
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000
	var bid := w.spawn_boss(BossLab.table_index(w, id), Vector2(9, 0))
	for t in LIMIT_TICKS:
		var i := w.actors.index_of(bid)
		if i < 0:
			return t
		var to := w.actors.pos(i) - w.player_pos()
		var dist := Kin.length(to)
		var mv := Vector2i.ZERO
		if dist > 0.001:
			var dir := to / dist
			if dist > 6.0:
				mv = Vector2i(roundi(dir.x * 127.0), roundi(dir.y * 127.0))
			elif dist < 4.0:
				mv = Vector2i(roundi(-dir.x * 127.0), roundi(-dir.y * 127.0))
		w.step(InputFrame.make(mv, Kin.angle_of(to), int(dist * 100.0), InputFrame.SHOOT, 0))
	return -1


func test_each_boss_falls_to_a_steady_shooter_within_the_band() -> void:
	for id: StringName in [&"gatekeeper", &"brood_mother", &"siege_engine"]:
		var ticks := fight(id)
		var secs := float(ticks) / SimTick.TICKS_PER_SECOND
		print("BOSSFIGHT| %s ticks=%d seconds=%.1f" % [id, ticks, secs])
		assert_gt(ticks, 0, "%s dies" % id)
		assert_between(secs, BAND_MIN_S, BAND_MAX_S, "%s: %.1f s" % [id, secs])
