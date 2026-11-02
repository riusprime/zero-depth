class_name ParticleShadowOff
extends Node
## v0.10.5 PB (owner, perf wave 2 option 3: "yes particles should not draw shadows"; evidence/DRAW_CALLS.md: 123 of a
## 60-enemy fight's sun-shadow draws were the VFX pack's particles): every GPUParticles3D and CPUParticles3D under
## its parent (WorldViewRoot, HubView) casts no shadow. One central place instead of each effect's own code: the
## pack's scenes, the pools and the hand-built motes all pass through here when they join the tree (node_added), and
## the ones already under the parent are set when this node enters. RenderSwitches.PARTICLES_NO_SHADOW false: the
## particles keep the shadow setting their scene gives them. Presentation only (EI-07): writes only cast_shadow.

var _root: Node


func _init() -> void:
	name = "ParticleShadowOff"


func _enter_tree() -> void:
	_root = get_parent()
	if not RenderSwitches.PARTICLES_NO_SHADOW:
		return
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	if _root != null:
		for n in _root.find_children("*", "GeometryInstance3D", true, false):
			off(n)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


## A particle system: its shadow off. Anything else is left alone.
static func off(n: Node) -> void:
	if n is GPUParticles3D or n is CPUParticles3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Whether `n` is a particle system that still casts a shadow (the tests and the census read it).
static func casts(n: Node) -> bool:
	return (
		(n is GPUParticles3D or n is CPUParticles3D)
		and (n as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)


func _on_node_added(n: Node) -> void:
	if (n is GPUParticles3D or n is CPUParticles3D) and _root != null and _root.is_ancestor_of(n):
		off(n)
