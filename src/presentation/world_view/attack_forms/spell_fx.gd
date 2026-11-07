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
## v0.11.0 O11 (every spell its element's colour; nothing is a filled round ground mark, Meteor's mark is four chevrons
## closing in and a falling rock, never a boss's red disc), drawn with SpellShapes:
## - Blizzard: a hexagon outline and snow streaks falling slant inside it; Frost Nova's shatter: six ice shards out;
##   Ice Lances: a thin pale shard line;
## - Burning Ground (and Fireball's and Meteor's burning ground): an octagon outline of flame and flame tongues licking
##   up; Meteor: its chevrons and a rock falling, then a twelve-spike star and a column from the sky;
## - Ball Lightning: a pale-blue orb rolling, its zaps thin lines; Static Field: a dashed ring around you; a discharge:
##   ten spokes;
## - Venom Orb: the green ball in flight, then bubbles and a jagged outline; Toxic Cloud: green puffs; Spitter Vine: a
##   green stalk with a head, its spits green lines;
## - Blood Thorns: crimson spikes rising in the ring; Hemorrhage: a turning crimson diamond over its mark, a burst;
##   Leech: a crimson triangle over you and drain lines from the enemies.

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
## v0.11.0 O11: Blood Thorns' eruptions (vfx_impact_02) without the white puff and the floor disc.
const THORN_HIDE := ["Core", "Ground_Impact"]

## Counted for tests: casts drawn by kind; v0.11.0 O11: the spells seen drawn (a cast or a lasting look).
var seen := {}
var drawn := {}
## v0.11.0 O11 (owner PD-13, 2026-11-07: every new effect from the premade packs): with the effects layer (the game),
## the twelve spells and the new Lv 5 extras draw as pack effects in draw_fx (a hero drawer), and the strips below are
## not drawn; without it (a bare view in tests) the strips stand in.
var vfx_on := false
## Live casts: [kind, at, to, start tick, radius m, spell, serial].
var _live: Array = []
## The strips and orbs that stand in without the effects layer.
var _shapes := SpellShapes.new()
var _hold := PackHold.new()
var _once := {}
var _serial := 0
var _tick := 0
var _zones := {}
var _ball_at := PackedVector2Array()
var _ball_spell := PackedInt32Array()
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
	add_child(_shapes)
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
	var ball_spell: PackedInt32Array = fx["ball_spell"]
	for k in BALLS:
		var on := k < balls.size()
		_balls[k].visible = on
		_cores[k].visible = on
		if on:
			var p := SimPlane.to_3d(balls[k], BALL_M)
			_balls[k].position = p
			_cores[k].position = p
			var venom := k < ball_spell.size() and ball_spell[k] == WorldReader.SPELL_VENOM_ORB
			if venom and vfx_on:  # O11: the Venom Orb flies as the pack's orb (draw_fx)
				_balls[k].visible = false
				_cores[k].visible = false
			var el := WorldReader.SPELL_ELEMENT_VENOM if venom else WorldReader.SPELL_ELEMENT_FIRE
			(_balls[k].material_override as StandardMaterial3D).albedo_color = SpellLooks.color(el)
			if k < ball_spell.size():
				seen[ball_spell[k]] = true
	_tick = tick
	_zones = reader.spell_zones()
	_ball_at = balls
	_ball_spell = ball_spell
	_shapes.begin()
	if not vfx_on:
		_draw_new(tick)
		_draw_zones(_zones, tick)
	else:
		for s: int in _zones["spell"]:
			seen[s] = true
		for e: Array in _live:
			if int(e[5]) >= 0:
				seen[int(e[5])] = true
	_shapes.finish()


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
		var sp: PackedInt32Array = fx.get("spell", PackedInt32Array())
		var spell := sp[k] if k < sp.size() else -1
		_serial += 1
		_live.append(
			[kinds[k], fx["from"][k], fx["to"][k], t, float(fx["size"][k]), spell, _serial]
		)
		if spell >= 0:
			seen[spell] = true
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
		WorldReader.SPELL_FX_LANCE, WorldReader.SPELL_FX_SHATTER, WorldReader.SPELL_FX_DISCHARGE:
			return 14.0
		WorldReader.SPELL_FX_THORNS, WorldReader.SPELL_FX_HEMO:
			return 20.0
		WorldReader.SPELL_FX_STRIKE:
			return 26.0
		WorldReader.SPELL_FX_DRAIN:
			return 10.0
		WorldReader.SPELL_FX_SPIT, WorldReader.SPELL_FX_ZAP:
			return 7.0
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
			WorldReader.SPELL_FX_JUMP:
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


