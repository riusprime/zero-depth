class_name StatusVisuals
extends Node3D
## Engine statuses and combo payoffs on screen. Reads the sim through WorldReader only:
## - burn: embers rising around the enemy (more stacks, more embers); its orange glow is ItemVisuals' tint;
## - shock: flickering sparks; a discharge draws a lightning line to each enemy it jumped to;
## - v0.10.0 FX: every stacking status (burn, bleed, poison, shock, frost) shows its icon and count ("x3") over the
##   health bar (StatusBadges), in place of the shock pips and the poison and bleed dots;
## - bleed: red drips falling from the enemy (more stacks, more drips); a burst draws a red ring;
## - frost: ice crystals around the enemy's feet, one per stack; frozen: an ice shell (and ItemVisuals' icy tint);
## - Bulwark's guard charges: gold orbs circling the player;
## - combo payoffs: Plasma Arc (an orange arc), Shatter Dash, Wildfire, Blood Harvest and Frozen Bastion rings,
##   Resonance's second wave.
## With the new look (v0.5.9 art, VFX phase 2: `vfx` set) the enemy statuses draw into the VfxLayer instead of the
## boxes: flames on a burning body, arcs over a shocked one, red drips, bubbles and green drips for poison, ice
## crystals and a crystal cage for frost and frozen; the bleed, shatter, wildfire and harvest payoffs burst in
## their element and a discharge strikes as lightning. The badges and guard orbs stay (they are counts).
## Materials are made once and kept (never emission toggles at runtime: the v0.2.0 DAMAGE_LAG rule); each actor's
## pieces are children of its ActorViews node, so they move and go with it.

## A Contagion arc lasts 0.25 s (15 ticks); the Exsanguinate splash 20 ticks.
const JUMP_TICKS := 15.0
const SPLASH_TICKS := 20.0
const SPLASH_RADIUS_M := 1.2
## The "+" over a burning (Heat sync) or frozen (Shatter) enemy's bar at Lv 3; an Overcharge strike's bolt
## and a shard's streak last 0.33 s and 0.25 s.
const PLUS_FIRE := Color("#FFB347")
const PLUS_FROST := Color("#BDEBFF")
const STRIKE_TICKS := 20.0
const SHARD_TICKS := 15.0
const STRIKE_TOP_M := 3.5
const EMBERS := 3
const DRIPS := 3
const CRYSTALS := 4
const ORBS := 3
const FX_FRAMES := 16
## The ring radii the payoffs draw (m), their meshes made by prepare(); and the fading pieces it pools (a
## starting value: a discharge's bolt and its ring).
const RING_RADII: Array[float] = [0.8, 0.9, 1.0, SPLASH_RADIUS_M, 1.6]
const FX_PREFILL := 6
## A status's reach past the actor's radius for the cull: its flames and arcs (about 1.5 m over the body)
## and its light (VfxLayer._light_status: 3 m range).
const STATUS_REACH_M := 3.5
## A payoff's reach past its point for the cull: a burst's widest light (VfxLayer._explosion_rest:
## r * 3 + 2 m) and its rising smoke; a line's length and the light at its far end (StormPack.lightning: 4 m).
const SHOT_REACH_PER_M := 3.0
const SHOT_REACH_M := 2.5
const SHOT_LINE_REACH_M := 4.0

## P-9: the pieces the effects layer draws instead (hidden under the new look).
const VFX_DRAWN: Array[String] = ["embers", "drips", "crystals", "sparks"]

