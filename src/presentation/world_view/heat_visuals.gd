class_name HeatVisuals
extends Node3D
## Overclock heat on the hero and in the world (v0.3.0 PLAN L18). Reads WorldReader.heat_state() only (EI-07):
## - the visor and the blade lean from their own cyan toward amber, red-orange and white-hot as heat rises
##   (HeatLooks; kept materials, colour and energy only, never emission_enabled);
## - a vent blast: a flash disc and a ring that grows out to the blast's real radius (the sim's), hotter the more
##   heat was vented; a Meltdown is the same blast in white-hot;
## - overheat: a burst of steam, then steam venting from the hero for the whole stall;
## - Overclock: embers fly off every Overclock hit, and the hero sheds an ember trail while moving.

const FX_FRAMES := 24
const STEAM_EVERY := 3
const TRAIL_EVERY := 4

var kit: KitView
var actors: ActorViews
## Kept for the view's life so the effects compile their shader once (the v0.2.0 H rule, as ItemVisuals).
var _fx_template := _make_fx_template()
var _sphere := SphereMesh.new()
var _box := BoxMesh.new()
var _disc := CylinderMesh.new()
var _rng := RandomNumberGenerator.new()
var _last_vent := -1
var _last_overheat := -1
var _last_ember := -1
var _last_tick := -1
var _last_pos := Vector2.ZERO
## Live effects: [node, material, frames left, frames, kind, velocity, base alpha, grow to].
var _fx: Array = []


func _init(p_kit: KitView, p_actors: ActorViews) -> void:
	kit = p_kit
	actors = p_actors
	name = "HeatVisuals"
	_rng.seed = 18
	_sphere.radius = 0.16
	_sphere.height = 0.32
	_sphere.radial_segments = 10
	_sphere.rings = 5
	_box.size = Vector3(0.07, 0.07, 0.07)
	_disc.top_radius = 1.0
	_disc.bottom_radius = 1.0
	_disc.height = 0.02
	_disc.radial_segments = 32


func sync(reader: WorldReader) -> void:
	var s := reader.heat_state()
	var look := HeatLooks.from_state(s)
	kit.set_heat_tint(look[0], look[1])
	var avatar := _avatar(reader)
	if avatar != null:
		avatar.set_heat(look[0], look[1])
	if s.is_empty():
		return
	var tick := reader.tick()
	var fresh := tick != _last_tick
	var pos := reader.player_pos()
	if int(s["vent_tick"]) != _last_vent:
		_last_vent = s["vent_tick"]
		if _last_vent >= 0:
			_blast(s)
	if int(s["overheat_tick"]) != _last_overheat:
		_last_overheat = s["overheat_tick"]
		if _last_overheat >= 0:
			for k in 10:
				_steam(pos, 1.6)
	if int(s["ember_tick"]) != _last_ember:
		_last_ember = s["ember_tick"]
		if _last_ember >= 0:
			for k in 5:
				_ember(s["ember_pos"], 3.5)
	if fresh:
		var tier: int = s["tier"]
		if tier == HeatLooks.TIER_OVERHEAT and tick % STEAM_EVERY == 0:
			_steam(pos, 1.0)
		if tier == HeatLooks.TIER_OVERCLOCK and tick % TRAIL_EVERY == 0 and pos != _last_pos:
			_ember(pos, 1.2)
	_last_tick = tick
	_last_pos = pos


func _avatar(reader: WorldReader) -> PlayerAvatar:
	var node := actors.actor_node(reader.actor_id(0)) if reader.actor_count() > 0 else null
	if node == null or not node.has_meta(&"avatar"):
		return null
	return node.get_meta(&"avatar") as PlayerAvatar


func fx_count() -> int:
	return _fx.size()


## How many live effects of a kind (&"blast", &"ring", &"steam", &"ember").
func fx_count_of(kind: StringName) -> int:
	return _fx.filter(func(f: Array) -> bool: return f[4] == kind).size()


## The radius the newest ring grows to (the vent's sim radius), or 0.
func ring_radius() -> float:
	for k in range(_fx.size() - 1, -1, -1):
		if _fx[k][4] == &"ring":
			return _fx[k][7]
	return 0.0


func _blast(s: Dictionary) -> void:
	var at: Vector2 = s["vent_pos"]
	var r: float = s["vent_radius"]
	var share := clampf(float(s["vent_heat"]) / float(s["max"]), 0.0, 1.0)
	var c := (
		HeatLooks.WHITE_HOT
		if s["meltdown"]
		else HeatLooks.color(s["vent_heat"], s["max"], s["hot"], s["overclock"])
	)
	var disc := MeshInstance3D.new()
	disc.mesh = _disc
	disc.position = SimPlane.to_3d(at, 0.06)
	disc.scale = Vector3(r, 1, r)
	_add(disc, c.lerp(HeatLooks.WHITE_HOT, 0.3), 0.2 + 0.25 * share, &"blast", Vector3.ZERO, r)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	ring.mesh = torus
	ring.position = SimPlane.to_3d(at, 0.2)
	ring.scale = Vector3(0.25, 0.3, 0.25)
	_add(ring, c, 0.95, &"ring", Vector3.ZERO, r)
	for k in 6 + int(10 * share):
		_ember(at, 5.0)


func _steam(at: Vector2, spread: float) -> void:
	var n := MeshInstance3D.new()
	n.mesh = _sphere
	var off := Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))
	n.position = SimPlane.to_3d(at + off, 0.9 + _rng.randf_range(0.0, 0.3))
	var vel := Vector3(off.x * spread, _rng.randf_range(1.2, 2.0), -off.y * spread)
	_add(n, HeatLooks.STEAM, 0.55, &"steam", vel, 2.4)


func _ember(at: Vector2, speed: float) -> void:
	var n := MeshInstance3D.new()
	n.mesh = _box
	n.position = SimPlane.to_3d(at, 0.5)
	var a := _rng.randf_range(0.0, TAU)
	var vel := (
		Vector3(cos(a), _rng.randf_range(0.6, 1.4), sin(a)) * speed * _rng.randf_range(0.4, 1.0)
	)
	var c := HeatLooks.OVERCLOCK.lerp(HeatLooks.WHITE_HOT, _rng.randf_range(0.0, 0.6))
	_add(n, c, 1.0, &"ember", vel, 1.0)


func _add(
	n: MeshInstance3D, c: Color, alpha: float, kind: StringName, vel: Vector3, grow: float
) -> void:
	var m := _fx_template.duplicate() as StandardMaterial3D
	m.albedo_color = Color(c, alpha)
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(n)
	_fx.append([n, m, FX_FRAMES, FX_FRAMES, kind, vel, alpha, grow])


func _process(delta: float) -> void:
	var dt := clampf(delta, 0.0, 0.05)
	for k in range(_fx.size() - 1, -1, -1):
		var fx: Array = _fx[k]
		fx[2] -= 1
		var t: float = float(fx[2]) / fx[3]
		var n: Node3D = fx[0]
		(fx[1] as StandardMaterial3D).albedo_color.a = fx[6] * t
		match fx[4]:
			&"ring":
				var r: float = lerpf(fx[7], 0.25, t * t)
				n.scale = Vector3(r, 0.3, r)
			&"steam":
				n.position += fx[5] * dt
				n.scale = Vector3.ONE * lerpf(fx[7], 0.6, t)
			&"ember":
				n.position += fx[5] * dt
				fx[5] += Vector3(0, -9.0, 0) * dt
		if fx[2] <= 0:
			n.queue_free()
			_fx.remove_at(k)


static func _make_fx_template() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
