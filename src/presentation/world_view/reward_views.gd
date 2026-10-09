class_name RewardViews
extends Node3D
## Altars and chests (v0.3.0 E). Low-poly, faceted stone like the gate:
## - an altar (v0.6.1 SW, the shard look): a stone base with a cluster of outlined faceted crystals in its tier's
##   card-frame colour, a soft glow, small fragments floating over it, and a light (ShardMesh builds the pieces);
## - a chest: a stone chest with iron bands and a red-glowing lock; its price floats above it while you are near,
##   red when you can't afford it. A refused open shakes it.
## The reward you can open now glows brighter. A node disappears when the sim removes its reward. Glowing
## materials have emission on from creation; only energies change at runtime (flash-safe).

const ALTAR_LIGHT := Color("#9CC8FF")
## v0.5.0 RT: a Deep floor's epic altar glows the Deep gate's violet.
const EPIC_LIGHT := Color("#8B3DFF")
## v0.5.5 AR (X1b): the boss's legendary altar glows bright gold.
const LEGENDARY_LIGHT := Color("#FFC233")
## v0.5.5 AR: a reward locked in an arena that isn't cleared wears an amber seal ring until the clear.
const SEAL := Color("#FFB020")
const LOCK_RED := Color("#FF3B30")
const STONE := Color("#77706A")
const STONE_TOP := Color("#8B847D")
const IRON := Color("#3A3D44")
## The price shows within this distance (m).
const PRICE_NEAR_M := 4.5
const PRICE_OK := Color("#F4F1EA")
const PRICE_POOR := Color("#FF4A3D")
const SHAKE_S := 0.35
## v0.5.9 Step 5: the owner's chest model. When its reward is taken the chest stays a moment: the lid swings open
## on its back hinge over LID_OPEN_S with a warm flare, then the node goes after OPENED_S (cosmetic only: the
## reward is already gone from the sim and from count()).
const LID_OPEN_S := 0.35
const LID_OPEN_RAD := 1.9
const OPENED_S := 1.1
const FLARE := Color("#FFB45A")
## v0.6.1 SW: the shard altar. Its tier wears a card frame's colour (CardFrames.TINT; one table, the owner may remap):
## a plain altar the blue frame (the old rune's cold blue), the Deep floor's epic altar the purple frame (the Deep
## gate's violet, PickSlot.EPIC), the boss's legendary altar the gold frame (the legendary cards' gold).
const ALTAR_FRAME := {&"normal": &"blue", &"epic": &"purple", &"legendary": &"gold"}
## The footprint (m): the stone base's radius, as the old plinth's. The sim's altar radius is not drawn from this.
const ALTAR_RADIUS := 0.62
const ALTAR_SPIN_Y := 1.3
const ALTAR_CRYSTAL_ENERGY := 0.5
const ALTAR_GLOW_ALPHA := 0.3
## In reach: the crystals' emission and the glow's strength are multiplied by this.
const ALTAR_HOT := 1.8
## A dropped core floats this high (m); before v0.6.1 SW it was built at 0.9 and the bob lifted it to 1.25.
const DROP_SPIN_Y := 1.0

## Use the owner's chest model (set by WorldViewRoot when the floor has a lighting mood; the old look keeps the
## code-built stone chest).
var kit_chest := false

var _nodes := {}
var _t := 0.0
var _reach_id := -1
var _denied_tick := -1
## id -> seconds of shake left.
var _shake := {}
## Chests whose reward was taken, opening: node -> seconds since.
var _opening := {}
var _lock_mat := StandardMaterial3D.new()
var _seal_mat := StandardMaterial3D.new()


func _init() -> void:
	name = "Rewards"
	for pair: Array in [[_lock_mat, LOCK_RED, 2.6], [_seal_mat, SEAL, 2.0]]:
		var m: StandardMaterial3D = pair[0]
		m.albedo_color = pair[1]
		m.emission_enabled = true
		m.emission = pair[1]
		m.emission_energy_multiplier = pair[2]


