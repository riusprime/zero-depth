extends GutTest
## v0.10.0 VX5, the views (R13, R19, R21, R27, R40, R42): the beams, the shell, the blink flash, the sigils, the shatter
## and the molten floor. Each replaced effect spawns its pack id, the held ones are let go the frame they end, and a
## full family keeps that instance's old look (the strikes are in test_vx5_bosses.gd).

const W := preload("res://tests/support/mx4_world.gd")


## A node BossPackHold.find reads a PackFx from (WorldViewRoot's `pack_fx`).
class Holder:
	extends Node3D
	var pack_fx: PackFx


var _holder: Holder
var _fx: PackFx
var _saved := ""


func before_each() -> void:
	_saved = ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"
	_holder = add_child_autofree(Holder.new())
	_fx = PackFx.new()
	_holder.add_child(_fx)
	_holder.pack_fx = _fx


func after_each() -> void:
	ViewPrefs.effects_density = _saved


func _under(n: Node) -> Node:
	_holder.add_child(n)
	return n


func _fill(family: StringName, id: StringName) -> void:
	while _fx.has_room(family):
		_fx.spawn(id, Vector3.ZERO, 1.0, {}, 0.0)


# --- The views ----------------------------------------------------------------------------------------------------
func test_the_prism_cross_is_pack_beams_and_the_cylinders_where_it_is_full() -> void:
	var v: PrismViews = _under(PrismViews.new())
	v.set_process(false)
	v._at = Vector2.ZERO
	v._cross = {
		"progress": 0,
		"window": false,
		"winding": false,
		"half_width": 0.5,
		"arms": [[Vector2(1, 0), Vector2(9, 0), true], [Vector2(0, 1), Vector2(0, 9), false]],
	}
	v._draw(0.0)
	assert_eq(_fx.live_count(&"beam"), 2, "one pack beam an arm")
	assert_eq(v.beam_count(), 2, "the arms still count as drawn")
	assert_false((v._arms[0]["core"] as Node3D).visible, "the old cylinders give way")
	v._cross = {}
	v._draw(0.0)
	assert_eq(_fx.live_count(&"beam"), 0, "let go when the cross ends")
	_fill(&"beam", &"bx_beam_01")
	v._cross = {
		"progress": 0,
		"window": false,
		"winding": false,
		"half_width": 0.5,
		"arms": [[Vector2(1, 0), Vector2(9, 0), true]],
	}
	v._draw(0.0)
	assert_true((v._arms[0]["core"] as Node3D).visible, "the old cylinder where the family is full")


func test_the_pack_beam_runs_from_a_to_b() -> void:
	var n: Node3D = _fx.spawn(&"bx_beam_01", Vector3.ZERO, 1.0, {}, 0.0)
	BossPackHold.beam_place(n, Vector3(1, 1, 2), Vector3(1, 1, 8), 0.5)
	assert_almost_eq(n.global_position.distance_to(Vector3(1, 1, 2)), 0.0, 0.001)
	assert_almost_eq(float(n.get("beam_length")), 6.0, 0.001, "its length is a to b")
	var along := -n.global_transform.basis.z.normalized()
	assert_almost_eq(along.dot(Vector3(0, 0, 1)), 1.0, 0.001, "it runs along -Z toward b")


func test_the_menders_beam_is_the_packs_and_its_box_gives_way() -> void:
	var v: HordeVisuals = _under(HordeVisuals.new())
	v._hold = BossPackHold.new(_fx)
	v._hold.begin()
	v._beam(5, Vector2.ZERO, Vector2(4, 0))
	v._hold.end()
	assert_eq(_fx.live_count(&"beam"), 1)
	assert_false((v._beams[5] as Node3D).visible)
	v._hold.begin()
	v._hold.end()
	assert_eq(_fx.live_count(&"beam"), 0, "let go when the beam is")
	_fill(&"beam", &"bx_beam_01")
	v._hold.begin()
	v._beam(6, Vector2.ZERO, Vector2(4, 0))
	assert_true((v._beams[6] as Node3D).visible, "the box where the family is full")


func test_the_aether_shell_is_a_held_forcefield() -> void:
	var w := W.world(&"blade", [&"aether_shell"])
	var o: ModifierOverlays = _under(ModifierOverlays.new())
	W.run(w, 200)
	o.sync(WorldReader.new(w))
	assert_true(o.shown("shell"), "the barrier is up")
	assert_eq(_fx.live_count(&"area"), 1, "the pack's forcefield")
	assert_eq(o.shell.layers, 0, "the sphere gives way")
	o.sync(WorldReader.new(w))
	assert_eq(_fx.spawned, 1, "held, not respawned")
	o._hold.begin()
	o._hold.end()
	assert_eq(_fx.live_count(&"area"), 0, "let go when the shell is down")


