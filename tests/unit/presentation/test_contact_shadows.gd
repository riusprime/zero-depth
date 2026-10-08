extends GutTest
## Contact shadows (v0.5.9 Step 1): one falloff quad per footprint in a single mesh, each carrying its offset from
## the footprint's centre (UV) and its half extents (UV2), so the shader darkens the ground around the block.


func test_one_quad_per_box_in_one_mesh() -> void:
	var boxes := [
		[Vector2(0, 0), Vector2(2, 0.5), 0.0],
		[Vector2(5, -3), Vector2(1, 1), PI * 0.25],
	]
	var node := ContactShadows.build(boxes, 0.9, 0.6)
	autofree(node)
	var arrays := node.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), 12, "two quads, six vertices each")
	assert_eq(node.mesh.get_surface_count(), 1, "one draw call")
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	assert_almost_eq(
		uv[0], Vector2(-2.9, -1.4), Vector2(0.001, 0.001), "corner offset = half + radius"
	)
	assert_eq(uv2[0], Vector2(2, 0.5), "half extents ride along")
	for v in verts:
		assert_almost_eq(v.y, ContactShadows.LIFT, 0.0001, "flat, just above the ground")
	# The second box is turned 45°: its corners sit at the rotated offsets around its centre (sim y -> 3D -z).
	var c := SimPlane.to_3d(Vector2(5, -3), ContactShadows.LIFT)
	var expect := c + Vector3(-1.9, 0, -1.9).rotated(Vector3.UP, PI * 0.25)
	assert_almost_eq(verts[6], expect, Vector3(0.001, 0.001, 0.001))


func test_no_boxes_no_node() -> void:
	assert_null(ContactShadows.build([], 0.9, 0.6))
