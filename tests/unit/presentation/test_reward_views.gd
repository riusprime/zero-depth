extends GutTest
## v0.3.0 E presentation: altar and chest models (flash-safe glow), the chest's price tag, shard gems flying to the
## player, the HUD counter and prompt, and the 3-card pick panel (rarity frames, keys, pad, mouse, cancel).

var _items: Array[ItemTable] = []


func before_all() -> void:
	_items = ContentCompiler.compile_items(ContentRepository.load_all())


func _world() -> World:
	var w := World.new(9, PlayerTable.starting_values())
	w.set_enemy_tables(CombatLab.tables())
	w.set_item_tables(_items)
	return w


func _open(w: World) -> void:
	var f := InputFrame.make(Vector2i.ZERO, 0, 0, 0, InputFrame.INTERACT)
	w.step(f)


func _glow_materials(n: Node) -> Array:
	var out := []
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var mat := m.material_override as StandardMaterial3D
		if mat != null and mat.emission_enabled:
			out.append(mat)
	return out


func test_altars_and_chests_are_built_and_removed_with_the_sim() -> void:
	var w := _world()
	var altar := w.add_reward(RewardStore.Kind.ALTAR, Vector2(5, 0), 0)
	var chest := w.add_reward(RewardStore.Kind.CHEST, Vector2(1, 1), 40)
	var r := WorldReader.new(w)
	var v := RewardViews.new()
	add_child_autofree(v)
	v.sync(r)
	assert_eq(v.count(), 2)
	assert_gt(_glow_materials(v.node_of(altar)).size(), 0, "the altar's rune glows")
	assert_gt(_glow_materials(v.node_of(chest)).size(), 0, "the chest's lock glows")
	var label := v.price_label(chest)
	assert_not_null(label, "a chest has a price tag")
	assert_null(v.price_label(altar), "an altar has none")
	assert_true(label.visible, "near: the price shows")
	assert_eq(label.text, "40")
	assert_eq(label.modulate, RewardViews.PRICE_POOR, "red while you can't afford it")
	w.shards = 40
	v.sync(r)
	assert_eq(label.modulate, RewardViews.PRICE_OK)
	w.actors.set_pos(0, Vector2(20, 20))
	v.sync(r)
	assert_false(label.visible, "far: hidden")
	w.rewards.remove_at(w.rewards.index_of(altar))
	v.sync(r)
	assert_eq(v.count(), 1, "a consumed reward disappears")


func test_glow_is_flash_safe() -> void:
	# Emission is on from creation and stays on; only energies animate (never toggle emission_enabled).
	var w := _world()
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(1, 0), 0)
	w.add_reward(RewardStore.Kind.CHEST, Vector2(-1, 0), 40)
	var v := RewardViews.new()
	add_child_autofree(v)
	var r := WorldReader.new(w)
	v.sync(r)
	var before := _glow_materials(v).size()
	for k in 30:
		v.sync(r)
		v._process(1.0 / 60.0)
	assert_eq(_glow_materials(v).size(), before)


func test_a_refused_chest_shakes() -> void:
	var w := _world()
	var chest := w.add_reward(RewardStore.Kind.CHEST, Vector2(1, 0), 40)
	var v := RewardViews.new()
	add_child_autofree(v)
	var r := WorldReader.new(w)
	v.sync(r)
	_open(w)
	assert_eq(w.reward_denied_id, chest)
	v.sync(r)
	v._process(0.05)
	var body: Node3D = v.node_of(chest).get_meta(&"body")
	assert_ne(body.position.x, 0.0, "it shakes")


func test_shard_gems_fly_from_the_kill_to_the_player() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var s := ShardViews.new()
	add_child_autofree(s)
	s.sync(r)
	w.add_enemy(ActorStore.Kind.WARDEN, Vector2(4, 0))
	var i := w.actors.size() - 1
	w.actors.dead[i] = 1
	w.step(InputFrame.new())
	s.sync(r)
	assert_eq(s.count(), 6, "a gem per shard (Warden: 6)")
	for k in 120:
		s._process(1.0 / 60.0)
	assert_eq(s.count(), 0, "they reached the player and vanished")