func sync(reader: WorldReader) -> void:
	var live := {}
	var p := reader.player_pos()
	var reach := reader.reward_in_reach()
	_reach_id = reader.reward_id(reach) if reach >= 0 else -1
	for i in reader.reward_count():
		var id := reader.reward_id(i)
		live[id] = true
		var n: Node3D = _nodes.get(id)
		if n == null:
			var kind := reader.reward_kind(i)
			if kind == WorldReader.REWARD_LEGENDARY:  # v0.5.5 AR (X1b)
				n = make_altar(false, true)
			elif kind == WorldReader.REWARD_DROP:  # v0.6.0 CU: a stolen core, Marked's card
				n = make_drop(CoreViews.card_color(reader, reader.reward_drop_card(i)))
			elif kind == WorldReader.REWARD_ALTAR:
				n = make_altar(reader.reward_is_epic(i))
			else:
				n = make_chest()
			_add_seal(n)
			n.position = SimPlane.to_3d(reader.reward_pos(i))
			add_child(n)
			n.reset_physics_interpolation()
			_nodes[id] = n
		(n.get_meta(&"seal") as Node3D).visible = reader.reward_locked(i)  # v0.5.5 AR
		var label: Label3D = n.get_meta(&"price") if n.has_meta(&"price") else null
		if label != null:
			label.text = str(reader.reward_price(i))
			label.modulate = PRICE_OK if reader.reward_affordable(i) else PRICE_POOR
			label.visible = reader.reward_pos(i).distance_to(p) <= PRICE_NEAR_M
	if reader.reward_denied_tick() != _denied_tick:
		_denied_tick = reader.reward_denied_tick()
		if _denied_tick >= 0:
			_shake[reader.reward_denied_id()] = SHAKE_S
	for id in _nodes.keys():
		if not live.has(id):
			var gone: Node3D = _nodes[id]
			if gone.has_meta(&"lid"):
				_opening[gone] = 0.0
			else:
				gone.queue_free()
			_nodes.erase(id)
			_shake.erase(id)


func count() -> int:
	return _nodes.size()


## v0.5.5 AR: whether reward `id` shows its arena seal (tests).
func is_sealed(id: int) -> bool:
	var n: Node3D = _nodes.get(id)
	return n != null and (n.get_meta(&"seal") as Node3D).visible


## v0.5.5 AR: an amber ring around the reward's foot and two crossed bars over it, shown while it's locked.
func _add_seal(root: Node3D) -> void:
	var seal := Node3D.new()
	seal.name = "ArenaSeal"
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.72
	t.outer_radius = 0.8
	ring.mesh = t
	ring.position.y = 0.08
	ring.material_override = _seal_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seal.add_child(ring)
	for k in 2:
		var bar := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(1.3, 0.06, 0.06)
		bar.mesh = b
		bar.position.y = 1.0
		bar.rotation.y = PI * 0.25 + PI * 0.5 * k
		bar.material_override = _seal_mat
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		seal.add_child(bar)
	seal.visible = false
	root.add_child(seal)
	root.set_meta(&"seal", seal)


## The node of reward `id` (tests and shot scripts), or null.
func node_of(id: int) -> Node3D:
	return _nodes.get(id)


func price_label(id: int) -> Label3D:
	var n: Node3D = _nodes.get(id)
	return n.get_meta(&"price") if n != null and n.has_meta(&"price") else null


func _process(delta: float) -> void:
	_t += delta
	for n: Node3D in _opening.keys():
		var s: float = _opening[n] + delta
		_opening[n] = s
		var lid: Node3D = n.get_meta(&"lid")
		lid.rotation.x = LID_OPEN_RAD * smoothstep(0.0, LID_OPEN_S, s)
		var flare: OmniLight3D = n.get_meta(&"light")
		flare.light_color = FLARE
		flare.light_energy = 3.0 * (1.0 - smoothstep(LID_OPEN_S, OPENED_S, s))
		if s >= OPENED_S:
			_opening.erase(n)
			n.queue_free()
	for id: int in _nodes:
		var n: Node3D = _nodes[id]
		var hot := id == _reach_id
		var light: OmniLight3D = n.get_meta(&"light")
		light.light_energy = move_toward(
			light.light_energy, n.get_meta(&"energy") * (1.8 if hot else 1.0), delta * 4.0
		)
		var spin: Node3D = n.get_meta(&"spin") if n.has_meta(&"spin") else null
		if spin != null:
			var y0: float = n.get_meta(&"spin_y", 1.25)
			spin.position.y = y0 + sin(_t * 2.0 + n.position.x) * 0.07
			spin.rotation.y = _t * (1.6 if hot else 0.9)
			for frag: Node3D in spin.get_children():
				if frag.has_meta(&"bob"):  # v0.6.1 SW: each fragment bobs on its own beat
					frag.position.y = (
						frag.get_meta(&"bob") + sin(_t * 2.6 + frag.get_index() * 1.7) * 0.05
					)
		if n.has_meta(&"crystal_mat"):  # v0.6.1 SW: the shard altar brightens in reach
			_glow_toward(n, hot, delta)
		var body: Node3D = n.get_meta(&"body")
		var left: float = _shake.get(id, 0.0)
		if left > 0.0:
			left = maxf(0.0, left - delta)
			_shake[id] = left
			body.position.x = sin(left * 70.0) * 0.06 * (left / SHAKE_S)
		else:
			body.position.x = 0.0


