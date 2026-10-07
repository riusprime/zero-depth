class_name LensDroneAvatar
extends Node3D
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

const RED := Color("#D8433A")
const GREY := Color("#5F5551")
const EYE := Color("#FF2A22")

var pod: Node3D
var ring: Node3D
var shadow: MeshInstance3D
var body_materials: Array[StandardMaterial3D] = []

var _eye_mat := StandardMaterial3D.new()
var _parts: BossParts
var _fresh := true
var _state := WorldReader.STATE_SPAWN
var _t := 0.0
var _rise := 0.0
var _charge := 0.0


func setup(outline_color: Color, technique: StringName = &"xray") -> void:
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
	_parts.piece(pod, BossParts.block(Vector3(0.5, 0.34, 0.46), 30, 0.3), Vector3.ZERO, RED)
	_parts.piece(
		pod, BossParts.block(Vector3(0.28, 0.1, 0.26), 31, 0.3), Vector3(-0.04, 0.2, 0), GREY
	)
	var eye := _parts.glow(
		pod, BossParts.block(Vector3(0.05, 0.08, 0.28), 33), Vector3(0.26, 0, 0), EYE, 1.8
	)
	_eye_mat = eye.material_override as StandardMaterial3D
	ring = Node3D.new()
	pod.add_child(ring)
	_parts.piece(
		ring,
		BossParts.tube(0.06, 0.42, 34, 10),
		Vector3(-0.03, 0, 0),
		GREY,
		Vector3(0, 0, PI * 0.5)
	)
	body_materials = _parts.body_materials
	_pose()


func sync(reader: WorldReader, i: int) -> void:
	apply_state({"tick": reader.tick(), "state": reader.actor_state(i)})


## The same as sync(), from plain values (tests drive the avatar with this).
func apply_state(s: Dictionary) -> void:
	_state = s["state"]
	if _fresh:
		_fresh = false
		_rise = 0.0 if _state == WorldReader.STATE_SPAWN else 1.0
		_pose()


func _process(delta: float) -> void:
	advance(delta)


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


## The pod's current height above the ground (the hover plus the bob).
func hover_height() -> float:
	return pod.position.y


func _pose() -> void:
	var bob := sin(_t * TAU * 0.8) * BOB_M
	pod.position = Vector3(0, lerpf(0.4, HOVER_Y, _rise) + bob, 0)
	pod.rotation = Vector3(sin(_t * 1.5) * 0.08, 0, sin(_t * 1.9) * 0.06 - 0.05 * _charge)
	ring.rotation = Vector3(_t * 2.5, 0, 0)
	_eye_mat.emission_energy_multiplier = 1.8 + 3.5 * _charge
	var s := lerpf(0.6, 1.0, _rise) * (1.0 - bob)
	shadow.scale = Vector3(s, 1, s)
