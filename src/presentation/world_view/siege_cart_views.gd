class_name SiegeCartViews
extends Node3D
## The Siege Engine's ammo cart and its Doom Shell, drawn from WorldReader.boss_siege (EI-07: where the cart stands,
## its HP, its way, when the shell fires and whether the armour is stripped are the sim's, BossDoom).
## - The cart: a code-made ammo wagon in the Engine's red (SiegeLooks.cart: a stand-in until the owner's model) on
##   the cart's place, facing its way, its wheels turning as it rolls (the warden body the sim uses never shows:
##   ActorViews hides it), with its own HP bar over it, shown from full.
## - Its track: a rail on the floor from where it set off to the Engine's edge, dim ahead of it and lit behind it, so
##   how far it has come reads at a glance; under the Engine a countdown ring fills with the roll.
## - Its blast: a faint red circle of the blast's radius round it, stronger as its HP runs low, and turning gold once
##   the Engine stands inside it (blowing it up now strips the armour).
## - The Doom Shell: when the cart arrives the Engine's ring flashes white-hot and the pack's rising cast (se_cast)
##   and pillar (se_doom) stand on it until the shell fires; it fires in the pack's explosion on the Engine and, when
##   the hero stood in the open, on the hero. The cart destroyed: the pack's explosion of the blast's size where it
##   stood.
## Built hidden; marked for the shader warm-up. Reduced motion stills the wheels and the pulses. Nothing here decides.

const CAST_ID := &"se_cast"
const DOOM_ID := &"se_doom"
const BLAST_ID := &"se_blast"
const SENT := &"siege_cart"
const DESTROYED := &"siege_cart_destroyed"
const DOOM_EVENT := &"siege_doom_shell"
const BLAST_PER_M := 0.6
const CAST_SCALE := 1.4
const DOOM_SCALE := 1.1
## The countdown ring under the Engine: this far past its edge (m).
const RING_PAST_M := 0.9
## The rail: its width (m) and its glow ahead of and behind the cart.
const RAIL_W := 0.5
const AHEAD_ALPHA := 0.22
const BEHIND_ALPHA := 0.7
## The blast circle's alpha at full HP and near death.
const BLAST_FAINT := 0.18
const BLAST_STRONG := 0.7
const GOLD := Color("#FFC15A")
## The wheels' radius (m) and the HP bar (m: its width, its height over the floor).
const WHEEL_R := 0.34
const BAR_W := 1.3
const BAR_H := 0.12
const BAR_Y := 1.9

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
var quiet := false
var _siege := {}
var _engine := Vector2.ZERO
var _engine_r := 2.8
## The cart's blast radius (m), as the reader gives it (boss_siege "cart_blast").
var _blast_m := 0.0
var _hero := Vector2.ZERO
var _last_seq := 0
var _primed := false
var _clock := 0.0
var _locked_for := -1.0
var _cart_root: Node3D
var _wheels: Array[Node3D] = []
var _roll := 0.0
var _last_at := Vector2.INF
var _bar_back := MeshInstance3D.new()
var _bar_fill := MeshInstance3D.new()
var _bar_quad := QuadMesh.new()
var _bar_frac := -1.0
var _ahead: MeshInstance3D
var _behind: MeshInstance3D
var _blast_ring: MeshInstance3D
var _cast_ring: MeshInstance3D


func _init() -> void:
	name = "SiegeCartViews"
	var parts := SiegeLooks.cart(self)
	_cart_root = parts[0]
	_wheels.assign(parts[1])
	_cart_root.visible = false
	_cart_root.set_meta(ShaderWarmup.WARM_META, true)
	_build_bar()
	_ahead = WardenLooks.floor_mesh(self, false, SiegeLooks.DANGER)
	_behind = WardenLooks.floor_mesh(self, false, SiegeLooks.GLOW)
	_blast_ring = WardenLooks.floor_mesh(self, true, SiegeLooks.DANGER)
	_cast_ring = WardenLooks.floor_mesh(self, true, SiegeLooks.GLOW)