## v0.6.1 SW: eases the shard altar's crystal emission and glow toward their in-reach (hot) or idle strength. Only
## energies and the glow's alpha change (flash-safe).
func _glow_toward(n: Node3D, hot: bool, delta: float) -> void:
	var mat: StandardMaterial3D = n.get_meta(&"crystal_mat")
	var want := ALTAR_CRYSTAL_ENERGY * (ALTAR_HOT if hot else 1.0)
	mat.emission_energy_multiplier = move_toward(mat.emission_energy_multiplier, want, delta * 3.0)
	var glow_mat := (n.get_meta(&"glow") as MeshInstance3D).material_override as StandardMaterial3D
	var c := glow_mat.albedo_color
	c.a = move_toward(c.a, ALTAR_GLOW_ALPHA * (ALTAR_HOT if hot else 1.0), delta * 1.5)
	glow_mat.albedo_color = c


## v0.6.1 SW (owner R3): the altar in the crystal-shard look of the owner's card art. On the same hexagonal footprint
## as before (radius ALTAR_RADIUS): a two-step stone base, a cluster of outlined faceted shards growing from it in
## the tier's card-frame colour (ALTAR_FRAME), a soft additive inner glow, and a few small fragments floating and
## bobbing over the cluster. The crystals are lit by the scene (the v0.5.9 moods) with a little emission of their
## own. In reach the light, the glow and the crystals' emission brighten and the fragments turn faster.
func make_altar(epic: bool = false, legendary: bool = false) -> Node3D:
	var tier := &"legendary" if legendary else (&"epic" if epic else &"normal")
	var color := altar_color(tier)
	var root := Node3D.new()
	root.name = "ShardAltar"
	var body := Node3D.new()
	root.add_child(body)
	var stone := ShardMesh.stone_material(ShardMesh.STONE)
	var top := ShardMesh.stone_material(ShardMesh.STONE_TOP)
	body.add_child(_mesh(prism(6, ALTAR_RADIUS, 0.56, 0.16, 0.0, 0.0, 3), stone))
	var rock := _mesh(ShardMesh.rock(7, 0.5, 0.4, 0.2, 5), top)
	rock.position.y = 0.16
	body.add_child(rock)
	var mat := ShardMesh.crystal_material(color, ALTAR_CRYSTAL_ENERGY)
	var cluster := ShardMesh.cluster(mat, 8, 0.95 if legendary else 0.85, 0.5, 11)
	cluster.position.y = 0.3
	body.add_child(cluster)
	var glow := ShardMesh.glow(color, 1.7, ALTAR_GLOW_ALPHA)
	glow.position.y = 0.85
	root.add_child(glow)
	var spin := Node3D.new()
	spin.position.y = ALTAR_SPIN_Y
	root.add_child(spin)
	for k in 4:
		var a := TAU * k / 4.0
		var frag := ShardMesh.fragment(mat, 0.05 if k % 2 == 0 else 0.035, 13 + k)
		frag.position = Vector3(cos(a) * 0.46, 0.08 * (k % 2), sin(a) * 0.46)
		frag.rotation = Vector3(0.4 * k, a, 0.3)
		frag.set_meta(&"bob", frag.position.y)
		spin.add_child(frag)
	var light := OmniLight3D.new()
	light.light_color = EPIC_LIGHT if epic else ALTAR_LIGHT
	if legendary:
		light.light_color = LEGENDARY_LIGHT
	light.light_energy = 0.9
	light.omni_range = 3.0
	light.position.y = 1.2
	root.add_child(light)
	root.set_meta(&"body", body)
	root.set_meta(&"spin", spin)
	root.set_meta(&"spin_y", ALTAR_SPIN_Y)
	root.set_meta(&"light", light)
	root.set_meta(&"energy", 0.9)
	root.set_meta(&"epic", epic)
	root.set_meta(&"legendary", legendary)
	root.set_meta(&"tier", tier)
	root.set_meta(&"crystal_mat", mat)
	root.set_meta(&"glow", glow)
	return root


