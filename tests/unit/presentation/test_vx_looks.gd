extends GutTest
## v0.9.0 VX (docs/roadmap/v0.9.0/VFX_AUDIT.md, the owner's G1 answers in the PLAN's VX row): the one element palette
## (V1, Bleed dark red), two elements on the beam forms (V2), the hero's colours off every hostile shot (V46, V50),
## player ground marks out of the hostile hues (V49), and the layered element effects each form now draws into the
## effects layer: launch cues (V3, V27, V33, V35), element impacts (V4, V8, V19), live accents (V6, V15, V22, V25, V29,
## V30, V31), the Void's growth and collapse (V12, V14), the Glaive's catch (V26), the long trails (V18, V36), the
## Lance without its camera kick (V17), and Effects density Low / reduced motion per view (V47).

const W := preload("res://tests/support/mx4_world.gd")
const FIVE: Array[StringName] = [&"ember", &"storm", &"frost", &"venom", &"bleed"]

var _layer: VfxLayer


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	ViewPrefs.reduced_motion = false
	_layer = add_child_autofree(VfxLayer.new())


func after_each() -> void:
	ViewPrefs.effects_density = "high"
	ViewPrefs.reduced_motion = false


static func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


# --- V1, V2, V46, V50: the palette ---------------------------------------------------------------------------------
func test_one_palette_feeds_the_orbs_the_beam_forms_and_the_impacts() -> void:
	for e in FIVE:
		assert_eq(AttackFormLooks.element_color(e), ElementLooks.core(e), "%s: the Orbs' core" % e)
		var look: StringName = ElementLooks.LOOK[e]
		assert_eq(BeamLooks.edge(look), ElementLooks.core(e), "%s: the beam forms' colour" % e)
		assert_eq(BeamLooks.core(look), ElementLooks.hot(e), "%s: the beam forms' centre" % e)
	var bleed := ElementLooks.core(&"bleed")
	assert_lt(bleed.get_luminance(), 0.3, "Bleed is dark")
	assert_true(bleed.h > 0.9 or bleed.h < 0.03, "and red (owner: dark red everywhere)")
	assert_eq(
		AttackFormLooks.compose({"form": 1, "elements": PackedStringArray(["bleed"])})["core"],
		bleed,
		"the Orbs' Bleed is no longer the tinted cyan"
	)


func test_two_elements_take_the_first_ones_centre_and_the_seconds_edge() -> void:
	var c := BeamLooks.colors(PackedStringArray(["ember", "frost"]))
	assert_eq(c[1], ElementLooks.core(&"frost"), "the second's edge")
	assert_eq(c[0], ElementLooks.core(&"ember"), "the first's core as the centre")
	assert_eq(
		BeamLooks.look_of(PackedStringArray(["frost", "ember"])), &"frost", "the first's look"
	)
	assert_eq(
		BeamLooks.look_of(PackedStringArray(["bleed", "storm"])), &"bleed", "no fixed precedence"
	)
	var one := BeamLooks.colors(PackedStringArray(["venom"]))
	assert_eq([one[0], one[1]], [ElementLooks.hot(&"venom"), ElementLooks.core(&"venom")])


func test_no_hero_colour_sits_near_a_hostile_shots_core_and_none_has_a_dark_edge() -> void:
	var hero: Array[Color] = [ElementLooks.DEFAULT_HOT, ElementLooks.DEFAULT_CORE]
	for e in FIVE:
		hero.append_array([ElementLooks.hot(e), ElementLooks.core(e)])
		for f in FIVE:
			if f != e:
				hero.append_array(ElementLooks.pair(PackedStringArray([e, f])))
	for look: StringName in BeamLooks.LOOKS:
		hero.append_array([BeamLooks.core(look), BeamLooks.edge(look)])
		assert_gt(BeamLooks.edge(look).get_luminance(), 0.15, "%s: no dark edge (V50)" % look)
	for key: StringName in FireballViews.LOOKS:
		var hostile: Color = FireballViews.look_of(key)["core"]
		for c in hero:
			assert_gt(
				_dist(hostile, c),
				0.2,
				"%s #%s is off hero #%s" % [key, hostile.to_html(false), c.to_html(false)]
			)
	# V46 (owner "Move the hero's side"): Frost a little greener, the Bleed centre darker than before.
	var frost := ElementLooks.core(&"frost")
	assert_gt(frost.g - frost.b, Color("#B5F2FF").g - Color("#B5F2FF").b, "Frost leans greener")
	assert_lt(BeamLooks.core(&"bleed").get_luminance(), Color("#FF7080").get_luminance(), "darker")


