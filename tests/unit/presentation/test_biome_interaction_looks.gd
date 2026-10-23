extends GutTest
## v0.9.0 BV (owner W71, §11 Biomes: "share scripts … different models, sounds, and visual effects"): every Wave 4
## interaction picks its biome's look (InteractionLooks) in all five biomes: the timed door and its switches, the rune
## pillars and carving, the cracked wall, the containers and the explosive barrel, the hidden markings, the purple-rune
## dais, the Lockdown bars and hazard, the shrines and the fountain. The owner's models are tinted, not replaced; the
## code stand-ins take the biome's colours; each biome adds its accent. The hostile warnings stay out of the hero's
## attack colours. And a floor's view (WorldViewRoot) hands its biome to the views that have no stage.

const LONG := 1 << 24

var _timed: World
var _rune: World
var _crack: World
var _props: World
var _lock: World
var _purple: World
var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_timed = TimedLab.world()
	_rune = RuneLab.world()
	_crack = CrackLab.world(&"blade")
	_props = CrackLab.world(&"blade", false)
	if _props != null:
		var at := _props.floor_layout.start_pos + Vector2(0.0, 3.0)
		_props.breakables.add(at, Breakables.Kind.CRATE, 0, 0, 0)
		_props.breakables.add(at + Vector2(2.0, 0.0), Breakables.Kind.URN, 0, 0, 0)
		_props.breakables.add(at + Vector2(4.0, 0.0), Breakables.Kind.EXPLOSIVE, 0, 0, 0)
	_lock = LockLab.world()
	for s in range(1, 41):
		var w := SaveLab.floor_world(s, 2)
		if w.purple != null:
			w.actors.invuln[0] = LONG
			w.spawner = null
			w.boss_flow.arrive_left = 0
			_purple = w
			break


func _stage(biome: StringName) -> StageView:
	var s := StageView.new()
	s.prop_style = biome
	autofree(s)
	return s


func _cover(biome: StringName) -> Color:
	var def: BiomeDefinition = _repo.get_def(&"biomes", biome)
	return def.palette["cover"]


## The albedo the owner's model shows under `biome`: its delivered material's times the biome's tint.
func _tinted_albedo(id: StringName, biome: StringName) -> Color:
	var mat := ShopModels.get_model(id)["material"] as StandardMaterial3D
	return mat.albedo_color * (InteractionLooks.look(biome)["tint"] as Color)


func _model_albedo(mi: MeshInstance3D) -> Color:
	var m := mi.get_surface_override_material(0)
	if m == null:
		m = mi.material_override
	return (m as StandardMaterial3D).albedo_color


func test_the_five_biomes_have_five_looks() -> void:
	assert_eq(InteractionLooks.BIOMES.size(), 5)
	var repo := _repo
	assert_eq(repo.count(&"biomes"), 5, "five biomes in data")
	for b in InteractionLooks.BIOMES:
		assert_not_null(repo.get_def(&"biomes", b), "%s is a biome in data" % b)
		assert_eq(InteractionLooks.resolve(b), b, "%s has its own look" % b)
	assert_eq(InteractionLooks.resolve(&""), &"ruins", "a bare stage draws Ruins' look")
	for key in ["rune", "glyph", "tint", "metal", "wood", "clay", "water", "marking"]:
		var seen := {}
		for b in InteractionLooks.BIOMES:
			seen[InteractionLooks.color(b, key).to_html()] = true
		assert_eq(seen.size(), 5, "five different %s colours" % key)
	for b in InteractionLooks.BIOMES:
		assert_ne(
			InteractionLooks.color(b, "rune"),
			InteractionLooks.color(b, "glyph"),
			"%s: a matched rune reads apart from a shown one" % b
		)