## v0.6.1 SW: the colour of an altar of `tier` (&"normal", &"epic", &"legendary"): its card frame's tint.
static func altar_color(tier: StringName) -> Color:
	return CardFrames.tint(ALTAR_FRAME.get(tier, ALTAR_FRAME[&"normal"]))


## v0.6.0 CU: a free card drop (a stolen core, Marked's rare card): the core's crystal floating low over the floor,
## glowing its card family's frame colour, turning, with a small light. No plinth: it fell from the body.
func make_drop(color: Color) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var mat := CoreViews.glow_material(color, 2.6)
	var spin := Node3D.new()
	spin.position.y = DROP_SPIN_Y
	root.add_child(spin)
	# v0.6.1 SW: the core is a lit, outlined shard (ShardMesh) with a soft glow and two chips floating by it.
	var shard_mat := ShardMesh.crystal_material(color, 1.1)
	var gem := ShardMesh.outlined(
		ShardMesh.shard(6, 0.2, 0.36, 0.3, 31), shard_mat, Vector3.ZERO, 0.16
	)
	(gem.get_meta(&"crystal") as MeshInstance3D).cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	spin.add_child(gem)
	for k in 2:
		var frag := ShardMesh.fragment(shard_mat, 0.04, 33 + k)
		frag.position = Vector3(0.34 if k == 0 else -0.3, 0.12 - 0.2 * k, 0.1)
		frag.set_meta(&"bob", frag.position.y)
		spin.add_child(frag)
	var halo := ShardMesh.glow(color, 1.1, 0.3)
	spin.add_child(halo)
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.48
	ring.mesh = t
	ring.position.y = 0.05
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.8
	light.omni_range = 2.5
	light.position.y = 0.9
	root.add_child(light)
	root.set_meta(&"body", body)
	root.set_meta(&"spin", spin)
	root.set_meta(&"spin_y", DROP_SPIN_Y)
	root.set_meta(&"light", light)
	root.set_meta(&"energy", 0.8)
	root.set_meta(&"drop", true)
	root.set_meta(&"crystal_color", color)
	return root


## The owner's chest (v0.5.9 Step 5) when kit_chest is on and the model loads, else the code-built stone chest.
func make_chest() -> Node3D:
	if kit_chest:
		var parts := KitModels.split(&"chest", KitModels.CHEST_LID_CUT)
		if not parts.is_empty():
			return _kit_chest(parts)
	return _stone_chest()


## The owner's chest, its front (the lock) toward the camera's side (3D +z), the lid on a hinge at its back top
## edge; the red lock glow, light and price as on the stone chest.
func _kit_chest(parts: Dictionary) -> Node3D:
	var size: Vector3 = parts["size"]
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var model := Node3D.new()
	model.rotation.y = PI  # the model's front is its -z; the chest faces +z
	body.add_child(model)
	model.add_child(_mesh(parts["body"], parts["material"]))
	var hinge := Node3D.new()
	hinge.position = Vector3(0, size.y * KitModels.CHEST_LID_CUT, size.z * 0.5)
	model.add_child(hinge)
	var lid := _mesh(parts["lid"], parts["material"])
	lid.position = -hinge.position
	hinge.add_child(lid)
	var lock := _mesh(bipyramid(4, 0.06, 0.06, 0.06), _lock_mat)
	lock.position = Vector3(0, size.y * 0.5, size.z * 0.5 + 0.04)
	lock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(lock)
	_finish_chest(root, body, size.y)
	root.set_meta(&"lid", hinge)
	return root


