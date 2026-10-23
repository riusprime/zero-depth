extends GutTest
## v0.9.0 SH, HF (owner Q29b: "Today's gamble shrine becomes the Fortune Shrine; Blood and Chaos shrines are added (at
## most one shrine a floor, costs shown first; the Chaos challenge may bring an elite, a designed exception). Healing
## fountains (rare, one use)"; W36): the sim side of the shrines and the fountain.
## - Placement over SEEDS run seeds x floors 1-5, built as Main builds them (ShrineLab): at most one shrine a floor;
##   the kinds' shares and the fountains' rate printed (SH_PLACEMENT); the shrine and the fountain never in a Lockdown,
##   arena, secret, purple, shop, curse, event, Overrun, boss (or its host), portal or start room; never a fountain on
##   floor 1, never two, never in the shrine's room, never on a reward.
## - Blood: its price is a share of current HP shown before the press, never lethal (every HP from 1 to max), refused
##   when too low; paid once it raises a free altar. Chaos: the press spawns the floor's challenge in the room; once
##   all are down a free altar rises (no elite: EL's hook is 0). Fortune: the gamble shrine, unchanged. The fountain
##   heals once (40 % of max HP), then is dry; at full HP it refuses. The prompts name the cost.
## - Snapshot and hash: a save mid-challenge resumes exactly; the state is hashed. A floor saved under rules <= 13 has
##   no Blood or Chaos shrine and no fountain (its shrine is the gamble shrine, Fortune).

const SEEDS := 40


func test_placement_over_many_seeds() -> void:
	var bad := 0
	var lines := PackedStringArray()
	var all_kinds := [0, 0, 0]
	for floor_index in range(1, 6):
		var kinds := [0, 0, 0]
		var sites := 0
		var fountains := 0
		var both := 0
		for s in SEEDS:
			var w := ShrineLab.floor_world(1 + s * 37, floor_index)
			var f := w.floor_layout
			var never := [
				f.start_room, f.boss_room, f.boss_host_room, f.portal_room, f.overrun_room
			]
			never.append_array([f.curse_room, f.purple_room, f.shop_room, Routes.shop_room_of(f)])
			# (a secret's host is an ordinary room the secret opens from: a shrine may stand there, as before)
			never.append_array([f.timed_room, f.rune_room, f.crack_room])
			never.append_array(Array(f.lockdown_rooms))
			never.append_array(Array(f.arena_rooms))
			for k in w.ev.ids.size():
				never.append(w.ev.room[k])
			var shrine_room := -1
			if w.gamble_id >= 0:
				sites += 1
				var kind := Shrines.kind_of(w)
				kinds[kind] += 1
				shrine_room = f.room_of(w.gamble_pos)
				var fortune := Gamble.present(w)
				var other := w.shrine != null and w.shrine.has_shrine()
				if fortune == other:
					bad += 1
					gut.p("seed %d floor %d: not exactly one shrine" % [s, floor_index])
				if shrine_room in never:
					bad += 1
					gut.p(
						(
							"seed %d floor %d: shrine in forbidden room %d"
							% [s, floor_index, shrine_room]
						)
					)
			elif w.shrine != null and w.shrine.has_shrine():
				bad += 1
			if w.shrine != null and w.shrine.has_fountain():
				fountains += 1
				var at := w.shrine.fountain_pos
				var room := f.room_of(at)
				if floor_index == 1 or room in never or room == shrine_room or room < 0:
					bad += 1
					gut.p("seed %d floor %d: fountain in room %d" % [s, floor_index, room])
				for i in w.rewards.size():
					if w.rewards.pos(i).distance_to(at) < 1.5:
						bad += 1
						gut.p("seed %d floor %d: fountain on a reward" % [s, floor_index])
				if shrine_room >= 0:
					both += 1
			var entries := 0
			for i in w.interactables.size():
				if w.interactables.kind[i] == Interactables.Kind.FOUNTAIN:
					entries += 1
			if entries > 1:
				bad += 1
		for k in 3:
			all_kinds[k] += kinds[k]
		(
			lines
			. append(
				(
					"SH_PLACEMENT| floor=%d seeds=%d shrines=%d fortune=%d blood=%d chaos=%d fountains=%d with_both=%d"
					% [floor_index, SEEDS, sites, kinds[0], kinds[1], kinds[2], fountains, both]
				)
			)
		)
		if floor_index == 1:
			assert_eq(fountains, 0, "no fountain on floor 1")
		else:
			assert_between(
				fountains, SEEDS * 8 / 100, SEEDS * 45 / 100, "rare: about 25 %% a floor"
			)
	for l in lines:
		gut.p(l)
	var total: int = all_kinds[0] + all_kinds[1] + all_kinds[2]
	gut.p(
		(
			"SH_KINDS| shrines=%d fortune=%d blood=%d chaos=%d"
			% [total, all_kinds[0], all_kinds[1], all_kinds[2]]
		)
	)
	for k in 3:  # data weights 400 / 300 / 300
		assert_gt(all_kinds[k] * 100, total * 15, "kind %d is drawn (its share)" % k)
		assert_lt(all_kinds[k] * 100, total * 55, "kind %d is not every shrine" % k)
	assert_eq(bad, 0, "every floor follows the placement rules")


