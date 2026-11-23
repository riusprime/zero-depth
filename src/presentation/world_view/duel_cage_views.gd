class_name DuelCageViews
extends Node3D
## The Warlord's Duel as the player sees it, drawn from WorldReader.boss_warlord "duel" (EI-07: where the cage stands,
## its fence's radius, the recall's zone and its warning are the sim's, BossDuel). No word anywhere.
## - The cast: the Warlord's javelins (WarlordLooks.javelin: the spear lines' faceted spear, matte steel lit like the
##   walls, one MultiMesh) rain in from above, one after another, onto the circle the cage will close on, each landing
##   in a puff of the pack's dust.
## - The cage: SHAFTS javelins planted on the fence's exact circle, leaning outward; as the fence closes they slide in
##   with it, the pack's dust (bx_smoke_dust) kicked up at one of them after another. A faint dull rust rim lies on
##   the floor under them (WarlordLooks.RING_SHADER), and no glow inside it: the recall's circle must stand out on a
##   plain floor. A touch of the fence sparks at the hero (wl_fence).
## - The recall: the centre's circle (the charge burst's own floor circle, WardenLooks, with the pack's rim
##   tw_burst_rim) fills from its middle as the warning runs and the shafts' heads heat; then every shaft flies inward
##   through the centre and the pack's impact (wl_recall) bursts there.
## The Warlord's lowered shield is WarlordAvatar's. Reduced motion stills the pulses. Nothing here decides.

const SHAFTS := 28
const FENCE_ID := &"wl_fence"
const RECALL_ID := &"wl_recall"
const ZONE_RIM_ID := &"tw_burst_rim"
const DUST_ID := &"bx_smoke_dust"
const FENCE_EVENT := &"warlord_fence_touch"
const RECALL_EVENT := &"warlord_recall"
## The stages (BossDuel.CAST, CAGE, RECALL).
const CAST := 1
const CAGE := 2
const RECALL := 3
## The planted javelins: their size (the fan's javelin's), lean (radians below level from tail to head) and sink.
const SIZE := 1.25
const PITCH := 1.2
const SINK := 0.3
## The rain: each shaft falls FALL_SHARE of the cast from FALL_M up, the first starting at once, the last landing at
## LAST_LAND of the cast.
const FALL_SHARE := 0.22
const FALL_M := 9.0
const LAST_LAND := 0.92
## The rim (m wide) and its look.
const EDGE_M := 0.22
const EDGE_ALPHA := 0.6
const FILL_ALPHA := 0.0
## A dust puff at the next shaft this often while the fence closes (s), its size.
const DUST_EVERY := 0.3
const DUST_SCALE := 0.45
const FENCE_SCALE := 0.7
const ZONE_RIM_PER_M := 0.55
const RECALL_SCALE := 1.2
## The recall's flight (s): each shaft from the fence through the centre and out past it by THROUGH of the radius.
const RECALL_S := 0.32
const THROUGH := 0.6
## The zone's circle flashes like a lock in its last share of the warning.
const LOCK_AT := 0.7

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
var _duel := {}
var _hero := Vector3.ZERO
var _last_seq := 0
var _primed := false
var _clock := 0.0
var _dust_in := 0.0
var _dust_k := 0
var _landed := {}
var _sparks := 0
## The recall's flight after the cage is gone: [seconds since, centre (3D), radius].
var _recall: Array = []
var _mm := MultiMeshInstance3D.new()
var _mat := ShaderMaterial.new()
var _rim: MeshInstance3D
var _zone: MeshInstance3D
## Each shaft's head on the floor as last drawn (sim), and how many show.
var _heads: Array[Vector2] = []
var _shown := 0


