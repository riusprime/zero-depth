class_name StatusVisuals
extends Node3D
## Engine statuses and combo payoffs on screen (v0.3.0 G). Reads the sim through WorldReader only:
## - burn: embers rising around the enemy (more stacks, more embers); its orange glow is ItemVisuals' tint;
## - shock: a row of pips over the health bar, one lit per stack up to the discharge threshold, and flickering
##   sparks; a discharge draws a lightning line to each enemy it jumped to;
## - bleed: red drips falling from the enemy (more stacks, more drips); a burst draws a red ring;
## - frost: ice crystals around the enemy's feet, one per stack; frozen: an ice shell (and ItemVisuals' icy tint);
## - Bulwark's guard charges: gold orbs circling the player;
## - combo payoffs: Plasma Arc (an orange arc), Shatter Dash, Wildfire, Blood Harvest and Frozen Bastion rings,
##   Resonance's second wave.
## With the new look (v0.5.9 art, VFX phase 2: `vfx` set) the enemy statuses draw into the VfxLayer instead of the
## boxes: flames on a burning body, arcs over a shocked one, red drips, bubbles and green drips for poison, ice
## crystals and a crystal cage for frost and frozen; the bleed, shatter, wildfire and harvest payoffs burst in
## their element and a discharge strikes as lightning. The shock pips and guard orbs stay (they are counts).
## Materials are made once and kept (never emission toggles at runtime: the v0.2.0 DAMAGE_LAG rule); each actor's
## pieces are children of its ActorViews node, so they move and go with it.

const PIPS := 5
const EMBERS := 3
const DRIPS := 3
const CRYSTALS := 4
const ORBS := 3
const FX_FRAMES := 16

var actors: ActorViews
## The new look's effects layer (null: the boxes and rings as before).
var vfx: VfxLayer
## Kept for the view's life, one per look (see the class note).
var _mats := {}
var _box := BoxMesh.new()
var _prism := PrismMesh.new()
var _pip := QuadMesh.new()
var _shell := SphereMesh.new()
## Actor id -> its pieces: {"root": Node3D, "embers": [...], "pips": [...], ...}.
var _views := {}
var _frame := 0
var _seen := {}
var _fx: Array = []
var _fx_template := _make_template()
## Actor id -> {on, r, node} for the vfx drawer.
var _on := {}
## Payoffs drawn by the vfx layer: [kind, at (Vector3), radius, start tick, life, seed, to (Array of Vector3)].
var _shots: Array = []


func _init(p_actors: ActorViews) -> void:
	actors = p_actors
	_box.size = Vector3.ONE
	_prism.size = Vector3(0.12, 0.3, 0.12)
	_pip.size = Vector2(0.13, 0.13)
	_shell.radius = 0.5
	_shell.height = 1.0
	_shell.radial_segments = 8
	_shell.rings = 4
	for k: StringName in [&"burn", &"shock", &"bleed", &"frost", &"guard"]:
		_mats[k] = _material(ItemLooks.status_color(k), 1.0, false)
	_mats[&"pip_off"] = _material(Color(0.05, 0.06, 0.09, 0.85), 0.85, true)
	_mats[&"pip_on"] = _material(ItemLooks.status_color(&"shock"), 1.0, true)
	_mats[&"shell"] = _material(ItemLooks.status_color(&"frozen"), 0.38, false)


## Hands the statuses to the new look's effects layer (WorldViewRoot, when the new look is on).
func use_vfx(layer: VfxLayer) -> void:
	vfx = layer
	layer.drawers.append(_draw_vfx)


func sync(reader: WorldReader) -> void:
	_frame += 1
	_on.clear()
	var alive := {}
	for i in reader.actor_count():
		var id := reader.actor_id(i)
		var node := actors.actor_node(id)
		if node == null:
			continue
		var on := _statuses(reader, i)
		if on.is_empty():
			continue
		alive[id] = true
		var v: Dictionary = _views.get(id, {})
		if v.is_empty() or not is_instance_valid(v["root"]):
			v = _build(node, reader.actor_radius(i))
			_views[id] = v
		_update(v, on, reader.actor_radius(i))
		_on[id] = {
			"on": on,
			"r": reader.actor_radius(i),
			"node": node,
			"top": maxf(0.5, float(v["bar_y"]) - 0.4)
		}
	for id in _views.keys():
		if not alive.has(id):
			var v: Dictionary = _views[id]
			if is_instance_valid(v["root"]):
				(v["root"] as Node3D).queue_free()
			_views.erase(id)
	_sync_payoffs(reader)


