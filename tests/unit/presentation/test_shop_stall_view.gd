extends GutTest
## v0.8.0 SR (owner O13): the shop's tent stall and its vendor. The stall is built from the sim's shop room (a floor as
## Main builds it), in every biome with its own vendor stand-in; the vendor turns to face you when you come near and
## back when you leave, nods on a sale, shakes its head on a refusal, idles (breathing, a look round), and respects
## reduced motion; the lantern glows from creation; the owner's models replace the stand-ins when the manifest lists
## them (ShopModels). The owner's desert stall is listed (shop_tent): its vendor is fused into the mesh, so the code
## vendor is hidden over it and the lantern shows the sale and the refusal. The stand-in tests read a manifest that
## lists nothing.

const BIOMES: Array[StringName] = [
	&"ruins", &"night_rocks", &"red_canyon", &"frozen_shore", &"starfall"
]
const TEST_MANIFEST := "user://test_shop_manifest.json"
const EMPTY_MANIFEST := "user://test_shop_manifest_empty.json"
## v0.9.0 MI2: the device ids whose owner models are installed (assets/models/devices/<id>.glb in the manifest).
const MI2_DEVICES: Array[StringName] = [
	&"floor_receiver",
	&"arrival_altar",
	&"lockdown_seal",
	&"rune_switch",
	&"rune_pillar",
	&"rune_mural",
	&"cracked_wall",
	&"cracked_wall_broken",
	&"purple_rune_dais",
	&"shrine_fortune",
	&"shrine_blood",
	&"shrine_chaos",
	&"healing_fountain",
]

var _w: World


func before_all() -> void:
	_w = SaveLab.floor_world(11, 1)


func after_each() -> void:
	ViewPrefs.reduced_motion = false
	ShopModels.manifest = ShopModels.MANIFEST
	ShopModels.clear_cache()
	for path in [TEST_MANIFEST, EMPTY_MANIFEST]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## The stand-ins: a manifest that lists no shop model.
func _stand_ins() -> void:
	var f := FileAccess.open(EMPTY_MANIFEST, FileAccess.WRITE)
	f.store_string(JSON.stringify({"models": []}))
	f.close()
	ShopModels.manifest = EMPTY_MANIFEST
	ShopModels.clear_cache()


func _view(biome: StringName = &"ruins") -> ShopStallView:
	var v := ShopStallView.new()
	add_child_autofree(v)
	v.set_process(false)
	v.setup(WorldReader.new(_w), biome)
	v.vendor.set_process(false)
	return v


## TEST HELPER (labelled): the player put at q (the view reads it; the e2e walks there by input).
func _put(q: Vector2) -> void:
	_w.actors.pos_x[0] = q.x
	_w.actors.pos_y[0] = q.y


func _frames(v: ShopStallView, n: int) -> void:
	for k in n:
		v._process(1.0 / 60.0)
		v.vendor.step(1.0 / 60.0)


func test_the_stall_is_built_in_every_biome_with_its_vendor() -> void:
	_stand_ins()
	var reader := WorldReader.new(_w)
	assert_true(reader.shop_stall(), "the floor's shop is a stall")
	var heights := {}
	for b in BIOMES:
		var v := _view(b)
		assert_false(v.tent_from_model, "%s: the stand-in tent (no model listed)" % b)
		assert_false(v.vendor.from_model, "%s: the stand-in vendor" % b)
		assert_eq(v.vendor.biome, b)
		assert_gt(v.root.get_child_count(), 25, "%s: the tent has its pieces" % b)
		assert_gt(
			v.vendor.find_children("*", "MeshInstance3D", true, false).size(),
			12,
			"%s: vendor parts" % b
		)
		assert_not_null(v.lantern(), "the hanging lantern's light")
		assert_gte(v.light_count(), 1)
		for m in [v.materials()[0], v.vendor.eye_material()]:
			assert_true((m as StandardMaterial3D).emission_enabled, "glow on from creation")
		# The vendor stands behind the counter, inside the tent's footprint, facing the way in.
		var at := SimPlane.to_sim(v.vendor.global_position)
		var front := Kin.dir(reader.shop_angle())
		assert_lt((at - reader.shop_pos()).dot(front), -0.4, "%s: behind the counter" % b)
		heights[b] = v.vendor.height()
	assert_eq(
		heights,
		{
			&"ruins": 1.6,
			&"night_rocks": 1.7,
			&"red_canyon": 1.7,
			&"frozen_shore": 1.7,
			&"starfall": 1.8
		}
	)