## False hides the burn embers (frame_probe --ab=no_burn_fx measures their cost).
static var burn_embers := true
var actors: ActorViews
## The new look's effects layer (null: the boxes and rings as before).
var vfx: VfxLayer
## The camera's view (WorldViewRoot sets it): a status wholly out of the picture (past its
## reach + ScreenCull.MARGIN_M) is not drawn into the effects layer. Null: every status draws.
var cull: ScreenCull
## Statuses drawn into the effects layer last frame, and skipped as off screen (tests, the perf probe).
var statuses_drawn := 0
var statuses_culled := 0
## Payoffs drawn into the effects layer last frame, and skipped as off screen (tests, the perf probe).
var shots_drawn := 0
var shots_culled := 0
## The syncs that visited actors; a sync with no status anywhere, before or now, goes straight to the payoffs
## (tests read it).
var worked := 0
## Kept for the view's life, one per look (see the class note).
var _mats := {}
var _box := BoxMesh.new()
var _prism := PrismMesh.new()
var _dot := QuadMesh.new()
var _shell := SphereMesh.new()
## Actor id -> its pieces: {"root": Node3D, "embers": [...], "badges": StatusBadges, ...}.
var _views := {}
var _frame := 0
var _last_tick := -1
## The camera's right (world), the badges' row direction.
var _right := Vector3.RIGHT
## The last event read (Contagion jumps, the Exsanguinate burst).
var _last_seq := 0
## Where the last Shatter broke (its shards fly from there), and whether the "+" shows this sync.
var _shatter_at := Vector2.ZERO
var _plus_fire := false
var _plus_frost := false
var _seen := {}
var _fx: Array = []
var _fx_template := SkillVisuals._make_template()
## Each payoff ring made a TorusMesh and a material: the ring meshes by radius (shared), and the idle fading
## pieces (rings and bolt segments), each with its own material, reused instead of freed.
var _tori := {}
var _idle_fx: Array[MeshInstance3D] = []
## Actor id -> {on, r, node} for the vfx drawer.
var _on := {}
## Payoffs drawn by the vfx layer: [kind, at (Vector3), radius, start tick, life, seed, to (Array of Vector3)].
var _shots: Array = []
## The per-tick Dictionaries kept and refilled instead of built every tick: the actors alive with a
## status, each one's _on entry by id ({on, r, node, top}, its "on" swapped with the scratch), and the scratch a
## status-free enemy is read into (left empty, nothing kept for it).
var _alive := {}
var _entries := {}
var _scratch := {}


func _init(p_actors: ActorViews) -> void:
	actors = p_actors
	_box.size = Vector3.ONE
	_prism.size = Vector3(0.12, 0.3, 0.12)
	_shell.radius = 0.5
	_shell.height = 1.0
	_shell.radial_segments = 8
	_shell.rings = 4
	for k: StringName in [&"burn", &"shock", &"bleed", &"frost", &"guard"]:
		_mats[k] = _material(ItemLooks.status_color(k), 1.0, false)
	_mats[&"dot_plus_fire"] = _material(PLUS_FIRE, 1.0, true)
	_mats[&"dot_plus_frost"] = _material(PLUS_FROST, 1.0, true)
	_dot.size = Vector2(0.08, 0.08)
	_mats[&"shell"] = _material(ItemLooks.status_color(&"frozen"), 0.38, false)


## Hands the statuses to the new look's effects layer (WorldViewRoot, when the new look is on).
func use_vfx(layer: VfxLayer) -> void:
	vfx = layer
	layer.drawers.append(_draw_vfx)


func sync(reader: WorldReader) -> void:
	# It may sync every other tick, so the animation clock counts ticks, not syncs.
	var tick := reader.tick()
	_frame += clampi(tick - _last_tick, 1, 2)
	_last_tick = tick
	_plus_fire = reader.element_plus(true)  # v0.9.5 EE2
	_plus_frost = reader.element_plus(false)
	# Only the actors that show something are visited: the hero with guard charges, and the ones the sim's status
	# columns mark (one bulk read, not a status check and an anchor lookup per actor).
	var shown := reader.status_indices()
	if reader.guard_charges() > 0 and reader.actor_count() > 0:
		shown.insert(0, 0)
	_on.clear()
	if shown.is_empty() and _views.is_empty() and _entries.is_empty():
		_sync_payoffs(reader)  # Nothing on any actor, before or now
		return
	worked += 1
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		_right = cam.global_transform.basis.x
	_alive.clear()
	for i in shown:
		var id := reader.actor_id(i)
		var node := actors.anchor_node(id)  # (a batched enemy's anchor in the tree)
		if node == null:
			continue
		_scratch.clear()
		_statuses(reader, i, _scratch)
		if _scratch.is_empty():
			continue
		_alive[id] = true
		var v: Dictionary = _views.get(id, {})
		if v.is_empty() or not is_instance_valid(v["root"]):
			v = _build(node, reader.actor_radius(i))
			_views[id] = v
		var entry: Dictionary = _entries.get(id, {})
		if entry.is_empty():
			entry = {"on": {}}
			_entries[id] = entry
		var on: Dictionary = _scratch
		_scratch = entry["on"]
		entry["on"] = on
		_update(v, on, reader.actor_radius(i))
		entry["r"] = reader.actor_radius(i)
		entry["node"] = node
		entry["top"] = maxf(0.5, float(v["bar_y"]) - 0.4)
		_on[id] = entry
	for id in _entries.keys():
		if not _alive.has(id):
			_entries.erase(id)
	for id in _views.keys():
		if not _alive.has(id):
			var v: Dictionary = _views[id]
			if is_instance_valid(v["root"]):
				(v["root"] as Node3D).queue_free()
			_views.erase(id)
	_sync_payoffs(reader)


