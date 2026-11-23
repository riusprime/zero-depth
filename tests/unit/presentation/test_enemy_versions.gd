extends GutTest
## Each biome's own version of a base enemy wears its biome's colour over the whole body (EnemyPalettes.VERSIONS) on
## its base's model, while the base keeps its exact look; every version of a kind shares one set of body materials, so
## a crowd of them still draws as one instanced draw per piece.

const PAIRS := {
	WorldReader.KIND_EMBER_CHARGER: WorldReader.KIND_CHARGER,
	WorldReader.KIND_FROST_CHARGER: WorldReader.KIND_CHARGER,
	WorldReader.KIND_SPLIT_SNIPER: WorldReader.KIND_SNIPER,
	WorldReader.KIND_DIM_NEEDLE: WorldReader.KIND_NEEDLE,
	WorldReader.KIND_RUBBLE_WARDEN: WorldReader.KIND_WARDEN,
}


func test_every_version_has_its_own_colours_and_every_base_keeps_its_own() -> void:
	assert_eq(
		EnemyPalettes.VERSIONS.size(), BehaviourSchemas.VARIANT_OF.size(), "one row per version"
	)
	for v: int in PAIRS:
		var base: int = PAIRS[v]
		assert_true(EnemyPalettes.VERSIONS.has(v), "kind %d has its colours" % v)
		assert_false(EnemyPalettes.VERSIONS.has(base), "a base is no version")
		for slot in EnemyPalettes.SLOTS:
			var id: StringName = EnemyPalettes.KIND_IDS[base]
			assert_eq(
				EnemyPalettes.color(base, slot),
				EnemyPalettes.color_of(id, slot),
				"base %s %s: the palette's own" % [id, slot]
			)
		var vb := EnemyPalettes.color(v, &"body")
		var bb := EnemyPalettes.color(base, &"body")
		var apart := absf(vb.get_luminance() - bb.get_luminance()) + _hue_gap(vb, bb)
		assert_gt(apart, 0.2, "kind %d: its body reads apart from its base's (%.2f)" % [v, apart])
		assert_ne(EnemyPalettes.color(v, &"eye"), EnemyPalettes.color(base, &"eye"))


func test_a_version_built_on_its_bases_model_wears_its_colours() -> void:
	for v: int in PAIRS:
		var base: int = PAIRS[v]
		var mine := _albedos(_avatar(base, -1))
		var theirs := _albedos(_avatar(base, v))
		assert_true(
			mine.has(EnemyPalettes.color(base, &"body").to_html()), "base %d: its own body" % base
		)
		assert_true(
			theirs.has(EnemyPalettes.color(v, &"body").to_html()), "version %d: its body colour" % v
		)
		assert_false(
			theirs.has(EnemyPalettes.color(base, &"body").to_html()),
			"version %d: none of its base's body colour" % v
		)


func test_versions_of_a_kind_share_their_materials_and_never_the_bases() -> void:
	var a := _avatar(WorldReader.KIND_CHARGER, WorldReader.KIND_EMBER_CHARGER)
	var b := _avatar(WorldReader.KIND_CHARGER, WorldReader.KIND_EMBER_CHARGER)
	var base := _avatar(WorldReader.KIND_CHARGER, -1)
	assert_eq(a.body_looks(), b.body_looks(), "every Ember Charger: the same shared materials")
	var n := 0
	var own: Array[Color] = []
	for slot in EnemyPalettes.SLOTS:
		own.append(EnemyPalettes.color(WorldReader.KIND_EMBER_CHARGER, slot))
	for m in a.body_looks():  # (the neutral core plate both wear is one shared material)
		if own.has(m.get_shader_parameter("albedo")):
			n += 1
			assert_false(base.body_looks().has(m), "its own colours: none of them a Charger's")
	assert_gt(n, 1, "its hood and its flap in its own colours")
	var s1 := _avatar(WorldReader.KIND_SNIPER, WorldReader.KIND_SPLIT_SNIPER)
	var s2 := _avatar(WorldReader.KIND_SNIPER, WorldReader.KIND_SPLIT_SNIPER)
	assert_eq(
		_albedos(s1), _albedos(s2), "every Split Sniper: the same colours on the owner's model"
	)
	for v: int in PAIRS:
		assert_false(
			VatCrowd.supports(v), "kind %d: drawn as its own nodes (no VAT bake per colour)" % v
		)


func test_the_game_view_builds_a_version_in_its_colours() -> void:
	var w := CombatLab.world()
	w.actors.invuln[0] = 1 << 24
	var ids := {}
	var k := 0
	for v: int in PAIRS:
		ids[v] = w.add_enemy(v, Vector2(4 + 2 * k, 3))
		k += 1
	var actors := ActorViews.new()
	add_child_autofree(actors)
	actors.sync(WorldReader.new(w))
	for v: int in ids:
		var av: AvatarBase = actors.actor_node(ids[v]).get_meta(&"enemy_avatar")
		assert_eq(av.look_kind, v, "kind %d wears its own colours" % v)
		assert_true(_albedos(av).has(EnemyPalettes.color(v, &"body").to_html()), "kind %d" % v)


func _avatar(body: int, look: int) -> AvatarBase:
	var a: AvatarBase
	match body:
		WorldReader.KIND_CHARGER:
			a = ChargerAvatar.new()
		WorldReader.KIND_WARDEN:
			a = WardenAvatar.new()
		WorldReader.KIND_NEEDLE:
			a = NeedleAvatar.new()
		WorldReader.KIND_SNIPER:
			a = SniperAvatar.new()
		_:
			a = HordeAvatar.new()
	a.look_kind = look
	a.enemy_tint = VariantLooks.cast(look, Color(0, 0, 0, 0))
	a.role_glow = ActorViews.ROLE_GLOW
	if a is HordeAvatar:
		(a as HordeAvatar).setup(body)
	else:
		a.call(&"setup")
	add_child_autofree(a)
	return a


## The body colours an avatar draws with (its shared plates' and its own materials'), as html.
static func _albedos(a: AvatarBase) -> Array[String]:
	var out: Array[String] = []
	for m in a.body_looks():
		out.append((m.get_shader_parameter("albedo") as Color).to_html())
	for m in a.body_materials:
		out.append(m.albedo_color.to_html())
	return out


static func _hue_gap(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h)
	return minf(d, 1.0 - d) * minf(a.s, b.s) * 2.0
