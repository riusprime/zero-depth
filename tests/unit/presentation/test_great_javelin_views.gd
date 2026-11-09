extends GutTest
## v0.11.0 F9 (EI-07): the great javelin reads from the sim: drawn while out and gone when it is; embedded it vibrates
## with the sim's own shake (more as a pulse nears, full on the recall line); the recall line is a telegraph, the ring
## is
## StoneSpikeViews' quake ring (no pillar drawn for it).

const LONG := 1 << 20


func _world() -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"warlord", Vector2.ZERO)
	w.actors.set_pos(0, Vector2(9, 0))
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


func _step(w: World, n: int = 1) -> void:
	for t in n:
		w.actors.hp[0] = LONG
		w.actors.invuln[0] = 0
		w.step(InputFrame.new())


func test_it_is_drawn_while_out_vibrates_with_the_sim_and_its_lines_are_telegraphs() -> void:
	var s := _world()
	var w: World = s[0]
	var aid: int = s[1]
	var reader := WorldReader.new(w)
	var v := GreatJavelinViews.new()
	add_child_autofree(v)
	var tg := TelegraphViews.new()
	add_child_autofree(tg)
	var spikes := StoneSpikeViews.new()
	add_child_autofree(spikes)
	v.sync(reader)
	assert_false(v.shown(), "nothing before the throw")
	BossLab.start(w, w.actors.index_of(aid), &"great_javelin")
	var drawn_line := false
	while w.bosses.gj_boss.is_empty():
		_step(w)
		tg.sync(reader)
		drawn_line = drawn_line or tg.count() > 0
		if w.tick > 2000:
			break
	assert_true(drawn_line, "the throw's line and landing mark are a telegraph")
	while w.bosses.gj_phase[0] != BossGreatJavelin.EMBEDDED:
		_step(w)
	var atk := BossAi.table_of(w, w.actors.index_of(aid)).attacks[w.bosses.gj_attack[0]]
	_step(w, 10)
	v.sync(reader)
	spikes.sync(reader)
	assert_true(v.shown(), "drawn embedded")
	var rest := v.shake()
	assert_gt(rest, 0.0, "it vibrates")
	assert_eq(spikes.quake_count(), 1, "its ring is on the quake views")
	assert_eq(spikes.pillar_count(), 0, "no pillar for it")
	# Into the first pulse's warning: the ring grows (bands drawn) and it shakes harder.
	_step(w, atk.great_pulse_ticks - atk.great_warn_ticks / 2 - 10)
	v.sync(reader)
	spikes.sync(reader)
	assert_gt(v.shake(), rest, "harder as a pulse nears")
	assert_gt(spikes.ring_bands(), 0, "the ring's warning is drawn")
	while w.bosses.gj_phase[0] != BossGreatJavelin.RECALL_WARN:
		_step(w)
	v.sync(reader)
	tg.sync(reader)
	assert_almost_eq(v.shake(), 1.0, 0.001, "full on the recall line")
	assert_gt(tg.count(), 0, "the recall line is a telegraph")
	assert_false(reader.boss_javelin_recall_line(reader.boss_index()).is_empty())
	while not w.bosses.gj_boss.is_empty():
		_step(w)
		if w.tick > 6000:
			break
	v.sync(reader)
	assert_false(v.shown(), "gone once it is back")
