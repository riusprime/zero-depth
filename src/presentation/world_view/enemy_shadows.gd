class_name EnemyShadows
extends RefCounted
## v0.10.5 PA (owner, perf wave 2: "instead of making a so detailed shadow add something the shape of it that doesnt
## have that many parts, just 1 but shaped like it"; the blob: "let's try sure"): a normal or elite enemy's visible
## parts cast no shadow. Its shadow comes from one stand-in instead, by ViewPrefs.enemy_shadows:
## - "proxy" (default): one shadow-only mesh (SHADOWS_ONLY) shaped like it: the parts that cast before, merged into one
##   ArrayMesh in the rest pose, built once per kind and shared by every enemy of that kind. It is a child of the
##   avatar, so it follows the actor's position, facing, lean, rise-in, vanish and fall; the limbs don't animate.
## - "blob": a soft dark disc on the floor (one shared quad, an unshaded alpha material), sized to the actor's radius;
##   nothing of the enemy is drawn in a shadow pass.
## Bosses and the hero keep their real shadows (ActorViews never calls this for them). Presentation only (EI-07).

const MODES: Array[String] = ["proxy", "blob"]
const PROXY_NAME := &"ShadowProxy"
const BLOB_NAME := &"ShadowBlob"
## The blob's diameter is this many times the actor's radius (the sun's shadow of a body spreads past its feet).
## Starting value.
const BLOB_SCALE := 3.2
## The blob's darkness at its centre (alpha). Starting value.
const BLOB_ALPHA := 0.45
## Just over the contact disc (ActorViews: y 0.006), under the team ring (0.02).
const BLOB_Y := 0.012

## The merged shadow meshes by kind (null: the kind had no casting part).
static var _cache: Dictionary = {}
static var _blob_mesh: QuadMesh
static var _blob_mat: StandardMaterial3D


## Forgets the cached meshes (tests).
static func clear_cache() -> void:
	_cache.clear()


## The cached proxy meshes (tests).
static func cached_kinds() -> int:
	return _cache.size()


## Gives the actor `root` (its parts under `facing`; `host` the avatar, or the facing for a model without one) its
## shadow in `mode`, after turning off every visible part's own. Returns the stand-in node (null if none).
static func apply(
	root: Node3D, facing: Node3D, host: Node3D, kind: int, radius: float, mode: String
) -> GeometryInstance3D:
	if mode == "blob":
		_all_off(facing)
		return _add_blob(root, radius)
	var mesh := proxy_mesh(kind, host)
	_all_off(facing)
	if mesh == null:
		return null
	var proxy := MeshInstance3D.new()
	proxy.name = PROXY_NAME
	proxy.mesh = mesh
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	host.add_child(proxy)
	return proxy


## The proxy mesh of `kind` (null: no casting part): the cached one, else merged now from `host`'s casting parts
## (a VatCrowd gives a reference avatar, its own enemies having no parts).
static func proxy_mesh(kind: int, host: Node3D) -> ArrayMesh:
	if _cache.has(kind):
		return _cache[kind]
	var casters: Array = []
	var stood := _stand(host)
	_collect(host, Transform3D.IDENTITY, casters)
	if stood:
		_unstand(host as AvatarBase)
	var mesh := _merge(casters)
	_cache[kind] = mesh
	return mesh


## A fresh avatar is built posed for the rise-in, sunk under the floor; merged so,
## the stand-in sat under the floor and cast nothing. It is posed standing for the merge (its first state as a
## standing one: every avatar rises fully then), then put back to a fresh, unsynced one (its first real sync poses it
## from the sim's state, as before). Presentation only. False: `host` is not a fresh avatar (left as it is).
static func _stand(host: Node3D) -> bool:
	var a := host as AvatarBase
	if a == null or not a._fresh or not a.has_method(&"apply_state"):
		return false
	a.apply_state(_state_dict(WorldReader.STATE_MOVE))
	return true


## Back to a fresh avatar posed for the rise-in, as setup() left it.
static func _unstand(a: AvatarBase) -> void:
	a._fresh = true
	a.apply_state(_state_dict(WorldReader.STATE_SPAWN))
	a._fresh = true
	a._last_tick = -1
	a._last_pos = Vector2.ZERO
	a._vel = Vector2.ZERO


static func _state_dict(state: int) -> Dictionary:
	return {"tick": 0, "state": state, "pos": Vector2.ZERO, "windup": 0.0}


## Every GeometryInstance3D under `n` stops casting.
static func _all_off(n: Node) -> void:
	for c in n.get_children():
		var g := c as GeometryInstance3D
		if g != null:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_all_off(c)


## The casting, shown MeshInstance3D under `n` with their transforms in `n`'s space: [[mesh, xf], ...].
static func _collect(n: Node, xf: Transform3D, out: Array) -> void:
	for c in n.get_children():
		var n3 := c as Node3D
		if n3 == null or not n3.visible:
			continue
		var cxf := xf * n3.transform
		var mi := c as MeshInstance3D
		if (
			mi != null
			and mi.mesh != null
			and mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		):
			out.append([mi.mesh, cxf])
		_collect(c, cxf, out)


## One ArrayMesh (one surface: positions, normals, indices) of every caster's triangles at its rest transform.
static func _merge(casters: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for c: Array in casters:
		var mesh: Mesh = c[0]
		var xf: Transform3D = c[1]
		var nb := xf.basis.inverse().transposed()
		for s in mesh.get_surface_count():
			var am := mesh as ArrayMesh  # a PrimitiveMesh is always triangles
			if am != null and am.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arr := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			if v.is_empty():
				continue
			var nrm: Variant = arr[Mesh.ARRAY_NORMAL]
			var base := verts.size()
			for k in v.size():
				verts.append(xf * v[k])
				if nrm is PackedVector3Array and (nrm as PackedVector3Array).size() == v.size():
					normals.append((nb * (nrm as PackedVector3Array)[k]).normalized())
				else:
					normals.append(Vector3.UP)
			var ind: Variant = arr[Mesh.ARRAY_INDEX]
			if ind is PackedInt32Array and not (ind as PackedInt32Array).is_empty():
				for k in ind as PackedInt32Array:
					idx.append(base + k)
			else:
				for k in v.size():
					idx.append(base + k)
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## The blob: a flat soft disc under the actor (on its root, so it never tilts with the body).
static func _add_blob(root: Node3D, radius: float) -> MeshInstance3D:
	blob_parts()
	var blob := MeshInstance3D.new()
	blob.name = BLOB_NAME
	blob.mesh = _blob_mesh
	blob.material_override = _blob_mat
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.scale = Vector3.ONE * maxf(radius, 0.2) * BLOB_SCALE
	blob.position.y = BLOB_Y
	root.add_child(blob)
	return blob


## The blob's shared [mesh, material] (CritterCrowd draws the critters' blobs as one MultiMesh of it).
static func blob_parts() -> Array:
	if _blob_mesh == null:
		_blob_mesh = QuadMesh.new()
		_blob_mesh.size = Vector2.ONE
		_blob_mesh.orientation = PlaneMesh.FACE_Y
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 1))
		g.set_color(1, Color(0, 0, 0, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.albedo_color = Color(1, 1, 1, BLOB_ALPHA)
		_blob_mat.albedo_texture = tex
	return [_blob_mesh, _blob_mat]
