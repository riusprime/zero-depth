class_name BarChunks
extends MultiMeshInstance3D
## v0.8.0 N4 (owner O57: "the damage chunks with the ligher health decaying also applies to enemies, not just the
## players health"): the damage chunk on the bars over enemies (and over the hero): each bar's motion is a
## HealthBarTrail (the chunk holds from the burst's first hit, then drains; a heal grows the fill), and every chunk
## on screen is drawn by this one MultiMesh (one draw call however many bars show, PF budget): two light strips per
## bar, one each side of its fill (the bar shrinks toward its centre). Billboarded by hand to the camera's basis, at
## each bar's interpolated position. Reads what ActorViews gives it (the sim's fraction); decides nothing.

## The chunk's light (brighter while a big hit's light lasts).
const CHUNK := Color(1, 0.96, 0.86, 0.55)
const CHUNK_BIG := Color(1, 1, 0.94, 0.9)
## Instances the buffer grows by.
const GROW := 128
const HEIGHT := 0.07

## Trails by actor id, and the bar pivot each scales.
var _trails := {}
var _pivots := {}
var _width := 0.55
var _drawn := 0


func _init(bar_width: float = 0.55) -> void:
	name = "BarChunks"
	_width = bar_width
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	custom_aabb = AABB(Vector3(-4096, -64, -4096), Vector3(8192, 128, 8192))
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, HEIGHT)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 1
	quad.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = 0
	multimesh = mm
	visible = false


## ActorViews.sync: bar `pivot` of actor `id` shows fraction `f` this tick (a bar first seen starts full, so the first
## hit's chunk shows; `snap` shows it as is).
func feed(id: int, pivot: Node3D, f: float, snap: bool = false) -> void:
	var t: HealthBarTrail = _trails.get(id)
	if t == null:
		t = HealthBarTrail.new()
		_trails[id] = t
		_pivots[id] = pivot
		if snap:
			t.snap(f)
	t.set_target(f)
	pivot.scale = Vector3(maxf(t.fill, 0.001), 1, 1)


## Actor `id`'s bar is gone (its actor, or hidden): its trail goes.
func forget(id: int) -> void:
	_trails.erase(id)
	_pivots.erase(id)


## Drops the trails of actors not in `alive` (bounded with the actors).
func keep_only(alive: Dictionary) -> void:
	for id in _trails.keys():
		if not alive.has(id):
			forget(id)


func trail_of(id: int) -> HealthBarTrail:
	return _trails.get(id)


## Chunk strips drawn this frame (tests, the perf note).
func drawn() -> int:
	return _drawn


func trail_count() -> int:
	return _trails.size()


func _process(delta: float) -> void:
	advance(delta)


## Runs every moving trail `delta` seconds and lays out the strips (the views' frame; tests call it).
func advance(delta: float) -> void:
	var basis := Basis.IDENTITY
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		basis = cam.global_transform.basis.orthonormalized()
	var right := basis.x
	var n := 0
	var mm := multimesh
	var need := _trails.size() * 2
	if mm.instance_count < need:  # grows only (a resize clears the buffer; every strip is laid out below anyway)
		mm.instance_count = (need / GROW + 1) * GROW
	for id: int in _trails:
		var t: HealthBarTrail = _trails[id]
		if not t.moving():
			continue
		t.advance(delta)
		var pivot: Node3D = _pivots[id]
		if not is_instance_valid(pivot):
			continue
		pivot.scale = Vector3(maxf(t.fill, 0.001), 1, 1)
		var size := t.chunk_size()
		if size <= 0.0 or not pivot.visible:
			continue
		var hf := t.fill * _width * 0.5
		var hc := t.chunk * _width * 0.5
		var w := hc - hf
		var at := (
			pivot.get_global_transform_interpolated().origin
			if pivot.is_inside_tree()
			else pivot.position
		)
		var c := CHUNK_BIG if t.big > 0.0 else CHUNK
		var b := Basis(basis.x * w, basis.y, basis.z)
		var mid := (hf + hc) * 0.5
		mm.set_instance_transform(n, Transform3D(b, at + right * mid))
		mm.set_instance_color(n, c)
		mm.set_instance_transform(n + 1, Transform3D(b, at - right * mid))
		mm.set_instance_color(n + 1, c)
		n += 2
	mm.visible_instance_count = n
	visible = n > 0
	_drawn = n