# --- v0.11.0 O11: the rest of the roster ---------------------------------------------------------------------------
static func _col(spell: int) -> Color:
	var el := WorldReader.SPELL_ELEMENT_FROST
	if spell >= WorldReader.SPELL_FIREBALL and spell <= WorldReader.SPELL_METEOR:
		el = WorldReader.SPELL_ELEMENT_FIRE
	elif spell >= WorldReader.SPELL_SKY_STRIKE and spell <= WorldReader.SPELL_STATIC_FIELD:
		el = WorldReader.SPELL_ELEMENT_LIGHTNING
	elif spell >= WorldReader.SPELL_VENOM_ORB and spell <= WorldReader.SPELL_SPITTER_VINE:
		el = WorldReader.SPELL_ELEMENT_VENOM
	elif spell >= WorldReader.SPELL_BLOOD_THORNS:
		el = WorldReader.SPELL_ELEMENT_BLEED
	return SpellLooks.color(el)


## The new casts (the O10 kinds draw above).
func _draw_new(tick: int) -> void:
	var s := _shapes
	for e: Array in _live:
		var kind := int(e[0])
		if kind <= WorldReader.SPELL_FX_JUMP:
			continue
		var u := clampf(float(tick - int(e[3])) / _life(kind), 0.0, 1.0)
		var fade := 1.0 - u * u
		var c := _col(int(e[5]))
		var at := SimPlane.to_3d(e[1], NOVA_M)
		var r := float(e[4])
		match kind:
			WorldReader.SPELL_FX_LANCE:
				var a := SimPlane.to_3d(e[1], CHEST_M)
				var b := SimPlane.to_3d(e[2], CHEST_M)
				s.strip(a, b, 0.1, c, fade)
				s.strip(b - (b - a).normalized() * 0.6, b, 0.22, Color.WHITE, fade)
			WorldReader.SPELL_FX_SHATTER:
				s.spokes(SimPlane.to_3d(e[1], CHEST_M), 0.4 + u * 1.2, 6, 0.12, c, fade, 0.3, u)
			WorldReader.SPELL_FX_THORNS:
				_thorns(SimPlane.to_3d(e[1], 0.05), r * 0.5, r, 1.0 - u, c, fade)
			WorldReader.SPELL_FX_SPIT:
				s.strip(SimPlane.to_3d(e[1], 1.3), SimPlane.to_3d(e[2], CHEST_M), 0.12, c, fade)
			WorldReader.SPELL_FX_ZAP:
				s.strip(SimPlane.to_3d(e[1], 1.0), SimPlane.to_3d(e[2], CHEST_M), 0.07, c, fade)
			WorldReader.SPELL_FX_STRIKE:
				s.strip(
					SimPlane.to_3d(e[1], SKY_M), at, 0.6 * (1.0 - u) + 0.1, Color("#FFE6B0"), fade
				)
				s.spokes(at, r * minf(1.0, u * 3.0), 12, 0.3 * (1.0 - u) + 0.06, c, fade, 0.2, 0.1)
			WorldReader.SPELL_FX_DISCHARGE:
				s.spokes(at, r * minf(1.0, u * 3.0), 10, 0.12, c, fade, 0.0, 0.3)
			WorldReader.SPELL_FX_HEMO:
				s.spokes(SimPlane.to_3d(e[1], CHEST_M), 0.5 + u * r * 0.6, 8, 0.14, c, fade, 0.6)
			WorldReader.SPELL_FX_DRAIN:
				s.strip(SimPlane.to_3d(e[1], CHEST_M), SimPlane.to_3d(e[2], CHEST_M), 0.06, c, fade)


## Spikes standing in a ring from `inner` to `outer`, `h` tall (0..1).
func _thorns(o: Vector3, inner: float, outer: float, h: float, c: Color, alpha: float) -> void:
	for k in 18:
		var a := TAU * k / 18.0 + (0.17 if k % 2 == 0 else 0.0)
		var d := Vector3(cos(a), 0, sin(a))
		var at := inner + (outer - inner) * (0.25 + 0.5 * float(k % 3) / 2.0)
		var base := o + d * at
		_shapes.strip(base, base + d * 0.25 + Vector3.UP * (0.4 + 0.7 * h), 0.16, c, alpha)


