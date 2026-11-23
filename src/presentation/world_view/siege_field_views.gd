class_name SiegeFieldViews
extends Node3D
## The Siege Engine's Target Lock, the boulders its shells leave and the cover they give, drawn from
## WorldReader.boss_siege (EI-07: where the circle stands, when the shell lands, where each boulder stands and whether
## the hero is covered are the sim's, BossSiege).
## - The Target Lock: a red-orange reticle of the circle's exact radius on its centre (a ring, four ticks turning, a
##   small cross, a countdown arc filling as the shell comes) with the pack's rim on it (se_lock_rim). It turns while
##   it tracks the hero; for its last moments it holds still, flashes white-hot and pulses fast. The shell falls into
##   it as a streak from above (the pack's javelin, se_shell) and slams into the stone (GroundSlamViews: chunks,
##   grit, cracks and a short orange flash; no fireball or smoke).
## - The boulders: each the kit's large rock (SiegeLooks.rock) stretched to the boulder's exact square and 1.1 m tall,
##   so the hero shows over it. It rises out of the shell's cracks with a kick of grit and dust when placed; in its
##   last seconds its cracks glow, and over its last second it shakes and sinks; shattered (a blast it took, the cart,
##   the cap) it bursts into stone chunks and goes at once.
## - The cover: only while a blast that needs cover comes (a Shockwave under the cover rule winding up, the Doom
##   Shell's cart in its last 2 s, the Doom Shell due), a cool teal shadow lies behind each boulder, away from the
##   Engine, clipped to the room (the sim's line of sight from the Engine's centre: the hero is safe with its centre in
##   it), and the hero wears a ring drawn over the rocks: teal and steady with the pack's rim (se_cover) while covered,
##   red and pulsing fast while the Engine sees it. Quiet at every other moment.
## Every slot is built hidden at the start and the first boulder is marked for the shader warm-up. Reduced motion stills
## the reticle's turn, the shake and the pulses. Nothing here decides.

const RIM_ID := &"se_lock_rim"
const SHELL_ID := &"se_shell"
const COVER_ID := &"se_cover"
const LOCK_EVENT := &"siege_lock"
const SHELL_EVENT := &"siege_shell"
const BOULDER_UP := &"siege_boulder"
const BOULDER_DOWN := &"siege_boulder_down"
## BOULDER_DOWN's reason: run out (it sinks: no burst).
const END_EXPIRED := 0
## The cart's last 2 s of its roll (BossDoom.WARN_TICKS): the Doom Shell comes.
const DOOM_WARN_TICKS := 120
const BOULDERS := 6
## The pack rim's size per metre of radius.
const RIM_PER_M := 0.55
## The shell's slam (its short orange flash) and the boulder's rise and shatter (m round).
const SHELL_STYLE := {"flash": Color(1.0, 0.5, 0.2, 0.75)}
const RISE_M := 1.8
const SHATTER_M := 2.0
const SHATTER := (
	GroundSlamViews.P_BIG | GroundSlamViews.P_MID | GroundSlamViews.P_GRIT | GroundSlamViews.P_DUST
)
const COVER_SCALE := 0.45
## The shell's fall: its last ticks before it lands, from this high (m), at this size.
const FALL_TICKS := 24
const FALL_M := 14.0
const SHELL_SCALE := 0.7
## A boulder's rise (ticks), its cracks (they glow over its last CRACK_TICKS), its shake and sink (its last
## SINK_TICKS: the sim's crumbling).
const RISE_TICKS := 14.0
const CRACK_TICKS := 300.0
const SINK_TICKS := 60.0
const SINK_M := 0.9
const SHAKE_M := 0.05
## The reticle's turn (rad/s) and the lock's flash (s).
const SPIN := 1.4
const FLASH_S := 0.18
## The ring the hero wears (m) and its alpha.
const HALO_R := 0.85

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
## The shells' slams and the boulders' rise and shatter.
var slams := GroundSlamViews.new(4)
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
var _siege := {}
var _engine := Vector2.ZERO
var _hero := Vector2.ZERO
var _need_cover := false
var _last_seq := 0
var _primed := false
var _clock := 0.0
var _step := 0.0
var _spin := 0.0
var _locked_for := -1.0
## The lock's whole length (ticks, its `left` when first seen) and its radius last seen (the shell's blast).
var _lock_len := 0
var _lock_r := 2.2
var _reticle: MeshInstance3D
var _halo: MeshInstance3D
var _shadow := MeshInstance3D.new()
var _shadow_mesh := ImmediateMesh.new()
var _shadow_polys: Array = []
var _rock_nodes: Array[Node3D] = []
var _rocks: Array[MeshInstance3D] = []
## Boulder id -> its age (in 60ths of a second of frame time) since this view saw it rise (absent: it stood before
## this view saw it).
var _rising := {}


