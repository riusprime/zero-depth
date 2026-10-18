class_name LoopDevice
extends Node3D
## v0.8.0 P2 (owner O28: "you can pick a small different device than the ascension to loop … two different visual
## elements the ascension to go fight final boss or the loop element, separated"): the Loop device, beside the
## Ascension portal on a loop's last floor (the sim's pad: WorldReader.loop_device_pos, its radius
## loop_device_radius). Smaller than the portal and in its own colour (an emerald green, apart from the portal's gold
## and lavender, the gate's visor blue and Deep's violet):
## - a low round pad of dark stone with a glowing rim the size of the sim's pad (stepping on it takes the hero);
## - an upright ring standing on the pad, turned to face the camera (so it never reads edge-on), with two arrowheads
##   chasing round it (the loop), and a faint disc of light inside the ring;
## - no floating name (v0.8.0 N18, owner O76: P2's "Loop" label is gone; the player finds out what it is).
## Dormant while the boss lives (dim, still); when the portal opens it lights and its arrowheads chase round
## (reduced motion: they stand). Presentation only (EI-07): it reads nothing and decides nothing; WorldViewRoot
## unseals it with the portal, PortalTransitView flares it when the hero steps in. Its clock is the presentation's.
##
## Local frame: setup() turns local +X to the sim facing angle (out of the wall behind it); the ring's plane faces it.

const GREEN := Color("#3DE0A8")
const GREEN_DEEP := Color("#1E7A5E")
const STONE := Color("#2E3436")
const RING_R := 0.7
const RING_Y := 0.95
const PAD_H := 0.1
const LIGHT_SEALED := 0.15
const LIGHT_OPEN := 1.6
const FLARE_ENERGY := 4.0
const FLARE_SECONDS := 1.0
const ARROW_SPEED := 0.35
## v0.8.0 MI: the owner's model of the device.
const MODEL_PATH := "res://assets/models/devices/loop_device.glb"

static var _model_cache := {}

var pad: MeshInstance3D
var rim: MeshInstance3D
var ring: MeshInstance3D
var veil: MeshInstance3D
var arrows: Array[MeshInstance3D] = []
var light := OmniLight3D.new()
var ring_material := StandardMaterial3D.new()
var rim_material := StandardMaterial3D.new()
var veil_material := StandardMaterial3D.new()
## Reduced motion (ViewPrefs, read at setup): the arrowheads stand.
var calm := false
## The pad's radius (m): the sim's.
var radius := 0.9
## How far round the arrowheads have chased (turns; tests read it).
var chase := 0.0
## v0.8.0 MI: the owner's pad (null: the code-made one; _model_width: its width as prepared, m).
var model: MeshInstance3D
var _sealed := true
var _flare := 0.0
var _spin: Node3D
var _model_width := 1.0


func _init() -> void:
	name = "LoopDevice"
	_build()
	set_sealed(true)


## Places it at `sim_pos` facing `facing_angle` (1/4096 turn), its pad `pad_radius` m (the sim's).
func setup(sim_pos: Vector2, facing_angle: int, pad_radius: float) -> void:
	position = SimPlane.to_3d(sim_pos)
	rotation = Vector3(0, SimPlane.yaw_of(facing_angle), 0)
	calm = ViewPrefs.reduced_motion
	radius = pad_radius
	(pad.mesh as CylinderMesh).top_radius = radius
	(pad.mesh as CylinderMesh).bottom_radius = radius + 0.06
	(rim.mesh as TorusMesh).inner_radius = radius - 0.07
	(rim.mesh as TorusMesh).outer_radius = radius
	if model != null:  # v0.8.0 MI: the owner's pad spans the sim's pad
		model.scale = Vector3.ONE * (radius * 2.0 / maxf(_model_width, 0.0001))


## v0.8.0 MI: the owner's Loop device (MODEL_PATH, mi_prep.py: 8k triangles, 0.9 m tall as prepared) in place of the
## code-made stone pad; the rim's glow, the upright ring, its chasing arrowheads, the veil and the light stay on top
## of it, animated as before. Missing: the code-made pad (L15).
func _build_model() -> void:
	if not _model_cache.has(MODEL_PATH):
		_model_cache[MODEL_PATH] = (
			ModelLibrary.first_surface(load(MODEL_PATH) as PackedScene)
			if ResourceLoader.exists(MODEL_PATH)
			else {}
		)
	var surface: Dictionary = _model_cache[MODEL_PATH]
	if surface.is_empty():
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface["arrays"])
	model = MeshInstance3D.new()
	model.name = "Model"
	model.mesh = mesh
	if surface["material"] != null:
		model.material_override = surface["material"]
	var box: AABB = surface["aabb"]
	_model_width = maxf(box.size.x, box.size.z)
	model.scale = Vector3.ONE * (radius * 2.0 / maxf(_model_width, 0.0001))
	add_child(model)
	pad.visible = false


