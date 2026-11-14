class_name BladePack
extends RefCounted
## VFX_PACK N3: what the Blade's views share to draw the swings in the VFX pack's style: the pack the
## view hangs under (WorldViewRoot.pack_fx, found up the tree so the views need no wiring), the ribbon material (the
## beam pack's scrolling noise, assets/vfx_zd/blade/blade_trail.gdshader), the rim material the baked crescents and
## ghost slashes wear (a copy of rim_area_04's, assets/vfx_zd/blade/blade_rim.tres) and the ribbon slots (the `trail`
## family's cap, scaled by Effects density). Presentation only (EI-07).

const TRAIL_SHADER := "res://assets/vfx_zd/blade/blade_trail.gdshader"
const RIM_MATERIAL := "res://assets/vfx_zd/blade/blade_rim.tres"
## The hero's gold, for a spark with no element.
const GOLD := Color("#FFD36B")
## How fast the ribbon's noise runs along it (noise tiles a second).
const SCROLL_PER_S := 3.0
const NOISE_SIZE := 128

static var _shader: Shader
static var _noise: Texture2D
static var _rim: ShaderMaterial
## Ribbons drawn now (each view claims one for its swing).
static var _ribbons := 0


## The PackFx of the nearest ancestor of `node` that has one (null: none, the old looks draw).
static func pack_of(node: Node) -> PackFx:
	var n: Node = node.get_parent() if node != null else null
	while n != null:
		var p: Variant = n.get(&"pack_fx")
		if p is PackFx:
			return p
		n = n.get_parent()
	return null


## Claims a ribbon slot; false when the `trail` family is full at the Effects density (the old look draws).
static func claim_ribbon(pack: PackFx) -> bool:
	if pack == null or _ribbons >= pack.cap_for(&"trail"):
		return false
	_ribbons += 1
	return true


static func free_ribbon() -> void:
	_ribbons = maxi(_ribbons - 1, 0)


static func ribbons() -> int:
	return _ribbons


## A ribbon material of its own (UV.x along the ribbon, UV.y across it).
static func trail_material() -> ShaderMaterial:
	if _shader == null:
		_shader = load(TRAIL_SHADER) as Shader
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.03
		n.fractal_octaves = 2
		_noise = ImageTexture.create_from_image(n.get_seamless_image(NOISE_SIZE, NOISE_SIZE))
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter(&"noise_texture", _noise)
	m.set_shader_parameter(&"phase", 0.0)
	tint(m, Color.WHITE)
	return m


## Recolours a ribbon material to the colour `c`: its light core, its body and its dark edge.
static func tint(m: ShaderMaterial, c: Color) -> void:
	m.set_shader_parameter(&"primary_color", Color(c.lightened(0.45), 1.0))
	m.set_shader_parameter(&"secondary_color", Color(c, 1.0))
	m.set_shader_parameter(&"tertiary_color", Color(c.darkened(0.5), 1.0))


## A rim material of its own, recoloured to `c` (the baked crescents' and ghost slashes').
static func rim_material(c: Color) -> ShaderMaterial:
	if _rim == null:
		_rim = load(RIM_MATERIAL) as ShaderMaterial
	var m := _rim.duplicate() as ShaderMaterial
	m.set_shader_parameter(&"primary_color", Color(c.lerp(Color.WHITE, 0.55), 1.0))
	m.set_shader_parameter(&"secondary_color", Color(c, 1.0))
	return m


## The spark colours of a tint `c` (`primary`, `secondary`, `tertiary`).
static func colors_of(c: Color) -> Dictionary:
	return HitPack.tint(c)