## The cart's HP bar: a dark back and a red fill facing the camera, the fill's mesh rebuilt to its share.
func _build_bar() -> void:
	for pair: Array in [
		[_bar_back, Color(0.05, 0.04, 0.04, 0.85), 0], [_bar_fill, SiegeLooks.GLOW, 1]
	]:
		var mi: MeshInstance3D = pair[0]
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.no_depth_test = true
		m.albedo_color = pair[1]
		m.render_priority = int(pair[2]) + 3
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = BAR_Y
		_cart_root.add_child(mi)
	var back := QuadMesh.new()
	back.size = Vector2(BAR_W + 0.08, BAR_H + 0.08)
	_bar_back.mesh = back
	_bar_fill.mesh = _bar_quad
	_set_bar(1.0)


func _set_bar(frac: float) -> void:
	if is_equal_approx(frac, _bar_frac):
		return
	_bar_frac = frac
	_bar_quad.size = Vector2(maxf(BAR_W * frac, 0.001), BAR_H)
	_bar_quad.center_offset = Vector3(-BAR_W * 0.5 + BAR_W * frac * 0.5, 0.0, 0.001)


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	_siege = reader.boss_siege()
	_hero = reader.actor_pos(0)
	if not _siege.is_empty():
		var b := int(_siege["boss"])
		_engine = reader.actor_pos(b)
		_engine_r = reader.actor_radius(b)
		_blast_m = float(_siege["cart_blast"])
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # joining a fight under way replays nothing that already happened
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.STATUS_APPLY:
			continue
		match e.effect_id:
			DESTROYED:
				_spawn(SimPlane.to_3d(e.pos, 0.1), _blast_m * BLAST_PER_M)
			DOOM_EVENT:
				_spawn(SimPlane.to_3d(e.pos, 1.2), 2.0)
				if e.amount_applied < 0:  # in the open: the shell lands on the hero
					_spawn(SimPlane.to_3d(_hero, 0.1), 1.4)
			SENT:
				_last_at = Vector2.INF


func _spawn(at: Vector3, scale: float) -> void:
	if pack_fx != null and pack_fx.has_id(BLAST_ID) and pack_fx.has_room(&"explosion"):
		pack_fx.spawn(BLAST_ID, at, scale)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	var cart: Dictionary = _siege.get("cart", {})
	var doom := int(_siege.get("doom", -1))
	if cart.is_empty() and doom < 0 and hold.count() == 0:
		if quiet:
			return
		quiet = true
	else:
		quiet = false
	var still := ViewPrefs.reduced_motion
	_clock += delta * (0.0 if still else 1.0)
	hold.begin()
	_draw_cart(cart, still)
	_draw_cast(cart, doom, delta)
	hold.end()


func _draw_cart(cart: Dictionary, still: bool) -> void:
	var on := not cart.is_empty()
	_cart_root.visible = on and int(cart["id"]) >= 0  # (its body arrives a tick after it sets off)
	for mi: MeshInstance3D in [_ahead, _behind, _blast_ring]:
		mi.visible = on
	if not on:
		_last_at = Vector2.INF
		return
	var at: Vector2 = cart["position"]
	var from: Vector2 = cart["from"]
	var to: Vector2 = cart["to"]
	var way := to - from
	_cart_root.position = SimPlane.to_3d(at)
	_cart_root.rotation.y = atan2(way.y, way.x)
	if _last_at != Vector2.INF and not still:
		_roll -= at.distance_to(_last_at) / WHEEL_R
	_last_at = at
	for w in _wheels:
		w.rotation.z = _roll
	var hp_max := maxi(1, int(cart["max"]))
	var frac := clampf(float(cart["hp"]) / float(hp_max), 0.0, 1.0)
	_set_bar(frac)
	WardenLooks.lay_strip(_ahead, at, to, RAIL_W, 0.04)
	WardenLooks.param(_ahead, &"alpha", AHEAD_ALPHA)
	WardenLooks.param(_ahead, &"glow", 0.4)
	WardenLooks.param(_ahead, &"clock", _clock)
	_behind.visible = at.distance_to(from) > 0.05
	WardenLooks.lay_strip(_behind, from, at, RAIL_W, 0.045)
	WardenLooks.param(_behind, &"alpha", BEHIND_ALPHA)
	WardenLooks.param(_behind, &"clock", _clock)
	var near_engine := at.distance_to(_engine) <= _blast_m + _engine_r
	_blast_ring.position = SimPlane.to_3d(at, 0.03)
	_blast_ring.scale = Vector3.ONE * _blast_m
	WardenLooks.param(_blast_ring, &"tint", GOLD if near_engine else SiegeLooks.DANGER)
	WardenLooks.param(_blast_ring, &"alpha", lerpf(BLAST_STRONG, BLAST_FAINT, frac))
	WardenLooks.param(_blast_ring, &"locked", 1.0 if near_engine else 0.0)
	WardenLooks.param(_blast_ring, &"fill", 0.0)
	WardenLooks.param(_blast_ring, &"clock", _clock)


