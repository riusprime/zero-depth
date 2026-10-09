class_name CoreViews
extends Node3D
## Core theft and the trade-off curses in the world (v0.6.0 CU; CoreTheft, Curses). Reads only (EI-07).
## - A core: a faceted crystal floating over every elite and boss that carries one, glowing the frame colour of its
##   card's family (CardFrames: the card's own family, also for a boss's legendary core), turning slowly. A staggered
##   carrier's crystal flares bigger and brighter.
## - The steal window: while it is open, a bright ring on the floor around the carrier, shrinking from wide to the
##   body as the window runs out (its radius is the time left), pulsing; a steal throws a burst of the core's colour.
## - Rooted's dodge: "DODGE" pops over the hero and rises. Brittle's stun: "STUNNED" hangs over the hero while it holds.
## Glowing materials have emission on from creation; only energies, scales and colours change (flash-safe).

const RING_COLOR := Color("#FFF2C2")
const GEM_ENERGY := 2.4
const RING_MAX_M := 1.6
const POP_S := 0.7
const BURST_S := 0.5
const DODGE_COLOR := Color("#7FE8FF")
const STUN_COLOR := Color("#FFD23A")

## Per carrier actor id: its gem node (with metas "mat" and "card"), and its ring.
var _gems := {}
var _rings := {}
var _ring_mat := StandardMaterial3D.new()
var _t := 0.0
var _dodge := Label3D.new()
var _stun := Label3D.new()
var _dodge_tick := -1
var _dodge_left := 0.0
var _steal_tick := -1
var _burst: MeshInstance3D
var _burst_left := 0.0
var _hero := Vector3.ZERO


func _init() -> void:
	name = "Cores"
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_mat.albedo_color = Color(RING_COLOR, 0.85)
	for pair: Array in [[_dodge, DODGE_COLOR], [_stun, STUN_COLOR]]:
		var l: Label3D = pair[0]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 44
		l.outline_size = 10
		l.outline_modulate = Color(0, 0, 0, 0.85)
		l.pixel_size = 0.006
		l.modulate = pair[1]
		l.visible = false
		l.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(l)
	_dodge.name = "Dodge"
	_stun.name = "Stun"
	_burst = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 8
	s.rings = 4
	_burst.mesh = s
	_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_burst.visible = false
	add_child(_burst)


## The frame colour of card `code`'s family (CardFrames), or the ring's white for no card.
static func card_color(reader: WorldReader, code: int) -> Color:
	if code < 0:
		return RING_COLOR
	var info := reader.card_info(code)
	var fam := CardFrames.family(info["id"], int(info["type"]), 0, false)
	return CardFrames.tint(CardFrames.frame_of(fam))