## What actor i shows: {status: stacks}, filled into `out` (a kept Dictionary, emptied by the caller).
## Enemies show burn/shock/bleed/frost/frozen; the player its charges.
func _statuses(reader: WorldReader, i: int, out: Dictionary) -> Dictionary:
	if i == 0:
		if reader.guard_charges() > 0:
			out[&"guard"] = reader.guard_charges()
		return out
	if not reader.any_status(i):
		return out
	if reader.burn_stacks(i) > 0:
		out[&"burn"] = reader.burn_stacks(i)
		if _plus_fire:
			out[&"plus_fire"] = 1  # Heat sync
	if reader.shock_stacks(i) > 0:
		out[&"shock"] = reader.shock_stacks(i)
	if reader.bleed_stacks(i) > 0:
		out[&"bleed"] = reader.bleed_stacks(i)
	if reader.frost_stacks(i) > 0:
		out[&"frost"] = reader.frost_stacks(i)
	if reader.actor_frozen(i):
		out[&"frozen"] = 1
		if _plus_frost:
			out[&"plus_frost"] = 1  # Shatter
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
	elif node.has_meta(&"bar_y"):  # A batched enemy's anchor (its bar is the batch's)
		bar_y = node.get_meta(&"bar_y")
	var v := {
		"root": root,
		"bar_y": bar_y,
		"badges": StatusBadges.new(root, bar_y),
		"orbs": [],
		"dots_plus_fire": [],
		"dots_plus_frost": []
	}
	if vfx != null:
		# The effects layer draws the embers, drips, crystals, sparks and shell,
		# so none of their ~15 hidden meshes is built per affected enemy (a burning horde built and freed them as
		# statuses came and went); the badges and guard orbs are built the first time they show (_update).
		for kind: String in VFX_DRAWN:
			v[kind] = []
		v["shell"] = null
		return v
	v["embers"] = _pieces(root, EMBERS, _box, Vector3(0.11, 0.11, 0.11), &"burn")
	v["drips"] = _pieces(root, DRIPS, _box, Vector3(0.08, 0.2, 0.08), &"bleed")
	v["crystals"] = _pieces(root, CRYSTALS, _prism, Vector3.ONE, &"frost")
	v["sparks"] = _pieces(root, 2, _box, Vector3(0.05, 0.05, 0.5), &"shock")
	_build_orbs(v)
	var shell := _piece(root, _shell, Vector3(r * 2.6, 1.3, r * 2.6), &"shell")
	shell.position = Vector3(0, 0.55, 0)
	v["shell"] = shell
	for k in CRYSTALS:
		var a := TAU * k / CRYSTALS + 0.4
		(v["crystals"][k] as Node3D).position = Vector3(
			cos(a) * (r + 0.08), 0.15, sin(a) * (r + 0.08)
		)
	return v


## The "+" (one bigger dot, beside the bar's right end) of `status` (plus_fire or plus_frost).
func _update_plus(v: Dictionary, status: StringName, on: bool) -> void:
	var dots: Array = v[&"dots_plus_fire" if status == &"plus_fire" else &"dots_plus_frost"]
	if on and dots.is_empty():
		var p := _piece(
			v["root"], _dot, Vector3(1.7, 1.7, 1.7), StringName("dot_" + String(status))
		)
		p.position = Vector3(0.42, float(v["bar_y"]) + 0.2, 0)
		dots.append(p)
	for p: Node3D in dots:
		p.visible = on


