class_name FloorReceiver
extends Node3D
## v0.8.0 N11 (owner O69: "some kind of receiving platform from the portal … so you know it's connected every floor …
## But the receiver should be different than the portal, just to not confuse the user"): the platform the hero arrives
## on, in the middle of every run floor's first room (WorldReader.floor_receiver, at floor_start_pos). Low and round,
## nothing to walk into, in its own pale cyan-white (apart from the gate's visor blue, the Deep gate's violet, the
## Ascension portal's gold and the Loop device's green):
## - a worn stone disc with a dark metal inset and a glowing landing circle in its centre, a ring of light round it;
## - four short metal arms rising from the rim and bending inward like a cage opened, a light strip up each;
## - a soft light; a ring of light that bursts out across the floor when the hero lands (set_burst) and a puff of dust.
## The owner's `floor_receiver` model (docs/OWNER_TODO.md §3.1) replaces the disc and the arms once
## assets/models/manifest.json lists it (ShopModels.get_model); the landing glow, the light and the burst stay.
## Presentation only (EI-07): PortalTransitView poses it from the sim's arrival progress (set_charge, set_burst, puff);
## at rest it breathes slowly on the presentation's clock (reduced motion: it stands still). Walk-over: the sim has
## no body for it (the start's open floor, StageView keeps props off it).

const MODEL_ID := &"floor_receiver"
const PALE := Color("#C9F3FA")
const CORE := Color("#F4FDFF")
const STONE := Color("#4A4E52")
const METAL := Color("#2B2F35")
## The disc's radius and height (m), the landing circle's radius, the arms' rim radius and count.
const RADIUS := 1.1
const DISC_H := 0.16
const LANDING_R := 0.6
const ARM_R := 0.98
const ARMS := 4
const LIGHT_IDLE := 0.7
const LIGHT_CHARGED := 5.0
## The burst ring: its reach (scale of the landing circle) at the end.
const BURST_REACH := 5.5

var body := Node3D.new()
var landing: MeshInstance3D
var halo: MeshInstance3D
var shock: MeshInstance3D
var light := OmniLight3D.new()
var dust := CPUParticles3D.new()
var arms: Array[Node3D] = []
## The owner's model is drawn (tests read it).
var uses_model := false
## 0 at rest .. 1 fully charged (tests read it).
var charge := 0.0
var calm := false
var _glow_mat := StandardMaterial3D.new()
var _strip_mat := StandardMaterial3D.new()
var _landing_mat := StandardMaterial3D.new()
var _shock_mat := StandardMaterial3D.new()
var _t := 0.0


func _init() -> void:
	name = "FloorReceiver"
	_build()
	set_charge(0.0)


## Stands it at `sim_pos` (the hero's start).
func setup(sim_pos: Vector2) -> void:
	position = SimPlane.to_3d(sim_pos)
	calm = ViewPrefs.reduced_motion


## The glow from rest (0) to full charge (1): the landing circle, the ring, the arms' strips and the light.
func set_charge(k: float) -> void:
	charge = clampf(k, 0.0, 1.0)
	_apply()


## The landing's ring of light running out across the floor: `t` 0..1 through it (outside that: none).
func set_burst(t: float) -> void:
	if t < 0.0 or t >= 1.0:
		shock.visible = false
		return
	shock.visible = true
	var s := 1.0 + (BURST_REACH - 1.0) * (1.0 - (1.0 - t) * (1.0 - t))
	shock.scale = Vector3(s, 1.0, s)
	_shock_mat.albedo_color = Color(CORE, 0.9 * (1.0 - t))


## A puff of dust off the disc's rim (the landing).
func puff() -> void:
	dust.restart()


func _process(delta: float) -> void:
	if calm:
		return
	_t += delta
	_apply()


func _apply() -> void:
	var breathe := 0.0 if calm else 0.12 * (0.5 + 0.5 * sin(_t * TAU * 0.4))
	var k := charge
	_landing_mat.albedo_color = Color(CORE, clampf(0.35 + breathe + 0.6 * k, 0.0, 1.0))
	_glow_mat.emission_energy_multiplier = 1.2 + 4.0 * k + breathe * 4.0
	_strip_mat.emission_energy_multiplier = 0.8 + 3.5 * k * k
	light.light_energy = LIGHT_IDLE + (LIGHT_CHARGED - LIGHT_IDLE) * k * k + breathe
	for a in arms:  # charged, the arms' tips lean in a touch (the cage closing round the light)
		a.rotation.z = 0.08 * k


func _emissive(m: StandardMaterial3D, c: Color) -> void:
	m.albedo_color = c.darkened(0.25)
	m.emission_enabled = true
	m.emission = c
	m.roughness = 0.35


func _additive(m: StandardMaterial3D, c: Color) -> void:
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c


