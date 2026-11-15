class_name LensLatticeViews
extends Node3D
## The Hive Lens's Lattice and its burnt glass as the player sees them, drawn from WorldReader.boss_lens (EI-07: when
## the web rises, where each strand runs, which drone's death opens a gap and where the glass lies are the sim's,
## BossLattice and BossGlass). No word anywhere (the owner: the player discovers it from glows and motion).
## - The cast: the Lens gathers light (the pack's big orb, hl_charge, growing through the cast) and each of its drones
##   brightens (hl_glow) as the cast fills.
## - The web: each strand is the pack's beam in the Lens's pink (hl_strand) on the reader's exact pair of points, as
##   wide as the sim's strand (its half width); a strand the reader no longer lists (its drone died) is gone the same
##   frame, so the gap is open at once. Each drone of the web trails a faint ember as it orbits (hl_orbit, a world-space
##   trail). A strand that hurts the hero sparks on the hero (hl_spark).
## - The burnt glass: each strip is laid on its exact rectangle (its ends and half width) as dark glass with hot rose
##   cracks and edge, cooling as its time runs but glowing until it goes; a thin smoke rises as it is laid (hl_sizzle).
## A strand the pack has no room for is drawn as a plain glowing rod. Reduced motion: nothing here pulses or flickers
## (the glass holds its shimmer still). Nothing here decides.

const STRAND_ID := &"hl_strand"
const CHARGE_ID := &"hl_charge"
const GLOW_ID := &"hl_glow"
const ORBIT_ID := &"hl_orbit"
const SPARK_ID := &"hl_spark"
const SIZZLE_ID := &"hl_sizzle"
const HIT_EVENT := &"lattice_strand_hit"
const LAID_EVENT := &"lens_glass_laid"
## The most strips the sim lays at once (BossLensTable.strip_max) is far under this.
const GLASS_MAX := 6
## How far the glass cools over its life (its heat goes from 1 to 1 - COOL).
const COOL := 0.65
const GLASS_Y := 0.035
const CHARGE_FROM := 0.5
const CHARGE_TO := 1.4
const BRIGHT_FROM := 0.3
const BRIGHT_TO := 0.8
const ORBIT_SCALE := 0.6
const SPARK_SCALE := 0.8
const SIZZLE_SCALE := 0.8
const HERO_Y := 1.0

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := LensPackHold.new()
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
var _on := false
var _lens_at := Vector3.ZERO
var _casting := -1
var _strands: Array = []
var _half := 0.3
var _web: Array = []
var _feeders: Array = []
var _glass: Array = []
## What each strand was drawn as this frame: [from (3D), to (3D), radius, pack beam or rod].
var _drawn: Array = []
var _rods: Array[MeshInstance3D] = []
var _strips: Array[MeshInstance3D] = []
var _clock := 0.0
var _last_seq := 0
var _primed := false
var _hero := Vector3.ZERO


func _init() -> void:
	name = "LensLatticeViews"


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	var lens := reader.boss_lens()
	_on = not lens.is_empty()
	_strands = []
	_web = []
	_feeders = []
	_glass = []
	_casting = -1
	_hero = SimPlane.to_3d(reader.player_pos(), HERO_Y)
	if _on:
		_lens_at = SimPlane.to_3d(reader.actor_pos(int(lens["boss"])), LensLooks.LENS_Y)
		var lat: Dictionary = lens["lattice"]
		_casting = int(lat.get("casting", -1))
		_half = float(lat.get("half_width", _half))
		if bool(lat.get("running", false)):
			_strands = lat["strands"]
			_web = lat["drones"]
		_feeders = lens["drones"]
		_glass = lens["glass"]
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # joining a fight under way replays nothing that already happened
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.STATUS_APPLY or pack_fx == null:
			continue
		if e.effect_id == HIT_EVENT and pack_fx.has_id(SPARK_ID) and pack_fx.has_room(&"hit"):
			pack_fx.spawn(SPARK_ID, _hero, SPARK_SCALE, LensLooks.GLOW_COLORS)
		elif e.effect_id == LAID_EVENT and pack_fx.has_id(SIZZLE_ID) and pack_fx.has_room(&"cloud"):
			pack_fx.spawn(
				SIZZLE_ID, SimPlane.to_3d(e.pos, 0.2), SIZZLE_SCALE, LensLooks.SMOKE_COLORS
			)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	if not _on and hold.count() == 0 and _drawn.is_empty():
		if not quiet:
			for n: MeshInstance3D in _rods + _strips:
				n.visible = false
		quiet = true
		return
	quiet = false
	if not ViewPrefs.reduced_motion:
		_clock += delta
	hold.begin()
	_draw_cast()
	_draw_web()
	hold.end()
	_draw_glass()