## The guard orbs (once per view).
func _build_orbs(v: Dictionary) -> void:
	v["orbs"] = _pieces(v["root"], ORBS, _box, Vector3(0.12, 0.12, 0.12), &"guard")


func _update(v: Dictionary, on: Dictionary, r: float) -> void:
	var t := _frame / 60.0
	if vfx == null:
		_update_pieces(v, on, r, t)
	else:  # the new look draws these in the effects layer (_draw_vfx); P-9: nothing to lay out, only hidden
		for kind: String in VFX_DRAWN:
			for p: Node3D in v[kind]:
				p.visible = false
		if v["shell"] != null:
			(v["shell"] as Node3D).visible = false
	(v["badges"] as StatusBadges).update(on, _right)  # Icon and "xN" a status
	_update_plus(v, &"plus_fire", on.has(&"plus_fire"))
	_update_plus(v, &"plus_frost", on.has(&"plus_frost"))
	var charges: int = on.get(&"guard", 0)
	if charges > 0 and (v["orbs"] as Array).is_empty():
		_build_orbs(v)
	for k in (v["orbs"] as Array).size():
		var o: Node3D = v["orbs"][k]
		# The pack's orbs draw the first guard_orbs_packed of them (one frame behind)
		o.visible = k < charges and (vfx == null or k >= vfx.guard_orbs_packed)
		var a := t * 3.0 + TAU * k / ORBS
		o.position = Vector3(cos(a) * (r + 0.35), 0.7, sin(a) * (r + 0.35))


## The old look's embers, drips, ice crystals, shell and shock sparks (without the effects layer).
func _update_pieces(v: Dictionary, on: Dictionary, r: float, t: float) -> void:
	var burn: int = on.get(&"burn", 0) if burn_embers else 0
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
	for k in 2:
		var s: Node3D = v["sparks"][k]
		s.visible = shock > 0 and (_frame / 3 + k) % 2 == 0
		var a := (_frame / 3) * 1.7 + k * 3.1
		s.position = Vector3(cos(a) * r * 0.6, 0.4 + 0.3 * k, sin(a) * r * 0.6)
		s.rotation = Vector3(0.4 * k, a, 0.6)


## The count the badge of `status` shows on actor `id` (0: none).
func badge(id: int, status: StringName) -> int:
	var v: Dictionary = _views.get(id, {})
	return 0 if v.is_empty() else (v["badges"] as StatusBadges).shown(status)


## The number of actors showing at least one status piece (tests read it).
func view_count() -> int:
	return _views.size()


## The visible pieces of `kind` (&"embers", &"drips", &"crystals", &"shell", &"orbs") on actor `id`.
func shown(id: int, kind: StringName) -> int:
	var v: Dictionary = _views.get(id, {})
	if v.is_empty():
		return 0
	if kind == &"shell":
		return 1 if v["shell"] != null and (v["shell"] as Node3D).visible else 0
	var n := 0
	for p: Node3D in v[kind]:
		if p.visible:
			n += 1
	return n


func fx_count() -> int:
	return _fx.size()


# --- Combo and engine payoffs --------------------------------------------------------------------------------
func _sync_payoffs(reader: WorldReader) -> void:
	_sync_element_events(reader)
	if vfx != null:
		_sync_payoff_shots(reader)
		return
	if _changed(&"discharge", reader.discharge_tick()):
		for to in reader.discharge_to():
			_bolt_line(reader.discharge_from(), to, ItemLooks.status_color(&"shock"))
		_ring(reader.discharge_from(), 0.8, ItemLooks.status_color(&"shock"))
	for kind: StringName in [&"shatter", &"burst", &"wildfire", &"harvest"]:
		var p: Array = reader.payoff(kind)
		if _changed(kind, p[0]):
			_ring(p[1], 1.6, _payoff_color(kind))
	if _changed(&"slipstream", reader.slipstream_tick()):
		_ring(reader.player_pos(), 0.9, ItemLooks.combo_color(&"slipstream"))


