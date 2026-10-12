class_name IceViews
extends Node3D
## v0.7.5 NB1: the floor's ice patches (Frozen Shore), drawn exactly where the sim has them (WorldReader.ice_patch:
## looks slippery = is slippery). Each patch is one flat faceted sheet: 1 m facets in slightly different pale-blue
## shades, glossy so the moon glints on it, a bright frosted rim on its exact edge so its boundary reads at a
## glance, and a few dark hairline cracks. Lit by the scene (it is ground, not a warning: ice never hurts), never
## casts a shadow. Its facet shades and cracks come from the cosmetic stream. Presentation only.

const ICE := Color("#A9D6EE")
const RIM := Color("#F2FAFF")
const CRACK := Color("#4F7FA6")
const GLOW := Color("#7FC2E8")
## Height above the ground (the rim a hair higher, the cracks higher still), so nothing z-fights.
const LIFT := 0.014
const RIM_W := 0.09
const FACET_M := 1.0
## Facet shade spread (±) and cracks per square metre.
const SHADE := 0.07
const CRACKS_PER_M2 := 0.12

var patch_count := 0


## Builds every patch of `reader`'s floor. `seed_value`: the floor seed (the cosmetic stream's root).
func build(reader: WorldReader, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 9001  # the cosmetic stream: presentation only
	var sheet := SurfaceTool.new()
	sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := SurfaceTool.new()
	rim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cracks := SurfaceTool.new()
	cracks.begin(Mesh.PRIMITIVE_TRIANGLES)
	patch_count = reader.ice_patch_count()
	for i in patch_count:
		var r := reader.ice_patch(i)
		_sheet(sheet, r, rng)
		_rim(rim, r)
		_cracks(cracks, r, rng)
	if patch_count == 0:
		return
	_add_mesh("IceSheet", sheet, sheet_material())
	_add_mesh("IceRim", rim, _flat(RIM, 0.35))
	_add_mesh("IceCracks", cracks, _flat(CRACK, 0.0))


## The sheet material: pale ice, glossy, a faint cold glow so it reads in the darkest mood.
static func sheet_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.roughness = 0.08
	m.metallic_specular = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = GLOW
	m.emission_energy_multiplier = 0.12
	return m


static func _flat(c: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _add_mesh(n: String, st: SurfaceTool, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The patch cut into ~1 m facets, two triangles each, every triangle its own shade.
func _sheet(st: SurfaceTool, r: Rect2, rng: RandomNumberGenerator) -> void:
	var nx := maxi(1, int(round(r.size.x / FACET_M)))
	var ny := maxi(1, int(round(r.size.y / FACET_M)))
	for i in nx:
		for j in ny:
			var a := r.position + Vector2(r.size.x * i / nx, r.size.y * j / ny)
			var b := r.position + Vector2(r.size.x * (i + 1) / nx, r.size.y * j / ny)
			var c := r.position + Vector2(r.size.x * (i + 1) / nx, r.size.y * (j + 1) / ny)
			var d := r.position + Vector2(r.size.x * i / nx, r.size.y * (j + 1) / ny)
			var flip := (i + j) % 2 == 0
			_quad_tris(st, [a, b, c, d] if flip else [b, c, d, a], LIFT, rng)


func _quad_tris(st: SurfaceTool, q: Array, y: float, rng: RandomNumberGenerator) -> void:
	for tri: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
		var shade := ICE.lightened(rng.randf_range(-SHADE, SHADE))
		for p: Vector2 in tri:
			st.set_color(shade)
			st.set_normal(Vector3.UP)
			st.add_vertex(SimPlane.to_3d(p, y))


## A flat strip RIM_W wide just inside the patch's edge, a hair above the sheet.
func _rim(st: SurfaceTool, r: Rect2) -> void:
	var inner := r.grow(-RIM_W)
	var y := LIFT + 0.002
	for strip: Rect2 in [
		Rect2(r.position, Vector2(r.size.x, RIM_W)),
		Rect2(Vector2(r.position.x, inner.end.y), Vector2(r.size.x, RIM_W)),
		Rect2(Vector2(r.position.x, inner.position.y), Vector2(RIM_W, inner.size.y)),
		Rect2(Vector2(inner.end.x, inner.position.y), Vector2(RIM_W, inner.size.y)),
	]:
		_flat_rect(st, strip, y)


## Thin dark hairlines from a point inside the patch, two or three segments each, kept inside the rim.
func _cracks(st: SurfaceTool, r: Rect2, rng: RandomNumberGenerator) -> void:
	var inner := r.grow(-RIM_W * 2.0)
	if inner.size.x <= 0.2 or inner.size.y <= 0.2:
		return
	var y := LIFT + 0.004
	for k in maxi(1, int(r.get_area() * CRACKS_PER_M2)):
		var p := inner.position + Vector2(rng.randf() * inner.size.x, rng.randf() * inner.size.y)
		var heading := rng.randf() * TAU
		for seg in rng.randi_range(2, 3):
			heading += rng.randf_range(-0.7, 0.7)
			var q := p + Vector2(cos(heading), sin(heading)) * rng.randf_range(0.3, 0.7)
			q = q.clamp(inner.position, inner.end)
			_line(st, p, q, 0.025, y)
			p = q


func _line(st: SurfaceTool, a: Vector2, b: Vector2, w: float, y: float) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var n := Vector2(-d.y, d.x).normalized() * w * 0.5
	for p: Vector2 in [a - n, b - n, b + n, a - n, b + n, a + n]:
		st.set_normal(Vector3.UP)
		st.add_vertex(SimPlane.to_3d(p, y))


static func _flat_rect(st: SurfaceTool, r: Rect2, y: float) -> void:
	var a := r.position
	var b := Vector2(r.end.x, r.position.y)
	var c := r.end
	var d := Vector2(r.position.x, r.end.y)
	for p: Vector2 in [a, b, c, a, c, d]:
		st.set_normal(Vector3.UP)
		st.add_vertex(SimPlane.to_3d(p, y))
