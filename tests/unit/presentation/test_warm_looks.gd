extends GutTest
## The looks no node shows when a floor opens are drawn once behind the loading cover too (ShaderWarmup, a view's
## warm_looks()), so a fight never compiles them: a wall's faded look (swapped in when it hides the hero), the heat
## effects' templates (each burst draws copies of them) and the Stone Thrower's rock.


class LookView:
	extends Node3D
	var looks: Array = []

	func warm_looks() -> Array:
		return looks


func _view() -> Array:
	var root := Node3D.new()
	add_child_autofree(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	var actors := ActorViews.new()
	root.add_child(actors)
	return [root, cam, actors]


func test_the_warmup_draws_each_look_a_view_gives_once() -> void:
	if not RenderSwitches.SHADER_WARMUP:
		pass_test("switched off")
		return
	var v := _view()
	var quad := QuadMesh.new()
	var faded := StandardMaterial3D.new()
	faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var lv := LookView.new()
	lv.looks = [[quad, faded], [quad, faded], [quad, null], [null, faded]]
	(v[0] as Node3D).add_child(lv)
	var w := ShaderWarmup.build(v[0], v[1], v[2])
	autofree(w)
	assert_eq(w.look_proxies, 1, "the pair once; a pair missing its mesh or material is left out")
	var found := false
	for c in w.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override == faded:
			found = (c as MeshInstance3D).mesh == quad
	assert_true(found, "drawn on its own mesh, with its own material")


func test_the_heat_effects_burst_from_the_templates_the_warmup_draws() -> void:
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var kit := KitView.new()
	add_child_autofree(kit)
	var fx := HeatVisuals.new(kit, actors)
	add_child_autofree(fx)
	var looks := fx.warm_looks()
	assert_eq(looks.size(), 4, "steam, ember, ring and flash")
	var meshes := []
	for look: Array in looks:
		assert_not_null(look[0])
		assert_true(look[1] is StandardMaterial3D)
		meshes.append(look[0])
	fx._blast(
		{
			"vent_pos": Vector2.ZERO,
			"vent_radius": 2.0,
			"vent_heat": 50,
			"max": 100,
			"meltdown": false,
			"hot": 60,
			"overclock": 80
		}
	)
	fx._steam(Vector2.ZERO, 1.0)
	assert_gt(fx.fx_count(), 0)
	for e: Array in fx._fx:
		var n := e[0] as MeshInstance3D
		assert_has(meshes, n.mesh, "every effect draws a mesh the warm-up drew")
		var m := e[1] as StandardMaterial3D
		var same := false
		for look: Array in looks:
			var t := look[1] as StandardMaterial3D
			same = (
				same
				or (
					look[0] == n.mesh
					and t.shading_mode == m.shading_mode
					and t.transparency == m.transparency
					and t.cull_mode == m.cull_mode
					and t.blend_mode == m.blend_mode
					and t.depth_draw_mode == m.depth_draw_mode
				)
			)
		assert_true(same, "and a copy of a warmed template on it (the same shader)")


func test_a_kit_gives_each_faded_look_on_a_mesh_of_its_pieces() -> void:
	if KitModels.get_piece(&"rock_large").is_empty():
		pass_test("the kit's rock is not installed")
		return
	var kit := StageKit.new()
	var at := Transform3D(Basis(), Vector3(2, 0, 0))
	var rock := {"piece": &"rock_large", "xform": at, "wall": 0, "kind": &"cover"}
	var other := rock.duplicate()
	other["xform"] = at.translated(Vector3(3, 0, 0))
	kit.build([rock, other], 1, Color.GRAY, BiomeMood.new())
	add_child_autofree(kit)
	var looks := kit.warm_looks()
	assert_eq(looks.size(), 1, "one look for the pieces sharing a material")
	var piece := kit.wall_pieces[0][0] as MeshInstance3D
	var solid := piece.material_override
	kit.set_faded(PackedInt32Array([0]))
	assert_eq(looks[0][0], piece.mesh, "on the mesh the pieces draw")
	assert_eq(looks[0][1], piece.material_override, "the very faded copy a fade swaps in")
	assert_ne(piece.material_override, solid)


func test_the_rock_a_thrower_throws_is_the_look_the_warmup_draws() -> void:
	var rocks := RuinsRocksViews.new()
	add_child_autofree(rocks)
	var looks := rocks.warm_looks()
	assert_eq(looks.size(), 1)
	var mi := rocks._boulder()
	assert_eq(looks[0][0], mi.mesh, "the thrown rock's mesh")
	assert_eq(looks[0][1], mi.material_override, "and the one material every rock shares")
	mi.free()