func test_hostile_warnings_keep_out_of_the_heros_attack_colours() -> void:
	var hero: Array[Color] = [ThemePalette.color(&"player_core")]
	for c: Color in AttackFormLooks.ELEMENT_CORE.values():
		hero.append(c)
	var hostile: Array[Color] = [LockdownView.WARN, LockdownView.SPARK, LockdownView.PLUME]
	for c: Color in LockdownView.STAND_IN_BODY.values():
		hostile.append(c)
	for h in hostile:
		for c in hero:
			var d := Vector3(h.r - c.r, h.g - c.g, h.b - c.b).length()
			assert_gt(
				d, 0.2, "hostile #%s is far from hero #%s" % [h.to_html(false), c.to_html(false)]
			)
	assert_true(AttackFormLooks.is_hostile_hue(LockdownView.WARN), "the warning is a hostile hue")
	for b in InteractionLooks.BIOMES:
		var rim := InteractionLooks.color(b, "warn_rim")
		assert_lt(rim.get_luminance(), 0.2, "%s: the warning's band is dark" % b)


func test_the_timed_door_and_switches_per_biome() -> void:
	assert_not_null(_timed, "a floor with a timed door")
	if _timed == null:
		return
	var reader := WorldReader.new(_timed)
	for b in InteractionLooks.BIOMES:
		var v := TimedDoorView.new()
		add_child_autofree(v)
		v.setup(reader, _stage(b), _cover(b))
		assert_eq(v.biome, b)
		assert_eq(v.rune_color, InteractionLooks.color(b, "rune"), "%s: the rune colour" % b)
		var sw := v.get_node("RuneSwitch0") as Node3D
		var rune := sw.get_node("Rune") as MeshInstance3D
		assert_eq(
			(rune.material_override as StandardMaterial3D).emission,
			InteractionLooks.color(b, "rune"),
			"%s: the switch's rune" % b
		)
		assert_true(sw.has_node("Accent"), "%s: the biome's touch at the switch" % b)
		assert_true(v.get_node("Door/Foot").has_node("Accent"), "%s: and at the jambs" % b)
		assert_eq(
			(v.get_node("RoomLight") as OmniLight3D).light_color,
			InteractionLooks.color(b, "room"),
			"%s: the room's light" % b
		)
		if v.switch_uses_model:
			assert_eq(
				_model_albedo(sw.get_node("Model")),
				_tinted_albedo(&"rune_switch", b),
				"%s: the owner's switch, tinted" % b
			)


func test_the_rune_pillars_and_carving_per_biome() -> void:
	assert_not_null(_rune, "a floor with a rune puzzle")
	if _rune == null:
		return
	var reader := WorldReader.new(_rune)
	for b in InteractionLooks.BIOMES:
		var v := RuneAlignmentView.new()
		add_child_autofree(v)
		v.setup(reader, _stage(b), _cover(b))
		assert_eq(v.biome, b)
		assert_eq(v.glyph_color, InteractionLooks.color(b, "glyph"), "%s: the glyphs" % b)
		assert_eq(v.rune_color, InteractionLooks.color(b, "rune"), "%s: the matched face" % b)
		var p := v.get_node("RunePillar0")
		assert_true(p.has_node("Accent"), "%s: the biome's touch at the pillar" % b)
		if v.uses_model:
			assert_eq(
				_model_albedo(p.get_node("Drum/Model")),
				_tinted_albedo(&"rune_pillar", b),
				"%s: the owner's pillar, tinted" % b
			)
			assert_eq(
				_model_albedo(v.get_node("Door/Slab/Mural/Model")),
				_tinted_albedo(&"rune_mural", b),
				"%s: and his carving" % b
			)