func test_the_vendor_turns_to_you_when_you_come_near() -> void:
	_stand_ins()
	var v := _view()
	var reader := WorldReader.new(_w)
	var front := Kin.dir(reader.shop_angle())
	var side := Vector2(-front.y, front.x)
	_put(reader.shop_pos() + front * 2.0 + side * 2.0)
	v.sync(reader)
	_frames(v, 60)
	assert_true(v.vendor.has_target(), "near: it looks at you")
	assert_true(v.vendor.facing_target(), "it has turned to you")
	var yaw_left := v.vendor.yaw()
	assert_gt(absf(yaw_left), 0.3, "it turned")
	_put(reader.shop_pos() + front * 2.0 - side * 2.0)
	v.sync(reader)
	_frames(v, 60)
	assert_true(v.vendor.facing_target())
	assert_lt(yaw_left * v.vendor.yaw(), 0.0, "it follows you to the other side")
	# Facing you: its front (+X of the vendor) points at you.
	var fwd := SimPlane.to_sim(v.vendor.global_transform.basis.x).normalized()
	var to_you := (_w.player_pos() - SimPlane.to_sim(v.vendor.global_position)).normalized()
	assert_gt(fwd.dot(to_you), 0.95, "it faces the player")
	_put(reader.shop_pos() + front * (ShopStallView.NEAR_M + 3.0))
	v.sync(reader)
	_frames(v, 90)
	assert_false(v.vendor.has_target(), "far: back to its counter")
	assert_almost_eq(v.vendor.yaw(), 0.0, 0.01)


func test_it_nods_on_a_sale_and_shakes_its_head_on_a_refusal() -> void:
	_stand_ins()
	var v := _view()
	var reader := WorldReader.new(_w)
	_put(ShopPlacement.front(_w.floor_layout))
	v.sync(reader)
	assert_true(v.hot(), "in reach")
	_w.shards = 500
	_w.input_buffer[3] = 1
	assert_true(Shop.interact(_w), "the shop opens at the counter")
	_w.actors.hp[0] = 10
	Shop.heal(_w)
	v.sync(reader)
	assert_true(v.vendor.nodding(), "a purchase: a nod")
	_frames(v, 10)
	assert_lt(v.vendor.head_rotation().z, -0.05, "its head dips")
	Shop.heal(_w)  # once per shop: refused
	v.sync(reader)
	assert_true(v.vendor.shaking(), "a refusal: a shake")
	assert_false(v.vendor.nodding())
	var turns := []
	for k in 30:
		_frames(v, 1)
		turns.append(v.vendor.head_rotation().y)
	assert_gt(turns.max() - turns.min(), 0.3, "its head shakes side to side")
	_frames(v, 60)
	assert_false(v.vendor.shaking())
	assert_false(v.vendor.nodding())
	_w.shop.open = false


func test_it_idles_and_respects_reduced_motion() -> void:
	_stand_ins()
	var v := _view(&"starfall")
	var reader := WorldReader.new(_w)
	_put(reader.shop_pos() + Kin.dir(reader.shop_angle()) * 20.0)
	v.sync(reader)
	var looks := []
	var breaths := []
	for k in 600:
		_frames(v, 1)
		looks.append(v.vendor.head_rotation().y)
		breaths.append(v.vendor.get_child(0).get_child(0).scale.y)
	assert_gt(looks.max() - looks.min(), 0.2, "it looks round")
	assert_gt(breaths.max() - breaths.min(), 0.02, "it breathes")
	ViewPrefs.reduced_motion = true
	var calm := _view(&"starfall")
	calm.sync(reader)
	for k in 120:
		_frames(calm, 1)
		assert_eq(calm.vendor.head_rotation(), Vector3.ZERO, "reduced motion: no look round")
		assert_eq(calm.vendor.get_child(0).position.y, 0.0, "no hover")
	var front := Kin.dir(reader.shop_angle())
	_put(reader.shop_pos() + front * 2.0 + Vector2(-front.y, front.x) * 2.0)
	calm.sync(reader)
	assert_true(calm.vendor.facing_target(), "reduced motion: it turns to you at once")
	calm.vendor.nod()
	var base := calm.vendor.eye_material().emission_energy_multiplier
	_frames(calm, 5)
	assert_true(calm.vendor.nodding())
	assert_eq(calm.vendor.head_rotation(), Vector3.ZERO, "the nod is not a movement")
	assert_gt(calm.vendor.eye_material().emission_energy_multiplier, base, "it is a glow")
	calm.vendor.shake()
	_frames(calm, 5)
	assert_eq(calm.vendor.eye_material().emission, ShopVendor.DENY_GLOW, "a refusal glows red")
	assert_eq(calm.vendor.head_rotation(), Vector3.ZERO)