func _draw_cast(cart: Dictionary, doom: int, delta: float) -> void:
	var on := not cart.is_empty() or doom >= 0
	_cast_ring.visible = on
	if not on:
		_locked_for = -1.0
		return
	var share := float(cart["progress"]) / 1000.0 if not cart.is_empty() else 1.0
	var firing := doom >= 0
	_locked_for = (0.0 if _locked_for < 0.0 else _locked_for + delta) if firing else -1.0
	var at := SimPlane.to_3d(_engine, 0.05)
	_cast_ring.position = at
	_cast_ring.scale = Vector3.ONE * (_engine_r + RING_PAST_M)
	WardenLooks.param(_cast_ring, &"share", share)
	WardenLooks.param(_cast_ring, &"locked", 1.0 if firing else 0.0)
	WardenLooks.param(
		_cast_ring, &"flash", 1.0 - clampf(_locked_for / 0.2, 0.0, 1.0) if firing else 0.0
	)
	WardenLooks.param(_cast_ring, &"fill", share if firing else 0.0)
	WardenLooks.param(_cast_ring, &"alpha", 1.0 if firing else 0.75)
	WardenLooks.param(_cast_ring, &"clock", _clock)
	if firing:
		hold.put(&"cast", CAST_ID, &"status", SiegeLooks.at(at, _engine_r * 0.5 * CAST_SCALE))
		hold.put(&"doom", DOOM_ID, &"area", SiegeLooks.at(at, _engine_r * 0.5 * DOOM_SCALE))


# --- tests and the shot scripts ----------------------------------------------------------------------------------


func cart_shown() -> bool:
	return _cart_root.visible


## Where the cart is drawn (sim plane).
func cart_position() -> Vector2:
	return SimPlane.to_sim(_cart_root.position)


## Its HP bar's fill (0..1).
func cart_hp_fraction() -> float:
	return _bar_frac


## The cart's look is the code-made wagon (its wheels), never an enemy's model.
func cart_wheels() -> int:
	return _wheels.size()


func track_shown() -> bool:
	return _ahead.visible


## The blast circle: [centre (sim), radius, gold (the Engine inside it)] or [] none.
func blast_circle() -> Array:
	if not _blast_ring.visible:
		return []
	var gold := (
		float((_blast_ring.material_override as ShaderMaterial).get_shader_parameter("locked"))
		> 0.5
	)
	return [SimPlane.to_sim(_blast_ring.position), _blast_ring.scale.x, gold]


## The Engine's ring: -1 hidden, else its share filled (0..1).
func cast_share() -> float:
	if not _cast_ring.visible:
		return -1.0
	return float((_cast_ring.material_override as ShaderMaterial).get_shader_parameter("share"))


## The Doom Shell is due: the cast's pack effects stand on the Engine.
func doom_shown() -> bool:
	return hold.has(&"cast")