func _init() -> void:
	name = "SiegeFieldViews"
	_reticle = SiegeLooks.floor_quad(self, &"reticle", SiegeLooks.DANGER)
	_halo = SiegeLooks.floor_quad(self, &"halo", SiegeLooks.SAFE)
	_shadow.mesh = _shadow_mesh
	_shadow.material_override = SiegeLooks.shadow_material()
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.visible = false
	add_child(_shadow)
	for k in BOULDERS:
		var node := Node3D.new()
		node.visible = false
		add_child(node)
		_rock_nodes.append(node)
		_rocks.append(SiegeLooks.rock(node))
	_rock_nodes[0].set_meta(ShaderWarmup.WARM_META, true)
	add_child(slams)


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	_siege = reader.boss_siege()
	_hero = reader.actor_pos(0)
	_need_cover = false
	if not _siege.is_empty():
		var b := int(_siege["boss"])
		_engine = reader.actor_pos(b)
		_need_cover = need_cover(reader, _siege)
	var lock: Dictionary = _siege.get("lock", {})
	if not lock.is_empty():
		_lock_r = float(lock["radius"])
	var live := {}
	for row: Dictionary in _siege.get("boulders", []):
		live[int(row["id"])] = true
	for id: int in _rising.keys():
		if not live.has(id):
			_rising.erase(id)
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # joining a fight under way replays nothing that already happened
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.STATUS_APPLY:
			_event(e)


## A blast that needs cover comes now: a Shockwave under the cover rule winding up (its ring telegraph), the cart's
## last 2 s, or the Doom Shell due.
static func need_cover(reader: WorldReader, siege: Dictionary) -> bool:
	if int(siege.get("doom", -1)) >= 0:
		return true
	var cart: Dictionary = siege.get("cart", {})
	if not cart.is_empty() and int(cart["left"]) <= DOOM_WARN_TICKS:
		return true
	if not bool(siege.get("cover_rule", false)):
		return false
	return reader.telegraph(int(siege["boss"])).get("shape", &"") == &"ring"


func _event(e: SimEvent) -> void:
	match e.effect_id:
		LOCK_EVENT:
			_lock_len = maxi(1, e.amount)
		SHELL_EVENT:
			slams.slam(SimPlane.to_3d(e.pos, 0.0), _lock_r, SHELL_STYLE)
		BOULDER_UP:
			_rising[e.amount] = 0.0
			slams.slam(
				SimPlane.to_3d(e.pos, 0.0),
				RISE_M,
				{"parts": BossStrikeImpacts.CHIPS, "amount": 0.6}
			)
		BOULDER_DOWN:
			if e.amount_applied != END_EXPIRED:
				slams.slam(SimPlane.to_3d(e.pos, 0.0), SHATTER_M, {"parts": SHATTER})


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	if _siege.is_empty() and hold.count() == 0:
		if quiet:
			return
		quiet = true
		_hide_all()
		return
	quiet = false
	var still := ViewPrefs.reduced_motion
	_clock += delta * (0.0 if still else 1.0)
	_step = delta * 60.0
	hold.begin()
	_draw_lock(delta, still)
	_draw_boulders(still)
	_draw_cover()
	hold.end()


func _hide_all() -> void:
	_reticle.visible = false
	_halo.visible = false
	_shadow.visible = false
	for n in _rock_nodes:
		n.visible = false
	hold.begin()
	hold.end()


func _draw_lock(delta: float, still: bool) -> void:
	var lock: Dictionary = _siege.get("lock", {})
	_reticle.visible = not lock.is_empty()
	if lock.is_empty():
		_locked_for = -1.0
		return
	var locked := bool(lock["locked"])
	var left := int(lock["left"])
	if _lock_len < left:
		_lock_len = left
	if locked:
		_locked_for = 0.0 if _locked_for < 0.0 else _locked_for + delta
	else:
		_locked_for = -1.0
		_spin += delta * (0.0 if still else SPIN)
	var radius := float(lock["radius"])
	var at := SimPlane.to_3d(lock["centre"], 0.06)
	_reticle.position = at
	_reticle.scale = Vector3.ONE * radius
	SiegeLooks.param(_reticle, &"locked", 1.0 if locked else 0.0)
	SiegeLooks.param(
		_reticle, &"flash", (1.0 - clampf(_locked_for / FLASH_S, 0.0, 1.0)) if locked else 0.0
	)
	SiegeLooks.param(_reticle, &"share", 1.0 - float(left) / float(maxi(1, _lock_len)))
	SiegeLooks.param(_reticle, &"spin", _spin)
	SiegeLooks.param(_reticle, &"clock", _clock)
	hold.put(&"lock_rim", RIM_ID, &"area", SiegeLooks.at(at, radius * RIM_PER_M))
	if left <= FALL_TICKS:
		var u := float(left) / float(FALL_TICKS)
		var pos := SimPlane.to_3d(lock["centre"], 0.3 + FALL_M * u)
		var down := Vector3.DOWN
		var side := Vector3.BACK
		var b := Basis(down * SHELL_SCALE, side * SHELL_SCALE, down.cross(side) * SHELL_SCALE)
		hold.put(&"shell", SHELL_ID, &"projectile", Transform3D(b, pos))


