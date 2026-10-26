class_name RuneRingView
extends Node3D
## v0.9.5 RS2 (RUNIC_STONE.md S6): the full Runic Stone's ring, the 24 Elder Futhark runes (RunicGlyphs) lying on the
## floor around the stone's base, glowing violet and turning slowly. Built in code from the glyph strokes as thin
## ribbons (one unshaded emissive mesh, no texture, no art file). Presentation only: it reads nothing, and the turn is
## decoration (no outcome depends on it).

const VIOLET := Color("#9B6BFF")
const GLYPH_M := 0.5  # a glyph's height on the floor
const STROKE_M := 0.045  # a stroke's width
const TURN_RAD_S := 0.12  # about 52 s a turn

var radius := 1.6


func _init(p_radius: float = 1.6) -> void:
	name = "RuneRing"
	radius = p_radius
	var mi := MeshInstance3D.new()
	mi.name = "Glyphs"
	mi.mesh = _build()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = VIOLET.lightened(0.2)
	m.emission_enabled = true
	m.emission = VIOLET
	m.emission_energy_multiplier = 2.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _process(delta: float) -> void:
	rotation.y += TURN_RAD_S * delta


## The glyphs' ribbons: glyph g stands at angle g/24 of the circle, its top pointing outward.
func _build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := GLYPH_M / RunicGlyphs.H
	for g in RuneCipher.GLYPHS:
		var a := TAU * float(g) / float(RuneCipher.GLYPHS)
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a))
		for stroke: PackedVector2Array in RunicGlyphs.strokes(g):
			for i in stroke.size() - 1:
				_ribbon(st, _at(out, side, stroke[i], s), _at(out, side, stroke[i + 1], s))
	return st.commit()


## A box point (x right, y down) on the floor: y = 0 is the glyph's outer top, y = 4 its foot toward the stone.
func _at(out: Vector3, side: Vector3, p: Vector2, s: float) -> Vector3:
	return out * (radius + (RunicGlyphs.H - p.y) * s) + side * ((p.x - RunicGlyphs.W * 0.5) * s)


func _ribbon(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var d := b - a
	if d.length() < 0.0001:
		return
	var n := Vector3(-d.z, 0, d.x).normalized() * (STROKE_M * 0.5)
	var q := [a - n, a + n, b + n, b - n]
	for k: int in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(q[k])