# --- V49: player ground marks --------------------------------------------------------------------------------------
func test_no_forms_ground_mark_takes_a_hostile_hue() -> void:
	var sets: Array[PackedStringArray] = [PackedStringArray()]
	for e in FIVE:
		sets.append(PackedStringArray([e]))
		for f in FIVE:
			if f != e:
				sets.append(PackedStringArray([e, f]))
	for els in sets:
		var cols := BeamLooks.colors(els)
		for c in cols:
			assert_false(AttackFormLooks.is_hostile_hue(AttackFormLooks.ground_safe(c)), "%s" % els)
	assert_false(AttackFormLooks.is_hostile_hue(VfxLayer.FIRE_PATCH_TINT), "V43's fire patch")
	var v: VoidView = add_child_autofree(VoidView.new())
	assert_false(
		AttackFormLooks.is_hostile_hue(v._ring_mat.get_shader_parameter(&"arm_color")),
		"Void's ring"
	)
	for pair: Array in [[&"ember_core", "fire"], [&"shared_bleed", "bleed"]]:
		var b: BombView = add_child_autofree(BombView.new())
		var w := W.world(&"gun", [&"gun_bomb", pair[0]], [[Vector2(4.0, 0.0), 100000]])
		var r := WorldReader.new(w)
		b.sync(r)
		W.run(w, 24, 0, W.S)
		b.sync(r)
		assert_eq(b.blasts, 1, "%s: a blast" % pair[1])
		for p: StringName in [&"core", &"edge"]:
			var c: Color = b._ring_mat[0].get_shader_parameter(p)
			assert_false(AttackFormLooks.is_hostile_hue(c), "%s blast ring %s (V10)" % [pair[1], p])


# --- V3, V27, V33, V35: the volley cues ----------------------------------------------------------------------------
func _forms() -> AttackFormView:
	var f: AttackFormView = add_child_autofree(AttackFormView.new())
	f.vfx = _layer
	return f


func _cues_of(f: AttackFormView, kind: StringName) -> int:
	var n := 0
	for e: Dictionary in f._effects:
		n += 1 if e.get("kind") == kind else 0
	return n


func test_each_volley_gets_one_launch_cue_never_one_per_copy() -> void:
	var cases := [
		[[], &"muzzle", 1, "the Orbs: one muzzle spark"],
		[[&"gun_twin"], &"muzzle", 1, "Twin's copies share it"],
		[[&"gun_backfire"], &"muzzle", 2, "Backfire: one at the back too (V35)"],
		[[&"gun_seekers"], &"muzzle", 3, "the Seekers: fanned three ways (V27)"],
		[[&"halo_shot"], &"halo", 1, "Halo: a ground ring (V33)"],
	]
	for c: Array in cases:
		var f := _forms()
		var w := W.world(&"gun", c[0], [[Vector2(4.0, 0.0), 100000]])
		var r := WorldReader.new(w)
		W.run(w, 1, 0, W.S)
		f.sync(r)
		assert_eq(_cues_of(f, c[1]), c[2], c[3])
		f.draw_at(float(r.tick()) + 1.0)
		var pool := &"ring" if c[1] == &"halo" else &"glow"
		assert_gt(_layer.used(pool), 0, "%s: drawn in the layer" % c[3])
	var lance := _forms()
	var lw := W.world(&"gun", [&"gun_scatter"], [])
	var lr := WorldReader.new(lw)
	W.run(lw, 1, 0, W.S)
	lance.sync(lr)
	assert_eq(lance.volley_cues, 0, "a form with its own launch (the Scatter's cone) gets none")


func test_the_halo_ring_is_ground_safe_and_low_density_drops_the_cues() -> void:
	var f := _forms()
	var w := W.world(&"gun", [&"halo_shot", &"shared_bleed"], [])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	f.sync(r)
	for e: Dictionary in f._effects:
		if e.get("kind") == &"halo":
			assert_false(AttackFormLooks.is_hostile_hue(AttackFormLooks.ground_safe(e["color"])))
	ViewPrefs.effects_density = "low"
	f.sync(r)
	f.draw_at(float(r.tick()) + 1.0)
	assert_eq(_layer.used(&"ring") + _layer.used(&"glow"), 0, "none at Low")


