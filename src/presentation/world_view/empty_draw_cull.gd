class_name EmptyDrawCull
extends Node
## The effect pools'
## MultiMeshes with nothing in them leave the renderer. A pool (a MultiMeshInstance3D whose MultiMesh shows only its
## first visible_instance_count instances: VfxCore's sprites, the boss strikes, spikes, signatures, tides, twins,
## judges, shades, the final boss's marks) stays shown with 0 instances between uses, and the renderer still issues
## its draw in the camera pass and, when it casts, in every shadow pass its 16 km cull margin reaches (the sun's and
## each shadowed torch's two): ~70 of a quiet floor's ~470 draw calls drew nothing.
## Each frame, after every view has filled its pools (PROCESS_LAST), a watched pool whose node is shown but has no
## instance to draw is hidden from the renderer (RenderingServer.instance_set_visible on its own instance), and shown
## again the frame it has one. The node's `visible` is never touched, so the views, ShaderWarmup's proxies and the
## tests see what they set; a node the view hides is left to Godot. Same pixels: an empty MultiMesh draws none.
## Presentation only (EI-07): reads the views' nodes, writes only the renderer's visibility of empty ones.

## After every other node's _process in the frame (the views fill their pools in theirs and in the sync).
const PROCESS_LAST := 1 << 30
## Marks a watched pool (the draw census reads it).
const META := &"empty_draw_cull"

var _root: Node
var _pools: Array[MultiMeshInstance3D] = []
var _scanned := false


func _init() -> void:
	process_priority = PROCESS_LAST
	name = "EmptyDrawCull"


## Watches every pool under its parent (WorldViewRoot), added before or after it.
func _enter_tree() -> void:
	_root = get_parent()
	_scanned = false
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


## A pool: its MultiMesh shows a counted part (visible_instance_count 0 or more when it joins the tree); a whole
## static MultiMesh (-1: all its instances, the kit's decoration) is never watched.
static func is_pool(n: Node) -> bool:
	if not n is MultiMeshInstance3D:
		return false
	var mm := (n as MultiMeshInstance3D).multimesh
	return mm != null and mm.visible_instance_count >= 0


## Nothing to draw: no MultiMesh, or none of its instances shown.
static func is_empty(n: MultiMeshInstance3D) -> bool:
	var mm := n.multimesh
	if mm == null or mm.mesh == null:
		return true
	var shown := mm.visible_instance_count
	return shown == 0 or (shown < 0 and mm.instance_count == 0)


func pools() -> Array[MultiMeshInstance3D]:
	return _pools


func _on_node_added(n: Node) -> void:
	if _root != null and is_pool(n) and _root.is_ancestor_of(n) and not n.has_meta(META):
		_add(n as MultiMeshInstance3D)


func _add(n: MultiMeshInstance3D) -> void:
	n.set_meta(META, true)
	_pools.append(n)


func _scan() -> void:
	_scanned = true
	if _root == null:
		return
	for n in _root.find_children("*", "MultiMeshInstance3D", true, false):
		if is_pool(n) and not n.has_meta(META):
			_add(n as MultiMeshInstance3D)


func _process(_delta: float) -> void:
	if not _scanned:
		_scan()
	var k := 0
	while k < _pools.size():
		var n := _pools[k]
		if not is_instance_valid(n):
			_pools.remove_at(k)
			continue
		k += 1
		if n.is_inside_tree() and n.is_visible_in_tree():
			RenderingServer.instance_set_visible(n.get_instance(), not is_empty(n))