func test_the_cracked_wall_and_markings_per_biome() -> void:
	assert_not_null(_crack, "a floor with a cracked wall")
	if _crack == null:
		return
	_crack.step(InputFrame.new())
	var reader := WorldReader.new(_crack)
	for b in InteractionLooks.BIOMES:
		var v := BreakablesView.new()
		add_child_autofree(v)
		v.setup(reader, _stage(b), _cover(b))
		assert_eq(v.biome, b)
		assert_true(v.get_node("CrackedWall/Foot").has_node("Accent"), "%s: the wall's foot" % b)
		var whole := v.wall.get_node_or_null("Model") as MeshInstance3D
		if whole != null:
			assert_eq(
				_model_albedo(whole),
				_tinted_albedo(&"cracked_wall", b),
				"%s: the owner's wall, tinted" % b
			)
		var m := RuneMarkingsView.new()
		m.biome = b
		add_child_autofree(m)
		m.setup(reader)
		assert_eq(m.tint, InteractionLooks.color(b, "marking"), "%s: the markings' scratch" % b)


func test_the_containers_and_barrel_per_biome() -> void:
	assert_not_null(_props, "a floor")
	if _props == null:
		return
	var reader := WorldReader.new(_props)
	var n := _props.breakables.pos.size()
	for b in InteractionLooks.BIOMES:
		var v := BreakablesView.new()
		add_child_autofree(v)
		v.setup(reader, _stage(b), _cover(b))
		var crate := v.props[n - 3]
		var urn := v.props[n - 2]
		var keg := v.props[n - 1]
		if crate.has_node("Model"):
			continue  # the owner's containers: tinted like the wall
		var c0 := crate.get_child(0) as MeshInstance3D
		assert_eq(_model_albedo(c0), InteractionLooks.color(b, "wood"), "%s: the crate's wood" % b)
		var u0 := urn.get_child(0) as MeshInstance3D
		assert_eq(_model_albedo(u0), InteractionLooks.color(b, "clay"), "%s: the urn's clay" % b)
		var k0 := keg.get_child(0) as MeshInstance3D
		var k1 := keg.get_child(1) as MeshInstance3D
		assert_eq(_model_albedo(k0), InteractionLooks.color(b, "keg"), "%s: the barrel" % b)
		assert_eq(_model_albedo(k1), InteractionLooks.color(b, "keg_band"), "%s: its band" % b)
		var ground: Color = (_repo.get_def(&"biomes", b) as BiomeDefinition).palette["ground"]
		assert_gt(
			absf(InteractionLooks.color(b, "keg").get_luminance() - ground.get_luminance()),
			0.12,
			"%s: the barrel's body stands off the ground" % b
		)
		assert_eq(
			crate.has_node("Snow"), b == &"frozen_shore", "%s: snow on top only on the shore" % b
		)


func test_the_purple_dais_per_biome() -> void:
	assert_not_null(_purple, "a floor with the purple runes")
	if _purple == null:
		return
	var reader := WorldReader.new(_purple)
	for b in InteractionLooks.BIOMES:
		var v := PurpleRuneView.new()
		v.biome = b
		add_child_autofree(v)
		v.setup(reader, _cover(b))
		assert_true(v.has_node("Accent"), "%s: the biome's touch round the dais" % b)
		assert_eq(v.light.light_color, PurpleRuneView.SIGIL, "%s: the runes stay violet" % b)
		if v.uses_model:
			assert_eq(
				_model_albedo(v.get_node("Model")),
				_tinted_albedo(&"purple_rune_dais", b),
				"%s: the owner's dais, tinted" % b
			)


