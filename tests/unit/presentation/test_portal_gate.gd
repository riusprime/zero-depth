extends GutTest
## The portal gate (v0.2.0 PLAN step D, L8; the visor's light blue since v0.3.5 PT): placement on the sim plane,
## the portal shader, its colour and the sealed state.

const UNIFORMS := [
	"opening_size",
	"color_deep",
	"color_mid",
	"color_light",
	"veil_color",
	"swirl_speed",
	"energy",
	"sealed"
]


func _gate() -> PortalGate:
	var g := PortalGate.new()
	add_child_autofree(g)
	return g


func test_setup_places_and_turns_the_gate() -> void:
	var g := _gate()
	g.setup(Vector2(3.0, -2.0), 1024)
	assert_almost_eq(
		g.position, Vector3(3.0, 0.0, 2.0), Vector3.ONE * 1e-5, "sim (x, y) -> 3D (x, 0, -y)"
	)
	assert_almost_eq(g.rotation.y, SimPlane.yaw_of(1024), 1e-5)
	# The gate's front (+X) points along the sim facing: a quarter turn is sim +y.
	var front := SimPlane.to_sim(g.global_basis * Vector3.RIGHT)
	assert_almost_eq(front, Vector2(0, 1), Vector2.ONE * 1e-5)


func test_opening_is_clear_and_portal_fills_it() -> void:
	var g := _gate()
	var quad := g.portal.mesh as QuadMesh
	assert_eq(quad.size, Vector2(PortalGate.OPENING_W, PortalGate.OPENING_H))
	assert_almost_eq(g.portal.position.y, PortalGate.OPENING_H * 0.5, 1e-5)
	assert_gt(g.stone_blocks.size(), 8, "pillars, lintel and keystone are stacked blocks")
	for b in g.stone_blocks:
		var half := (b.mesh as BoxMesh).size.z * 0.5
		if b.position.y < PortalGate.OPENING_H:
			assert_true(
				absf(b.position.z) - half >= PortalGate.OPENING_W * 0.5 - 0.02,
				"block at %s stays out of the opening" % b.position
			)


func test_portal_shader_has_the_expected_uniforms() -> void:
	var g := _gate()
	var shader := g.portal_material.shader
	assert_not_null(shader)
	assert_eq(shader.get_mode(), Shader.MODE_SPATIAL)
	for u in UNIFORMS:
		assert_true(shader.code.contains("uniform") and shader.code.contains(" %s" % u), u)
	assert_true(shader.code.contains("TIME"), "the swirl animates")
	var listed := shader.get_shader_uniform_list().map(
		func(d: Dictionary) -> String: return d["name"]
	)
	# The shader compiler fills this only when the code parses (it does under --headless too).
	assert_eq(listed, UNIFORMS, "the shader parses and exposes its uniforms")
	assert_true(g.glow_material.shader.code.contains("blend_add"), "the floor glow adds light")
	assert_true(g.light is OmniLight3D)


## v0.3.5 PT (owner F19): the portal is the hero visor's light blue (it replaces L12's deeper blue).
func test_the_portal_is_the_visors_light_blue() -> void:
	var g := _gate()
	var visor := ThemePalette.color(&"player_core")
	var mid: Color = g.portal_material.get_shader_parameter("color_mid")
	assert_eq(mid, visor, "the swirl's main colour is the visor's")
	assert_eq(g.light.light_color, visor, "its light")
	assert_eq(g.glow_material.get_shader_parameter("glow_color"), visor, "its floor glow")
	var deep: Color = g.portal_material.get_shader_parameter("color_deep")
	var light: Color = g.portal_material.get_shader_parameter("color_light")
	assert_lt(deep.v, mid.v, "a deep shade")
	assert_gt(light.get_luminance(), mid.get_luminance(), "to near white")
	for c: Color in [deep, mid]:
		assert_almost_eq(c.h, visor.h, 0.02, "the same hue: %s" % c)
	var avatar := PlayerAvatar.new()
	avatar.setup(Color.BLACK)
	assert_eq(avatar.visor_color(), visor, "the colour the visor glows")
	avatar.free()
	for key in ["color_deep", "color_mid", "color_light", "veil_color"]:
		assert_true(g.portal_material.shader.code.contains(key), key)


func test_sealed_is_the_default_and_toggles_the_uniform() -> void:
	var g := _gate()
	assert_true(g.is_sealed())
	assert_eq(g.portal_material.get_shader_parameter("sealed"), 1.0)
	var dim := g.light.light_energy
	g.set_sealed(false)
	assert_false(g.is_sealed())
	assert_eq(g.portal_material.get_shader_parameter("sealed"), 0.0)
	assert_gt(g.light.light_energy, dim, "open is brighter")
	g.set_sealed(true)
	assert_eq(g.portal_material.get_shader_parameter("sealed"), 1.0)


func test_gate_strings_exist_in_both_languages() -> void:
	var rows := {}
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3:
			rows[row[0]] = row
	for key in ["GATE_SEALED", "GATE_NAME"]:
		assert_true(rows.has(key), key)
		if rows.has(key):
			assert_false(rows[key][1].is_empty(), key + " en")
			assert_false(rows[key][2].is_empty(), key + " es")
