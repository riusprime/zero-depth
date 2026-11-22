class_name GlacierTurtleBody
extends RefCounted
## The Glacier Turtle's node body (GlacierTurtleAvatar.setup on the node path, the VAT crowd off): the owner's model's
## parts in their joints' frames, or the code-made stand-in on the same joints. The avatar poses the frames; this only
## builds what hangs in them. Presentation only (EI-07).

const A := preload("res://src/presentation/world_view/glacier_turtle_avatar.gd")


## The frame node a part's mesh hangs in and that frame's own pivot (m).
static func frame_of(a: GlacierTurtleAvatar, part: StringName) -> Array:
	match part:
		&"carapace":
			return [a.carapace, a._pivots[&"carapace"]]
		&"head":
			return [a.head, a._pivots[&"head"]]
		&"shield":
			return [a.shield, a._pivots[&"shield"]]
	var s := String(part)
	var k := A.LEGS.find(StringName(s.substr(4, 2)))
	if not s.begins_with("leg_") or k < 0:
		return [a.rig, Vector3.ZERO]
	return [a.uppers[k] if s.ends_with("_u") else a.lowers[k], a._pivots[part]]


## The owner's model: each part's mesh in its joint's frame, its surfaces on the base plates (the colour map as
## delivered; a role surface, if any, tinted COLOR) and the visor's glow.
static func build_model(a: GlacierTurtleAvatar, m: Dictionary) -> void:
	var tex: Texture2D = m["texture"]
	var s: float = m["scale"]
	var parts_in: Dictionary = m["parts"]
	var mats := {}
	for slot: StringName in [&"base", &"role"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = A.COLOR if slot == &"role" else Color.WHITE
		mat.roughness = 1.0
		mat.set_meta(&"enemy_tex", true)
		mats[slot] = ActorViews.flashable(mat)
		a.body_materials.append(mat)
	for pname: StringName in parts_in:
		var part: Dictionary = parts_in[pname]
		var f: Array = frame_of(a, pname)
		var mi := MeshInstance3D.new()
		mi.name = String(pname)
		mi.mesh = part["mesh"]
		mi.position = a._pivots[pname] - (f[1] as Vector3)
		mi.scale = Vector3.ONE * s
		var surfaces: Array = part["surfaces"]
		for k in surfaces.size():
			mi.set_surface_override_material(
				k, a._visor_mat if surfaces[k] == &"glow" else mats.get(surfaces[k], mats[&"base"])
			)
		(f[0] as Node3D).add_child(mi)


## The code-made stand-in (the model file missing): boxes on the same joints, so every clip still plays.
static func build_code(a: GlacierTurtleAvatar) -> void:
	var charcoal := Color("#2A2828")
	var grey := Color("#5C5A58")
	_piece(a, a.rig, Vector3(0.8, 0.26, 0.6), Vector3(-0.1, 0.32, 0), charcoal)
	_piece(a, a.carapace, Vector3(0.84, 0.24, 0.8), Vector3(0.0, 0.06, 0), A.ICE)
	_piece(a, a.carapace, Vector3(0.3, 0.08, 0.3), Vector3(0.0, 0.2, 0), A.COLOR)
	_piece(a, a.head, Vector3(0.22, 0.18, 0.2), Vector3(0.12, -0.04, 0), charcoal)
	_glow_box(a.head, Vector3(0.03, 0.06, 0.08), Vector3(0.24, -0.04, 0), a._visor_mat)
	_piece(a, a.shield, Vector3(0.12, 0.88, 0.56), Vector3(-0.1, 0.44, 0), A.ICE)
	for k in A.LEGS.size():
		var hip: Vector3 = a._pivots[StringName("leg_%s_u" % A.LEGS[k])]
		var knee: Vector3 = a._pivots[StringName("leg_%s_l" % A.LEGS[k])]
		_rod(a, a.uppers[k], Vector3.ZERO, knee - hip, grey)
		_rod(a, a.lowers[k], Vector3.ZERO, a._feet[k] - knee, grey)


static func _piece(
	a: GlacierTurtleAvatar, parent: Node3D, size: Vector3, at: Vector3, c: Color
) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return a._body_piece(parent, m, at, c)


static func _glow_box(parent: Node3D, size: Vector3, at: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)


static func _rod(
	a: GlacierTurtleAvatar, parent: Node3D, from: Vector3, to: Vector3, c: Color
) -> void:
	var piece := _piece(a, parent, Vector3(0.12, (to - from).length(), 0.12), (from + to) * 0.5, c)
	piece.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))
