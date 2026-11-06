class_name LensDroneAvatar
extends AvatarBase
## The Lens Drone (v0.4.0 BO): one of the three drones the Hive Lens splits into at half HP, a small copy of its
## rim pods in the enemy style. A red faceted pod with a grey cap and a glowing red eye slit in front, a grey ring
## turning round it, hovering HOVER_Y up with a bob over a soft dark ground shadow (the sim treats it as a body on
## the ground, so melee and shots hit it there). It flies the Needle's behaviour: its eye flares through a windup.
## Presentation only (EI-07): sync() reads the sim through WorldReader once per tick, advance() animates in frame
## time. ActorViews puts it under the actor's facing node: +X is the front. Flash materials: ActorViews.flashable.

const HOVER_Y := 1.3
const BOB_M := 0.07
const HEIGHT := HOVER_Y + 0.35
const SHADOW_R := 0.4
const OUTLINE_M := 0.02

## v0.8.0 EC: the pod (body), the cap (trim), the ring (grey) and the eye slit (eye) come from EnemyPalettes.
const KIND := WorldReader.KIND_LENS_DRONE

var pod: Node3D
var ring: Node3D
## v0.8.0 MI: true when the pod is the owner's model.
var has_model := false
var shadow: MeshInstance3D

var _eye_mat := StandardMaterial3D.new()
var _parts: BossParts
var _state := WorldReader.STATE_SPAWN
var _rise := 0.0
var _charge := 0.0


func setup(outline_color: Color, technique: StringName = &"outline") -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_parts = BossParts.new(outline_color, technique, OUTLINE_M)
	shadow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = SHADOW_R
	disc.bottom_radius = SHADOW_R
	disc.height = 0.005
	disc.radial_segments = 16
	shadow.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.35)
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.material_override = sm
	shadow.position.y = 0.012
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	pod = Node3D.new()
	add_child(pod)
	if _build_model():  # v0.8.0 MI: the owner's model
		body_materials = _parts.body_materials
		_pose()
		return
	_parts.piece(
		pod, BossParts.block(Vector3(0.5, 0.34, 0.46), 30, 0.3), Vector3.ZERO, _color(&"body")
	)
	_parts.piece(
		pod,
		BossParts.block(Vector3(0.28, 0.1, 0.26), 31, 0.3),
		Vector3(-0.04, 0.2, 0),
		_color(&"trim")
	)
	var eye := _parts.glow(
		pod,
		BossParts.block(Vector3(0.05, 0.08, 0.28), 33),
		Vector3(0.26, 0, 0),
		_color(&"eye"),
		1.8
	)
	_eye_mat = eye.material_override as StandardMaterial3D
	ring = Node3D.new()
	pod.add_child(ring)
	_parts.piece(
		ring,
		BossParts.tube(0.06, 0.42, 34, 10),
		Vector3(-0.03, 0, 0),
		_color(&"grey"),
		Vector3(0, 0, PI * 0.5)
	)
	body_materials = _parts.body_materials
	_pose()


## v0.8.0 MI: the owner's Lens Drone (EnemyModels &"lens_drone"): its pod centred on the pod node (the hover and
## bob as the code-made pod's), its red plates in the palette's body colour (greyscale in the texture), its frame as
## delivered, its eye slit on the eye material (flaring through the windup as before) and its little ring of feet
## turning under it (the ring). False when the model is missing (the code-made pod is built).
func _build_model() -> bool:
	var m := EnemyModels.get_model(&"lens_drone")
	if m.is_empty():
		return false
	has_model = true
	var tex: Texture2D = m["texture"]
	var mats := {}
	for slot: StringName in [&"base", &"role"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = _color(&"body") if slot == &"role" else Color.WHITE
		mat.roughness = 1.0
		ActorLooks.outline(mat, Color.BLACK, 0.0)
		mat.set_meta(&"enemy_tex", true)
		mats[slot] = ActorViews.flashable(mat)
		_parts.body_materials.append(mat)
	_eye_mat.albedo_color = _color(&"eye")
	_eye_mat.emission_enabled = true
	_eye_mat.emission = _color(&"eye")
	_eye_mat.emission_energy_multiplier = 1.8
	var holder := Node3D.new()
	holder.name = "Model"
	var s: float = m["scale"]
	holder.scale = Vector3.ONE * s
	holder.position = Vector3(0, -float(m["height"]) * s * 0.5, 0)  # the pod's middle on the pod node
	pod.add_child(holder)
	var parts_in: Dictionary = m["parts"]
	for pname: StringName in parts_in:
		var part: Dictionary = parts_in[pname]
		var pivot := Node3D.new()
		pivot.name = String(pname)
		pivot.position = part["pivot"]
		holder.add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = part["mesh"]
		var surfaces: Array = part["surfaces"]
		for k in surfaces.size():
			mi.set_surface_override_material(
				k, _eye_mat if surfaces[k] == &"glow" else mats.get(surfaces[k], mats[&"base"])
			)
		pivot.add_child(mi)
		if pname == &"ring":
			ring = pivot
	if ring == null:
		ring = Node3D.new()
		holder.add_child(ring)
	return true


static func _color(slot: StringName) -> Color:
	return EnemyPalettes.color(KIND, slot)


func sync(reader: WorldReader, i: int) -> void:
	apply_state({"tick": reader.tick(), "state": reader.actor_state(i)})


## The same as sync(), from plain values (tests drive the avatar with this).
func apply_state(s: Dictionary) -> void:
	_state = s["state"]
	if _fresh:
		_fresh = false
		_rise = 0.0 if _state == WorldReader.STATE_SPAWN else 1.0
		_pose()


func advance(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	if dt <= 0.0 or pod == null:
		return
	_t += dt
	var spawning := _state == WorldReader.STATE_SPAWN
	_rise = move_toward(_rise, 0.0 if spawning else 1.0, dt * (6.0 if spawning else 2.0))
	var aiming := _state == WorldReader.STATE_WINDUP or _state == WorldReader.STATE_ACTIVE
	_charge = move_toward(_charge, 1.0 if aiming else 0.0, dt * (4.0 if aiming else 2.0))
	_pose()


## v0.8.0 GF2: the flinch leans the pod about itself, not about the ground under it.
func _flinch_pivot() -> float:
	return HOVER_Y


## The pod's current height above the ground (the hover plus the bob).
func hover_height() -> float:
	return pod.position.y


func _pose() -> void:
	var bob := sin(_t * TAU * 0.8) * BOB_M
	pod.position = Vector3(0, lerpf(0.4, HOVER_Y, _rise) + bob, 0)
	pod.rotation = Vector3(sin(_t * 1.5) * 0.08, 0, sin(_t * 1.9) * 0.06 - 0.05 * _charge)
	# The code-made ring turns about its tube; the owner's ring of feet spins under the pod (v0.8.0 MI), faster as
	# the eye charges.
	ring.rotation = (
		Vector3(0, _t * (2.5 + 6.0 * _charge), 0) if has_model else Vector3(_t * 2.5, 0, 0)
	)
	_eye_mat.emission_energy_multiplier = 1.8 + 3.5 * _charge
	var s := lerpf(0.6, 1.0, _rise) * (1.0 - bob)
	shadow.scale = Vector3(s, 1, s)
