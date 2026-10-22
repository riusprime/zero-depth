class_name RuneGlyphs
extends RefCounted
## v0.9.0 RA (owner Q22: "a carving on the wall shows the 3 symbols"; W3 understood in under 5 s): the rune puzzle's
## four symbols, simple and angular, each told apart at a glance by its outline alone: 0 a chevron (Λ), 1 a cross (X),
## 2 a square ring, 3 three bars (≡). Built from thin boxes in the local XY plane, facing +Z, `size` m across. The
## pillars' faces and the carving's sockets draw the same ones. Presentation only.

const COUNT := 4
const BAR := 0.12


## Symbol `code` (0..3) as a node of bars, `size` m across, in material `mat`.
static func build(code: int, size: float, mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Glyph%d" % code
	var t := size * BAR
	match code:
		0:
			_bar(root, Vector2(-size * 0.22, 0.0), Vector2(t, size), 0.42, mat)
			_bar(root, Vector2(size * 0.22, 0.0), Vector2(t, size), -0.42, mat)
		1:
			_bar(root, Vector2.ZERO, Vector2(t, size * 1.1), PI * 0.25, mat)
			_bar(root, Vector2.ZERO, Vector2(t, size * 1.1), -PI * 0.25, mat)
		2:
			for s in [-1.0, 1.0]:
				_bar(root, Vector2(0.0, s * size * 0.42), Vector2(size, t), 0.0, mat)
				_bar(root, Vector2(s * size * 0.42, 0.0), Vector2(t, size), 0.0, mat)
		_:
			for s in [-1.0, 0.0, 1.0]:
				_bar(root, Vector2(0.0, s * size * 0.36), Vector2(size * 0.9, t), 0.0, mat)
	return root


static func _bar(root: Node3D, at: Vector2, size: Vector2, roll: float, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, size.y, 0.03)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = Vector3(at.x, at.y, 0.0)
	node.rotation.z = roll
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
