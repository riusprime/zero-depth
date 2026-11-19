class_name BossPieceModels
extends RefCounted
## The owner's boss attack pieces (docs/OWNER_TODO.md §3.5): the War Banner (`war_banner`), the Clockwork Judge's hour
## clock (`hour_clock`) and the Siege Engine's ammo cart (`siege_cart`), at assets/models/fx/<id>.glb as
## scripts/assets/boss_pieces_v0120_prep.py writes them: already at their size in metres and cut into the parts the
## game moves, one node per part (the banner's pole, top and cloth; the clock and its minute hand; the cart's body and
## four wheels). The javelin is BossSignatureViews' (one part, drawn as a MultiMesh).
## A piece is used when assets/models/manifest.json lists its id and its file is on disk; otherwise get_piece gives {}
## and the caller builds its code-made stand-in (L15: missing art never blocks a step). Each is read once (cached).
## Presentation only.

const DIR := "res://assets/models/fx/"
const MANIFEST := "res://assets/models/manifest.json"

## Where pieces are looked up (tests point it elsewhere to see the stand-ins).
static var dir := DIR
static var _cache := {}
static var _listed := {}
static var _listed_read := false


## {"parts": {part name: {"mesh": Mesh, "at": Vector3 (where its node stands)}}, "texture": the piece's colour map,
## "material": a matte material of it (matte()) }, or {} when the piece is missing or lacks one of `needs`.
static func get_piece(id: StringName, needs: Array = []) -> Dictionary:
	var path := dir + String(id) + ".glb"
	if not _cache.has(path):
		_cache[path] = _read(id, path)
	var out: Dictionary = _cache[path]
	for part: String in needs:
		if not out.get("parts", {}).has(part):
			return {}
	return out


## Drops the cached pieces (tests switch `dir`).
static func clear_cache() -> void:
	_cache.clear()


## A material lit like the walls and the kit's props: the piece's map, matte (roughness 1, metallic 0, the default
## specular), seen from either side (the owner's meshes are thin in places).
static func matte(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 1.0
	m.metallic = 0.0
	m.metallic_specular = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A MeshInstance3D of `piece`'s `part` under `parent`, at the part's own place, on `mat` (the piece's matte material
## when null).
static func put(
	piece: Dictionary, part: String, parent: Node3D, mat: Material = null
) -> MeshInstance3D:
	var p: Dictionary = piece["parts"][part]
	var mi := MeshInstance3D.new()
	mi.name = part.to_pascal_case()
	mi.mesh = p["mesh"]
	mi.position = p["at"]
	mi.material_override = mat if mat != null else piece["material"]
	parent.add_child(mi)
	return mi


static func _read(id: StringName, path: String) -> Dictionary:
	if not _is_listed(id) or not ResourceLoader.exists(path):
		return {}
	var scene := load(path) as PackedScene
	if scene == null:
		return {}
	var root := scene.instantiate()
	var parts := {}
	var tex: Texture2D = null
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		parts[String(mi.name)] = {"mesh": mi.mesh, "at": mi.position}
		var mat := mi.get_active_material(0) as BaseMaterial3D
		if tex == null and mat != null:
			tex = mat.albedo_texture
	root.free()
	if parts.is_empty() or tex == null:
		return {}
	return {"parts": parts, "texture": tex, "material": matte(tex)}


static func _is_listed(id: StringName) -> bool:
	if not _listed_read:
		_listed_read = true
		if FileAccess.file_exists(MANIFEST):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
			if typeof(data) == TYPE_DICTIONARY:
				for m: Dictionary in (data as Dictionary).get("models", []):
					_listed[StringName(String(m.get("id", "")))] = true
	return _listed.has(id)
