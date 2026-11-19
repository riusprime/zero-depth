extends RefCounted
## What a frame compiled, and what was drawn for the first time around it: for the probes' --pipelines option
## (scripts/checks/frame_probe.gd, scripts/checks/floor_fight_probe.gd). Every frame it reads the renderer's pipeline
## compile counters (canvas, mesh, surface, draw, specialization) and walks the visible 3D instances under `root`,
## keeping a key per kind of thing drawn: the owner's script (or the node's class), the mesh's resource and the
## material's resource or its look (a StandardMaterial3D's flags: transparency, shading, billboard, blend, culling,
## textures). A frame whose counters moved prints a `PIPES` line with the counts and the keys first seen in that frame
## and the two before it (a pipeline is compiled when its draw is first set up, a frame or two after the node shows).
## Probe-only, never loaded by the game. The walk costs milliseconds a frame: never time a --pipelines run.

const KINDS: Array[int] = [
	RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS,
	RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
	RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE,
	RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
	RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION,
]
const KEEP_FRAMES := 3

var lines := 0
var compiles := PackedInt32Array([0, 0, 0, 0, 0])
var _last := PackedInt32Array()
var _seen := {}
var _recent: Array = []  # the keys first seen, per frame, the newest last
var _last_us := 0
var _ids := {}
var _new_nodes: Array = []  # the instances made, per frame, the newest last


## One frame: `root` is the subtree walked, `tag` names the probe's phase in the printed line.
func frame(root: Node, tag: String) -> void:
	var now := Time.get_ticks_usec()
	var fresh := PackedStringArray()
	var made := PackedStringArray()
	_walk(root, fresh, made, false)
	_recent.append(fresh)
	_new_nodes.append(made)
	while _recent.size() > KEEP_FRAMES:
		_recent.pop_front()
		_new_nodes.pop_front()
	var cur := PackedInt32Array()
	for k in KINDS:
		cur.append(RenderingServer.get_rendering_info(k))
	if not _last.is_empty():
		var d := PackedInt32Array()
		var any := false
		for i in cur.size():
			d.append(cur[i] - _last[i])
			compiles[i] += d[i]
			any = any or d[i] != 0
		if any:
			var keys := PackedStringArray()
			for f: PackedStringArray in _recent:
				keys.append_array(f)
			var nodes := PackedStringArray()
			for f: PackedStringArray in _new_nodes:
				nodes.append_array(f)
			print(
				(
					"PIPES t=%.2f %s frame_ms=%.1f canvas/mesh/surface/draw/spec=%s new: %s || made: %s"
					% [
						now / 1e6,
						tag,
						(now - _last_us) / 1000.0,
						d,
						" | ".join(keys),
						" | ".join(nodes.slice(0, 30))
					]
				)
			)
			lines += 1
	_last = cur
	_last_us = now


func _walk(n: Node, fresh: PackedStringArray, made: PackedStringArray, hidden: bool) -> void:
	var off := hidden or (n is Node3D and not (n as Node3D).visible)
	off = off or (n is CanvasItem and not (n as CanvasItem).visible)
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		var id := g.get_instance_id()
		if not _ids.has(id):
			_ids[id] = true
			var ks := _keys(g)
			made.append(
				("(hidden) " if off else "") + (ks[0] if not ks.is_empty() else g.get_class())
			)
		if not off:
			for k in _keys(g):
				if not _seen.has(k):
					_seen[k] = true
					fresh.append(k)
	for c in n.get_children(true):
		_walk(c, fresh, made, off)


func _keys(g: GeometryInstance3D) -> PackedStringArray:
	var who := _owner_name(g)
	var out := PackedStringArray()
	var mesh: Mesh = null
	if g is MeshInstance3D:
		mesh = (g as MeshInstance3D).mesh
	elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
		mesh = (g as MultiMeshInstance3D).multimesh.mesh
	elif g is GPUParticles3D:
		mesh = (g as GPUParticles3D).draw_pass_1
	elif g is CPUParticles3D:
		mesh = (g as CPUParticles3D).mesh
	var mats: Array[Material] = []
	if g.material_override != null:
		mats.append(g.material_override)
	elif mesh != null:
		for s in mesh.get_surface_count():
			var m: Material = null
			if g is MeshInstance3D:
				m = (g as MeshInstance3D).get_active_material(s)
			else:
				m = mesh.surface_get_material(s)
			if m != null:
				mats.append(m)
	if g is GPUParticles3D and (g as GPUParticles3D).process_material != null:
		mats.append((g as GPUParticles3D).process_material)
	if g is SpriteBase3D or g is Label3D:
		out.append("%s %s" % [who, g.get_class()])
		return out
	var mesh_name := _res_name(mesh)
	if mats.is_empty():
		out.append("%s %s %s (no material)" % [who, g.get_class(), mesh_name])
	for m in mats:
		out.append("%s %s %s %s" % [who, g.get_class(), mesh_name, _mat_key(m)])
	return out


static func _owner_name(n: Node) -> String:
	var p := n
	while p != null:
		var s: Script = p.get_script()
		if s != null and not s.resource_path.is_empty():
			return s.resource_path.get_file().get_basename()
		p = p.get_parent()
	return n.get_class()


static func _res_name(r: Resource) -> String:
	if r == null:
		return "-"
	if not r.resource_path.is_empty():
		return r.resource_path.get_file()
	return r.get_class()


static func _mat_key(m: Material) -> String:
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		if sh != null and sh.resource_path.is_empty():  # made in code: each new Shader compiles anew
			return "shader:Shader#%d" % sh.get_instance_id()
		return "shader:" + (_res_name(sh) if sh != null else "-")
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		return (
			"std:t%d s%d bb%d bl%d c%d tex%d%d vc%d%s"
			% [
				b.transparency,
				b.shading_mode,
				b.billboard_mode,
				b.blend_mode,
				b.cull_mode,
				int(b.albedo_texture != null),
				int(b.emission_enabled),
				int(b.vertex_color_use_as_albedo),
				" next" if b.next_pass != null else ""
			]
		)
	return m.get_class()