# --- V4, V6, V8: element impacts and live accents ------------------------------------------------------------------
func test_an_element_bolts_impact_adds_its_own_extra() -> void:
	var fx := ImpactFx.new()
	var at := Vector3(1, 0.5, 1)
	var kinds := {
		&"fire": &"ember",
		&"storm": &"bolt",
		&"frost": &"flake",
		&"venom": &"bubble",
		&"bleed": &"bubble"
	}
	for k: StringName in kinds:
		fx._live.clear()
		fx.add(at, Vector3.RIGHT, at + Vector3.RIGHT * 0.4, Color.WHITE, 10, 1.0, ImpactFx.BOLT, k)
		_layer.begin(12.0)
		var before := _layer.used(kinds[k])
		fx.draw(_layer)
		assert_gt(_layer.used(kinds[k]), before, "%s: its extra" % k)
	fx._live.clear()
	fx.add(at, Vector3.RIGHT, at, Color.WHITE, 10, 1.0, ImpactFx.BOLT, &"")
	_layer.begin(12.0)
	fx.draw(_layer)
	assert_eq(_layer.used(&"glow") + _layer.used(&"flake"), 0, "no element: the plain impact")
	_layer.density = 0.25
	fx._live.clear()
	fx.add(at, Vector3.RIGHT, at, Color.WHITE, 10, 1.0, ImpactFx.BOLT, &"frost")
	_layer.begin(12.0)
	fx.draw(_layer)
	assert_eq(_layer.used(&"flake"), 0, "none at Low")


func test_an_ember_bolts_hit_records_fire() -> void:
	var w := W.world(&"gun", [&"ember_core"], [[Vector2(3.0, 0.0), 100000]])
	var r := WorldReader.new(w)
	var fx := ImpactFx.new()
	var seq := 0
	for t in 60:
		W.run(w, 1, 0, W.S)
		for e in r.events_since(seq):
			seq = e.seq
			if e.kind == SimEvent.Kind.DAMAGE and e.owner_id == r.actor_id(0) and fx.live() == 0:
				fx.on_hit(r, e)
		fx.track(r)
	assert_gt(fx.live(), 0, "a hit")
	assert_eq(fx._live[0][8], &"fire", "its element's extra: Fire")


func test_a_live_orb_carries_its_elements_accent_and_none_at_low() -> void:
	for density: String in ["high", "low"]:
		ViewPrefs.effects_density = density
		var f := _forms()
		var w := W.world(&"gun", [&"ember_core"], [[Vector2(8.0, 0.0), 100000]])
		var r := WorldReader.new(w)
		W.run(w, 4, 0, W.S)
		f.sync(r)
		f.draw_at(float(r.tick()))
		if density == "high":
			assert_gt(_layer.used(&"ember"), 0, "Fire embers trail a live Orb (V6)")
			assert_gt(_layer.used(&"glow"), 0, "and its glow")
		else:
			assert_eq(_layer.used(&"ember"), 0, "Low: the pulse and trail only")


func test_the_lasers_impact_plays_its_extra_twice_a_second() -> void:
	var v: LaserView = add_child_autofree(LaserView.new())
	var w := W.world(&"gun", [&"gun_laser", &"ember_core"], [[Vector2(4.0, 0.0), 100000]])
	var r := WorldReader.new(w)
	W.run(w, 2, 0, W.S)
	v.sync(r)
	assert_gt(v.impacts, 0, "the beam hits")
	_layer.begin(3.0)
	v.draw_fx(_layer)
	assert_gt(_layer.used(&"ember"), 0, "Fire's embers at the beam's end")
	_layer.begin(25.0)
	v.draw_fx(_layer)
	assert_eq(_layer.used(&"ember"), 0, "between two (never on every damage tick)")


# --- V12, V14, V15, V47: the Void ----------------------------------------------------------------------------------
func test_the_void_grows_tints_its_rim_and_trail_and_collapses() -> void:
	var v: VoidView = add_child_autofree(VoidView.new())
	var w := W.world(&"gun", [&"gun_void", &"ember_core"], [[Vector2(4.0, 2.0), 100000]])
	var r := WorldReader.new(w)
	W.run(w, 4, 0, W.S)
	v.sync(r)
	assert_eq(v.voids, 1)
	assert_lt(v.growth, 0.5, "V12: it starts small")
	W.run(w, 6, 0, 0)
	v.sync(r)
	assert_almost_eq(v.growth, 1.0, 1e-4, "full size after its first ticks")
	assert_ne(v.rim_color, VoidView.RIM, "V15: Fire tints the bent-light rim")
	assert_ne(v.trail_color, VoidView.VIOLET, "and the dust trail")
	_layer.begin(float(r.tick()))
	v.draw_fx(_layer)
	assert_gt(_layer.used(&"ember"), 0, "and adds its accent to the trail")
	var gone := false
	for t in 120:
		W.run(w, 1, 0, 0)
		v.sync(r)
		if v.voids == 0:
			gone = true
			break
	assert_true(gone, "the shot ends")
	assert_eq(v.collapses, 1, "V14: it collapses where it was")
	_layer.begin(float(r.tick()) + 1.0)
	v.draw_fx(_layer)
	assert_gt(_layer.used(&"ring"), 0, "a violet flash")
	W.run(w, 10, 0, 0)
	v.sync(r)
	assert_eq(v.collapses, 0, "over in 8 ticks")