## A glowing material (emission on from creation; flash-safe).
static func glow_material(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func sync(reader: WorldReader) -> void:
	var live := {}
	_hero = SimPlane.to_3d(reader.player_pos())
	for i in range(1, reader.actor_count()):
		var code := reader.actor_core(i)
		if code < 0 or reader.actor_dead(i):
			continue
		var id := reader.actor_id(i)
		live[id] = true
		var gem: Node3D = _gems.get(id)
		if gem == null:
			gem = _make_gem(card_color(reader, code))
			add_child(gem)
			_gems[id] = gem
		var boss := reader.actor_core_boss(i)
		var r := reader.actor_radius(i)
		gem.position = SimPlane.to_3d(reader.actor_pos(i), maxf(2.6, r * 2.2) if boss else 1.35 + r)
		var staggered := reader.actor_core_staggered(i) or (boss and reader.boss_staggered(i))
		gem.set_meta(&"hot", staggered)
		gem.set_meta(&"base", 1.6 if boss else 1.0)
		var left := reader.actor_steal_ticks(i)
		var ring: MeshInstance3D = _rings.get(id)
		if left > 0:
			if ring == null:
				ring = _make_ring()
				add_child(ring)
				_rings[id] = ring
			var frac := float(left) / maxf(1.0, float(reader.steal_window_ticks()))
			var rr := r + 0.25 + RING_MAX_M * frac
			ring.scale = Vector3(rr, 1.0, rr)
			ring.position = SimPlane.to_3d(reader.actor_pos(i), 0.06)
			ring.visible = true
		elif ring != null:
			ring.visible = false
	var gone := Vector3.INF
	for id in _gems.keys():
		if not live.has(id):
			gone = (_gems[id] as Node3D).position
			(_gems[id] as Node3D).queue_free()
			_gems.erase(id)
			if _rings.has(id):
				(_rings[id] as Node3D).queue_free()
				_rings.erase(id)
	if reader.steal_tick() != _steal_tick:
		_steal_tick = reader.steal_tick()
		if _steal_tick >= 0:
			_burst.material_override = glow_material(card_color(reader, reader.steal_card()), 3.0)
			_burst_left = BURST_S
			_burst.visible = gone != Vector3.INF
			_burst.position = gone if gone != Vector3.INF else _hero
	if reader.dodge_tick() != _dodge_tick:
		_dodge_tick = reader.dodge_tick()
		if _dodge_tick >= 0:
			_dodge.text = tr("HUD_DODGE")
			_dodge_left = POP_S
			_dodge.visible = true
	_stun.text = tr("HUD_STUNNED")
	_stun.visible = reader.stun_ticks() > 0
	_stun.position = _hero + Vector3(0, 2.3, 0)


func _make_gem(c: Color) -> Node3D:
	var root := Node3D.new()
	var mat := glow_material(c, GEM_ENERGY)
	var gem := MeshInstance3D.new()
	gem.mesh = RewardViews.bipyramid(5, 0.16, 0.28, 0.24)
	gem.material_override = mat
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(gem)
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = 0.5
	light.omni_range = 1.8
	root.add_child(light)
	root.set_meta(&"mat", mat)
	root.set_meta(&"hot", false)
	root.set_meta(&"base", 1.0)
	return root


func _make_ring() -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.93
	t.outer_radius = 1.0
	t.rings = 48
	ring.mesh = t
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring


# --- Reads (tests) ------------------------------------------------------------------------------------------
## Cores drawn now, and the steal rings showing.
func core_count() -> int:
	return _gems.size()


func ring_count() -> int:
	var n := 0
	for id in _rings:
		n += 1 if (_rings[id] as Node3D).visible else 0
	return n


## The colour actor `id`'s core glows (Color.BLACK when none).
func core_color_of(id: int) -> Color:
	var gem: Node3D = _gems.get(id)
	return (gem.get_meta(&"mat") as StandardMaterial3D).albedo_color if gem != null else Color.BLACK


func dodge_showing() -> bool:
	return _dodge.visible


func stun_showing() -> bool:
	return _stun.visible


func _process(delta: float) -> void:
	_t += delta
	for id in _gems:
		var gem: Node3D = _gems[id]
		var hot: bool = gem.get_meta(&"hot")
		var base: float = gem.get_meta(&"base")
		gem.rotation.y = _t * (3.0 if hot else 1.2)
		gem.scale = Vector3.ONE * base * (1.45 if hot else 1.0)
		var mat: StandardMaterial3D = gem.get_meta(&"mat")
		mat.emission_energy_multiplier = GEM_ENERGY * (2.0 if hot else 1.0)
	_ring_mat.albedo_color = Color(RING_COLOR, 0.6 + 0.35 * absf(sin(_t * 9.0)))
	if _dodge_left > 0.0:
		_dodge_left = maxf(0.0, _dodge_left - delta)
		var k := 1.0 - _dodge_left / POP_S
		_dodge.position = _hero + Vector3(0, 1.9 + 0.8 * k, 0)
		_dodge.modulate = Color(DODGE_COLOR, 1.0 - k * k)
		_dodge.visible = _dodge_left > 0.0
	if _burst_left > 0.0:
		_burst_left = maxf(0.0, _burst_left - delta)
		var k := 1.0 - _burst_left / BURST_S
		_burst.scale = Vector3.ONE * (0.4 + 2.2 * k)
		_burst.visible = _burst_left > 0.0
