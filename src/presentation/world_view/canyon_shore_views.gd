class_name CanyonShoreViews
extends Node3D
## v0.11.0 O13c (ENEMIES.md R5-R8): what the Red Canyon's and the Frozen Shore's signature enemies leave on the floor,
## read through WorldReader (EI-07), in the premade packs' effects (PD-13):
## - a Kiln Beetle's burst waiting: the pack's enemy fire patch growing over its fuse (VfxLayer.field &"fire", hostile:
##   zone_fire_foe_a/b) inside the pack's fire ring at its full radius (VfxLayer.ring &"fire": ring_fire); its blow is
##   the pack's explosion (explosion_fire_a, vfx_explosion_01) at its size;
## - a lava vent: a low basalt cone (the Hazard Lockdown's vent stand-in, smaller) over the pack's enemy fire patch,
##   dim at rest and brightening through its pulse, with the pack's fire ring closing in (the pulse the priest's staff
##   keeps time with); its eruption is the pack's light pillar in fire colours (bx_pillar_light, pillar_area_vfx_01)
##   with a small explosion at its foot (explosion_fire_b, vfx_explosion_03);
## - a Frost Spitter's throw: the blue arc from the spitter to the landing (VfxLayer.line &"frost", ice_area's frost
##   line, in short pieces along the lob) and the landing ring (VfxLayer.ring &"frost": ring_frost), through its windup
##   and the flight; the blob itself is the pack's frost orb (vx2_small_frost) riding the arc; its landing the pack's
##   frost burst (burst_frost). The slick it leaves is the Frost Charger's (VariantViews: zone_frost);
## - a Glacier Turtle's shell breaking: the pack's shatter (burst_shatter) at the turtle; each chunk an ice block (the
##   Hazard Lockdown's ice stand-in, small) on a frost patch (VfxLayer.field &"frost").
## Nothing here decides.

const VENT_MAT := Color("#3A2420")
const ICE_MAT := Color("#7FB8E0")
const BLAST_ID := &"explosion_fire_a"
## v0.11.0 F1 (owner: the small beetle's explosion was far too big): the pack blast's spawn scale (it was radius * 0.6,
## 1.5 for the 2.5 m burst). The true danger area is still the ground ring across the fuse, not this visual.
const BLAST_SCALE := 0.6
const ERUPT_FOOT_ID := &"explosion_fire_b"
const PILLAR_ID := &"bx_pillar_light"
const PILLAR_COLORS := {
	&"primary": Color(1.0, 0.62, 0.22),
	&"secondary": Color(1.0, 0.32, 0.08),
	&"tertiary": Color(0.45, 0.08, 0.02)
}
const BLOB_ID := &"vx2_small_frost"
const LAND_ID := &"burst_frost"
const SHATTER_ID := &"burst_shatter"
## The arc's peak over its length, and its pieces.
const ARC_RISE := 0.35
const ARC_PIECES := 8
## Ticks a vent's eruption counts as just now (a frame may skip the very tick).
const ERUPT_NEW_TICKS := 3

## The effects layer (WorldViewRoot sets it; null: no patches) and the pack (null: no one-shots).
var vfx: VfxCore = null
var pack_fx: PackFx = null
var _tick := 0.0
var _bursts: Array = []
var _vents: Array = []
var _blobs: Array = []
var _arcs: Array = []
var _chunks: Array = []
var _cones: Array[MeshInstance3D] = []
var _ice: Array[MeshInstance3D] = []
var _seen_bursts := {}
var _seen_blobs := {}
var _orbs := {}
var _erupted := {}
var _shells := {}


