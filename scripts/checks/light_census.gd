extends RefCounted
## The frame probe's light and ring counts (scripts/checks/frame_probe.gd --fx): per measured frame, the sim's live
## rings, and the omni and spot lights the clustered Forward+ renderer has to shade: how many are on, how many reach
## into the camera's view, how many cast shadows, their summed screen cover (each light's range sphere as a screen
## square, clipped to the screen, as a percent of it: the per-pixel light cost grows with it), and the effects layer's
## own pooled lights (VfxCore.lights) among them. Probe-only, never loaded by the game.

var _lights: Array[Light3D] = []


## Keeps every omni and spot light the tree has or gets.
func setup(tree: SceneTree) -> void:
	tree.node_added.connect(_on_added)
	var stack: Array[Node] = [tree.root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		_on_added(n)


func _on_added(n: Node) -> void:
	if n is OmniLight3D or n is SpotLight3D:
		_lights.append(n as Light3D)


## This frame's counts, as {counter name: value}.
func count(main: Node) -> Dictionary:
	var view: Node = main.get(&"view")
	var cam: Camera3D = view.get(&"rig").get(&"camera")
	var vp := cam.get_viewport().get_visible_rect().size
	var on := 0
	var in_view := 0
	var shadowed := 0
	var cover := 0.0
	var layer_on := 0
	var keep: Array[Light3D] = []
	for l in _lights:
		if not is_instance_valid(l):
			continue
		keep.append(l)
		if not l.is_visible_in_tree() or l.light_energy <= 0.0:
			continue
		on += 1
		var rng := (
			(l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range
		)
		var p := l.global_position
		var s := l.global_transform.basis.get_scale()
		rng *= maxf(s.x, maxf(s.y, s.z))
		if not _sphere_in_view(cam, p, rng):
			continue
		in_view += 1
		if l.shadow_enabled:
			shadowed += 1
		var c := cam.unproject_position(p)
		var e := cam.unproject_position(p + cam.global_transform.basis.x * rng)
		var half := c.distance_to(e)
		var w := clampf(c.x + half, 0.0, vp.x) - clampf(c.x - half, 0.0, vp.x)
		var h := clampf(c.y + half, 0.0, vp.y) - clampf(c.y - half, 0.0, vp.y)
		cover += w * h / (vp.x * vp.y) * 100.0
	_lights = keep
	var forms: Node = view.get(&"attack_forms")
	var layer: VfxCore = forms.get(&"vfx")
	if layer != null:
		for l in layer.lights:
			if l.visible:
				layer_on += 1
	var w: World = main.get(&"driver").get(&"world")
	return {
		"rings_live": w.ab.ring_pos.size(),
		"lights_on": on,
		"lights_in_view": in_view,
		"lights_shadowed_in_view": shadowed,
		"lights_screen_cover_pct": cover,
		"layer_lights_on": layer_on,
	}


static func _sphere_in_view(cam: Camera3D, p: Vector3, r: float) -> bool:
	for pl: Plane in cam.get_frustum():
		if pl.distance_to(p) > r:
			return false
	return true