func test_the_lockdown_bars_and_hazard_per_biome() -> void:
	assert_not_null(_lock, "a floor with a Lockdown")
	if _lock == null:
		return
	var reader := WorldReader.new(_lock)
	var hazards := {}
	for b in InteractionLooks.BIOMES:
		_lock.floor_layout.lockdown_kinds[0] = WorldReader.LOCKDOWN_HAZARD
		var v := LockdownView.new()
		add_child_autofree(v)
		v.setup(reader, b)
		assert_eq(v.biome, b)
		assert_eq(v.hazard_id, LockdownView.HAZARDS[b], "%s: its own hazard" % b)
		hazards[v.hazard_id] = true
		var seal: Node3D = null
		for c in v.get_children():
			if String(c.name).begins_with("Seal"):
				seal = c
				break
		assert_not_null(seal, "%s: the bars" % b)
		var bars := seal.get_node("Bars")
		if v.uses_model:
			assert_eq(
				_model_albedo(bars.get_node("Model")),
				_tinted_albedo(&"lockdown_seal", b),
				"%s: the owner's bars, tinted" % b
			)
		else:
			assert_eq(
				_model_albedo(bars.get_child(0)),
				InteractionLooks.color(b, "metal"),
				"%s: the rods' metal" % b
			)
		var warn := v.get_node("Warning0")
		assert_true(warn.has_node("Rim"), "%s: the warning's dark band" % b)
	assert_eq(hazards.size(), 5, "five hazards")


func test_the_shrines_and_fountain_per_biome() -> void:
	for b in InteractionLooks.BIOMES:
		var w := World.new(5, PlayerTable.starting_values())
		w.gamble_id = w.take_root()
		w.gamble_pos = Vector2(3.0, -2.0)
		var s := ShrineState.new()
		s.table = ShrineTable.new()
		s.kind = ShrineTable.Kind.BLOOD
		s.pos = w.gamble_pos
		s.entry = w.interactables.add(Interactables.Kind.SHRINE, s.pos, s.table.reach_m, s.kind)
		s.fountain_pos = Vector2(-4.0, 3.0)
		s.fountain_entry = w.interactables.add(
			Interactables.Kind.FOUNTAIN, s.fountain_pos, s.table.reach_m, 0
		)
		w.shrine = s
		var v := ShrinesView.new()
		v.biome = b
		add_child_autofree(v)
		v.setup(WorldReader.new(w), _cover(b))
		assert_eq(v.water_color, InteractionLooks.color(b, "water"), "%s: the water" % b)
		assert_eq(
			v.fountain_light.light_color, InteractionLooks.color(b, "water"), "%s: its light" % b
		)
		assert_eq(v.shrine_light.light_color, ShrinesView.BLOOD, "%s: Blood stays red" % b)
		assert_true(v.shrine_root.has_node("Accent"), "%s: the shrine's foot" % b)
		assert_true(v.fountain_root.has_node("Accent"), "%s: the fountain's foot" % b)
		if v.fountain_model:
			var mi := v.fountain_root.get_node("Model") as MeshInstance3D
			assert_eq(
				(mi.material_override as StandardMaterial3D).albedo_color,
				_tinted_albedo(&"healing_fountain", b),
				"%s: the owner's fountain, tinted" % b
			)
		var g := GambleShrineView.new()
		g.kit_model = true
		g.biome = b
		add_child_autofree(g)
		g.set_process(false)
		g.setup(w.gamble_pos)
		assert_true(g.root.has_node("Accent"), "%s: the Fortune shrine's foot" % b)
		if g.uses_model() and ShopModels.listed_path(GambleShrineView.FORTUNE_ID) != "":
			assert_eq(
				(g.model().material_override as StandardMaterial3D).albedo_color,
				_tinted_albedo(GambleShrineView.FORTUNE_ID, b),
				"%s: the owner's Fortune shrine, tinted" % b
			)


func test_a_floor_view_hands_its_biome_to_every_interaction() -> void:
	assert_not_null(_purple, "a floor with the purple runes")
	if _purple == null:
		return
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"starfall")
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood
	v.stage.prop_style = biome.id
	add_child_autofree(v)
	v.setup(WorldReader.new(_purple), biome.palette, 60.0)
	assert_eq(v.purple.biome, &"starfall", "the purple dais")
	for view: Node in [
		v.timed_door, v.rune_view, v.breakables, v.lockdowns, v.shrines, v.markings, v.gamble_shrine
	]:
		if view != null:
			assert_eq(view.get(&"biome"), &"starfall", "%s draws Starfall's look" % view.name)
