class_name SpellFx
extends Node3D
## v0.11.0 O10 (SPELLS.md "Readability": each spell its element's colour and a shape no enemy attack uses; player spells
## are never round red or purple ground marks): the first spells' looks, plain unshaded strips so they read.
## - Frost Nova: six ice spokes and the hexagon joining their tips grow out from the hero to the nova's radius and fade
##   (a snowflake, never a disc);
## - Fireball: an orange ball with a bright core flies at chest height to its point; its burst is an eight-point star of
##   flame spikes out to the burst radius;
## - Sky Strike: a pale-blue bolt drops from the sky onto each struck enemy, and a thin pale line marks its jump.
## The casts come from WorldReader.spell_fx() (each new entry once); lives are sim ticks. Presentation only (EI-07).

const NOVAS := 2
const BURSTS := 4
const BALLS := 6
const BOLTS := 12
const JUMPS := 12
const NOVA_TICKS := 24.0
const BURST_TICKS := 20.0
const BOLT_TICKS := 10.0
const JUMP_TICKS := 9.0
const SPOKE_W := 0.18
## The nova and the burst sit this high (m): over a raised floor (the start pad) too.
const NOVA_M := 0.45
const BOLT_W := 0.14
const SKY_M := 9.0
const CHEST_M := 0.9
const BALL_M := 1.2
const STAR := 8

## Counted for tests: casts drawn by kind.
var drawn := {}
## Live casts: [kind, at, to, start tick, radius m].
var _live: Array = []
var _seen_tick := -1
var _seen_n := 0
var _novas: Array = []
var _bursts: Array = []
var _balls: Array[MeshInstance3D] = []
var _cores: Array[MeshInstance3D] = []
var _bolts: Array[MeshInstance3D] = []
var _jumps: Array[MeshInstance3D] = []
var _box := BoxMesh.new()


func _init() -> void:
	name = "SpellFx"
	_box.size = Vector3.ONE
	var ice := _mat(SpellLooks.color(WorldReader.SPELL_ELEMENT_FROST))
	var fire := _mat(SpellLooks.color(WorldReader.SPELL_ELEMENT_FIRE))
	var sky := _mat(SpellLooks.color(WorldReader.SPELL_ELEMENT_LIGHTNING))
	for k in NOVAS:
		var parts: Array[MeshInstance3D] = []
		for p in 12:
			parts.append(_node(_box, ice))
		_novas.append(parts)
	for k in BURSTS:
		var parts: Array[MeshInstance3D] = []
		for p in STAR:
			parts.append(_node(_box, fire))
		_bursts.append(parts)
	var ball := SphereMesh.new()
	ball.radius = 0.32
	ball.height = 0.64
	var core := SphereMesh.new()
	core.radius = 0.18
	core.height = 0.36
	var hot := _mat(Color("#FFE6B0"))
	for k in BALLS:
		_balls.append(_node(ball, fire))
		_cores.append(_node(core, hot))
	for k in BOLTS:
		_bolts.append(_node(_box, sky))
	for k in JUMPS:
		_jumps.append(_node(_box, sky))


