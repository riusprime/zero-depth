extends GutTest
## Optional routes, shown (v0.5.0 RT, R5): the Deep gate reads apart from the gate at a glance (violet swirl, red rim
## and frame vs the visor's light blue), it opens with the gate and each closes when the other is taken; the floor
## card and the HUD's floor label name a Deep floor; the recap lists the route per floor; the epic altar glows
## violet and says so; the Deep gate's opening has its own sound and caption; every new string has en and es.
## Presentation only (EI-07): the views read WorldReader.

const LONG := 1 << 24
const KEYS := [
	"HUD_FLOOR_DEEP",
	"HUD_FLOOR_CARD_DEEP",
	"HUD_PORTALS_OPEN",
	"REWARD_OPEN_EPIC_ALTAR",
	"PICK_TITLE_EPIC_ALTAR",
	"MAP_LEGEND_PORTAL_DEEP",
	"UI_RECAP_ROUTE",
	"ROUTE_NORMAL",
	"ROUTE_DEEP",
	"CAPTION_DEEP_PORTAL",
]


func _world() -> World:
	var w := FightLab.floor_world(51, 1)
	w.actors.invuln[0] = LONG
	return w


func _open(w: World) -> void:
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_inside(1.5))
	CombatLab.idle(w, 4)
	var bi := w.actors.index_of(w.boss_id)
	w.actors.invuln[bi] = 0
	Damage.hit(w, bi, 999999, 1, 1, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
	CombatLab.idle(w, 2)


func _view(w: World) -> WorldViewRoot:
	var v := WorldViewRoot.new()
	add_child_autofree(v)
	v.setup(WorldReader.new(w), _palette(), 60.0)
	return v


func _palette() -> Dictionary:
	var repo := ContentRepository.load_all()
	var biome: BiomeDefinition = repo.get_def(&"biomes", &"ruins")
	return biome.palette


func test_the_deep_gate_reads_apart_from_the_gate() -> void:
	var g := PortalGate.new()
	add_child_autofree(g)
	var d := PortalGate.new()
	add_child_autofree(d)
	d.set_deep()
	assert_true(d.deep)
	assert_eq(d.rim_strips.size(), 3, "a red frame: two sides and the top")
	assert_eq(g.rim_strips.size(), 0, "the gate keeps its plain stone")
	var mid: Color = d.portal_material.get_shader_parameter("color_mid")
	var blue: Color = g.portal_material.get_shader_parameter("color_mid")
	assert_gt(absf(mid.h - blue.h), 0.1, "a different hue (violet vs light blue)")
	assert_lt(
		mid.get_luminance(), blue.get_luminance(), "and darker, so it reads apart without colour"
	)
	var rim: Color = d.portal_material.get_shader_parameter("rim_color")
	assert_eq(rim.a, 1.0, "the swirl's rim is red")
	assert_gt(rim.r, rim.b)
	assert_eq(d.light.light_color, PortalGate.DEEP_VIOLET)
	var plain: Variant = g.portal_material.get_shader_parameter("rim_color")
	assert_true(plain == null or (plain as Color).a == 0.0, "the gate's rim stays its light blue")


func test_the_view_builds_both_gates_and_closes_the_one_not_taken() -> void:
	var w := _world()
	var v := _view(w)
	assert_not_null(v.deep_gate, "floor 1 of 3 shows the Deep gate")
	assert_true(v.deep_gate.deep)
	assert_eq(
		v.deep_gate.position, SimPlane.to_3d(w.floor_layout.deep_portal_pos), "where the sim has it"
	)
	assert_true(v.gate.is_sealed() and v.deep_gate.is_sealed(), "both sealed during the fight")
	_open(w)
	v.sync()
	assert_false(v.gate.is_sealed(), "both open")
	assert_false(v.deep_gate.is_sealed())
	assert_eq(v.transit.deep_gate, v.deep_gate)
	var f := w.floor_layout
	var n := Kin.dir(f.deep_portal_angle)
	w.actors.set_pos(0, Routes.deep_front(f).get_center())
	var frame := InputFrame.new()
	frame.move = Vector2i(roundi(-n.x * SimTick.MOVE_MAX), roundi(-n.y * SimTick.MOVE_MAX))
	for k in 120:
		w.step(frame)
		if w.boss_flow.state != BossFlow.State.OPEN:
			break
	v.sync()
	assert_eq(w.boss_flow.route_taken, Routes.Route.DEEP)
	assert_true(v.gate.is_sealed(), "the gate closes when the Deep gate is taken")
	assert_false(v.deep_gate.is_sealed())


func test_the_last_floor_has_one_gate() -> void:
	var w := FightLab.floor_world(51, 3)
	var v := _view(w)
	assert_null(v.deep_gate, "floor 3's boss still wins the run with one portal")


func test_the_floor_card_and_label_name_a_deep_floor() -> void:
	var h := Hud.new()
	add_child_autofree(h)
	h.show_floor(2, "BIOME_RUINS", true)
	assert_eq(h.floor_card_text(), "%s %s" % [tr("HUD_FLOOR_CARD_DEEP") % 2, tr("BIOME_RUINS")])
	h.show_floor(2, "BIOME_RUINS")
	assert_eq(
		h.floor_card_text(), "%s %s" % [tr("HUD_FLOOR_CARD") % 2, tr("BIOME_RUINS")], "normal"
	)
	var w := _world()
	w.boss_flow.deep = true
	w.floor_index = 2
	h.sync(WorldReader.new(w))
	assert_eq(h.floor_text(), tr("HUD_FLOOR_DEEP") % [2, tr("BIOME_RUINS")])
	w.boss_flow.deep = false
	h.sync(WorldReader.new(w))
	assert_eq(h.floor_text(), tr("HUD_FLOOR") % [2, tr("BIOME_RUINS")])


func test_the_english_and_spanish_say_deep() -> void:
	var rows := _csv()
	assert_true(String(rows["HUD_FLOOR_CARD_DEEP"][0]).contains("Deep"), "Floor 2 · Deep")
	assert_true(String(rows["HUD_FLOOR_CARD_DEEP"][1]).contains("Profundo"))
	for k in KEYS:
		assert_true(rows.has(k), "%s exists" % k)
		if rows.has(k):
			assert_false(String(rows[k][0]).is_empty(), "%s en" % k)
			assert_false(String(rows[k][1]).is_empty(), "%s es" % k)


func test_the_recap_lists_the_route_per_floor() -> void:
	var p := (
		EndPanel
		. new(
			true,
			-1,
			&"",
			{
				"floor": 3,
				"floors": 3,
				"routes": PackedInt32Array([WorldReader.ROUTE_NORMAL, WorldReader.ROUTE_DEEP, 0]),
			}
		)
	)
	var names := "%s → %s → %s" % [tr("ROUTE_NORMAL"), tr("ROUTE_DEEP"), tr("ROUTE_NORMAL")]
	assert_eq(p.recap_line("Route"), tr("UI_RECAP_ROUTE") % names)
	p.free()
	var q := EndPanel.new(false, -1, &"", {"floor": 1, "floors": 3})
	assert_eq(q.recap_line("Route"), "", "no route line without routes")
	q.free()


func test_the_epic_altar_glows_violet() -> void:
	var r := RewardViews.new()
	add_child_autofree(r)
	var epic := r.make_altar(true)
	var plain := r.make_altar()
	assert_true(epic.get_meta(&"epic"))
	assert_false(plain.get_meta(&"epic"))
	assert_eq((epic.get_meta(&"light") as OmniLight3D).light_color, RewardViews.EPIC_LIGHT)
	assert_eq((plain.get_meta(&"light") as OmniLight3D).light_color, RewardViews.ALTAR_LIGHT)
	epic.free()
	plain.free()


func test_the_deep_gate_opening_has_its_sound() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var ev := AudioEvents.new()
	ev.prime(r)
	_open(w)
	var ids := []
	for c: Array in ev.collect(r):
		ids.append(c[0])
	assert_has(ids, &"portal_open")
	assert_has(ids, &"deep_portal_open", "the Deep gate rumbles open too")
	assert_true(ResourceLoader.exists("res://data/audio/cues/deep_portal_open.tres"))
	var cue: AudioCueDefinition = load("res://data/audio/cues/deep_portal_open.tres")
	assert_eq(cue.caption_key, &"CAPTION_DEEP_PORTAL")
	var single := FightLab.floor_world(51, 3)
	single.actors.invuln[0] = LONG
	var r3 := WorldReader.new(single)
	var ev3 := AudioEvents.new()
	ev3.prime(r3)
	_open(single)
	var ids3 := []
	for c: Array in ev3.collect(r3):
		ids3.append(c[0])
	assert_does_not_have(ids3, &"deep_portal_open", "one portal on the last floor, one sound")


func _csv() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3:
			out[row[0]] = [row[1], row[2]]
	return out