## What actor i shows: {status: stacks}. Enemies show burn/shock/bleed/frost/frozen; the player its charges.
func _statuses(reader: WorldReader, i: int) -> Dictionary:
	var out := {}
	if i == 0:
		if reader.guard_charges() > 0:
			out[&"guard"] = reader.guard_charges()
		return out
	if reader.burn_stacks(i) > 0:
		out[&"burn"] = reader.burn_stacks(i)
	if reader.shock_stacks(i) > 0:
		out[&"shock"] = reader.shock_stacks(i)
		out[&"shock_max"] = maxi(1, reader.shock_threshold())
	if reader.bleed_stacks(i) > 0:
		out[&"bleed"] = reader.bleed_stacks(i)
	if reader.frost_stacks(i) > 0:
		out[&"frost"] = reader.frost_stacks(i)
	if reader.actor_frozen(i):
		out[&"frozen"] = 1
	if reader.poison_stacks(i) > 0:
		out[&"poison"] = reader.poison_stacks(i)
	return out


## The pieces drawn on one actor's view (all hidden until a status shows them).
func _build(node: Node3D, r: float) -> Dictionary:
	var root := Node3D.new()
	root.name = "Statuses"
	node.add_child(root)
	var bar_y := 1.3
	if node.has_meta(&"bar"):
		bar_y = (node.get_meta(&"bar") as Node3D).get_parent().position.y
	var v := {"root": root, "bar_y": bar_y}
	v["embers"] = _pieces(root, EMBERS, _box, Vector3(0.11, 0.11, 0.11), &"burn")
	v["drips"] = _pieces(root, DRIPS, _box, Vector3(0.08, 0.2, 0.08), &"bleed")
	v["crystals"] = _pieces(root, CRYSTALS, _prism, Vector3.ONE, &"frost")
	v["sparks"] = _pieces(root, 2, _box, Vector3(0.05, 0.05, 0.5), &"shock")
	v["orbs"] = _pieces(root, ORBS, _box, Vector3(0.12, 0.12, 0.12), &"guard")
	var pips: Array = []
	for k in PIPS:
		var p := _piece(root, _pip, Vector3.ONE, &"pip_off")
		p.position = Vector3((k - (PIPS - 1) * 0.5) * 0.16, bar_y + 0.2, 0)
		pips.append(p)
	v["pips"] = pips
	var shell := _piece(root, _shell, Vector3(r * 2.6, 1.3, r * 2.6), &"shell")
	shell.position = Vector3(0, 0.55, 0)
	v["shell"] = shell
	for k in CRYSTALS:
		var a := TAU * k / CRYSTALS + 0.4
		(v["crystals"][k] as Node3D).position = Vector3(
			cos(a) * (r + 0.08), 0.15, sin(a) * (r + 0.08)
		)
	return v


func _update(v: Dictionary, on: Dictionary, r: float) -> void:
	var t := _frame / 60.0
	var burn: int = on.get(&"burn", 0)
	for k in EMBERS:
		var e: Node3D = v["embers"][k]
		e.visible = k < mini(EMBERS, 1 + burn / 2) and burn > 0
		var rise := fmod(t * 0.9 + k / float(EMBERS), 1.0)
		var a := t * 2.0 + k * 2.1
		e.position = Vector3(cos(a) * r * 0.9, 0.25 + rise * 1.0, sin(a) * r * 0.9)
	var bleed: int = on.get(&"bleed", 0)
	for k in DRIPS:
		var d: Node3D = v["drips"][k]
		d.visible = k < mini(DRIPS, 1 + bleed / 3) and bleed > 0
		var fall := fmod(t * 1.4 + k / float(DRIPS), 1.0)
		var a := k * 2.4 + 0.7
		d.position = Vector3(cos(a) * r * 0.7, 0.75 * (1.0 - fall), sin(a) * r * 0.7)
	var frost: int = on.get(&"frost", 0)
	var frozen := on.has(&"frozen")
	for k in CRYSTALS:
		(v["crystals"][k] as Node3D).visible = frozen or k < frost
	(v["shell"] as Node3D).visible = frozen
	var shock: int = on.get(&"shock", 0)
	var shock_max: int = mini(on.get(&"shock_max", PIPS), PIPS)
	for k in PIPS:
		var p: MeshInstance3D = v["pips"][k]
		p.visible = shock > 0 and k < shock_max
		p.material_override = _mats[&"pip_on" if k < shock else &"pip_off"]
	for k in 2:
		var s: Node3D = v["sparks"][k]
		s.visible = shock > 0 and (_frame / 3 + k) % 2 == 0
		var a := (_frame / 3) * 1.7 + k * 3.1
		s.position = Vector3(cos(a) * r * 0.6, 0.4 + 0.3 * k, sin(a) * r * 0.6)
		s.rotation = Vector3(0.4 * k, a, 0.6)
	if vfx != null:  # the new look draws these in the effects layer (_draw_vfx)
		for kind: String in ["embers", "drips", "crystals", "sparks"]:
			for p: Node3D in v[kind]:
				p.visible = false
		(v["shell"] as Node3D).visible = false
	var charges: int = on.get(&"guard", 0)
	for k in ORBS:
		var o: Node3D = v["orbs"][k]
		o.visible = k < charges
		var a := t * 3.0 + TAU * k / ORBS
		o.position = Vector3(cos(a) * (r + 0.35), 0.7, sin(a) * (r + 0.35))


