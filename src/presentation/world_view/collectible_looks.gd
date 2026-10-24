class_name CollectibleLooks
extends Node3D
## v0.9.0 CL (COLLECTIBLES.md; the VX bar, PLAN `| VX |`: "every VFX has a high quality layered effect … never flat
## single-colour 2D shapes"): one collectible's pickup, in layers: a faceted stone (a six-sided bipyramid with flat
## facets, lit by the scene and glowing from within) turning slowly and bobbing, a white-hot core inside it, a
## camera-facing halo with a hot centre and a glow pooled on the floor (HubProps.glow), a real light, motes drifting up
## from a ring under it, and a slow pulse. Taken (vanish): it flares, rises and shrinks away, then frees itself.
## Presentation only: it reads nothing and decides nothing.

const SIDES := 6
const SPIN := 0.9
const BOB_M := 0.08
const VANISH_S := 0.6

var color := Color.WHITE
var size := 0.3
var stone: MeshInstance3D
var core: MeshInstance3D
var glow := {}
var motes: CPUParticles3D
var vanishing := false
var _t := 0.0
var _gone_t := 0.0
var _base_y := 0.0


## A pickup under `parent` at `at` (parent-local), `s` m tall, in colour `c`.
static func gem(parent: Node3D, n: String, c: Color, at: Vector3, s: float) -> CollectibleLooks:
	var g := CollectibleLooks.new()
	g.name = n
	g.color = c
	g.size = s
	g.position = at
	parent.add_child(g)
	g._build()
	return g


func _build() -> void:
	_base_y = position.y
	var m := StandardMaterial3D.new()
	m.albedo_color = color.lerp(Color.WHITE, 0.15)
	m.metallic = 0.2
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.6
	m.rim_enabled = true
	m.rim = 0.6
	stone = HubProps.mesh(self, "Stone", _bipyramid(size * 0.42, size), m, Vector3.ZERO)
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = color.lerp(Color.WHITE, 0.8)
	var sp := SphereMesh.new()
	sp.radius = size * 0.14
	sp.height = size * 0.28
	core = HubProps.mesh(self, "Core", sp, cm, Vector3.ZERO)
	glow = HubProps.glow(
		self, "Glow", color, color.lerp(Color.WHITE, 0.85), Vector3.ZERO, size * 4.2
	)
	(glow["pool"] as MeshInstance3D).position = Vector3(0, -position.y + 0.04, 0)
	motes = HubProps.motes(self, "Motes", color, Vector3(0, -position.y + 0.1, 0), size * 1.2, 14)
	HubProps.set_glow(glow, 1.0, 1.4)


## A six-sided bipyramid (`r` m round, `h` m tall) with flat facets.
static func _bipyramid(r: float, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var top := Vector3(0, h * 0.55, 0)
	var bot := Vector3(0, -h * 0.45, 0)
	var ring: Array[Vector3] = []
	for k in SIDES:
		var a := TAU * k / SIDES
		ring.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	for k in SIDES:
		var p := ring[k]
		var q := ring[(k + 1) % SIDES]
		for v: Vector3 in [top, q, p, bot, p, q]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Taken: it flares, rises and shrinks away (VANISH_S), then frees itself.
func vanish() -> void:
	vanishing = true
	_gone_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	var calm := ViewPrefs.reduced_motion
	if not calm:
		stone.rotation.y = _t * SPIN
		position.y = _base_y + sin(_t * 2.2) * BOB_M
	var pulse := 1.0 + (0.0 if calm else 0.18 * sin(_t * 3.1))
	if not vanishing:
		HubProps.set_glow(glow, pulse, 1.4)
		return
	_gone_t += delta
	var k := clampf(_gone_t / VANISH_S, 0.0, 1.0)
	HubProps.set_glow(glow, (1.0 - k) * 2.6 + 0.01, 2.2)
	stone.scale = Vector3.ONE * maxf(0.01, 1.0 + 0.5 * k - 1.4 * k * k)
	core.scale = stone.scale
	position.y = _base_y + 1.2 * k
	if motes != null:
		motes.emitting = false
	if k >= 1.0:
		queue_free()
