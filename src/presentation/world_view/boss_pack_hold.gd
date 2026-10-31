class_name BossPackHold
extends RefCounted
## v0.10.0 VX5 (VFX_PACK R13-R42): the boss, elite and shield views' way of using PackFx. Their effects are drawn from
## the sim's state every frame, so a pack effect needs a keyed owner: one-shots start once per key (`once`), held ones
## stay while the caller keeps asking (`hold`) and go back to the pool the frame it stops (`end`). When the effect's
## family is full the call answers "no" and the caller draws its old look for that instance (the fallback); the answer
## is remembered for a one-shot's key, so a strike never swaps look half way. Cosmetic only (EI-03, EI-07).

## Each VX5 id's family (data/vfx/pack_fx_vx5.tres; a test keeps them equal).
const FAMILY := {
	&"bx_beam_01": &"beam",
	&"bx_beam_02": &"beam",
	&"bx_beam_03": &"beam",
	&"bx_beam_04": &"beam",
	&"bx_beam_05": &"beam",
	&"bx_beam_06": &"beam",
	&"bx_beam_07": &"beam",
	&"bx_beam_08": &"beam",
	&"bx_rail": &"beam",
	&"bx_impact_a": &"impact",
	&"bx_impact_b": &"impact",
	&"bx_smoke_big": &"cloud",
	&"bx_smoke_thin": &"cloud",
	&"bx_smoke_dust": &"cloud",
	&"bx_pillar_light": &"area",
	&"bx_pillar_fallen": &"area",
	&"bx_pulse_light": &"area",
	&"bx_pulse_shock": &"area",
	&"bx_pulse_steam": &"area",
	&"bx_fire_lane_a": &"status",
	&"bx_fire_lane_b": &"status",
	&"bx_shell": &"area",
	&"bx_flash": &"impact",
	&"bx_shatter": &"explosion",
}
## The beam scenes' own hues (degrees, the secondary colour) and which are near-white (steel).
const BEAM_HUES := [6.0, 187.0, 56.0, 173.0, 346.0, 37.0, 76.0]
const BEAM_STEEL_SAT := 0.18
## The pack beams' own radius (m): a beam of half width hw is scaled to hw * BEAM_FACTOR / BEAM_NATIVE_R.
const BEAM_NATIVE_R := 0.15
const BEAM_FACTOR := 0.55
## The rail's blast scene is wider (blast_vfx_01: radius 0.45 and its edge).
const RAIL_NATIVE_R := 0.5

var pack: PackFx
var _held := {}  # key -> {node, id}
var _seen := {}
var _once := {}  # key -> true when the pack took it
var _once_seen := {}


func _init(p: PackFx = null) -> void:
	pack = p


## The PackFx of the WorldViewRoot above `from` (null in a view built alone). Views find it when they first draw.
static func find(from: Node) -> PackFx:
	var n := from
	while n != null:
		if "pack_fx" in n and n.get("pack_fx") is PackFx:
			return n.get("pack_fx") as PackFx
		n = n.get_parent()
	return null


## The beam scene (&"bx_beam_01".."08") whose hue is nearest to `c`'s (a washed-out colour is the steel one).
static func beam_id(c: Color) -> StringName:
	if c.s < BEAM_STEEL_SAT:
		return &"bx_beam_08"
	var best := 0
	var gap := 999.0
	for k in BEAM_HUES.size():
		var d := absf(c.h * 360.0 - float(BEAM_HUES[k]))
		d = minf(d, 360.0 - d)
		if d < gap:
			gap = d
			best = k
	return StringName("bx_beam_0%d" % (best + 1))


## Puts a held pack beam from `a` to `b`, `half_width` wide as the old cylinders were (the beam scenes run along -Z;
## their length is `beam_length`). The scene's width is not set (its meshes are shared): the node is scaled across.
static func beam_place(
	node: Node3D, a: Vector3, b: Vector3, half_width: float, native_r := BEAM_NATIVE_R
) -> void:
	var d := b - a
	var len := maxf(d.length(), 0.05)
	var dn := d / len
	var up := Vector3.UP if absf(dn.y) < 0.98 else Vector3.RIGHT
	var basis := Basis.looking_at(dn, up)
	var w := clampf(half_width * BEAM_FACTOR / native_r, 0.4, 6.0)
	basis = basis * Basis.from_scale(Vector3(w, w, 1.0))
	if node.is_inside_tree():
		node.global_transform = Transform3D(basis, a)
	else:
		node.transform = Transform3D(basis, a)
	node.set("beam_length", len)