func test_low_density_keeps_the_voids_core_lens_and_ring_and_reduced_motion_stills_it() -> void:
	ViewPrefs.effects_density = "low"
	ViewPrefs.reduced_motion = true
	var v: VoidView = add_child_autofree(VoidView.new())
	var w := W.world(&"gun", [&"gun_void"], [[Vector2(4.0, 2.0), 100000]])
	var r := WorldReader.new(w)
	W.run(w, 4, 0, W.S)
	v.sync(r)
	assert_eq([v.voids, v.puffs, v.dust_on], [1, 0, false], "the dust disc and trail puffs go")
	assert_true(
		v._cores[0].visible and v._lenses[0].visible and v._rings[0].visible, "core lens ring"
	)
	assert_eq(v._dust_mats[0].get_shader_parameter(&"motion"), 0.0, "the swirl stills")


# --- V17, V19, V47: the Lance --------------------------------------------------------------------------------------
func test_the_lance_has_no_camera_kick_halves_its_motes_at_low_and_marks_a_wall_stop() -> void:
	var v: LanceView = add_child_autofree(LanceView.new())
	assert_false("rig" in v, 'V17 (owner "Drop it"): no camera kick')
	var w := W.world(&"gun", [&"gun_lance", &"frost_core"], [])
	var r := WorldReader.new(w)
	ViewPrefs.effects_density = "low"
	ViewPrefs.reduced_motion = true
	v.sync(r)
	assert_eq(v._circle_mat.get_shader_parameter(&"motes_n"), 4, "V47: half the motes")
	assert_eq(v._circle_mat.get_shader_parameter(&"motion"), 0.0, "reduced motion stills it")
	ViewPrefs.effects_density = "high"
	var box := Obb.make(Vector2(6.0, 0.0), Vector2(0.5, 2.0), 0)
	w.walls.append(box)  # TEST HELPER (labelled): a wall the ball would meet
	assert_true(LanceView._wall_ahead(r, box.center, 0.1), "a wall where the ball goes")
	assert_false(LanceView._wall_ahead(r, Vector2(9999, 9999), 0.1), "none in the open")
	v._walls.append([Vector3(1, 0.5, 1), 0.0, Vector3.RIGHT])
	_layer.begin(2.0)
	v.draw_fx(_layer)
	assert_gt(_layer.used(&"ring"), 0, "V19: a flash where the wall stopped it")
	assert_gt(_layer.used(&"flake"), 0, "and Frost's extra")


# --- V18, V36: the long trails -------------------------------------------------------------------------------------
func test_a_spiral_bolt_and_a_full_charge_take_the_long_trail() -> void:
	var f := _forms()
	var look := AttackFormLooks.compose({"form": 1, "spiral": 1, "elements": PackedStringArray()})
	assert_true(LiveBoltLook.of(look, f).helix, "Spiral: the helix cue")
	var plain := AttackFormLooks.compose({"form": 1, "elements": PackedStringArray(["frost"])})
	var trail := PackedVector2Array()
	for k in 12:
		trail.append(Vector2(k * 0.3, 0.0))
	for case: Array in [[look, 1.0, 9], [plain, 1.0, 4], [plain, 2.0, 9]]:
		f._live.clear()
		f._live.append(
			{
				"id": 1,
				"pos": trail[trail.size() - 1],
				"vel": Vector2(0.3, 0),
				"look": case[0],
				"trail": trail,
				"scale": case[1]
			}
		)
		f.draw_at(10.0)
		assert_eq(f.pool(&"bolt_edge").used, case[2], "trail segments at scale %s" % case[1])


