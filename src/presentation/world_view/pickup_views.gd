class_name PickupViews
extends Node3D
## Item pedestals (PLAN v0.2.0 F): a stone plinth with a glowing gem floating and turning above it, in the item's
## colour, and a small light. A pedestal disappears when its pickup is taken (the sim removes it).

var _nodes := {}
var _t := 0.0


func sync(reader: WorldReader) -> void:
	var live := {}
	for i in reader.pickup_count():
		var id := reader.pickup_id(i)
		live[id] = true
		if not _nodes.has(id):
			var n := _make(ItemLooks.color(reader.item_kind(reader.pickup_item(i))))
			n.position = SimPlane.to_3d(reader.pickup_pos(i))
			add_child(n)
			n.reset_physics_interpolation()
			_nodes[id] = n
	for id in _nodes.keys():
		if not live.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)


func count() -> int:
	return _nodes.size()


func _process(delta: float) -> void:
	_t += delta
	for n: Node3D in _nodes.values():
		var gem: Node3D = n.get_meta(&"gem")
		gem.position.y = 1.05 + sin(_t * 2.2 + n.position.x) * 0.08
		gem.rotation.y = _t * 1.4


func _make(c: Color) -> Node3D:
	var root := Node3D.new()
	var plinth := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.38
	cyl.bottom_radius = 0.46
	cyl.height = 0.55
	cyl.radial_segments = 8
	plinth.mesh = cyl
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#6F6A66")
	stone.roughness = 1.0
	plinth.material_override = stone
	plinth.position.y = 0.275
	root.add_child(plinth)
	var gem := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.32, 0.32, 0.32)
	gem.mesh = box
	var gm := StandardMaterial3D.new()
	gm.albedo_color = c
	gm.emission_enabled = true
	gm.emission = c
	gm.emission_energy_multiplier = 2.5
	gem.material_override = gm
	gem.rotation = Vector3(0.6, 0, 0.6)
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spin := Node3D.new()
	spin.position.y = 1.05
	spin.add_child(gem)
	root.add_child(spin)
	root.set_meta(&"gem", spin)
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = 0.8
	light.omni_range = 2.5
	light.position.y = 1.0
	root.add_child(light)
	return root