func _blood() -> World:
	var w := ShrineLab.with_kind(ShrineTable.Kind.BLOOD)
	assert_not_null(w, "a Blood shrine within 80 seeds")
	return w


func test_blood_shows_its_cost_and_pays_once() -> void:
	var w := _blood()
	if w == null:
		return
	assert_false(Gamble.present(w), "the gamble shrine is not there")
	ShrineLab.stand_by(w, w.shrine.pos)
	var reader := WorldReader.new(w)
	var hp := w.actors.hp[0]
	var cost := (hp * 300 + 999) / 1000
	assert_eq(reader.interact_prompt_key(), &"SHRINE_BLOOD_PROMPT", "the prompt names the price")
	assert_eq(reader.interact_prompt_args(), [cost], "30 %% of current HP, rounded up")
	var rewards := w.rewards.size()
	ShrineLab.press(w)
	assert_eq(w.actors.hp[0], hp - cost, "paid in HP")
	assert_eq(w.shrine.paid, cost)
	assert_eq(w.rewards.size(), rewards + 1, "a free altar rose")
	var k := w.rewards.size() - 1
	assert_eq(w.rewards.kind[k], RewardStore.Kind.ALTAR)
	assert_eq(w.rewards.price[k], 0, "free")
	assert_gte(
		w.rewards.pos(k).distance_to(w.shrine.pos), Shrines.REWARD_GAP_M - 0.001, "beside it"
	)
	assert_eq(reader.interact_prompt_key(), &"", "spent: no prompt")
	var after := w.actors.hp[0]
	ShrineLab.press(w)
	assert_eq(w.actors.hp[0], after, "one use")


func test_blood_is_never_lethal_and_refuses_when_too_low() -> void:
	var w := _blood()
	if w == null:
		return
	var top := w.actors.max_hp[0]
	var low := Shrines.blood_min_hp(w)
	for hp in range(1, top + 1):
		w.actors.hp[0] = hp
		var c := Shrines.blood_cost(w)
		assert_true(c == 0 or hp - c >= 1, "HP %d: never below 1 (price %d)" % [hp, c])
		if hp * 1000 < top * 250:
			assert_eq(c, 0, "HP %d of %d: too weak, refused" % [hp, top])
	ShrineLab.stand_by(w, w.shrine.pos)
	w.actors.hp[0] = low - 1
	var reader := WorldReader.new(w)
	assert_eq(reader.interact_prompt_key(), &"SHRINE_BLOOD_LOW", "the prompt says why")
	assert_eq(reader.interact_prompt_args(), [low], "and how much HP it needs")
	ShrineLab.press(w)
	assert_eq(w.actors.hp[0], low - 1, "nothing taken")
	assert_eq(w.shrine.denied_tick, w.tick - 1, "the refusal is recorded")
	assert_eq(w.shrine.used_tick, -1, "and it stays")