func _init() -> void:
	name = "DuelCageViews"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = WarlordLooks.javelin()
	mm.instance_count = SHAFTS
	mm.visible_instance_count = 0
	_mm.multimesh = mm
	var sh := Shader.new()
	sh.code = WarlordLooks.JAVELIN_SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("steel", WarlordLooks.JAVELIN_STEEL)
	_mat.set_shader_parameter("hot", WarlordLooks.JAVELIN_HOT)
	BossSignatureViews.dress_javelin(_mat)
	_mm.material_override = _mat
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mm.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_mm.extra_cull_margin = 16384.0
	_mm.set_meta(ShaderWarmup.WARM_META, true)
	add_child(_mm)
	_rim = WarlordLooks.ring(self, WarlordLooks.CAGE_RIM)
	_zone = WardenLooks.floor_mesh(self, true, WardenLooks.DANGER)
	_heads.resize(SHAFTS)


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	var was := _duel
	_duel = reader.boss_warlord().get("duel", {})
	_hero = SimPlane.to_3d(reader.player_pos())
	if _duel.is_empty() or int(_duel["stage"]) != CAST:
		_landed.clear()
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # joining a fight under way replays nothing that already happened
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.STATUS_APPLY:
			continue
		if e.effect_id == FENCE_EVENT:
			_sparks += 1
			_spawn(FENCE_ID, &"hit", _hero + Vector3(0, 0.8, 0), FENCE_SCALE)
		elif e.effect_id == RECALL_EVENT and not was.is_empty():
			_recall = [0.0, SimPlane.to_3d(e.pos), float(was["radius"])]


func _spawn(id: StringName, family: StringName, at: Vector3, scale: float, colors := {}) -> void:
	if pack_fx != null and pack_fx.has_id(id) and pack_fx.has_room(family):
		pack_fx.spawn(id, at, scale, colors)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	if _duel.is_empty() and _recall.is_empty() and hold.count() == 0:
		if quiet:
			return
		quiet = true
		_hide()
		return
	quiet = false
	_clock += delta * (0.0 if ViewPrefs.reduced_motion else 1.0)
	hold.begin()
	if not _duel.is_empty():
		_recall = []
		_draw_duel(delta)
	elif not _recall.is_empty():
		_draw_recall(delta)
	else:
		_hide()
	hold.end()


func _hide() -> void:
	_mm.multimesh.visible_instance_count = 0
	_shown = 0
	_rim.visible = false
	_zone.visible = false


## Shaft k's angle round the circle (a fixed set, so they keep their places as the fence closes).
static func angle_of(k: int) -> float:
	return TAU * float(k) / float(SHAFTS)


## When shaft k lands, as a share of the cast (spread round the ring, not in order).
static func lands_at(k: int) -> float:
	var order := fposmod(float(k) * 0.618034, 1.0)
	return FALL_SHARE + (LAST_LAND - FALL_SHARE) * order


func _draw_duel(delta: float) -> void:
	var stage := int(_duel["stage"])
	var c2: Vector2 = _duel["centre"]
	var c := SimPlane.to_3d(c2)
	var radius := float(_duel["radius"])
	var cast := float(_duel["cast"]) / 1000.0 if stage == CAST else 1.0
	var zone: Dictionary = _duel.get("zone", {})
	var warn := float(zone.get("warn", 0)) / 1000.0 if not zone.is_empty() else 0.0
	var mm := _mm.multimesh
	var n := 0
	var buf := PackedFloat32Array()
	buf.resize(SHAFTS * 16)
	for k in SHAFTS:
		var a := angle_of(k)
		var head2 := c2 + Vector2(cos(a), sin(a)) * radius
		var head := SimPlane.to_3d(head2)
		var lift := 0.0
		if stage == CAST:
			var u := (cast - (lands_at(k) - FALL_SHARE)) / FALL_SHARE
			if u <= 0.0:
				continue
			lift = FALL_M * (1.0 - clampf(u, 0.0, 1.0)) * (1.0 - clampf(u, 0.0, 1.0))
			if u >= 1.0 and not _landed.has(k):
				_landed[k] = true
				if k % 3 == 0:
					_spawn(DUST_ID, &"cloud", head, DUST_SCALE, WarlordLooks.DUST)
		var xf := WarlordLooks.planted(head + Vector3(0, lift, 0), c, PITCH, SIZE, SINK)
		_heads[n] = head2
		_put(buf, n, xf, 0.15 + 0.85 * warn)
		n += 1
	mm.buffer = buf
	mm.visible_instance_count = n
	_shown = n
	_rim.visible = stage != CAST or cast > LAST_LAND
	_rim.position = c + Vector3(0, 0.04, 0)
	_rim.scale = Vector3.ONE * radius
	WarlordLooks.param(_rim, &"edge", EDGE_M / maxf(radius, 0.1))
	WarlordLooks.param(_rim, &"edge_alpha", EDGE_ALPHA)
	WarlordLooks.param(_rim, &"fill_alpha", FILL_ALPHA)
	WarlordLooks.param(_rim, &"pulse", 1.0)
	WarlordLooks.param(_rim, &"clock", _clock)
	if stage == CAGE and float(_duel["from_radius"]) > float(_duel["to_radius"]):
		_dust_in -= delta
		if _dust_in <= 0.0:
			_dust_in = DUST_EVERY
			_dust_k = (_dust_k + 11) % SHAFTS
			var a := angle_of(_dust_k)
			_spawn(
				DUST_ID,
				&"cloud",
				SimPlane.to_3d(c2 + Vector2(cos(a), sin(a)) * radius),
				DUST_SCALE,
				WarlordLooks.DUST
			)
	_draw_zone(zone, warn)


