extends GutTest
## The Fallen's theft as the player sees it, from WorldReader only: the taken card's pip on the HUD's wand row goes dark
## under a violet glow and its tile on the Build page darkens with a violet rim; the mark sits on The Fallen's back,
## turns with its facing, shows a pip per hit still needed and flashes on each counted hit; every card's flight goes
## to The Fallen and back; nothing stays once the card is back. No word anywhere.

const SEED := 951
const GUN_CARDS := [[&"gun_twin", 2], [&"split_shot", 5], [&"ember_core", 3], [&"halo_shot", 1]]
const DT := 1.0 / 60.0


func _world() -> World:
	var w := NemesisLab.world(SEED, &"gun", GUN_CARDS, true, true)
	var fs := w.boss_fight
	fs.fl_gates = 3  # The remembered mechanics out of the way
	fs.fl_open = w.tick
	fs.fl_next = w.tick + 1000000
	fs.fl_end = -1
	var i := FinalLab.body(w)
	w.actors.hp[i] = w.actors.max_hp[i] * 650 / 1000  # A test's write: its first theft gate
	for k in 900:
		if not fs.fl_tk_code.is_empty():
			break
		w.step(InputFrame.new())
	assert_eq(fs.fl_tk_code.size(), 1, "a card is taken")
	return w


func _hit_back(w: World) -> void:
	var i := FinalLab.body(w)
	var at := w.actors.pos(i)
	var pid := w.actors.ids[0]
	Damage.hit(w, i, 1, pid, pid, w.take_root(), 0, at - Kin.dir(w.actors.facing[i]) * 2.0, at)


func test_the_taken_slot_is_dark_on_the_hud_and_the_build_page() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var code := w.boss_fight.fl_tk_code[0]
	var slot := w.mod_slots.find(code)
	var build := BuildHud.new()
	add_child_autofree(build)
	build.sync(r)
	var hud := FallenTheftHud.new()
	hud.build = build
	hud.project = func(_p: Vector2) -> Vector2: return Vector2(900, 400)
	add_child_autofree(hud)
	hud.sync(r)
	assert_eq(hud.dark_slots(), PackedInt32Array([slot]), "only its pip is dark")
	var row := WandRow.new()
	add_child_autofree(row)
	row.show_wand(r.wand(), 8)
	assert_eq(row.tile(slot).modulate, WandRow.TAKEN_TINT, "its tile darkens")
	assert_eq(row.astral_box(slot).rim, FallenTheftHud.VIOLET, "under a violet rim")
	for k in row.card_count():
		if k != slot:
			assert_ne(row.tile(k).modulate, WandRow.TAKEN_TINT, "slot %d stays lit" % k)
	for k in 8:
		_hit_back(w)
	hud.sync(r)
	assert_true(hud.dark_slots().is_empty(), "back: the pip is lit again")
	row.show_wand(r.wand(), 8)
	assert_ne(row.tile(slot).modulate, WandRow.TAKEN_TINT)


func test_the_card_flies_to_the_fallen_and_back() -> void:
	var w := NemesisLab.world(SEED, &"gun", GUN_CARDS, true, true)
	var r := WorldReader.new(w)
	var build := BuildHud.new()
	add_child_autofree(build)
	build.sync(r)
	var hud := FallenTheftHud.new()
	hud.build = build
	hud.project = func(_p: Vector2) -> Vector2: return Vector2(900, 400)
	add_child_autofree(hud)
	hud.sync(r)
	var fs := w.boss_fight
	fs.fl_gates = 3
	fs.fl_open = w.tick
	fs.fl_next = w.tick + 1000000
	var i := FinalLab.body(w)
	w.actors.hp[i] = w.actors.max_hp[i] * 650 / 1000
	for k in 900:
		if not fs.fl_tk_code.is_empty():
			break
		w.step(InputFrame.new())
		hud.sync(r)
	hud.sync(r)
	assert_eq(hud.flown(), 1, "its icon flies to The Fallen")
	for k in 8:
		_hit_back(w)
	hud.sync(r)
	assert_eq(hud.flown(), 2, "and back to its pip")


func test_the_mark_sits_on_its_back_counts_down_and_goes() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var mark := FallenMarkView.new()
	add_child_autofree(mark)
	mark.set_process(false)
	mark.sync(r, r.boss_fallen())
	mark.advance(DT)
	var i := FinalLab.body(w)
	assert_true(mark.shown(), "the mark shows")
	assert_eq(mark.pips(), 8, "a pip per hit needed")
	var back := -Kin.dir(w.actors.facing[i])
	assert_almost_eq(mark.back_dir().dot(back), 1.0, 0.001, "on its back")
	var p := SimPlane.to_3d(w.actors.pos(i))
	var flat := Vector2(mark.mark_at().x - p.x, -(mark.mark_at().z - p.z))
	assert_gt(flat.dot(back), 0.0, "behind it, not in front")
	for k in 3:
		_hit_back(w)
	mark.sync(r, r.boss_fallen())
	mark.advance(DT)
	assert_eq(mark.pips(), 5, "three counted: five left")
	assert_eq(mark.pulses(), 3, "each counted hit flashes it")
	w.actors.facing[i] = (w.actors.facing[i] + 1024) & 4095  # A test's write: it turns a quarter
	mark.sync(r, r.boss_fallen())
	assert_almost_eq(
		mark.back_dir().dot(-Kin.dir(w.actors.facing[i])), 1.0, 0.001, "it turns with it"
	)
	for k in 5:
		_hit_back(w)
	mark.sync(r, r.boss_fallen())
	mark.advance(DT)
	assert_false(mark.shown(), "the card back: no mark")
	assert_eq(mark.pips(), 0)