func test_chaos_spawns_its_challenge_and_clearing_it_rewards() -> void:
	var w := ShrineLab.with_kind(ShrineTable.Kind.CHAOS)
	assert_not_null(w, "a Chaos shrine within 80 seeds")
	if w == null:
		return
	ShrineLab.stand_by(w, w.shrine.pos)
	var reader := WorldReader.new(w)
	var size := w.shrine.table.chaos_size(w.floor_index)
	assert_eq(reader.interact_prompt_key(), &"SHRINE_CHAOS_PROMPT")
	assert_eq(reader.interact_prompt_args(), [size], "the prompt names the challenge")
	var rewards := w.rewards.size()
	w.shrine.table.chaos_elite_permille = 0  # v0.9.0 EL: the plain challenge (its elite: the test below)
	ShrineLab.press(w)
	var s := w.shrine
	assert_eq(s.chaos_phase, 1, "the challenge began")
	assert_eq(s.members.size(), size, "the floor's challenge size")
	var room := w.floor_layout.room_of(s.pos)
	for id in s.members:
		var i := w.actors.index_of(id)
		assert_eq(w.floor_layout.room_of(w.actors.pos(i)), room, "spawned in the shrine's room")
		assert_true(
			w.spawner.kinds.has(w.actors.kinds[i]), "a horde kind (the elite's chance set to 0)"
		)
	assert_eq(w.rewards.size(), rewards, "no reward yet")
	for k in 10:
		w.step(InputFrame.new())
	assert_eq(s.chaos_phase, 1, "still being fought")
	for id in s.members:
		var i := w.actors.index_of(id)
		if i >= 0 and w.actors.dead[i] == 0:
			w.actors.invuln[i] = 0
			var p := w.actors.pos(i)
			Damage.hit(w, i, 1 << 20, 0, 0, w.take_root(), 0, p, p)
	for k in 120:  # (a Splitling's young arrive first)
		w.step(InputFrame.new())
		if s.chaos_phase == 2:
			break
	assert_eq(s.chaos_phase, 2, "cleared")
	assert_eq(w.rewards.size(), rewards + 1, "a free altar rose: the extra upgrade")
	assert_eq(w.rewards.price[w.rewards.size() - 1], 0)


## v0.9.0 EL (owner Q29b: "the Chaos challenge may bring an elite, a designed exception"): with its chance (250 per
## mille as shipped; forced to 1000 here) the challenge also brings one elite archetype, which counts as a member.
func test_chaos_may_bring_an_elite() -> void:
	var w := ShrineLab.with_kind(ShrineTable.Kind.CHAOS)
	assert_not_null(w, "a Chaos shrine within 80 seeds")
	if w == null:
		return
	assert_eq(w.shrine.table.chaos_elite_permille, 250, "the starting value")
	w.shrine.table.chaos_elite_permille = 1000
	# The owner (2026-10-23): a Chaos elite only on floors 4-5. This floor's number set to 4 (TEST HELPER).
	w.floor_index = 4
	ShrineLab.stand_by(w, w.shrine.pos)
	var size := w.shrine.table.chaos_size(w.floor_index)
	ShrineLab.press(w)
	var s := w.shrine
	assert_eq(s.members.size(), size + 1, "the challenge and one elite")
	var elites := 0
	for id in s.members:
		var i := w.actors.index_of(id)
		if EliteAi.is_elite_kind(w.actors.kinds[i]):
			elites += 1
			assert_eq(
				w.floor_layout.room_of(w.actors.pos(i)),
				w.floor_layout.room_of(s.pos),
				"in the room"
			)
	assert_eq(elites, 1, "exactly one elite")
	assert_eq(Elites.alive(w), 1, "it counts as the floor's elite alive")


func test_fortune_is_the_gamble_shrine() -> void:
	var w := ShrineLab.with_kind(ShrineTable.Kind.FORTUNE)
	assert_not_null(w, "a Fortune shrine within 80 seeds")
	if w == null:
		return
	assert_true(Gamble.present(w), "the gamble shrine stands")
	assert_true(w.shrine == null or not w.shrine.has_shrine(), "no other shrine")
	for i in w.interactables.size():
		assert_ne(w.interactables.kind[i], Interactables.Kind.SHRINE)
	w.shards = 1000
	ShrineLab.stand_by(w, w.gamble_pos)
	var price := Gamble.price(w)
	ShrineLab.press(w)
	assert_eq(w.shards, 1000 - price, "it takes shards, as before")
	assert_eq(w.gamble_uses, 1)
	assert_eq(Gamble.max_wins(w), 3, "3 wins")
	assert_eq(Gamble.fail_permille(w), 300, "30 % fail")