## The owner's desert stall (assets/models/shop/shop_tent.glb) is the stall in every biome: scaled to 2.55 m, inside
## the stall's 4.0 x 3.4 m footprint; its fused vendor stands in for the code one (hidden), its own goods for the
## counter's; the lantern brightens on a sale and reddens on a refusal. No vendor or goods model is listed yet.
func test_the_owners_stall_is_the_tent() -> void:
	assert_eq(ShopModels.listed_path(&"shop_tent"), "res://assets/models/shop/shop_tent.glb")
	var tent := ShopModels.get_model(&"shop_tent")
	assert_false(tent.is_empty(), "the owner's stall loads")
	var box: AABB = tent["aabb"]
	assert_almost_eq(box.size.y, 2.55, 0.01, "2.55 m to the awnings")
	assert_lt(box.size.x, ShopRoomDefinition.STALL_SIZE.y, "inside the footprint, front to back")
	assert_lt(box.size.z, ShopRoomDefinition.STALL_SIZE.x + 0.001, "and across")
	assert_almost_eq(box.get_center().x, 0.0, 0.01, "centred")
	assert_almost_eq(box.position.y, 0.0, 0.01, "on the floor")
	for id: StringName in ShopModels.SPECS:
		if String(id).begins_with("hub_"):
			continue  # v0.9.0 HB: the owner's hub pieces (test_hub_view)
		if id in MI2_DEVICES:  # v0.9.0 MI2: the owner's device models, installed (assets/models/manifest.json)
			assert_eq(
				ShopModels.listed_path(id),
				"res://assets/models/devices/%s.glb" % id,
				"%s: the owner's installed file" % id
			)
		elif id != &"shop_tent" and id != &"curse_altar":  # v0.8.0 N17: the owner's altar
			assert_eq(
				ShopModels.listed_path(id), "", "%s: the stand-in until the owner's file" % id
			)
	var reader := WorldReader.new(_w)
	for b in [&"red_canyon", &"frozen_shore"]:
		var v := _view(b)
		assert_true(v.tent_from_model, "%s: the owner's stall" % b)
		assert_false(v.vendor.visible, "%s: its fused vendor, the code one hidden" % b)
		for c in v.get_children():
			if c != v.root and c is Node3D:
				var at := SimPlane.to_sim((c as Node3D).position)
				assert_gt(
					Kin.length(at - reader.shop_pos()), 2.1, "no stand-in goods on its counter"
				)
	var v := _view(&"red_canyon")
	_put(ShopPlacement.front(_w.floor_layout))
	v.sync(reader)
	_frames(v, 2)
	var calm: Array = v.lantern_state()
	v.vendor.nod()
	_frames(v, 2)
	assert_gt(float(v.lantern_state()[0]), float(calm[0]) * 1.3, "a sale: the lantern brightens")
	_frames(v, 60)
	v.vendor.shake()
	_frames(v, 2)
	var c: Color = v.lantern_state()[1]
	assert_gt(
		c.r - c.g,
		(ShopStallView.LANTERN.r - ShopStallView.LANTERN.g) + 0.2,
		"a refusal: it reddens"
	)


## The hook: a model the manifest lists replaces its stand-in, turned and scaled to the stand-in's numbers. A kit
## piece stands in for the owner's files here (crate_stack as the tent, dead_tree as the vendor and the goods).
func test_a_listed_model_replaces_its_stand_in() -> void:
	var listing := {
		"models":
		[
			{"id": "shop_tent", "path": "assets/models/kit/crate_stack.glb"},
			{"id": "shop_vendor_ruins", "path": "assets/models/kit/dead_tree.glb"},
			{"id": "shop_wares", "path": "assets/models/kit/dead_tree.glb"},
		]
	}
	var f := FileAccess.open(TEST_MANIFEST, FileAccess.WRITE)
	f.store_string(JSON.stringify(listing))
	f.close()
	ShopModels.manifest = TEST_MANIFEST
	ShopModels.clear_cache()
	var tent := ShopModels.get_model(&"shop_tent")
	assert_false(tent.is_empty(), "the listed tent loads")
	var box: AABB = tent["aabb"]
	assert_almost_eq(box.size.y, 2.55, 0.01, "scaled to the stall's height")
	assert_almost_eq(box.position.y, 0.0, 0.01, "on the floor")
	var vendor := ShopModels.get_model(&"shop_vendor_ruins")
	assert_almost_eq((vendor["aabb"] as AABB).size.y, 1.6, 0.01, "the vendor at its height")
	assert_true(
		ShopModels.get_model(&"shop_vendor_starfall").is_empty(),
		"an unlisted one keeps its stand-in"
	)
	var v := _view(&"ruins")
	assert_true(v.tent_from_model, "the tent is the model")
	assert_true(v.vendor.from_model, "the vendor is the model")
	assert_false(v.vendor.visible, "hidden under a stall model (its vendor is the stall's)")
	var reader := WorldReader.new(_w)
	_put(ShopPlacement.front(_w.floor_layout))
	v.sync(reader)
	v.vendor.nod()
	_frames(v, 10)
	assert_true(v.vendor.nodding(), "a model vendor still reacts")
	var other := _view(&"starfall")
	assert_false(other.vendor.from_model, "Starfall's vendor is still the stand-in")