## A Contagion jump draws a thin green arc from the giver to the receiver for 0.25 s; the Exsanguinate
## burst splashes red (ElementLevels). Read from the event log; both go through the effects layer's pooled lines and
## bursts (their caps and Effects density), or the old look's bolt line and ring.
func _sync_element_events(reader: WorldReader) -> void:
	var now := float(reader.tick())
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == SimEvent.EFFECT_VENOM_JUMP:
			var gi := reader.actor_index(e.source_id)
			if gi < 0:
				continue
			var from := reader.actor_pos(gi)
			if vfx != null:
				var to: Array = [SimPlane.to_3d(e.pos, 0.6)]
				_shots.append([&"jump", SimPlane.to_3d(from, 0.6), 0.0, now, JUMP_TICKS, e.seq, to])
			else:
				_bolt_line(from, e.pos, StatusBadges.POISON)
		elif (
			e.kind == SimEvent.Kind.DAMAGE
			and e.effect_id == SimEvent.EFFECT_EXSANGUINATE
			and e.amount > 0
		):
			if vfx != null:
				var at := SimPlane.to_3d(e.pos, 0.07)
				_shots.append([&"exsang", at, SPLASH_RADIUS_M, now, SPLASH_TICKS, e.seq, []])
			else:
				_ring(e.pos, SPLASH_RADIUS_M, ItemLooks.status_color(&"bleed"))
		elif e.kind == SimEvent.Kind.STATUS_APPLY:
			_sync_fsf_event(e, now)


## An Overcharge strike (a bolt from above and a ring), a Shatter (a crackle where the ice broke) and its
## shards (streaks to the enemies they hit), through the effects layer's pooled lines and bursts (their caps and
## Effects density), or the old look's bolt line and ring.
func _sync_fsf_event(e: SimEvent, now: float) -> void:
	match e.effect_id:
		SimEvent.EFFECT_STORM_STRIKE:
			var radius := float(e.amount) / 1000.0
			if vfx != null:
				var top: Array = [SimPlane.to_3d(e.pos, STRIKE_TOP_M)]
				_shots.append(
					[&"strike", SimPlane.to_3d(e.pos, 0.07), radius, now, STRIKE_TICKS, e.seq, top]
				)
			else:
				_bolt_line(e.pos + Vector2(0.5, 0.5), e.pos, ItemLooks.status_color(&"shock"))
				_ring(e.pos, radius, ItemLooks.status_color(&"shock"))
		SimEvent.EFFECT_FROST_SHATTER:
			_shatter_at = e.pos
			if vfx != null:
				_shots.append(
					[&"shatter", SimPlane.to_3d(e.pos, 0.07), 1.2, now, SHARD_TICKS, e.seq, []]
				)
			else:
				_ring(e.pos, 1.0, ItemLooks.status_color(&"frozen"))
		SimEvent.EFFECT_PAIR_BURST:  # Thermal Shock, Brittle: the frost burst at the pair's radius
			var reach := float(e.amount) / 1000.0
			if vfx != null:
				_shots.append(
					[&"shatter", SimPlane.to_3d(e.pos, 0.07), reach, now, SHARD_TICKS, e.seq, []]
				)
			else:
				_ring(e.pos, reach, ItemLooks.status_color(&"frozen"))
		SimEvent.EFFECT_FROST_SHARD:
			if vfx != null:
				var to: Array = [SimPlane.to_3d(e.pos, 0.6)]
				_shots.append(
					[&"shard", SimPlane.to_3d(_shatter_at, 0.6), 0.0, now, SHARD_TICKS, e.seq, to]
				)
			else:
				_bolt_line(_shatter_at, e.pos, ItemLooks.status_color(&"frozen"))