func set_sealed(sealed: bool) -> void:
	if _sealed and not sealed and is_inside_tree() and not calm:
		_flare = FLARE_SECONDS * 0.6
	_sealed = sealed
	veil.visible = not sealed
	_apply()


func is_sealed() -> bool:
	return _sealed


## A flare of light (the hero stepping in: PortalTransitView).
func flare() -> void:
	if not calm:
		_flare = FLARE_SECONDS


## The colour the hero's way in flashes (PortalTransitView).
static func flash_color() -> Color:
	return GREEN


func _process(delta: float) -> void:
	if _flare > 0.0:
		_flare = maxf(0.0, _flare - delta)
	_face_camera()
	if not _sealed and not calm:
		chase += delta * ARROW_SPEED * (1.0 + 2.0 * _flare)
		for k in arrows.size():
			var a := TAU * (float(k) / arrows.size() + chase)
			arrows[k].position = Vector3(0, RING_Y + sin(a) * RING_R, cos(a) * RING_R)
			arrows[k].rotation = Vector3(-a, 0, 0)
	_apply()


## The ring's plane turned to face the camera about the upright axis.
func _face_camera() -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	if cam == null or not is_inside_tree():
		return
	var to := cam.global_position - _spin.global_position
	if Vector2(to.x, to.z).length() < 0.001:
		return
	_spin.global_rotation = Vector3(0, atan2(-to.z, to.x), 0)


func _apply() -> void:
	var k := _flare / FLARE_SECONDS
	var e := 0.25 if _sealed else 2.2
	ring_material.emission_energy_multiplier = e + 3.0 * k * k
	rim_material.emission_energy_multiplier = (0.2 if _sealed else 1.6) + 2.0 * k * k
	veil_material.albedo_color.a = 0.22 + 0.4 * k * k
	light.light_energy = (LIGHT_SEALED if _sealed else LIGHT_OPEN) + FLARE_ENERGY * k * k


func _glow(m: StandardMaterial3D, c: Color) -> void:
	m.albedo_color = c.darkened(0.3)
	m.emission_enabled = true
	m.emission = c
	m.roughness = 0.4


func _build() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = STONE
	stone.roughness = 0.9
	var pm := CylinderMesh.new()
	pm.radial_segments = 24
	pm.rings = 1
	pm.top_radius = radius
	pm.bottom_radius = radius + 0.06
	pm.height = PAD_H
	pad = MeshInstance3D.new()
	pad.name = "Pad"
	pad.mesh = pm
	pad.material_override = stone
	pad.position.y = PAD_H * 0.5
	add_child(pad)
	_build_model()
	var rm := TorusMesh.new()
	rm.inner_radius = radius - 0.07
	rm.outer_radius = radius
	rm.rings = 32
	rm.ring_segments = 6
	_glow(rim_material, GREEN)
	rim = MeshInstance3D.new()
	rim.name = "Rim"
	rim.mesh = rm
	rim.material_override = rim_material
	rim.position.y = PAD_H + 0.01
	rim.scale = Vector3(1.0, 0.3, 1.0)
	add_child(rim)
	_spin = Node3D.new()
	_spin.name = "Spin"
	add_child(_spin)
	var tm := TorusMesh.new()
	tm.inner_radius = RING_R - 0.09
	tm.outer_radius = RING_R + 0.03
	tm.rings = 40
	tm.ring_segments = 8
	_glow(ring_material, GREEN)
	ring = MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = tm
	ring.material_override = ring_material
	ring.position.y = RING_Y
	ring.rotation.z = PI / 2.0  # upright: its plane faces local +X
	_spin.add_child(ring)
	var vm := CylinderMesh.new()
	vm.top_radius = RING_R - 0.07
	vm.bottom_radius = RING_R - 0.07
	vm.height = 0.01
	vm.radial_segments = 24
	veil_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	veil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veil_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	veil_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	veil_material.albedo_color = Color(GREEN, 0.22)
	veil = MeshInstance3D.new()
	veil.name = "Veil"
	veil.mesh = vm
	veil.material_override = veil_material
	veil.position.y = RING_Y
	veil.rotation.z = PI / 2.0
	_spin.add_child(veil)
	var arrow_mat := StandardMaterial3D.new()
	_glow(arrow_mat, GREEN.lightened(0.35))
	for k in 2:
		var am := PrismMesh.new()
		am.size = Vector3(0.16, 0.24, 0.1)
		var a := MeshInstance3D.new()
		a.name = "Arrow%d" % k
		a.mesh = am
		a.material_override = arrow_mat
		var ang := TAU * k / 2.0
		a.position = Vector3(0, RING_Y + sin(ang) * RING_R, cos(ang) * RING_R)
		a.rotation = Vector3(-ang, 0, 0)
		_spin.add_child(a)
		arrows.append(a)
	light.name = "Light"
	light.light_color = GREEN
	light.omni_range = 4.0
	light.position.y = RING_Y
	light.shadow_enabled = false
	add_child(light)
