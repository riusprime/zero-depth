class_name ModifierOverlays
extends Node3D
## v0.6.0 MX4 (docs/design/MODIFIER_ENGINE.md §4: "A card adds an overlay only when the spec change alone isn't
## readable"): the few M-list effects no attack spec draws, read from WorldReader.modifier_marks:
## - Aether Shell: a pale green shell round the hero while the barrier is up, and a flash when it takes a hit;
## - Ascension: a warm ring at the hero's feet while the next attack is charged;
## - Phase Dash: a violet veil over the hero for the intangible dash;
## - Venom Core: a green drop over each poisoned enemy;
## - a queued launch (Long Shadow's afterimage, Twin Cast's repeat): a faint violet mark where it will fire.
## Presentation only (EI-07): it decides nothing. Every mesh is made once and only shown or moved.

const SHELL_R := 0.8
const SHELL := Color(0.55, 1.0, 0.78, 0.22)
const SHELL_FLASH_TICKS := 12
const CHARGE := Color(1.0, 0.72, 0.42, 0.85)
const PHASE := Color(0.72, 0.5, 1.0, 0.3)
const VENOM := Color(0.45, 0.95, 0.35, 0.95)
const QUEUED := Color(0.72, 0.5, 1.0, 0.35)
const POOL := 24

var shell := MeshInstance3D.new()
var charge := MeshInstance3D.new()
var phase := MeshInstance3D.new()
var drops: Array[MeshInstance3D] = []
var marks: Array[MeshInstance3D] = []
var _shell_mat := StandardMaterial3D.new()


func _ready() -> void:
	var s := SphereMesh.new()
	s.radius = SHELL_R
	s.height = SHELL_R * 2.0
	shell.mesh = s
	_shell_mat = _material(SHELL)
	shell.material_override = _shell_mat
	add_child(shell)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.5
	ring.outer_radius = 0.62
	charge.mesh = ring
	charge.material_override = _material(CHARGE)
	add_child(charge)
	var veil := CylinderMesh.new()
	veil.top_radius = 0.5
	veil.bottom_radius = 0.5
	veil.height = 1.8
	phase.mesh = veil
	phase.material_override = _material(PHASE)
	add_child(phase)
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.12
	drop_mesh.height = 0.3
	var mark_mesh := CylinderMesh.new()
	mark_mesh.top_radius = 0.45
	mark_mesh.bottom_radius = 0.45
	mark_mesh.height = 0.02
	for k in POOL:
		drops.append(_pooled(drop_mesh, VENOM))
		marks.append(_pooled(mark_mesh, QUEUED))
	for n: MeshInstance3D in [shell, charge, phase]:
		n.visible = false
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _pooled(mesh: Mesh, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _material(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	add_child(m)
	return m


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.no_depth_test = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func sync(reader: WorldReader) -> void:
	var m := reader.modifier_marks()
	var hero := SimPlane.to_3d(reader.player_pos())
	var flash := (
		int(m["shell_tick"]) >= 0 and reader.tick() - int(m["shell_tick"]) < SHELL_FLASH_TICKS
	)
	shell.visible = bool(m["shell"]) or flash
	shell.position = hero + Vector3(0, 0.9, 0)
	_shell_mat.albedo_color = Color(SHELL, 0.6) if flash else SHELL
	charge.visible = bool(m["charged"])
	charge.position = hero + Vector3(0, 0.05, 0)
	phase.visible = bool(m["phase"])
	phase.position = hero + Vector3(0, 0.9, 0)
	_place(drops, m["poisoned"], 1.9)
	_place(marks, m["queued"], 0.04)


static func _place(pool: Array[MeshInstance3D], at: PackedVector2Array, height: float) -> void:
	for k in pool.size():
		pool[k].visible = k < at.size()
		if k < at.size():
			pool[k].position = SimPlane.to_3d(at[k], height)


## Whether `what` ("shell", "charge", "phase") is shown, and how many drops and marks are (the tests read it).
func shown(what: String) -> bool:
	match what:
		"shell":
			return shell.visible
		"charge":
			return charge.visible
		"phase":
			return phase.visible
	return false


func count_shown(pool_name: String) -> int:
	var n := 0
	for d in drops if pool_name == "drops" else marks:
		if d.visible:
			n += 1
	return n