## The lasting spells (WorldReader.spell_zones), each frame.
func _draw_zones(z: Dictionary, tick: int) -> void:
	var kinds: PackedInt32Array = z["kind"]
	var s := _shapes
	for k in kinds.size():
		var spell := int(z["spell"][k])
		seen[spell] = true
		var c := _col(spell)
		var r := float(z["r"][k])
		var left := float(z["left"][k]) / 1000.0
		var fade := clampf(left * 4.0, 0.0, 1.0)
		var g := SimPlane.to_3d(z["pos"][k], 0.08)
		var f := float(tick)
		match kinds[k]:
			WorldReader.SPELL_ZONE_BLIZZARD:
				s.polygon(g, r, 6, 0.12, c, 0.8 * fade, 0.0)
				for n in 12:
					var a := TAU * n / 12.0 + f * 0.015
					var d := r * (0.25 + 0.65 * fmod(n * 0.37, 1.0))
					var h := 3.0 - fmod(f * 0.06 + n * 0.41, 3.0)
					var p := g + Vector3(cos(a) * d, h, sin(a) * d)
					s.strip(p, p + Vector3(0.25, -0.6, 0.1), 0.07, c, 0.9 * fade)
			WorldReader.SPELL_ZONE_FIRE:
				s.polygon(g, r, 8, 0.12, c, 0.75 * fade, 0.2)
				for n in 10:
					var a := TAU * n / 10.0 + 0.3
					var d := r * (0.72 if n % 2 == 0 else 0.36)
					var p := g + Vector3(cos(a) * d, 0, sin(a) * d)
					var h := 0.45 + 0.3 * absf(sin(f * 0.21 + n * 1.7))
					s.strip(p, p + Vector3(0, h, 0), 0.16, c, 0.85 * fade)
			WorldReader.SPELL_ZONE_METEOR_MARK:
				var close := r * (0.55 + 0.45 * left)
				for n in 4:
					var a := TAU * n / 4.0 + PI / 4.0
					var d := Vector3(cos(a), 0, sin(a))
					var side := Vector3(-d.z, 0, d.x)
					var tip := g + d * close
					s.strip(tip, tip + (d + side) * 0.7, 0.14, c, 0.95)
					s.strip(tip, tip + (d - side) * 0.7, 0.14, c, 0.95)
				s.orb(g + Vector3(0, 0.6 + 11.0 * left, 0), 0.55, Color("#FFE6B0"), 1.0)
			WorldReader.SPELL_ZONE_ORB:
				var o := g + Vector3(0, 1.0, 0)
				s.orb(o, 0.36, c, 0.95)
				s.spokes(o, 0.55, 3, 0.05, Color.WHITE, 0.8, 0.0, f * 0.4)
			WorldReader.SPELL_ZONE_STATIC:
				for n in 14:
					var a := TAU * n / 14.0 + f * 0.05
					var p := g + Vector3(cos(a) * r, 0.3, sin(a) * r)
					var t := Vector3(-sin(a), 0, cos(a)) * 0.4
					s.strip(p - t, p + t, 0.09, c, (1.0 if (tick + n) % 3 == 0 else 0.6) * fade)
			WorldReader.SPELL_ZONE_POOL:
				s.polygon(g, r, 7, 0.1, c, 0.7 * fade, 0.4)
				for n in 6:
					var a := TAU * n / 6.0 + 0.5
					var d := r * (0.25 + 0.4 * fmod(n * 0.53, 1.0))
					var bob := 0.12 + 0.1 * absf(sin(f * 0.1 + n))
					s.orb(
						g + Vector3(cos(a) * d, bob, sin(a) * d),
						0.12 + 0.04 * (n % 3),
						c,
						0.8 * fade
					)
			WorldReader.SPELL_ZONE_PUFF:
				s.orb(g + Vector3(0, 0.6, 0), r * 0.9, c, 0.28 * fade)
			WorldReader.SPELL_ZONE_VINE:
				var top := g + Vector3(0, 1.3, 0)
				s.strip(g, top, 0.16, c, 0.95)
				s.orb(top, 0.24, c, 0.95)
				if int(z["level"][k]) >= 3:
					s.strip(g, g + Vector3(0.35, 1.1, 0), 0.12, c, 0.95)
					s.orb(g + Vector3(0.35, 1.1, 0), 0.2, c, 0.95)
			WorldReader.SPELL_ZONE_THORN_WALL:
				_thorns(g, r * 0.5, r, 0.6, c, fade)
			WorldReader.SPELL_ZONE_HEMO:
				var top := g + Vector3(0, 2.3, 0)
				var a := f * 0.08
				var x := Vector3(cos(a), 0, sin(a)) * 0.35
				var y := Vector3(0, 0.5, 0)
				s.strip(top + y, top + x, 0.08, c, 1.0)
				s.strip(top + x, top - y, 0.08, c, 1.0)
				s.strip(top - y, top - x, 0.08, c, 1.0)
				s.strip(top - x, top + y, 0.08, c, 1.0)
			WorldReader.SPELL_ZONE_LEECH:
				var over := g + Vector3(0, 2.4, 0)
				s.polygon(over, 0.45, 3, 0.08, c, 0.9 * fade, f * 0.05)