## The number of actors showing at least one status piece (tests read it).
func view_count() -> int:
	return _views.size()


## The visible pieces of `kind` (&"embers", &"pips_lit", &"drips", &"crystals", &"shell", &"orbs") on actor `id`.
func shown(id: int, kind: StringName) -> int:
	var v: Dictionary = _views.get(id, {})
	if v.is_empty():
		return 0
	if kind == &"shell":
		return 1 if (v["shell"] as Node3D).visible else 0
	if kind == &"pips_lit":
		var lit := 0
		for p: MeshInstance3D in v["pips"]:
			if p.visible and p.material_override == _mats[&"pip_on"]:
				lit += 1
		return lit
	var n := 0
	for p: Node3D in v[kind]:
		if p.visible:
			n += 1
	return n


func fx_count() -> int:
	return _fx.size()


# --- Combo and engine payoffs --------------------------------------------------------------------------------
func _sync_payoffs(reader: WorldReader) -> void:
	if vfx != null:
		_sync_payoff_shots(reader)
		return
	if _changed(&"discharge", reader.discharge_tick()):
		for to in reader.discharge_to():
			_bolt_line(reader.discharge_from(), to, ItemLooks.status_color(&"shock"))
		_ring(reader.discharge_from(), 0.8, ItemLooks.status_color(&"shock"))
	if _changed(&"plasma", reader.plasma_tick()):
		_bolt_line(reader.plasma_from(), reader.plasma_to(), ItemLooks.combo_color(&"plasma_arc"))
	for kind: StringName in [&"shatter", &"burst", &"wildfire", &"harvest"]:
		var p: Array = reader.payoff(kind)
		if _changed(kind, p[0]):
			_ring(p[1], 1.6, _payoff_color(kind))
	if _changed(&"resonance", reader.resonance_tick()):
		_ring(reader.player_pos(), reader.shockwave_radius_m(), ItemLooks.combo_color(&"resonance"))
	if _changed(&"bastion", reader.bastion_tick()):
		_ring(reader.player_pos(), 1.2, ItemLooks.combo_color(&"frozen_bastion"))
	if _changed(&"slipstream", reader.slipstream_tick()):
		_ring(reader.player_pos(), 0.9, ItemLooks.combo_color(&"slipstream"))


## The new look's payoffs: element bursts and lightning in the effects layer, the radius rings kept for the rest.
func _sync_payoff_shots(reader: WorldReader) -> void:
	var now := vfx.now()
	if _changed(&"discharge", reader.discharge_tick()):
		var to: Array = []
		for p: Vector2 in reader.discharge_to():
			to.append(SimPlane.to_3d(p, 0.6))
		_shots.append(
			[&"discharge", SimPlane.to_3d(reader.discharge_from(), 0.6), 0.8, now, 18.0, _frame, to]
		)
	if _changed(&"plasma", reader.plasma_tick()):
		var to: Array = [SimPlane.to_3d(reader.plasma_to(), 0.6)]
		_shots.append(
			[&"discharge", SimPlane.to_3d(reader.plasma_from(), 0.6), 0.8, now, 18.0, _frame, to]
		)
	for kind: StringName in [&"shatter", &"burst", &"wildfire", &"harvest"]:
		var p: Array = reader.payoff(kind)
		if _changed(kind, p[0]):
			_shots.append([kind, SimPlane.to_3d(p[1], 0.07), 1.6, now, 60.0, _frame + p[0], []])
	if _changed(&"resonance", reader.resonance_tick()):
		_ring(reader.player_pos(), reader.shockwave_radius_m(), ItemLooks.combo_color(&"resonance"))
	if _changed(&"bastion", reader.bastion_tick()):
		_ring(reader.player_pos(), 1.2, ItemLooks.combo_color(&"frozen_bastion"))
	if _changed(&"slipstream", reader.slipstream_tick()):
		_ring(reader.player_pos(), 0.9, ItemLooks.combo_color(&"slipstream"))