## The new look's payoffs: element bursts and lightning in the effects layer, the radius rings kept for the rest.
func _sync_payoff_shots(reader: WorldReader) -> void:
	# P-19b: the sim's tick, not the effects layer's clock (0.0 until its first frame, so a payoff on a floor's first
	# sync, as a resumed save gives, was stamped 0 and dropped at once). The layer's clock is this tick + a fraction.
	var now := float(reader.tick())
	if _changed(&"discharge", reader.discharge_tick()):
		var to: Array = []
		for p: Vector2 in reader.discharge_to():
			to.append(SimPlane.to_3d(p, 0.6))
		_shots.append(
			[&"discharge", SimPlane.to_3d(reader.discharge_from(), 0.6), 0.8, now, 18.0, _frame, to]
		)
	for kind: StringName in [&"shatter", &"burst", &"wildfire", &"harvest"]:
		var p: Array = reader.payoff(kind)
		if _changed(kind, p[0]):
			_shots.append([kind, SimPlane.to_3d(p[1], 0.07), 1.6, now, 60.0, _frame + p[0], []])
	if _changed(&"slipstream", reader.slipstream_tick()):
		_ring(reader.player_pos(), 0.9, ItemLooks.combo_color(&"slipstream"))


## Draws the statuses and payoffs into the effects layer (called inside its frame).
func _draw_vfx(layer: VfxCore) -> void:
	var fx := layer as VfxLayer
	statuses_drawn = 0
	statuses_culled = 0
	for id: int in _on:
		var s: Dictionary = _on[id]
		var node_v: Variant = s["node"]  # A sync every other tick may see it freed
		if not is_instance_valid(node_v) or not (node_v as Node3D).is_inside_tree():
			continue
		var p := (node_v as Node3D).global_position
		var ground := Vector3(p.x, 0.0, p.z)
		var r := float(s["r"])
		if cull != null and not cull.shows(ground, r + STATUS_REACH_M):  # Wholly off screen
			statuses_culled += 1
			continue
		statuses_drawn += 1
		fx.status(ground, r, s["on"], id, float(s["top"]))
	# The payoffs in flight, kept in place (no new Array a frame); one wholly off screen (past its reach
	# + ScreenCull.MARGIN_M) draws nothing but the floor mark it leaves, so the mark is there when the camera arrives
	shots_drawn = 0
	shots_culled = 0
	var n := 0
	for shot: Array in _shots:
		var u := (fx.now() - float(shot[3])) / float(shot[4])
		if u > 1.0:
			continue
		_shots[n] = shot
		n += 1
		u = maxf(u, 0.0)
		if cull != null and not cull.shows(shot[1], _shot_reach(shot)):
			shots_culled += 1
			_shot_mark(fx, shot)
			continue
		shots_drawn += 1
		_draw_shot(fx, shot, u)
	_shots.resize(n)


## How far past its point a payoff can show: a line's length and the light at its far end, a burst's
## widest light and smoke.
static func _shot_reach(shot: Array) -> float:
	var reach := 0.0
	for to: Vector3 in shot[6]:
		reach = maxf(reach, (shot[1] as Vector3).distance_to(to) + SHOT_LINE_REACH_M)
	match shot[0]:
		&"discharge", &"jump", &"shard":
			return reach
	return maxf(reach, float(shot[2]) * SHOT_REACH_PER_M + SHOT_REACH_M)


## The floor mark an off-screen payoff leaves (the one _draw_shot's burst or line would lay).
static func _shot_mark(fx: VfxLayer, shot: Array) -> void:
	var sd := int(shot[5])
	match shot[0]:
		&"jump":
			fx.line_mark(&"venom", (shot[6] as Array)[0], sd)
		&"shatter", &"wildfire":
			fx.burst_mark(shot[0], shot[1], float(shot[2]), sd)
		&"discharge", &"strike", &"shard":
			pass  # (storm and frost lines and the storm burst leave none)
		_:
			fx.burst_mark(&"bleed", shot[1], float(shot[2]), sd)