func _mesh(n: String, mesh: Mesh, mat: Material, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


func _build() -> void:
	body.name = "Body"
	add_child(body)
	var model := ShopModels.get_model(MODEL_ID)
	if not model.is_empty():
		uses_model = true
		var mi := _mesh("Model", model["mesh"], model["material"], Vector3.ZERO, body)
		mi.material_override = null
		mi.set_surface_override_material(0, model["material"])
	else:
		_build_stand_in()
	var top := DISC_H + 0.03
	var lm := CylinderMesh.new()
	lm.top_radius = LANDING_R
	lm.bottom_radius = LANDING_R
	lm.height = 0.01
	lm.radial_segments = 32
	lm.rings = 1
	_additive(_landing_mat, Color(CORE, 0.4))
	landing = _mesh("Landing", lm, _landing_mat, Vector3(0, top, 0), self)
	landing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hm := TorusMesh.new()
	hm.inner_radius = LANDING_R + 0.05
	hm.outer_radius = LANDING_R + 0.12
	hm.rings = 40
	hm.ring_segments = 6
	_emissive(_glow_mat, PALE)
	halo = _mesh("Halo", hm, _glow_mat, Vector3(0, top, 0), self)
	halo.scale = Vector3(1.0, 0.25, 1.0)
	var sm := TorusMesh.new()
	sm.inner_radius = LANDING_R - 0.04
	sm.outer_radius = LANDING_R + 0.04
	sm.rings = 48
	sm.ring_segments = 4
	_additive(_shock_mat, Color(CORE, 0.0))
	shock = _mesh("Burst", sm, _shock_mat, Vector3(0, 0.06, 0), self)
	shock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shock.visible = false
	light.name = "Light"
	light.light_color = PALE
	light.omni_range = 4.0
	light.position.y = 0.7
	light.shadow_enabled = false
	add_child(light)
	_build_dust()


## The code-made stand-in (the owner's model replaces it): the disc, the inset and the four arms.
func _build_stand_in() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = STONE
	stone.roughness = 0.95
	var metal := StandardMaterial3D.new()
	metal.albedo_color = METAL
	metal.metallic = 0.6
	metal.roughness = 0.5
	var dm := CylinderMesh.new()
	dm.top_radius = RADIUS - 0.05
	dm.bottom_radius = RADIUS + 0.04
	dm.height = DISC_H
	dm.radial_segments = 12  # faceted, low-poly
	dm.rings = 1
	_mesh("Disc", dm, stone, Vector3(0, DISC_H * 0.5, 0), body)
	var im := CylinderMesh.new()
	im.top_radius = LANDING_R + 0.2
	im.bottom_radius = LANDING_R + 0.24
	im.height = 0.05
	im.radial_segments = 24
	im.rings = 1
	_mesh("Inset", im, metal, Vector3(0, DISC_H + 0.005, 0), body)
	_emissive(_strip_mat, PALE)
	for k in ARMS:
		var arm := Node3D.new()
		arm.name = "Arm%d" % k
		var yaw := TAU * (float(k) + 0.5) / ARMS
		var pivot := Node3D.new()
		pivot.rotation.y = yaw
		body.add_child(pivot)
		arm.position = Vector3(ARM_R, DISC_H, 0)
		pivot.add_child(arm)
		var foot := BoxMesh.new()
		foot.size = Vector3(0.22, 0.12, 0.3)
		_mesh("Foot", foot, metal, Vector3(0, 0.06, 0), arm)
		var low := BoxMesh.new()
		low.size = Vector3(0.12, 0.5, 0.16)
		_mesh("Low", low, metal, Vector3(0, 0.37, 0), arm)
		var bend := Node3D.new()  # the upper part leans in over the landing circle
		bend.name = "Bend"
		bend.position = Vector3(0, 0.62, 0)
		bend.rotation.z = 0.62
		arm.add_child(bend)
		var up := BoxMesh.new()
		up.size = Vector3(0.1, 0.42, 0.13)
		_mesh("Up", up, metal, Vector3(0, 0.21, 0), bend)
		var strip := BoxMesh.new()
		strip.size = Vector3(0.03, 0.78, 0.05)
		_mesh("Strip", strip, _strip_mat, Vector3(-0.065, 0.0, 0), arm).position.y = 0.45
		var tip := SphereMesh.new()
		tip.radius = 0.055
		tip.height = 0.11
		tip.radial_segments = 8
		tip.rings = 4
		_mesh("Tip", tip, _strip_mat, Vector3(0, 0.44, 0), bend)
		arms.append(arm)


func _build_dust() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = FxTextures.soft_dot()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(0.78, 0.76, 0.72, 0.7))
	fade.set_color(1, Color(0.7, 0.68, 0.64, 0.0))
	dust.name = "Dust"
	dust.mesh = quad
	dust.amount = 24
	dust.one_shot = true
	dust.emitting = false
	dust.explosiveness = 0.95
	dust.lifetime = 0.7
	dust.local_coords = false
	dust.color_ramp = fade
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	dust.emission_ring_axis = Vector3.UP
	dust.emission_ring_radius = RADIUS
	dust.emission_ring_inner_radius = RADIUS * 0.8
	dust.emission_ring_height = 0.05
	dust.direction = Vector3(1, 0.2, 0)
	dust.spread = 180.0
	dust.flatness = 0.85
	dust.initial_velocity_min = 1.5
	dust.initial_velocity_max = 3.2
	dust.gravity = Vector3(0, -1.0, 0)
	dust.damping_min = 2.0
	dust.damping_max = 3.0
	dust.scale_amount_min = 0.8
	dust.scale_amount_max = 1.8
	dust.position.y = 0.1
	add_child(dust)