func sync(reader: WorldReader) -> void:
	_tick = float(reader.tick())
	_sync_bursts(reader.kiln_bursts())
	_vents = reader.lava_vents()
	_sync_cones()
	_sync_eruptions()
	_sync_blobs(reader.ice_blobs())
	_chunks = reader.ice_chunks()
	_sync_ice()
	_arcs.clear()
	var spitters := reader.any_kind(WorldReader.KIND_FROST_SPITTER)
	var turtles := reader.any_kind(WorldReader.KIND_GLACIER_TURTLE)
	if spitters or turtles:
		for i in range(1, reader.actor_count()):
			var kind := reader.actor_kind(i)
			if kind == WorldReader.KIND_FROST_SPITTER:
				var tg := reader.telegraph(i)
				if tg.get("shape", &"") == &"ice_arc":
					_arcs.append(
						[tg["from"], tg["to"], tg["radius"], tg["progress"], reader.actor_id(i)]
					)
			elif kind == WorldReader.KIND_GLACIER_TURTLE:
				_sync_shell(reader, i)
	for id in _shells.keys():
		if reader.actor_index(id) < 0:
			_shells.erase(id)


## Counts drawn this frame (tests): bursts waiting, vents, arcs (windups and flights), chunks.
func counts() -> Dictionary:
	return {
		"bursts": _bursts.size(),
		"vents": _vents.size(),
		"arcs": _arcs.size() + _blobs.size(),
		"chunks": _chunks.size()
	}


## A VfxCore drawer: the bursts' fire, the vents' pulse, the arcs and rings, the chunks' frost.
func draw_fx(layer: VfxCore) -> void:
	var vl := layer as VfxLayer
	if vl == null:
		return
	for b: Array in _bursts:
		var c := SimPlane.to_3d(b[0], 0.0)
		var p := float(b[2]) / 1000.0
		vl.field(&"fire", c, float(b[1]) * lerpf(0.25, 1.0, p), 0.45 + 0.55 * p, _tick, b[3], true)
		vl.ring(&"fire", c, float(b[1]), 0.5 + 0.5 * p, _tick, b[3])
	for v: Array in _vents:
		var c := SimPlane.to_3d(v[0], 0.0)
		var pulse := float(v[2]) / 1000.0
		var sd: int = int(v[5]) * 16 + 7
		var rest := 0.3 if v[4] else 0.15
		vl.field(&"fire", c, float(v[1]), rest + 0.7 * pulse, _tick, sd, true)
		if pulse > 0.0:
			vl.ring(&"fire", c, float(v[1]) * lerpf(1.8, 1.0, pulse), pulse, _tick, sd)
	for a: Array in _arcs:
		_arc(vl, a[0], a[1], float(a[2]), 0.45 + 0.55 * float(a[3]) / 1000.0, int(a[4]))
	for b: Array in _blobs:
		_arc(vl, b[0], b[1], float(b[2]), 1.0, int(b[4]))
	for ch: Array in _chunks:
		vl.field(
			&"frost", SimPlane.to_3d(ch[0], 0.0), WorldReader.ICE_CHUNK_RADIUS_M, 0.7, _tick, ch[1]
		)


## The blue arc from `from` to `to` and its landing ring.
func _arc(vl: VfxLayer, from: Vector2, to: Vector2, r: float, fade: float, sd: int) -> void:
	var prev := arc_point(from, to, 0.0)
	for k in range(1, ARC_PIECES + 1):
		var q := arc_point(from, to, float(k) / ARC_PIECES)
		vl.line(&"frost", prev, q, fade, _tick, sd + k)
		prev = q
	vl.ring(&"frost", SimPlane.to_3d(to, 0.0), r, fade, _tick, sd)


## The point `u` (0..1) along the lob from `from` to `to` (3D, up to ARC_RISE of its length high at the middle).
static func arc_point(from: Vector2, to: Vector2, u: float) -> Vector3:
	var flat := from.lerp(to, u)
	var lift := 4.0 * u * (1.0 - u) * ARC_RISE * from.distance_to(to)
	return SimPlane.to_3d(flat, SimPlane.CORE_HEIGHT * (1.0 - u) + lift)


## PackFx.spawn leaves an animated scene's particles looping for the scene's whole length (the 0.5 s sparks run
## twice in its 1.2 s): the blast plays its particles once.
static func blast_once(node: Node3D) -> void:
	if node == null:
		return
	for c in node.get_children():
		if c is GPUParticles3D:
			(c as GPUParticles3D).one_shot = true
			(c as GPUParticles3D).restart()