func _draw_zone(zone: Dictionary, warn: float) -> void:
	_zone.visible = not zone.is_empty()
	if zone.is_empty():
		return
	var at := SimPlane.to_3d(zone["centre"], 0.06)
	var r := float(zone["radius"])
	var locked := warn >= LOCK_AT
	_zone.position = at
	_zone.scale = Vector3.ONE * r
	WardenLooks.param(_zone, &"locked", 1.0 if locked else 0.0)
	WardenLooks.param(_zone, &"flash", 0.0)
	WardenLooks.param(_zone, &"fill", warn)
	WardenLooks.param(_zone, &"alpha", 1.0 if locked else 0.75)
	WardenLooks.param(_zone, &"clock", _clock)
	hold.put(&"zone", ZONE_RIM_ID, &"area", WarlordLooks.at(at, r * ZONE_RIM_PER_M))


func _draw_recall(delta: float) -> void:
	var t := float(_recall[0]) + delta
	_recall[0] = t
	var c: Vector3 = _recall[1]
	var radius := float(_recall[2])
	_rim.visible = false
	_zone.visible = false
	var u := clampf(t / RECALL_S, 0.0, 1.0)
	if u >= 1.0:
		_spawn(RECALL_ID, &"impact", c + Vector3(0, 0.2, 0), RECALL_SCALE)
		_recall = []
		_mm.multimesh.visible_instance_count = 0
		_shown = 0
		return
	var buf := PackedFloat32Array()
	buf.resize(SHAFTS * 16)
	var span := radius * (1.0 + THROUGH)
	for k in SHAFTS:
		var a := angle_of(k)
		var from := c + Vector3(cos(a), 0.0, -sin(a)) * radius
		var inward := (c - from).normalized()
		var at := from + inward * span * u * u + Vector3(0, 1.0, 0)
		var b := (
			Basis(Vector3.UP, atan2(-inward.z, inward.x)) * Basis.from_scale(Vector3.ONE * SIZE)
		)
		var length := BossSignatureViews.JAVELIN_LENGTH * SIZE
		_put(buf, k, Transform3D(b, at - inward * length * 0.5), 1.0)
		_heads[k] = SimPlane.to_sim(at)
	_mm.multimesh.buffer = buf
	_mm.multimesh.visible_instance_count = SHAFTS
	_shown = SHAFTS


static func _put(buf: PackedFloat32Array, k: int, xf: Transform3D, glow: float) -> void:
	var b := xf.basis
	var o := xf.origin
	var row := [
		b.x.x,
		b.y.x,
		b.z.x,
		o.x,
		b.x.y,
		b.y.y,
		b.z.y,
		o.y,
		b.x.z,
		b.y.z,
		b.z.z,
		o.z,
		glow,
		0.0,
		0.0,
		0.0
	]
	for j in 16:
		buf[k * 16 + j] = row[j]


# --- tests and the shot scripts ----------------------------------------------------------------------------------


## The javelins drawn now.
func shafts_shown() -> int:
	return _shown


## Where shaft slot k's head was drawn last (sim; on the floor during the cage).
func shaft_head(k: int) -> Vector2:
	return _heads[k]


## The danger rim drawn now: [centre (sim), radius], or [] none.
func rim_circle() -> Array:
	if not _rim.visible:
		return []
	return [SimPlane.to_sim(_rim.position), _rim.scale.x]


## The recall's circle now: [centre (sim), radius, fill 0..1], or [] none.
func zone_circle() -> Array:
	if not _zone.visible:
		return []
	var fill := float((_zone.material_override as ShaderMaterial).get_shader_parameter("fill"))
	return [SimPlane.to_sim(_zone.position), _zone.scale.x, fill]


## The recall's flight is drawn now.
func recalling() -> bool:
	return not _recall.is_empty()


## Fence touches sparked.
func sparks() -> int:
	return _sparks