func test_the_fountain_heals_once_then_is_dry() -> void:
	var w := ShrineLab.with_fountain()
	assert_not_null(w, "a fountain within 80 seeds")
	if w == null:
		return
	var s := w.shrine
	ShrineLab.stand_by(w, s.fountain_pos)
	var reader := WorldReader.new(w)
	var top := w.actors.max_hp[0]
	w.actors.hp[0] = top
	assert_eq(reader.interact_prompt_key(), &"FOUNTAIN_FULL", "at full health it says so")
	ShrineLab.press(w)
	assert_eq(s.fountain_tick, -1, "and refuses: still full")
	w.actors.hp[0] = 10
	var heal := mini((top * 400 + 500) / 1000, top - 10)
	assert_eq(reader.interact_prompt_key(), &"FOUNTAIN_PROMPT")
	assert_eq(reader.interact_prompt_args(), [heal], "the prompt names the heal")
	var seq := w.last_event_seq()
	ShrineLab.press(w)
	assert_eq(w.actors.hp[0], 10 + heal, "40 %% of max HP")
	assert_eq(s.fountain_healed, heal)
	var heals := 0
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.HEAL and e.effect_id == Shrines.EFFECT_FOUNTAIN:
			heals += 1
	assert_eq(heals, 1, "a heal event")
	assert_eq(reader.interact_prompt_key(), &"", "dry: no prompt")
	w.actors.hp[0] = 10
	ShrineLab.press(w)
	assert_eq(w.actors.hp[0], 10, "one use")
	var wall := false
	for o in w.walls:
		wall = wall or (o.center == s.fountain_pos)
	assert_true(wall, "its footprint is a wall")


func test_a_save_mid_challenge_resumes_exactly() -> void:
	var w := ShrineLab.with_kind(ShrineTable.Kind.CHAOS)
	if w == null:
		return
	var seed_value := w.seed_value
	ShrineLab.stand_by(w, w.shrine.pos)
	ShrineLab.press(w)
	for k in 20:
		w.step(InputFrame.new())
	var snap := WorldSnapshot.take(w)
	var base: World = null
	for s in range(1, 81):
		var b := ShrineLab.floor_world(s, 2)
		if b.seed_value == seed_value:
			base = b
			break
	assert_not_null(base)
	assert_eq(WorldSnapshot.apply(base, snap), "", "a save mid-challenge fits")
	assert_eq(base.state_hash(), w.state_hash(), "same state")
	for k in 60:
		w.step(InputFrame.new())
		base.step(InputFrame.new())
	assert_eq(base.state_hash(), w.state_hash(), "and it plays on the same")
	var h0 := w.state_hash()
	w.shrine.paid += 1
	assert_ne(w.state_hash(), h0, "the shrine's state is hashed")


func test_a_floor_saved_before_sh_is_rebuilt_as_it_was() -> void:
	var today := 0
	for s in range(1, 25):
		var r := ShrineLab.run_state(s, 2)
		r.floor_rules = RunState.FLOOR_RULES_V090_LK
		var old := ShrineLab.build(r)
		assert_null(old.shrine, "seed %d: no Blood or Chaos shrine, no fountain under rules 13" % s)
		assert_eq(Gamble.present(old), old.gamble_id >= 0, "its shrine is the gamble shrine")
		# v0.9.0 CF moved the arenas (never a 1 x 1), and so the shrine's site with them: SH's own rules are compared
		# under the last floor rules before CF (15)
		var r15 := ShrineLab.run_state(s, 2)
		r15.floor_rules = RunState.FLOOR_RULES_V090_EL
		var now := ShrineLab.build(r15)
		assert_eq(now.gamble_id >= 0, old.gamble_id >= 0, "the shrine's site is drawn as before")
		assert_eq(now.gamble_pos, old.gamble_pos)
		if now.shrine != null:
			today += 1
	assert_gt(today, 0, "today's floors have Blood or Chaos shrines or fountains")


## v0.9.0 EL (owner 2026-10-23: "Floors 4-5 only"): on floors 1-3 a Chaos challenge brings no elite, whatever
## its chance.
func test_chaos_brings_no_elite_before_floor_4() -> void:
	var w := ShrineLab.with_kind(ShrineTable.Kind.CHAOS)
	assert_not_null(w, "a Chaos shrine within 80 seeds")
	if w == null:
		return
	w.shrine.table.chaos_elite_permille = 1000
	w.floor_index = 3
	ShrineLab.stand_by(w, w.shrine.pos)
	var size := w.shrine.table.chaos_size(w.floor_index)
	ShrineLab.press(w)
	assert_eq(w.shrine.members.size(), size, "the challenge only")
	assert_eq(Elites.alive(w), 0, "no elite")