func _sync_bursts(now: Array) -> void:
	var live := {}
	for b: Array in now:
		live[b[3]] = b
	for sd: int in _seen_bursts.keys():  # gone since the last frame: it blew
		if not live.has(sd):
			var was: Array = _seen_bursts[sd]
			if pack_fx != null:
				blast_once(pack_fx.spawn(BLAST_ID, SimPlane.to_3d(was[0], 0.0), BLAST_SCALE))
			_seen_bursts.erase(sd)
	for sd: int in live:
		_seen_bursts[sd] = live[sd]
	_bursts = now


func _sync_cones() -> void:
	while _cones.size() > _vents.size():
		_cones.pop_back().queue_free()
	while _cones.size() < _vents.size():
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.16
		c.bottom_radius = 0.5
		c.height = 0.32
		c.radial_segments = 7
		mi.mesh = c
		var m := StandardMaterial3D.new()
		m.albedo_color = VENT_MAT
		m.roughness = 0.85
		mi.material_override = m
		add_child(mi)
		_cones.append(mi)
	for k in _vents.size():
		_cones[k].position = SimPlane.to_3d(_vents[k][0], 0.16)


func _sync_eruptions() -> void:
	var seen := {}
	for v: Array in _vents:
		var id: int = v[5]
		seen[id] = true
		var since: int = v[3]
		if since < 0 or since > ERUPT_NEW_TICKS:
			continue
		var at_tick := int(_tick) - since
		if int(_erupted.get(id, -1)) == at_tick:
			continue
		_erupted[id] = at_tick
		if pack_fx != null:
			var c := SimPlane.to_3d(v[0], 0.0)
			pack_fx.spawn(PILLAR_ID, c, float(v[1]), PILLAR_COLORS)
			pack_fx.spawn(ERUPT_FOOT_ID, c, float(v[1]) * 0.5)
	for id in _erupted.keys():
		if not seen.has(id):
			_erupted.erase(id)


func _sync_blobs(now: Array) -> void:
	var live := {}
	for b: Array in now:
		live[b[4]] = b
	for sd: int in _seen_blobs.keys():  # landed since the last frame
		if not live.has(sd):
			var was: Array = _seen_blobs[sd]
			if pack_fx != null:
				pack_fx.spawn(LAND_ID, SimPlane.to_3d(was[1], 0.0), float(was[2]) * 0.8)
			var orb: Node3D = _orbs.get(sd)
			if orb != null and pack_fx != null:
				pack_fx.release(orb)
			_orbs.erase(sd)
			_seen_blobs.erase(sd)
	for sd: int in live:
		var b: Array = live[sd]
		_seen_blobs[sd] = b
		if pack_fx == null:
			continue
		var at := arc_point(b[0], b[1], float(b[3]) / 1000.0)
		var orb: Node3D = _orbs.get(sd)
		if orb == null or not pack_fx.is_live(orb):
			orb = pack_fx.spawn(BLOB_ID, at, 1.0, {}, 0.0)
			_orbs[sd] = orb
		if orb != null:
			orb.global_position = at
	_blobs = now


func _sync_ice() -> void:
	while _ice.size() > _chunks.size():
		_ice.pop_back().queue_free()
	while _ice.size() < _chunks.size():
		var mi := MeshInstance3D.new()
		var p := PrismMesh.new()
		p.size = Vector3(0.45, 0.4, 0.45)
		mi.mesh = p
		var m := StandardMaterial3D.new()
		m.albedo_color = ICE_MAT
		m.emission_enabled = true
		m.emission = ICE_MAT
		m.emission_energy_multiplier = 0.35
		mi.material_override = m
		add_child(mi)
		_ice.append(mi)
	for k in _chunks.size():
		_ice[k].position = SimPlane.to_3d(_chunks[k][0], 0.2)
		_ice[k].rotation.y = float(_chunks[k][1]) * 1.3


func _sync_shell(reader: WorldReader, i: int) -> void:
	var id := reader.actor_id(i)
	var on := reader.shell_on(i)
	if bool(_shells.get(id, on)) and not on and pack_fx != null:
		pack_fx.spawn(SHATTER_ID, SimPlane.to_3d(reader.actor_pos(i), 0.5), 1.0)
	_shells[id] = on