## A stone chest with a sloped lid, iron bands and a red-glowing lock; its price floats above it.
func _stone_chest() -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	var stone := _stone_mat(STONE)
	var top := _stone_mat(STONE_TOP)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	iron.metallic = 0.6
	iron.roughness = 0.55
	# Sim +y is 3D -z; the chest faces 3D +z (toward the camera's side), its long side along x.
	body.add_child(_box(Vector3(1.0, 0.5, 0.62), Vector3(0, 0.25, 0), Vector3.ZERO, stone))
	body.add_child(_box(Vector3(1.06, 0.1, 0.68), Vector3(0, 0.05, 0), Vector3.ZERO, top))
	body.add_child(_box(Vector3(1.04, 0.14, 0.4), Vector3(0, 0.6, 0.13), Vector3(28, 0, 0), top))
	body.add_child(_box(Vector3(1.04, 0.14, 0.4), Vector3(0, 0.6, -0.13), Vector3(-28, 0, 0), top))
	for x in [-0.33, 0.33]:
		body.add_child(_box(Vector3(0.09, 0.56, 0.66), Vector3(x, 0.3, 0), Vector3.ZERO, iron))
		body.add_child(_box(Vector3(0.09, 0.1, 0.44), Vector3(x, 0.66, 0), Vector3.ZERO, iron))
	body.add_child(_box(Vector3(0.24, 0.22, 0.08), Vector3(0, 0.42, 0.33), Vector3.ZERO, iron))
	var lock := _mesh(bipyramid(4, 0.07, 0.07, 0.07), _lock_mat)
	lock.position = Vector3(0, 0.42, 0.39)
	lock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(lock)
	_finish_chest(root, body, 0.75)
	return root


## The chest's red lock light and its floating price (both chests).
func _finish_chest(root: Node3D, body: Node3D, height: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = LOCK_RED
	light.light_energy = 0.7
	light.omni_range = 2.0
	light.position = Vector3(0, 0.5, 0.6)
	root.add_child(light)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 72
	label.outline_size = 16
	label.pixel_size = 0.008
	label.position.y = height + 0.7
	label.visible = false
	root.add_child(label)
	var gem := _mesh(bipyramid(4, 0.08, 0.12, 0.12), ShardViews.shared_material())
	gem.position = Vector3(-0.5, 0.0, 0)
	label.add_child(gem)
	root.set_meta(&"body", body)
	root.set_meta(&"light", light)
	root.set_meta(&"energy", 0.7)
	root.set_meta(&"price", label)


func _stone_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.vertex_color_use_as_albedo = true
	return m


func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	return n


func _box(size: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var n := _mesh(b, mat)
	n.position = pos
	n.rotation_degrees = rot_deg
	return n


## A flat-shaded prism: `sides` around, radius r0 at y0 and r1 at y0 + h, the top ring turned by `twist`
## radians; each facet tinted a little (from `salt`) so the planes read apart.
static func prism(
	sides: int, r0: float, r1: float, h: float, y0: float, twist: float, salt: int
) -> ArrayMesh:
	var tris := []
	var top := Vector3(0, y0 + h, 0)
	var bottom := Vector3(0, y0, 0)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var b0 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var b1 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
		var t0 := Vector3(cos(a0 + twist) * r1, y0 + h, sin(a0 + twist) * r1)
		var t1 := Vector3(cos(a1 + twist) * r1, y0 + h, sin(a1 + twist) * r1)
		tris.append([b0, b1, t1])
		tris.append([b0, t1, t0])
		tris.append([top, t0, t1])
		tris.append([bottom, b1, b0])
	return _flat(tris, Vector3(0, y0 + h * 0.5, 0), salt)


## A flat-shaded double pyramid (a crystal): `sides` around, radius r, tips up and down.
static func bipyramid(sides: int, r: float, up: float, down: float) -> ArrayMesh:
	var tris := []
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		tris.append([Vector3(0, up, 0), p0, p1])
		tris.append([Vector3(0, -down, 0), p1, p0])
	return _flat(tris, Vector3.ZERO, 0)


static func _flat(tris: Array, centre: Vector3, salt: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for k in tris.size():
		var a: Vector3 = tris[k][0]
		var b: Vector3 = tris[k][1]
		var c: Vector3 = tris[k][2]
		var n := (b - a).cross(c - a)
		if n.dot((a + b + c) / 3.0 - centre) < 0.0:
			var t := b
			b = c
			c = t
			n = -n
		n = n.normalized()
		verts.append_array([a, c, b])
		normals.append_array([n, n, n])
		var v := 1.0 if salt == 0 else 0.9 + 0.2 * float((salt * 131 + k * 17) % 11) / 10.0
		v *= lerpf(1.0, 0.75, clampf(-n.y, 0.0, 1.0))
		colors.append_array([Color(v, v, v), Color(v, v, v), Color(v, v, v)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