func _draw_boulders(still: bool) -> void:
	var rows: Array = _siege.get("boulders", [])
	for id: int in _rising.keys():
		_rising[id] = float(_rising[id]) + _step
	for k in BOULDERS:
		var node := _rock_nodes[k]
		node.visible = k < rows.size()
		if not node.visible:
			continue
		var row: Dictionary = rows[k]
		var size := float(row["size"])
		var left := float(row["left"])
		var up := 1.0
		if _rising.has(int(row["id"])):
			up = ease(clampf(float(_rising[int(row["id"])]) / RISE_TICKS, 0.0, 1.0), 0.4)
		var sink := clampf(1.0 - left / SINK_TICKS, 0.0, 1.0)
		var shake := Vector3.ZERO
		if sink > 0.0 and not still:
			shake = Vector3(sin(_clock * 53.0), 0.0, cos(_clock * 47.0)) * SHAKE_M
		node.position = SimPlane.to_3d(row["centre"]) + shake
		node.position.y = -SiegeLooks.ROCK_H * (1.0 - up) - SINK_M * sink
		node.scale = Vector3(size, SiegeLooks.ROCK_H, size)
		var crack := clampf(1.0 - left / CRACK_TICKS, 0.0, 1.0)
		var mat := _rocks[k].material_override as StandardMaterial3D
		mat.emission_energy_multiplier = crack * crack * (0.9 + 0.5 * sin(_clock * 6.0))
		mat.albedo_color = Color.WHITE.darkened(0.35 * crack)


func _draw_cover() -> void:
	var rows: Array = _siege.get("boulders", [])
	_shadow.visible = _need_cover and not rows.is_empty()
	_halo.visible = _need_cover
	_shadow_polys = []
	if not _need_cover:
		return
	var room: Rect2 = _siege["room"]
	_shadow_mesh.clear_surfaces()
	for row: Dictionary in rows:
		var poly := SiegeLooks.shadow_of(row["centre"], float(row["half"]), _engine, room)
		if poly.size() < 3:
			continue
		_shadow_polys.append(poly)
	if not _shadow_polys.is_empty():
		_shadow_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for poly: Array in _shadow_polys:
			for k in range(1, poly.size() - 1):
				for p: Array in [poly[0], poly[k], poly[k + 1]]:
					_shadow_mesh.surface_set_uv(Vector2(p[1], p[2]))
					_shadow_mesh.surface_add_vertex(SimPlane.to_3d(p[0], 0.07))
		_shadow_mesh.surface_end()
	else:
		_shadow.visible = false
	(_shadow.material_override as ShaderMaterial).set_shader_parameter("alpha", 1.0)
	var covered := bool(_siege.get("covered", false))
	var at := SimPlane.to_3d(_hero, 0.08)
	_halo.position = at
	_halo.scale = Vector3.ONE * HALO_R
	SiegeLooks.param(_halo, &"tint", SiegeLooks.SAFE if covered else SiegeLooks.DANGER)
	SiegeLooks.param(_halo, &"pulse", 0.0 if covered else 1.0)
	SiegeLooks.param(_halo, &"fill", 0.2 if covered else 0.12)
	SiegeLooks.param(_halo, &"clock", _clock)
	if covered:
		hold.put(&"cover", COVER_ID, &"area", SiegeLooks.at(at, COVER_SCALE))


# --- tests and the shot scripts ----------------------------------------------------------------------------------


## The reticle drawn now: [centre (sim), radius, locked], or [] none.
func lock_circle() -> Array:
	if not _reticle.visible:
		return []
	var locked := (
		float((_reticle.material_override as ShaderMaterial).get_shader_parameter("locked")) > 0.5
	)
	return [SimPlane.to_sim(_reticle.position), _reticle.scale.x, locked]


func boulders_shown() -> int:
	return _rock_nodes.filter(func(n: Node3D) -> bool: return n.visible).size()


## Boulder slot k as drawn: {"centre" (sim), "half" (its half side), "top" (m its top stands over the floor),
## "crack" (0..1 its cracks' glow)}.
func boulder_footprint(k: int) -> Dictionary:
	var node := _rock_nodes[k]
	var mat := _rocks[k].material_override as StandardMaterial3D
	return {
		"centre": SimPlane.to_sim(node.position),
		"half": Vector2(node.scale.x, node.scale.z) * 0.5,
		"top": node.position.y + node.scale.y,
		"crack": mat.emission_energy_multiplier,
	}


## The shadows drawn now (one polygon per boulder: [[sim point, along, out], ...]).
func shadows() -> Array:
	return _shadow_polys if _shadow.visible else []


## The hero's ring now: &"covered", &"exposed", or &"" none.
func hero_read() -> StringName:
	if not _halo.visible:
		return &""
	var pulse := float((_halo.material_override as ShaderMaterial).get_shader_parameter("pulse"))
	return &"exposed" if pulse > 0.5 else &"covered"