## Draws the statuses and payoffs into the effects layer (called inside its frame).
func _draw_vfx(layer: VfxCore) -> void:
	var fx := layer as VfxLayer
	for id: int in _on:
		var s: Dictionary = _on[id]
		var node: Node3D = s["node"]
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var p := node.global_position
		fx.status(Vector3(p.x, 0.0, p.z), float(s["r"]), s["on"], id, float(s["top"]))
	var keep: Array = []
	for shot: Array in _shots:
		var u := (fx.now() - float(shot[3])) / float(shot[4])
		if u > 1.0:
			continue
		keep.append(shot)
		u = maxf(u, 0.0)
		match shot[0]:
			&"discharge":
				for to: Vector3 in shot[6]:
					fx.line(&"storm", shot[1], to, 1.0 - u, u * float(shot[4]), int(shot[5]))
			&"shatter":
				fx.burst(&"frost", shot[1], shot[2], u, int(shot[5]))
			&"wildfire":
				fx.burst(&"fire", shot[1], shot[2], u, int(shot[5]))
			_:
				fx.burst(&"bleed", shot[1], shot[2], u, int(shot[5]))
	_shots = keep


## The payoffs the effects layer is drawing (tests).
func shot_count() -> int:
	return _shots.size()


static func _payoff_color(kind: StringName) -> Color:
	match kind:
		&"shatter":
			return ItemLooks.combo_color(&"shatter_dash")
		&"burst":
			return ItemLooks.status_color(&"bleed")
		&"wildfire":
			return ItemLooks.color_of_id(&"wildfire")
	return ItemLooks.combo_color(&"blood_harvest")


## True once per new tick value (and never for -1, "never happened").
func _changed(key: StringName, tick: int) -> bool:
	if _seen.get(key, -1) == tick:
		return false
	_seen[key] = tick
	return tick >= 0


## A jagged line of thin boxes from a to b (lightning), fading over FX_FRAMES.
func _bolt_line(a: Vector2, b: Vector2, c: Color) -> void:
	var pts: Array[Vector3] = [SimPlane.to_3d(a, 0.6)]
	var side := (b - a).orthogonal().normalized()
	for k in range(1, 4):
		var off := side * (0.18 if k % 2 == 1 else -0.18)
		pts.append(SimPlane.to_3d(a.lerp(b, k / 4.0) + off, 0.6 + 0.1 * k))
	pts.append(SimPlane.to_3d(b, 0.6))
	for k in pts.size() - 1:
		var from := pts[k]
		var to := pts[k + 1]
		var n := MeshInstance3D.new()
		n.mesh = _box
		var length := from.distance_to(to)
		n.position = (from + to) * 0.5
		n.scale = Vector3(0.05, 0.05, maxf(length, 0.01))
		add_child(n)
		if length > 0.001:
			n.look_at_from_position(n.position, to, Vector3.UP)
		_add_fx(n, c, 0.95, 0.0)


func _ring(at: Vector2, radius: float, c: Color) -> void:
	var n := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius - 0.12, 0.05)
	torus.outer_radius = radius
	n.mesh = torus
	n.position = SimPlane.to_3d(at, 0.2)
	n.scale = Vector3(0.4, 0.08, 0.4)
	add_child(n)
	_add_fx(n, c, 0.85, 0.6)


func _add_fx(n: MeshInstance3D, c: Color, a: float, grow: float) -> void:
	var m := _fx_template.duplicate() as StandardMaterial3D
	m.albedo_color = Color(c, a)
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_fx.append([n, m, FX_FRAMES, a, grow])


func _process(_delta: float) -> void:
	for k in range(_fx.size() - 1, -1, -1):
		var fx: Array = _fx[k]
		fx[2] -= 1
		var f := float(fx[2]) / FX_FRAMES
		(fx[1] as StandardMaterial3D).albedo_color.a = fx[3] * f
		if fx[4] > 0.0:
			var s: float = 1.0 - (1.0 - fx[4]) * f
			(fx[0] as Node3D).scale = Vector3(s, 0.08, s)
		if fx[2] <= 0:
			(fx[0] as Node).queue_free()
			_fx.remove_at(k)


# --- Building blocks ------------------------------------------------------------------------------------------
func _pieces(root: Node3D, n: int, mesh: Mesh, scale: Vector3, mat: StringName) -> Array:
	var out := []
	for k in n:
		out.append(_piece(root, mesh, scale, mat))
	return out


func _piece(root: Node3D, mesh: Mesh, scale: Vector3, mat: StringName) -> MeshInstance3D:
	var p := MeshInstance3D.new()
	p.mesh = mesh
	p.scale = scale
	p.material_override = _mats[mat]
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visible = false
	root.add_child(p)
	return p


## An unshaded material (alpha when a < 1); `billboard` for the pips, drawn over everything like the health bar.
static func _material(c: Color, a: float, billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c, a)
	if a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.no_depth_test = true
	return m


static func _make_template() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