func test_the_blink_flash_is_the_pack_flash_and_keeps_its_light() -> void:
	var b: BlinkFlash = _under(BlinkFlash.new())
	b.play(Vector3(3, 0, 3))
	assert_eq(_fx.live_count(&"impact"), 1, "the pack's flash")
	assert_false(b.column.visible, "the column gives way")
	assert_true(b.light is OmniLight3D, "its own light stays")
	assert_gt(b.light.light_energy, 0.0)
	_fill(&"impact", &"bx_impact_a")
	var b2: BlinkFlash = _under(BlinkFlash.new())
	b2.play(Vector3.ZERO)
	assert_true(b2.column.visible, "the column where the family is full")


func test_the_blink_flash_without_a_pack_is_the_old_one() -> void:
	var b := BlinkFlash.new()
	add_child_autofree(b)
	b.play(Vector3.ZERO)
	assert_true(b.column.visible)
	assert_eq(_fx.spawned, 0)


func test_the_elites_arrival_sigil_is_a_shadow_magic_circle() -> void:
	var e: EliteViews = _under(EliteViews.new())
	e._arrival(Vector2(3, 3))
	var area: MagicArea = null
	for c in e.get_children():
		if c is MagicArea:
			area = c
	assert_not_null(area, "a MagicArea")
	assert_eq(area.element, "shadow")
	assert_eq(area.kind, "circle")
	assert_almost_eq(area.radius, EliteViews.SIGIL_R, 0.001, "the radius as before")
	assert_false(area.light, "no light of its own")


func test_the_conduits_beam_is_one_pack_beam_for_its_short_life() -> void:
	var e: EliteViews = _under(EliteViews.new())
	e._beam(Obb.make(Vector2(5, 0), Vector2(5.0, 0.8), 0))
	assert_eq(_fx.live_count(&"beam"), 1)
	assert_eq(e.fx_count(), 0, "no old bar")
	_fx.advance(EliteViews.BEAM_S + 0.2)
	assert_eq(_fx.live_count(&"beam"), 0, "gone after BEAM_S")
	_fill(&"beam", &"bx_beam_01")
	e._beam(Obb.make(Vector2(5, 0), Vector2(5.0, 0.8), 0))
	assert_eq(e.fx_count(), 1, "the old bar where the family is full")


func test_the_fallens_eruption_is_a_violet_pillar() -> void:
	var v: InterphaseViews = _under(InterphaseViews.new())
	v._data = {
		"erupts": [{"pos": Vector2(4, 4), "radius": 1.5, "striking": true, "progress": 1000}],
	}
	v._note_strikes()
	assert_eq(_fx.live_count(&"area"), 1, "a pillar where it strikes")
	v._note_strikes()
	assert_eq(_fx.spawned, 1, "once a strike")


func test_the_final_boss_shatter_is_the_packs_explosion() -> void:
	var f: FinalBossViews = _under(FinalBossViews.new())
	f._burst(Vector3(2, 0, 2), 1.5, 10)
	assert_eq(_fx.live_count(&"explosion"), 1, "explosion_07")
	assert_true(f._burst_packed, "the crystal sprites give way")
	_fill(&"explosion", &"bx_shatter")
	f._burst(Vector3(2, 0, 2), 1.5, 20)
	assert_false(f._burst_packed, "the sprites where the family is full")


## v0.10.0 FX (owner: the Foundry drew "both older and newer VFX"): the molten floor is its shader alone, no pack fire
## on top of it.
func test_the_foundrys_molten_floor_is_its_shader_alone() -> void:
	var v: BossSignatureViews = _under(BossSignatureViews.new())
	v._lava_rows = [[Rect2(2, 2, 4, 4), 0.0, 400.0]]
	v._sync_lava_nodes()
	v._hold = BossPackHold.new(_fx)
	v._hold.begin()
	v._draw_lava(10.0)
	v._hold.end()
	assert_eq(_fx.spawned, 0, "no pack fire on the piece")
	assert_true(v._lava_nodes[0].visible, "the molten floor draws")


func test_the_nemesis_cast_sigil_is_a_blood_circle_while_it_casts() -> void:
	var w := NemesisLab.world(
		404, &"gun", [[&"gun_twin", 2], [&"ember_core", 3], [&"halo_shot", 1]]
	)
	var reader := WorldReader.new(w)
	var i := FinalLab.body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(6, 0))
	var k := -1
	for n in w.final_fight.casts.size():
		if w.final_fight.casts[n].card_id == &"ember_core":
			k = n
	var v: NemesisViews = _under(NemesisViews.new())
	var atk := NemesisLab.start(w, StringName("nemesis_card_%d" % (k + 1)))
	var area: MagicArea = null
	for t in atk.windup_ticks + 4:
		w.step(InputFrame.new())
		v.sync(reader)
		for c in v.get_children():
			if c is MagicArea:
				area = c
	assert_not_null(area, "a MagicArea at its feet")
	assert_eq(area.element, "blood")
	assert_eq(area.kind, "circle")
	assert_almost_eq(area.radius, NemesisViews.SIGIL_R, 0.001, "the radius as before")
	assert_true(v.sigil_shown(), "the sigil flag the tests read")
	for n in 40:
		w.step(InputFrame.new())
		v.sync(reader)
	assert_false(v.sigil_shown(), "gone once cast")
	assert_true(v._area == null, "the circle is let go to fade out")
