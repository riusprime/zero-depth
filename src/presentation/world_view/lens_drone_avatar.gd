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

## v0.8.0 EC: the pod (body), the cap (trim), the ring (grey) and the eye slit (eye) come from EnemyPalettes.
const KIND := WorldReader.KIND_LENS_DRONE
## v0.11.0 S4 (SoloVat): the raw drives (_vd) and their specs [lo, hi, loop]: the pod's roll about X and Z, the ring's
## turn (its charge-quickened spin).
const RX := 0
const RZ := 1
const SPIN := 2
const VAT_DRIVES := [[-0.08, 0.08, false], [-0.12, 0.07, false], [0.0, TAU, true]]

var pod: Node3D
var ring: Node3D
## v0.8.0 MI: true when the pod is the owner's model.
var has_model := false
var shadow: MeshInstance3D
## v0.11.0 S4 (the Enemy VAT, like the Bomb Drone): true (set before setup(), ActorViews from ViewPrefs.enemy_vat): a
## VatCrowd draws the body from baked poses; setup() builds only the ground disc.
var vat := false
var kind := KIND

var _vd := PackedFloat32Array([0, 0, 0])
var _lift := 0.0
var _eye_mat := StandardMaterial3D.new()
var _parts: BossParts
var _state := WorldReader.STATE_SPAWN
var _rise := 0.0
var _charge := 0.0


func setup() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_parts = BossParts.new()
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
	shadow.set_meta(SoloVat.LIVE, true)
	add_child(shadow)
	if vat:  # v0.11.0 S4: the crowd draws the body
		has_model = EnemyModels.has_model(&"lens_drone")  # (its ring spins as the model's does)
		_pose()
		return
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
	if dt <= 0.0 or (pod == null and not vat):
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
	return _lift


## v0.11.0 S4: the pose's numbers first (the hover, the pod's roll, the ring's turn: the VAT drives), then the nodes
## from them (the old path).
func _pose() -> void:
	var bob := sin(_t * TAU * 0.8) * BOB_M
	_lift = lerpf(0.4, HOVER_Y, _rise) + bob
	_vd[RX] = sin(_t * 1.5) * 0.08
	_vd[RZ] = sin(_t * 1.9) * 0.06 - 0.05 * _charge
	# The code-made ring turns about its tube; the owner's ring of feet spins under the pod (v0.8.0 MI), faster as
	# the eye charges.
	_vd[SPIN] = fposmod(_t * (2.5 + 6.0 * _charge if has_model else 2.5), TAU)
	_eye_mat.emission_energy_multiplier = 1.8 + 3.5 * _charge
	var s := lerpf(0.6, 1.0, _rise) * (1.0 - bob)
	shadow.scale = Vector3(s, 1, s)
	if vat:
		return
	pod.position = Vector3(0, _lift, 0)
	pod.rotation = Vector3(_vd[RX], 0, _vd[RZ])
	ring.rotation = Vector3(0, _vd[SPIN], 0) if has_model else Vector3(_vd[SPIN], 0, 0)


# --- v0.11.0 S4: the VAT rig (SoloVat) ----------------------------------------------------------------------------


## The pod's height (m): the whole body's lift VatCrowd moves the instance by (the ground disc is its own node).
func vat_lift() -> float:
	return _lift


func vat_drives() -> PackedFloat32Array:
	return SoloVat.normalized(_vd, VAT_DRIVES)


## The eye slit's glow (flaring through the windup).
func glow_energy() -> float:
	return _eye_mat.emission_energy_multiplier


## The pod rolls (about X, then Z, as its rotation composes them); the ring turns on its mount (about Y for the
## owner's ring of feet, about X for the code-made tube).
func vat_rig() -> Dictionary:
	var mount := SoloVat.between(pod, ring.get_parent()) * SoloVat.at(ring.position)
	var joints: Array = [
		[RX, -1, null, SoloVat.turn(Vector3.RIGHT)],
		[RZ, 0, pod, SoloVat.turn(Vector3.BACK)],
		[SPIN, 1, ring, SoloVat.turn(Vector3.UP if has_model else Vector3.RIGHT, 1.0, mount)],
	]
	var out := SoloVat.rig(
		"lens_drone", VAT_DRIVES, [[[RX, 17]], [[RZ, 17]], [[SPIN, 128]]], joints, false
	)
	if has_model:  # the owner's model's colour map (VatLooks' textured variant)
		out["albedo_tex"] = EnemyModels.get_model(&"lens_drone")["texture"]
	return out