# --- V22, V25, V26, V29, V30, V31, V47: the other forms ------------------------------------------------------------
func test_the_scatter_cone_carries_its_elements_spray() -> void:
	var v: ScatterView = add_child_autofree(ScatterView.new())
	var w := W.world(&"gun", [&"gun_scatter", &"ember_core"])
	var r := WorldReader.new(w)
	v.sync(r)
	W.run(w, 1, 0, W.S)
	v.sync(r)
	ViewPrefs.effects_density = "low"
	v.sync(r)
	assert_gt(v.cones, 0, "V47: Low keeps the cone")
	_layer.begin(float(r.tick()) + 2.0)
	v.draw_fx(_layer)
	assert_gt(_layer.used(&"ember"), 0, "V22: an ember spray over the cone")


func test_the_glaive_sheds_its_accent_loses_its_ghosts_at_low_and_flashes_on_the_catch() -> void:
	var v: GlaiveView = add_child_autofree(GlaiveView.new())
	var w := W.world(&"gun", [&"gun_glaive", &"venom_core"])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	for t in 4:
		W.run(w, 1, 0, 0)
		v.sync(r)
	assert_gt(v.ghosts, 0, "afterimages at High")
	_layer.begin(float(r.tick()))
	v.draw_fx(_layer)
	assert_gt(_layer.used(&"bubble") + _layer.used(&"drop"), 0, "V25: Venom drips off the rim")
	ViewPrefs.effects_density = "low"
	v.sync(r)
	assert_eq(v.ghosts, 0, "V47: Low drops the afterimages")
	ViewPrefs.effects_density = "high"
	for t in 120:
		W.run(w, 1, 0, 0)
		v.sync(r)
		if v.caught > 0:
			break
	assert_eq(v.caught, 1, "V26: caught at the hand")
	assert_eq(v.catches, 1, "its flash plays")
	_layer.begin(float(r.tick()) + 1.0)
	v.draw_fx(_layer)
	assert_gt(_layer.used(&"ring"), 0, "the catch flash")


func test_the_seekers_trail_becomes_the_elements_own_sprites() -> void:
	var v: SeekersView = add_child_autofree(SeekersView.new())
	v.vfx_on = true
	var w := W.world(&"gun", [&"gun_seekers", &"ember_core"], [[Vector2(5.0, 1.0), 100000]])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	for t in 6:
		W.run(w, 1, 0, 0)
		v.sync(r)
	assert_gt(v.motes, 0)
	var round := 0
	for m in v._motes:
		round += 1 if m.visible else 0
	assert_eq(round, 0, "V29: no round motes with an element")
	_layer.begin(float(r.tick()))
	v.draw_fx(_layer)
	assert_eq(_layer.used(&"ember"), v.motes, "one ember for each mote: the same count")
	ViewPrefs.effects_density = "low"
	v.sync(r)
	assert_lte(v.motes, v.darts * SeekersView.LOW_MOTES, "V47: Low keeps two motes a dart")


func test_the_wave_and_the_wisps_carry_their_elements_accent() -> void:
	var wave: WaveView = add_child_autofree(WaveView.new())
	var w := W.world(&"gun", [&"gun_wave", &"frost_core"])
	var r := WorldReader.new(w)
	W.run(w, 1, 0, W.S)
	wave.sync(r)
	assert_eq(wave.waves, 1)
	_layer.begin(float(r.tick()))
	wave.draw_fx(_layer)
	assert_gt(_layer.used(&"glow"), 0, "V30: Frost's accent at its foot")
	var plain: WaveView = add_child_autofree(WaveView.new())
	var pw := W.world(&"gun", [&"gun_wave"])
	var pr := WorldReader.new(pw)
	W.run(pw, 1, 0, W.S)
	plain.sync(pr)
	_layer.begin(float(pr.tick()))
	plain.draw_fx(_layer)
	assert_gt(_layer.used(&"smoke"), 0, "no element: a skim of dust")
	var wisps: WispsView = add_child_autofree(WispsView.new())
	var ww := W.world(&"gun", [&"gun_wisps", &"storm_core"], [[Vector2(3.0, 0.0), 100000]])
	var wr := WorldReader.new(ww)
	var fired := false
	for t in 90:
		W.run(ww, 1, 0, 0)
		wisps.sync(wr)
		_layer.begin(float(wr.tick()))
		wisps.draw_fx(_layer)
		fired = fired or _layer.used(&"ring") > 0
	assert_gt(wisps.wisps, 0)
	assert_gt(
		_layer.used(&"bolt") + _layer.used(&"glow"), 0, "V31: Lightning's accent on each wisp"
	)
	assert_true(fired, "a wisp flashes as it fires")