# --- v0.11.0 O11: the pack looks (owner PD-13) -------------------------------------------------------------------
## The effects layer's hero drawer (AttackFormView hands it in): each new cast and each lasting spell as a pack effect,
## through the layer's own pack-backed looks (field, ring, line, burst) or a held pack effect (PackHold):
## - Blizzard: the frost field (ice_area, ice_mist); Frost Nova's Lv 5 shatter: the shatter burst (ice_area_vfx_01);
## - Ice Lances: a frost javelin (mprojectile_javelin_vfx_01) to each end, the frost impact where it lands;
## - Burning Ground, Fireball's and Meteor's burning ground: the fire field (fire_area_01 / 02);
## - Meteor: the Starfall rock (fire_ball_03) falling over a fire rim (rim_area_vfx_04) that closes in; the strike:
##   the fire explosion and the meteor's landing (vfx_impact_01);
## - Ball Lightning: the storm orb (magic_orb_big_vfx_02), its zaps the layer's lightning (vfx_zd bolt), its end the
##   storm burst (pulse_area_vfx_02); Static Field: the storm ring (rim_area_vfx_02 and its sparks), the discharge: the
##   storm burst;
## - Venom Orb: the venom orb (magic_orb_big_vfx_05) in flight, the venom field (poison_puddle) where it lands;
##   Toxic Cloud: a poison cloud (poison_cloud_vfx_01) a puff; Spitter Vine: a poison bubble (poison_bubble_vfx_01)
##   where it grew, its spits venom orbs (magic_orb_small_vfx_05) and the venom hit;
## - Blood Thorns: eruptions (vfx_impact_02, bleed-coloured) round the ring, again each wall pulse; Hemorrhage: the
##   bleed drips (vfx_zd drips) over its mark, the bleed burst (poison_bubble_vfx_03, bleed); Leech: blood orbs
##   (magic_orb_small_vfx_04, bleed) flying from each drained enemy to you.
func draw_fx(layer: VfxLayer) -> void:
	if layer.pack_fx == null:
		return
	_hold.fx = layer.pack_fx
	_hold.begin()
	_pack_casts(layer)
	_pack_zones(layer)
	for k in _ball_at.size():
		if k < _ball_spell.size() and _ball_spell[k] == WorldReader.SPELL_VENOM_ORB:
			_hold.touch(
				900000 + k,
				&"vx2_big_venom",
				&"projectile",
				SimPlane.to_3d(_ball_at[k], BALL_M),
				0.8
			)
	_hold.end()
	if _once.size() > 512:
		_once.clear()


func _pack_casts(layer: VfxLayer) -> void:
	var fx := layer.pack_fx
	var bleed := VfxPackViews.kind_colors(&"bleed", false)
	for e: Array in _live:
		var kind := int(e[0])
		if kind <= WorldReader.SPELL_FX_JUMP:
			continue
		var u := clampf(float(_tick - int(e[3])) / _life(kind), 0.0, 1.0)
		var fade := 1.0 - u * u
		var sd := int(e[6])
		var c := SimPlane.to_3d(e[1], 0.0)
		var r := float(e[4])
		match kind:
			WorldReader.SPELL_FX_LANCE:
				_fly(fx, sd, &"vx2_jav_frost", e, CHEST_M, u, &"vx1_impact_frost", {})
			WorldReader.SPELL_FX_SHATTER:
				layer.burst(&"shatter", c, 1.2, u, sd)
			WorldReader.SPELL_FX_THORNS:
				_erupt(fx, sd, c, r, bleed)
			WorldReader.SPELL_FX_SPIT:
				_fly(fx, sd, &"vx2_small_venom", e, CHEST_M, u, &"vx1_hit_venom", {})
			WorldReader.SPELL_FX_ZAP:
				var a := SimPlane.to_3d(e[1], 1.0)
				layer.line(&"storm", a, SimPlane.to_3d(e[2], CHEST_M), fade, float(_tick), sd)
			WorldReader.SPELL_FX_STRIKE:
				layer.burst(&"fire", c, r, u, sd)
				if not _once.has(sd):
					_once[sd] = true
					fx.spawn(&"p10l_meteor_land", c, r * 0.5)
			WorldReader.SPELL_FX_DISCHARGE:
				layer.burst(&"storm", c, r, u, sd)
			WorldReader.SPELL_FX_HEMO:
				layer.burst(&"bleed", c, r, u, sd)
			WorldReader.SPELL_FX_DRAIN:
				_fly(fx, sd, &"vx2_small_bleed", e, CHEST_M, u, &"", bleed)


