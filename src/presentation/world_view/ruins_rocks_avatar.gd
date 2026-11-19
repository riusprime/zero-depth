class_name RuinsRocksAvatar
extends AvatarBase
## ENEMIES.md R1-R4: the Ruins' and the Night Rocks' signature pieces still drawn in code, as nodes (they come one or
## two at a time, not in crowds):
## - Cable post (WIRE_POST): a short grey post with a sparking yellow top, where a Wire Weaver planted it.
## (The Scrap Hound, the Rock Lurker, the Stone Thrower and the Wire Weaver are on the owner's models:
## ScrapHoundAvatar, RockLurkerAvatar, StoneThrowerAvatar, WireWeaverAvatar.)
## Presentation only (EI-07): sync() reads the sim through WorldReader once per tick, advance() animates in frame time.
## +X is the front.

const COLORS := {
	WorldReader.KIND_WIRE_POST: Color("#E8C22E"),
}
const HEIGHTS := {
	WorldReader.KIND_WIRE_POST: 0.95,
}
const GREY := Color("#8A817C")
const GREY_DARK := Color("#5F5551")
## The post top's glow (emission energy).
const SPARK := 7.0

var kind := -1
var height := 1.0
var _model := Node3D.new()
var _body := Node3D.new()
var _visor_mat: StandardMaterial3D


static func draws(p_kind: int) -> bool:
	return COLORS.has(p_kind)


## Builds the body of `p_kind` under `facing` and marks `root` (ActorViews: the avatar, its body materials for the
## hit flash); returns its height.
static func attach(root: Node3D, facing: Node3D, p_kind: int) -> float:
	var sig := RuinsRocksAvatar.new()
	sig.setup(p_kind)
	facing.add_child(sig)
	root.set_meta(&"enemy_avatar", sig)
	root.set_meta(&"mats", sig.body_materials.duplicate())
	return sig.height


## Builds the model for `p_kind` (one of COLORS).
func setup(p_kind: int) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	kind = p_kind
	height = HEIGHTS.get(kind, 1.0)
	add_child(_model)
	_model.add_child(_body)
	_visor_mat = _glow(COLORS[kind], SPARK)
	_build_post()


# --- Pieces -----------------------------------------------------------------------------------------------------
func _box(parent: Node3D, size: Vector3, at: Vector3, c: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _body_piece(parent, m, at, c)


func _rod(parent: Node3D, length: float, r: float, at: Vector3, c: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r * 0.8
	m.height = length
	m.radial_segments = 6
	m.rings = 1
	return _body_piece(parent, m, at, c)


static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _build_post() -> void:
	_rod(_body, 0.8, 0.07, Vector3(0, 0.4, 0), GREY)
	_box(_body, Vector3(0.22, 0.08, 0.22), Vector3(0, 0.04, 0), GREY_DARK)
	var top := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.18
	s.radial_segments = 6
	s.rings = 3
	top.mesh = s
	top.position = Vector3(0, 0.86, 0)
	top.material_override = _visor_mat
	_body.add_child(top)


# --- Sync and pose ----------------------------------------------------------------------------------------------
func sync(reader: WorldReader, i: int) -> void:
	_track_motion(reader.tick(), reader.actor_pos(i), 30.0)
	_fresh = false


## The post top's glow now (tests).
func visor_energy() -> float:
	return _visor_mat.emission_energy_multiplier


func advance(delta: float) -> void:
	_t += clampf(delta, 0.0, 0.05)
	_visor_mat.emission_energy_multiplier = SPARK * (0.5 + 0.3 * sin(_t * 31.0))
