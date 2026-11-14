extends GutTest
## Every catalogued pack effect stays under a triangle budget, counted with every particle alive (amount x the draw
## passes' triangles, plus each mesh). The pack's scenes used Godot's default primitive segments (a 64x32 sphere,
## a 32x32-subdivided quad) even for particles a dozen pixels wide at the game camera, so one beam drew over half a
## million triangles; those meshes now have the segments their size on screen needs. A new pack scene or a
## re-import that brings the dense defaults back fails here instead of quietly costing the frame.

## The most triangles one catalogued effect may draw. The heaviest after the cuts is about 140,000 (the rail blast,
## whose larger end particles keep 40 segments); the budget leaves headroom above it.
const BUDGET := 200_000
## A particle draw pass mesh may not be a sphere with more segments than this; the cut particle spheres have at most 40.
const MAX_PARTICLE_SPHERE_SEGMENTS := 48
## A particle quad or plane draws as a flat card unless its material moves vertices, so a subdivided one is waste.
const MAX_FLAT_PARTICLE_CARD_TRIANGLES := 2


static func _tris(m: Mesh) -> int:
	return 0 if m == null else m.get_faces().size() / 3


## Triangles the scene draws with every particle alive.
static func _count(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D:
		t += _tris((n as MeshInstance3D).mesh)
	elif n is GPUParticles3D:
		var p := n as GPUParticles3D
		for k in p.draw_passes:
			t += _tris(p.get_draw_pass_mesh(k)) * p.amount
	elif n is CPUParticles3D:
		t += _tris((n as CPUParticles3D).mesh) * (n as CPUParticles3D).amount
	for c in n.get_children():
		t += _count(c)
	return t


static func _moves_vertices(mat: Material) -> bool:
	if not mat is ShaderMaterial or (mat as ShaderMaterial).shader == null:
		return false
	var code := (mat as ShaderMaterial).shader.code
	var at := code.find("void vertex")
	if at < 0:
		return false
	for line in code.substr(at).split("\n"):
		var l := line.strip_edges()
		if l.begins_with("VERTEX") and not l.begins_with("VERTEX)"):
			if l.contains("displacement_scale"):
				var v: Variant = (mat as ShaderMaterial).get_shader_parameter(&"displacement_scale")
				return v != null and float(v) != 0.0
			return true
		if l.begins_with("void fragment"):
			break
	return false


func _scenes() -> Dictionary:
	var def := PackFx.shared_def()
	assert_not_null(def, "the pack table loads")
	var out := {}
	for k in def.count():
		if not out.has(def.scenes[k]):
			out[def.scenes[k]] = String(def.ids[k])
	return out


func test_every_catalogued_effect_is_under_the_triangle_budget() -> void:
	var over := PackedStringArray()
	var scenes := _scenes()
	for path: String in scenes:
		var node := (load(path) as PackedScene).instantiate()
		var t := _count(node)
		node.free()
		if t > BUDGET:
			over.append("%s (%s): %d" % [scenes[path], path.get_file(), t])
	assert_gt(scenes.size(), 100, "the table names the pack's scenes")
	assert_eq(over.size(), 0, "effects over %d triangles: %s" % [BUDGET, ", ".join(over)])


func test_particle_meshes_have_the_segments_their_size_needs() -> void:
	var bad := PackedStringArray()
	var scenes := _scenes()
	for path: String in scenes:
		var node := (load(path) as PackedScene).instantiate()
		for p: GPUParticles3D in node.find_children("*", "GPUParticles3D", true, false):
			var m := p.draw_pass_1
			var mat := p.material_override
			if mat == null and m is PrimitiveMesh:
				mat = (m as PrimitiveMesh).material
			# A material that moves vertices needs the mesh's density for its displacement; only its silhouette
			# is checked here when it does not.
			if _moves_vertices(mat):
				continue
			if m is SphereMesh and (m as SphereMesh).radial_segments > MAX_PARTICLE_SPHERE_SEGMENTS:
				bad.append(
					"%s %s: sphere %d segments" % [path.get_file(), p.name, m.radial_segments]
				)
			if m is QuadMesh or m is PlaneMesh:
				if _tris(m) > MAX_FLAT_PARTICLE_CARD_TRIANGLES:
					bad.append(
						"%s %s: flat card of %d triangles" % [path.get_file(), p.name, _tris(m)]
					)
		node.free()
	assert_eq(bad.size(), 0, "dense particle meshes: %s" % ", ".join(bad))
