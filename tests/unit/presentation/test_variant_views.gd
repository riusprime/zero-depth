extends GutTest
## v0.11.0 O13a (ENEMIES.md V1-V5): the variants' looks, read through WorldReader (EI-07): each is its base's body
## (never the VAT crowd's), the Rubble Warden wears its crust until it falls and its rocks stand where the sim has them,
## the trails are drawn while they last, a Dim Needle's shot draws dark beyond 4 m and lit within.

const K := ActorStore.Kind


func _world() -> World:
	var w := CombatLab.world()
	w.actors.invuln[0] = 1 << 24
	return w


func test_a_variant_is_its_bases_body_and_never_the_vat_crowds() -> void:
	var pairs := {
		WorldReader.KIND_RUBBLE_WARDEN: WorldReader.KIND_WARDEN,
		WorldReader.KIND_DIM_NEEDLE: WorldReader.KIND_NEEDLE,
		WorldReader.KIND_EMBER_CHARGER: WorldReader.KIND_CHARGER,
		WorldReader.KIND_FROST_CHARGER: WorldReader.KIND_CHARGER,
		WorldReader.KIND_SPLIT_SNIPER: WorldReader.KIND_SNIPER,
	}
	for v: int in pairs:
		assert_eq(WorldReader.body_kind(v), pairs[v])
		assert_false(VatCrowd.supports(v), "kind %d: drawn as its own nodes, in its cast" % v)
		assert_true(VariantLooks.is_variant(v))
		assert_ne(VariantLooks.cast(v, Color(0, 0, 0, 0)).a, 0.0, "kind %d: its biome's cast" % v)
	assert_eq(
		VariantLooks.cast(WorldReader.KIND_CHARGER, Color.RED), Color.RED, "others: the floor's"
	)


func test_the_crust_shows_until_it_falls_and_its_rocks_stand() -> void:
	var w := _world()
	w.add_enemy(K.RUBBLE_WARDEN, Vector2(5, 0))
	var i := w.actors.size() - 1
	var reader := WorldReader.new(w)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var fx := VariantViews.new()
	add_child_autofree(fx)
	actors.sync(reader)
	fx.sync(reader)
	var node := actors.actor_node(w.actors.ids[i])
	if not node.has_meta(&"crust"):
		pending("the kit's boulder is not installed: no crust to draw")
		return
	var crust: Node3D = node.get_meta(&"crust")
	assert_true(crust.visible, "in its crust")
	assert_eq(fx.rock_count(), 0)
	w.actors.hp[i] = 20
	w.step(InputFrame.new())
	actors.sync(reader)
	fx.sync(reader)
	assert_false(crust.visible, "the crust fell")
	assert_eq(fx.rock_count(), w.variants.rubble_count(), "a rock where each piece stands")
	assert_gt(fx.rock_count(), 0)


func test_the_trails_are_drawn_while_they_last() -> void:
	var w := _world()
	w.variants.add_trail(Variants.TRAIL_FIRE, Vector2(2, 0), 0.6, 0, 120, 24, 5, 30, 9)
	w.variants.add_trail(Variants.TRAIL_SLICK, Vector2(-2, 0), 0.8, 0, 360, 0, 40, 0, 9)
	var reader := WorldReader.new(w)
	var fx := VariantViews.new()
	add_child_autofree(fx)
	fx.sync(reader)
	assert_eq(fx.trail_count(), 2)
	var t := reader.variant_trails()
	assert_eq(t["kind"], PackedInt32Array([WorldReader.TRAIL_FIRE, WorldReader.TRAIL_SLICK]))
	assert_eq(t["lit"], PackedByteArray([0, 0]), "fresh fire is not burning yet")
	for _k in 130:
		w.step(InputFrame.new())
	fx.sync(reader)
	assert_eq(fx.trail_count(), 1, "the fire is gone after 2 s, the slick stays")


func test_a_dim_needles_shot_draws_dark_far_and_lit_near() -> void:
	var w := _world()
	w.queue_projectile(99, ActorStore.TEAM_ENEMY, Vector2(8, 0), Vector2(-0.1, 0), 5, 0.12, 200, 0)
	w.set_pending_look(WorldReader.DIM_LOOK)
	w.step(InputFrame.new())
	var reader := WorldReader.new(w)
	var fb := FireballViews.new()
	add_child_autofree(fb)
	fb.sync(reader)
	assert_eq(fb.ball_count(FireballViews.DIM_DARK_LOOK), 1, "far: dark")
	assert_eq(fb.ball_count(WorldReader.DIM_LOOK), 0)
	w.projectiles.pos_x[0] = 3.0
	fb.sync(reader)
	assert_eq(fb.ball_count(WorldReader.DIM_LOOK), 1, "near: lit")
	assert_eq(fb.ball_count(FireballViews.DIM_DARK_LOOK), 0)
	assert_lt(FireballViews.look_of(FireballViews.DIM_DARK_LOOK)["core"].get_luminance(), 0.1)