## A held pack projectile from the entry's start to its end over its life, the `hit` effect where it lands (once).
func _fly(
	fx: PackFx,
	sd: int,
	id: StringName,
	e: Array,
	height: float,
	u: float,
	hit: StringName,
	cols: Dictionary
) -> void:
	var a := SimPlane.to_3d(e[1], height)
	var b := SimPlane.to_3d(e[2], height)
	var t := minf(1.0, u * 1.6)
	if t >= 1.0:
		if hit != &"" and not _once.has(sd):
			_once[sd] = true
			fx.spawn(hit, b, 1.0)
		return
	var n := _hold.touch(sd, id, &"projectile", a.lerp(b, t), 0.7, cols)
	if n != null and a.distance_to(b) > 0.1 and n.is_inside_tree():
		n.look_at(b, Vector3.UP)


## Blood Thorns: eruptions round the ring from its inner edge to `r` (once per key).
func _erupt(fx: PackFx, key: int, c: Vector3, r: float, cols: Dictionary) -> void:
	if _once.has(key):
		return
	_once[key] = true
	for k in 10:
		var a := TAU * k / 10.0 + (0.2 if k % 2 == 0 else 0.0)
		var d := r * (0.62 if k % 2 == 0 else 0.86)
		var at := c + Vector3(cos(a) * d, 0.0, sin(a) * d)
		fx.spawn(&"vx8_erupt", at, 0.8, cols, -1.0, 1.0, THORN_HIDE)


func _pack_zones(layer: VfxLayer) -> void:
	if _zones.is_empty():
		return
	var fx := layer.pack_fx
	var kinds: PackedInt32Array = _zones["kind"]
	var age := float(_tick)
	var bleed := VfxPackViews.kind_colors(&"bleed", false)
	for k in kinds.size():
		var sd := int(_zones["root"][k])
		var c := SimPlane.to_3d(_zones["pos"][k], 0.0)
		var r := float(_zones["r"][k])
		var left := float(_zones["left"][k]) / 1000.0
		var fade := clampf(left * 4.0, 0.0, 1.0)
		match kinds[k]:
			WorldReader.SPELL_ZONE_BLIZZARD:
				layer.field(&"frost", c, r, fade, age, sd)
			WorldReader.SPELL_ZONE_FIRE:
				layer.field(&"fire", c, r, fade, age, sd)
			WorldReader.SPELL_ZONE_METEOR_MARK:
				layer.ring(&"fire", c, r * (0.55 + 0.45 * left), 1.0, age, sd)
				_hold.touch(
					sd * 4 + 1,
					&"p10l_meteor_head",
					&"projectile",
					c + Vector3.UP * (0.6 + 11.0 * left),
					1.2
				)
			WorldReader.SPELL_ZONE_ORB:
				_hold.touch(sd * 4, &"vx2_big_storm", &"projectile", c + Vector3.UP, 0.8)
			WorldReader.SPELL_ZONE_STATIC:
				layer.ring(&"storm", c, r, fade, age, sd)
			WorldReader.SPELL_ZONE_POOL:
				layer.field(&"venom", c, r, fade, age, sd)
			WorldReader.SPELL_ZONE_PUFF:
				_hold.touch(sd * 4, &"fumes_cloud", &"cloud", c, r * 0.5)
			WorldReader.SPELL_ZONE_VINE:
				_hold.touch(sd * 4, &"status_poison_bubble", &"status", c + Vector3.UP * 0.4, 1.6)
				if int(_zones["level"][k]) >= 3:
					var p := c + Vector3(0.45, 0.3, 0.0)
					_hold.touch(sd * 4 + 1, &"status_poison_bubble", &"status", p, 1.2)
			WorldReader.SPELL_ZONE_THORN_WALL:
				_erupt(fx, sd * 64 + int(age) / 30, c, r, bleed)
			WorldReader.SPELL_ZONE_HEMO:
				_hold.touch(sd * 4, &"vx7_bleed_drips", &"status", c + Vector3.UP * 1.6, 1.0, bleed)