func _node(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat.duplicate()  # each fades on its own
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.visible = false
	add_child(n)
	return n


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func sync(reader: WorldReader) -> void:
	var fx := reader.spell_fx()
	var tick := reader.tick()
	_take(fx)
	_live = _live.filter(func(e: Array) -> bool: return tick - int(e[3]) < _life(int(e[0])))
	_draw(tick)
	var balls: PackedVector2Array = fx["balls"]
	for k in BALLS:
		var on := k < balls.size()
		_balls[k].visible = on
		_cores[k].visible = on
		if on:
			var p := SimPlane.to_3d(balls[k], BALL_M)
			_balls[k].position = p
			_cores[k].position = p


## The log's entries not seen yet (the ticks rise; a new floor's world starts them again).
func _take(fx: Dictionary) -> void:
	var kinds: PackedInt32Array = fx["kind"]
	var ticks: PackedInt32Array = fx["tick"]
	if kinds.is_empty():
		return
	if ticks[ticks.size() - 1] < _seen_tick:
		_seen_tick = -1
		_seen_n = 0
	var at_tick := 0
	var last := -1
	for k in kinds.size():
		var t := ticks[k]
		at_tick = at_tick + 1 if t == last else 1
		last = t
		if t < _seen_tick or (t == _seen_tick and at_tick <= _seen_n):
			continue
		_live.append([kinds[k], fx["from"][k], fx["to"][k], t, float(fx["size"][k])])
		drawn[kinds[k]] = int(drawn.get(kinds[k], 0)) + 1
	_seen_tick = last
	_seen_n = at_tick


static func _life(kind: int) -> float:
	match kind:
		WorldReader.SPELL_FX_NOVA:
			return NOVA_TICKS
		WorldReader.SPELL_FX_BURST:
			return BURST_TICKS
		WorldReader.SPELL_FX_BOLT:
			return BOLT_TICKS
	return JUMP_TICKS


func _draw(tick: int) -> void:
	var nova := 0
	var burst := 0
	var bolt := 0
	var jump := 0
	for e: Array in _live:
		var u := clampf(float(tick - int(e[3])) / _life(int(e[0])), 0.0, 1.0)
		match int(e[0]):
			WorldReader.SPELL_FX_NOVA:
				if nova < NOVAS:
					_nova(_novas[nova], e[1], float(e[4]), u)
					nova += 1
			WorldReader.SPELL_FX_BURST:
				if burst < BURSTS:
					_star(_bursts[burst], e[1], float(e[4]), u)
					burst += 1
			WorldReader.SPELL_FX_BOLT:
				if bolt < BOLTS:
					_strip(
						_bolts[bolt],
						SimPlane.to_3d(e[1], SKY_M),
						SimPlane.to_3d(e[1], 0.1),
						BOLT_W,
						u
					)
					bolt += 1
			_:
				if jump < JUMPS:
					var a := SimPlane.to_3d(e[1], CHEST_M)
					_strip(_jumps[jump], a, SimPlane.to_3d(e[2], CHEST_M), BOLT_W * 0.5, u)
					jump += 1
	for k in range(nova, NOVAS):
		for n: MeshInstance3D in _novas[k]:
			n.visible = false
	for k in range(burst, BURSTS):
		for n: MeshInstance3D in _bursts[k]:
			n.visible = false
	for k in range(bolt, BOLTS):
		_bolts[k].visible = false
	for k in range(jump, JUMPS):
		_jumps[k].visible = false


## Six spokes out to `r` × the growth, and the hexagon between their tips.
func _nova(parts: Array, at: Vector2, r: float, u: float) -> void:
	var reach := r * minf(1.0, u * 2.5)
	var o := SimPlane.to_3d(at, NOVA_M)
	for k in 6:
		var a := TAU * k / 6.0
		var b := TAU * (k + 1) / 6.0
		var tip := o + Vector3(cos(a), 0.0, sin(a)) * reach
		var nxt := o + Vector3(cos(b), 0.0, sin(b)) * reach
		_strip(parts[k], o, tip, SPOKE_W, u)
		_strip(parts[6 + k], tip, nxt, SPOKE_W * 0.7, u)


## An eight-pointed star of spikes out to `r`.
func _star(parts: Array, at: Vector2, r: float, u: float) -> void:
	var reach := r * minf(1.0, u * 3.0)
	var o := SimPlane.to_3d(at, NOVA_M)
	for k in STAR:
		var a := TAU * k / STAR + 0.2
		var tip := o + Vector3(cos(a), 0.3, sin(a)) * reach
		_strip(parts[k], o, tip, 0.35 * (1.0 - u) + 0.05, u)


## A flat strip from `a` to `b`, `w` wide, fading as `u` goes to 1.
func _strip(n: MeshInstance3D, a: Vector3, b: Vector3, w: float, u: float) -> void:
	var d := b - a
	if d.length() < 0.05:
		n.visible = false
		return
	n.visible = true
	var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var basis := Basis.looking_at(d.normalized(), up)
	n.transform = Transform3D(basis.scaled_local(Vector3(w, w * 0.4, d.length())), (a + b) * 0.5)
	var m := n.material_override as StandardMaterial3D
	m.albedo_color.a = 1.0 - u * u