func _draw_shot(fx: VfxLayer, shot: Array, u: float) -> void:
	match shot[0]:
		&"discharge":
			for to: Vector3 in shot[6]:
				fx.line(&"storm", shot[1], to, 1.0 - u, u * float(shot[4]), int(shot[5]))
		&"jump":
			var to: Vector3 = (shot[6] as Array)[0]
			fx.line(&"venom", shot[1], to, 1.0 - u, u * float(shot[4]), int(shot[5]))
		&"strike":
			var top: Vector3 = (shot[6] as Array)[0]
			fx.line(&"storm", top, shot[1], 1.0 - u, u * float(shot[4]), int(shot[5]))
			fx.burst(&"storm", shot[1], shot[2], u, int(shot[5]))
		&"shard":
			var to: Vector3 = (shot[6] as Array)[0]
			fx.line(&"frost", shot[1], to, 1.0 - u, u * float(shot[4]), int(shot[5]))
		&"shatter":  # The frost burst and a small ice patch
			fx.burst(&"shatter", shot[1], shot[2], u, int(shot[5]))
		&"wildfire":  # fire_area_03 (the fire sprites' explosion without room)
			fx.burst(&"wildfire", shot[1], shot[2], u, int(shot[5]))
		_:
			fx.burst(&"bleed", shot[1], shot[2], u, int(shot[5]))


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
		var n := _take_fx()
		n.mesh = _box
		var length := from.distance_to(to)
		n.position = (from + to) * 0.5
		n.scale = Vector3(0.05, 0.05, maxf(length, 0.01))
		if length > 0.001:
			n.look_at_from_position(n.position, to, Vector3.UP)
		_add_fx(n, c, 0.95, 0.0)


func _ring(at: Vector2, radius: float, c: Color) -> void:
	var n := _take_fx()
	n.mesh = _torus(radius)
	n.position = SimPlane.to_3d(at, 0.2)
	n.scale = Vector3(0.4, 0.08, 0.4)
	_add_fx(n, c, 0.85, 0.6)


func _add_fx(n: MeshInstance3D, c: Color, a: float, grow: float) -> void:
	var m := n.material_override as StandardMaterial3D
	m.albedo_color = Color(c, a)
	_fx.append([n, m, FX_FRAMES, a, grow])


## The floor's load (WorldViewRoot): the payoff rings' meshes and FX_PREFILL idle pieces, so a floor's first
## payoff makes no mesh, node or material.
func prepare() -> void:
	for r in RING_RADII:
		_torus(r)
	while _idle_fx.size() < FX_PREFILL:
		_idle_fx.append(_new_fx())


## The idle fading pieces waiting (tests).
func idle_fx() -> int:
	return _idle_fx.size()


## The ring mesh of `radius` (shared by every ring that size; made once).
func _torus(radius: float) -> TorusMesh:
	var key := snappedf(radius, 0.01)
	var torus: TorusMesh = _tori.get(key)
	if torus == null:
		torus = TorusMesh.new()
		torus.inner_radius = maxf(key - 0.12, 0.05)
		torus.outer_radius = key
		_tori[key] = torus
	return torus


## An idle fading piece, shown at the origin, or a new one.
func _take_fx() -> MeshInstance3D:
	var n: MeshInstance3D = _idle_fx.pop_back() if not _idle_fx.is_empty() else _new_fx()
	if n.get_parent() == null:
		add_child(n)  # (idle outside the tree)
	n.transform = Transform3D.IDENTITY
	n.visible = true
	return n


## A hidden fading piece with its own material (each fades on its own); made outside the tree, _take_fx
## puts it in.
func _new_fx() -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.material_override = _fx_template.duplicate() as StandardMaterial3D
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	n.visible = false
	return n


## The idle pieces outside the tree
## (ShaderWarmup draws them once at the load).
func idle_pieces() -> Array[Node]:
	var out: Array[Node] = []
	for n: Variant in _idle_fx:  # (a Variant: freeing the view frees its in-tree pieces first)
		if is_instance_valid(n) and (n as Node).get_parent() == null:
			out.append(n)
	return out


## How many idle pieces wait outside the tree (tests, scripts/checks/pool_node_count.gd).
func idle_outside() -> int:
	return idle_pieces().size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:  # the idle pieces outside the tree go with the view
		for n in idle_pieces():
			n.free()
		_idle_fx.clear()


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
			var done := fx[0] as MeshInstance3D
			done.visible = false
			_idle_fx.append(done)
			remove_child(done)  # (idle outside the tree)
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


## An unshaded material (alpha when a < 1); `billboard` for the "+" marks, drawn over everything like the health bar.
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