func _draw_cast() -> void:
	if _casting < 0:
		return
	var share := float(_casting) / 1000.0
	hold.put(
		&"charge",
		CHARGE_ID,
		&"status",
		SiegeLooks.at(_lens_at, lerpf(CHARGE_FROM, CHARGE_TO, share)),
		LensLooks.GLOW_COLORS
	)
	for d: Dictionary in _feeders:
		hold.put(
			[&"bright", d["id"]],
			GLOW_ID,
			&"status",
			SiegeLooks.at(
				SimPlane.to_3d(d["position"], LensLooks.DRONE_Y),
				lerpf(BRIGHT_FROM, BRIGHT_TO, share)
			),
			LensLooks.GLOW_COLORS
		)


func _draw_web() -> void:
	_drawn = []
	var rod := 0
	for s: Dictionary in _strands:
		var a := SimPlane.to_3d(s["from"], LensLooks.STRAND_Y)
		var b := SimPlane.to_3d(s["to"], LensLooks.STRAND_Y)
		var key := [&"strand", s["a"], s["b"]]
		var n := hold.put(key, STRAND_ID, &"beam", Transform3D(Basis(), a), LensLooks.STRAND_COLORS)
		if n != null:
			LensLooks.place_beam(n, a, b, _half)
			_drawn.append([a, b, LensLooks.beam_radius(n), n])
			continue
		if rod >= _rods.size():
			_rods.append(LensLooks.rod(self, Color(LensLooks.LENS, 0.85)))
		_rods[rod].visible = true
		LensLooks.place_rod(_rods[rod], a, b, _half)
		_drawn.append([a, b, _half, _rods[rod]])
		rod += 1
	for k in range(rod, _rods.size()):
		_rods[k].visible = false
	for d: Dictionary in _web:
		hold.put(
			[&"orbit", d["id"]],
			ORBIT_ID,
			&"projectile",
			SiegeLooks.at(SimPlane.to_3d(d["position"], LensLooks.DRONE_Y - 0.3), ORBIT_SCALE),
			LensLooks.ORBIT_COLORS
		)


func _draw_glass() -> void:
	while _strips.size() < mini(_glass.size(), GLASS_MAX):
		_strips.append(LensLooks.glass_mesh(self))
	for k in _strips.size():
		var mi := _strips[k]
		mi.visible = k < _glass.size()
		if not mi.visible:
			continue
		var g: Dictionary = _glass[k]
		var a: Vector2 = g["from"]
		var b: Vector2 = g["to"]
		var hw := float(g["half_width"])
		LensLooks.lay_strip(mi, a, b, hw, GLASS_Y + 0.002 * k)
		var m := mi.material_override as ShaderMaterial
		m.set_shader_parameter("heat", heat_of(g))
		m.set_shader_parameter("size_m", Vector2(a.distance_to(b), hw * 2.0))
		m.set_shader_parameter("clock", _clock)
		m.set_shader_parameter("seed", fposmod(a.x * 0.37 + a.y * 0.61, 7.0))


## A strip's heat (1 just laid, 1 - COOL as it goes) from its progress through its life.
static func heat_of(g: Dictionary) -> float:
	return 1.0 - COOL * clampf(float(g["progress"]) / 1000.0, 0.0, 1.0)


# --- tests and the shot scripts ----------------------------------------------------------------------------------


## The strands drawn now: [from (3D), to (3D), drawn radius, its node].
func strands() -> Array:
	return _drawn


## The Lens's charge drawn now (the cast).
func charging() -> bool:
	return hold.has(&"charge")


## The drones brightened by the cast now.
func brightened() -> int:
	var n := 0
	for d: Dictionary in _feeders:
		n += 1 if hold.has([&"bright", d["id"]]) else 0
	return n


## The drones trailing their orbit now.
func orbit_trails() -> int:
	var n := 0
	for d: Dictionary in _web:
		n += 1 if hold.has([&"orbit", d["id"]]) else 0
	return n


## The glass strips drawn now.
func strips() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for mi in _strips:
		if mi.visible:
			out.append(mi)
	return out