func test_hud_counter_and_prompt() -> void:
	var w := _world()
	var hud := Hud.new()
	add_child_autofree(hud)
	var r := WorldReader.new(w)
	hud.sync(r)
	assert_eq(hud.shard_text(), "0")
	assert_eq(hud.prompt_text(), "")
	w.add_reward(RewardStore.Kind.CHEST, Vector2(1, 0), 40)
	w.shards = 12
	hud.sync(r)
	assert_eq(hud.shard_text(), "12")
	assert_eq(hud.prompt_text(), tr("REWARD_TOO_POOR") % [12, 40])
	assert_true(hud.prompt_poor())
	w.shards = 45
	hud.sync(r)
	assert_eq(hud.prompt_text(), tr("REWARD_OPEN_CHEST") % 40)
	assert_false(hud.prompt_poor())
	_open(w)
	hud.sync(r)
	assert_eq(hud.prompt_text(), "", "no prompt while choosing")
	assert_true(hud.pick_panel().is_open())


func test_the_pick_panel_shows_the_offer_with_rarity_frames() -> void:
	var w := _world()
	w.item_tables[3].rarity = ItemTable.RARE
	w.add_reward(RewardStore.Kind.CHEST, Vector2(1, 0), 40)
	w.shards = 40
	# Force the offer so the rare item is in it (the draw itself is tested in the sim).
	w.rewards.set_offer(0, PackedInt32Array([1, 3, 5]))
	_open(w)
	var r := WorldReader.new(w)
	var p := PickPanel.new()
	add_child_autofree(p)
	p.sync(r)
	assert_true(p.is_open())
	assert_eq(p.card_count(), 3)
	assert_eq(p.title_text(), tr("PICK_TITLE_CHEST") % 40, "the title carries the price")
	assert_eq(p.slot(0).frame_color(), PickSlot.COMMON)
	assert_eq(p.slot(1).frame_color(), PickSlot.RARE, "a rare item has the gold frame")
	assert_eq(p.slot(1).card.title_text(), tr(r.item_name_key(3)))
	assert_true(p.slot(0).focused, "the first card has the focus")
	w.item_tables[3].rarity = ItemTable.COMMON


func test_the_pick_panel_sends_picks_and_cancels() -> void:
	var w := _world()
	w.add_reward(RewardStore.Kind.ALTAR, Vector2(1, 0), 0)
	_open(w)
	var r := WorldReader.new(w)
	var got := []
	var p := PickPanel.new()
	add_child_autofree(p)
	p.picked.connect(func(v: int) -> void: got.append(v))
	p.sync(r)
	p._input(_key(KEY_RIGHT))
	p._input(_key(KEY_RIGHT))
	p._input(_key(KEY_RIGHT))
	assert_eq(p.focus_index(), 2, "right stops at the last card")
	p._input(_key(KEY_1))
	assert_eq(p.focus_index(), 0, "1 focuses the 1st card")
	p._input(_key(KEY_SPACE))
	assert_eq(got, [], "Space (dash) never confirms")
	p._input(_pad(JOY_BUTTON_DPAD_RIGHT))
	p._input(_pad(JOY_BUTTON_A))
	assert_eq(got, [2], "pad: d-pad right, A takes the 2nd card")
	p._input(_pad(JOY_BUTTON_A))
	assert_eq(got, [2], "one pick per opening")
	var q := PickPanel.new()
	add_child_autofree(q)
	q.picked.connect(func(v: int) -> void: got.append(v))
	q.sync(r)
	q._input(_pad(JOY_BUTTON_B))
	assert_eq(got, [2, InputFrame.PICK_CANCEL], "pad B cancels")
	var m := PickPanel.new()
	add_child_autofree(m)
	m.picked.connect(func(v: int) -> void: got.append(v))
	m.sync(r)
	m._on_clicked(2)
	assert_eq(got, [2, InputFrame.PICK_CANCEL, 3], "a click takes that card")


func test_the_latch_delivers_a_pick_once() -> void:
	var l := InputLatch.new()
	l.note_pick(2)
	assert_eq(l.close_frame(Vector2.ZERO, Vector2.ZERO, 0.0).pick, 2)
	assert_eq(l.close_frame(Vector2.ZERO, Vector2.ZERO, 0.0).pick, InputFrame.PICK_NONE)


func _key(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	return ev


func _pad(b: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	ev.pressed = true
	return ev