## Starts a frame: what is not asked again before `end()` is let go.
func begin() -> void:
	_seen.clear()
	_once_seen.clear()


## Ends a frame: held effects not asked for this frame go back to the pool; one-shot keys not seen are forgotten.
func end() -> void:
	for key in _held.keys():
		if not _seen.has(key):
			_drop(key)
	for key in _once.keys():
		if not _once_seen.has(key):
			_once.erase(key)


## Lets everything go (the view is done, or a test).
func release_all() -> void:
	for key in _held.keys():
		_drop(key)
	_once.clear()


func held_count() -> int:
	return _held.size()


func is_held(key: Variant) -> bool:
	return _held.has(key)


## Keeps effect `id` at `pos` while it is asked for every frame. Returns its node, or null when the family is full
## (the caller draws its old look). `move` false leaves the node where the caller put it (a beam).
func hold(
	key: Variant, id: StringName, pos: Vector3, scale := 1.0, colors := {}, move := true
) -> Node3D:
	if pack == null:
		return null
	_seen[key] = true
	var e: Dictionary = _held.get(key, {})
	if not e.is_empty() and (e["id"] != id or not _live(e["node"], id)):
		_drop(key)
		e = {}
	if e.is_empty():
		if not pack.has_room(FAMILY[id]):
			return null
		var n := pack.spawn(id, pos, scale, colors, 0.0)
		if n == null:
			return null
		_held[key] = {"node": n, "id": id}
		for c in n.get_children():  # a held effect burns until it is let go (PackFx plays a pooled one once)
			if c is GPUParticles3D:
				(c as GPUParticles3D).one_shot = false
				(c as GPUParticles3D).emitting = true
		return n
	var node: Node3D = e["node"]
	if move:
		var was := node.global_position if node.is_inside_tree() else node.position
		if node.is_inside_tree():
			node.global_position = pos
		else:
			node.position = pos
		PackFx.settle(node, was, pos)
	return node


## Starts effect `id` once for `key`. Returns true when the pack's effect plays (or already played for this key), false
## when the family was full at the start (the caller draws its old look for this key's whole life).
func once(
	key: Variant, id: StringName, pos: Vector3, scale := 1.0, colors := {}, life := -1.0
) -> bool:
	if pack == null:
		return false
	_once_seen[key] = true
	if _once.has(key):
		return _once[key]
	var took := false
	if pack.has_room(FAMILY[id]):
		took = pack.spawn(id, pos, scale, colors, life) != null
	_once[key] = took
	return took


## Whether `key` was answered (taken or not) and is still remembered.
func decided(key: Variant) -> bool:
	return _once.has(key)


func _drop(key: Variant) -> void:
	var e: Dictionary = _held.get(key, {})
	_held.erase(key)
	if not e.is_empty() and _live(e["node"], e["id"]):
		pack.release(e["node"])


## `node` is still the live instance PackFx started for `id` (it was not given back, or reused for another effect).
func _live(node: Variant, _id: StringName) -> bool:
	if not is_instance_valid(pack) or not is_instance_valid(node):
		return false
	return pack.is_live(node)  # (a node never changes id: each id has its own pool)


## A view's hold: made once the view is in a tree with a PackFx above it (null before, and without the pack).
static func of(view: Node, cached: BossPackHold) -> BossPackHold:
	if cached != null and cached.pack != null:
		return cached
	if not view.is_inside_tree():
		return null
	var p := find(view)
	return BossPackHold.new(p) if p != null else null


## Recolours a pack fire field (fire_forcefield, fire_area: no colour exports, the colours are on its mesh's material).
static func tint_field(node: Node3D, main: Color, edge: Color, glow: Color) -> void:
	for mi: Node in node.find_children("*", "MeshInstance3D", true, false):
		var m: Material = (mi as MeshInstance3D).material_override
		if m == null and (mi as MeshInstance3D).mesh is PrimitiveMesh:
			m = ((mi as MeshInstance3D).mesh as PrimitiveMesh).material
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter(&"main_color", main)
			(m as ShaderMaterial).set_shader_parameter(&"edge_color", edge)
			(m as ShaderMaterial).set_shader_parameter(&"glow_color", glow)
