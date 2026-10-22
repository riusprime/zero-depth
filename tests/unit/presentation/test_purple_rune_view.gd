extends GutTest
## v0.9.0 DP (owner Q26b: "activation purple runes, that make the screen shake so you know something happened"; Q17:
## the purple runes vibrate): the purple-rune room's view on a whole floor's view (WorldViewRoot). The dais stands in
## its room (the code stand-in until the owner's `purple_rune_dais` is listed) with a ring of purple runes round it,
## dim; the Deep gate is built but sealed (unseen). Awakened: the `purple_runes` sound, the runes light one after
## another, the camera's vibration builds while they light and lands in one thud; then they stay lit. A floor resumed
## with the runes awake shows them lit at once, with no vibration.

const LONG := 1 << 24


func _floor() -> World:
	for s in range(1, 41):
		var w := SaveLab.floor_world(s, 2)
		if w.purple != null:
			w.actors.invuln[0] = LONG
			w.spawner = null
			w.boss_flow.arrive_left = 0
			return w
	return null


func _view(w: World) -> WorldViewRoot:
	var biome: BiomeDefinition = ContentRepository.load_all().get_def(&"biomes", &"ruins")
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood
	add_child_autofree(v)
	v.setup(WorldReader.new(w), biome.palette, 60.0)
	return v


func _awaken(w: World) -> void:
	w.actors.set_pos(0, w.floor_layout.purple_pos + Vector2(0.3, 0.0))
	w.vel = Vector2.ZERO
	w.step(InputFrame.new())
	w.step(InputFrame.make(Vector2i.ZERO, 0, 1000, InputFrame.INTERACT, InputFrame.INTERACT))


func _ids(cues: Array) -> Array:
	var out := []
	for c: Array in cues:
		out.append(c[0])
	return out


func test_the_dais_the_runes_and_their_awakening() -> void:
	var w := _floor()
	assert_not_null(w, "a floor 2 with purple runes")
	if w == null:
		return
	w.step(InputFrame.new())
	var v := _view(w)
	var reader := v.reader
	var p := v.purple
	assert_not_null(p, "the view is built")
	assert_eq(
		p.uses_model,
		not ShopModels.get_model(PurpleRuneView.MODEL_DAIS).is_empty(),
		"the owner's model when listed, else the code stand-in"
	)
	assert_almost_eq(
		p.position.x, SimPlane.to_3d(reader.purple_dais_pos()).x, 0.001, "on the dais's spot"
	)
	assert_eq(p.sigils.size(), PurpleRuneView.RUNES, "a ring of runes")
	for j in PurpleRuneView.RUNES:
		assert_almost_eq(p.glow[j], PurpleRuneView.DIM, 0.001, "rune %d dim" % j)
	assert_not_null(v.deep_gate, "the Deep gate is built where it may open")
	assert_true(v.deep_gate.is_sealed(), "sealed: unseen")
	assert_false(reader.has_deep_portal(), "not earned yet")
	var cues := AudioEvents.new()
	cues.prime(reader)
	_awaken(w)
	v.sync()
	assert_true(_ids(cues.collect(reader)).has(&"purple_runes"), "the runes' sound")
	assert_true(p.lit)
	assert_false(_ids(cues.collect(reader)).has(&"purple_runes"), "once")
	var lit_before := 0
	var thuds := 0
	var vib_seen := 0.0
	var steps := int(ceil(PurpleRuneView.sequence_s() / 0.05)) + 4
	for k in steps:
		p._process(0.05)
		vib_seen = maxf(vib_seen, p.vibration)
		var n := 0
		for j in PurpleRuneView.RUNES:
			n += 1 if p.glow[j] >= PurpleRuneView.LIT - 0.2 else 0
		assert_gte(n, lit_before, "they light one after another, never going out")
		lit_before = n
		if p.take_thud():
			thuds += 1
	assert_eq(lit_before, PurpleRuneView.RUNES, "all lit")
	assert_gt(vib_seen, 0.2, "the vibration built while they lit")
	assert_eq(thuds, 1, "then one thud")
	assert_eq(p.vibration, 0.0, "and it is over")
	assert_true(reader.has_deep_portal(), "the Purple Portal is earned")


func test_a_floor_resumed_awake_shows_them_lit_without_vibration() -> void:
	var w := _floor()
	if w == null:
		return
	_awaken(w)
	for k in 120:
		w.step(InputFrame.new())
	var v := _view(w)
	var p := v.purple
	for j in PurpleRuneView.RUNES:
		assert_gte(p.glow[j], PurpleRuneView.LIT - 0.2, "rune %d lit" % j)
	p._process(0.05)
	assert_eq(p.vibration, 0.0, "no vibration")
	assert_false(p.take_thud(), "no thud")
	assert_true(v.deep_gate.is_sealed(), "the Deep gate waits for the boss")
