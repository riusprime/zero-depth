class_name WarBannerViews
extends Node3D
## The Warlord's War Banner as the player sees it, drawn from WorldReader.boss_warlord "banner" (EI-07: where it
## stands, how long, and who stands inside it are the sim's, BossWarlord). No word anywhere: the trade is found from
## glows (the owner: the player discovers it while playing).
## - The cast: the banner (WarlordLooks.banner: the owner's model, its cloth a part of its own) is raised from the
##   floor to upright through the cast, in the pack's warm lift (wl_banner_cast); its circle fades in.
## - Standing: a thin dull-gold rim of the circle's exact radius with a faint tint inside (WarlordLooks.RING_SHADER),
##   no glow; the cloth waves.
## - The Warlord inside it: the pack's red embers (wl_rage) rise round its feet (and WarlordAvatar's body glows hot).
## - The hero inside it: a warm flare (wl_hand) at its casting hand, and each of its hits on the Warlord lands with an
##   extra warm burst (wl_hit) over the usual hit.
## - Its last seconds: the cloth starts to burn from its hem. Fallen to its time: it burns away in the pack's flames
##   (status_burn_b) and sinks. Snapped by a charge: the pack's shards (wl_snap) burst at the pole, the top of the pole
##   with its cloth flies off tumbling and the stump goes.
## Reduced motion stills the wave and the tumble. Nothing here decides.

const CAST_ID := &"wl_banner_cast"
const RAGE_ID := &"wl_rage"
const HAND_ID := &"wl_hand"
const HIT_ID := &"wl_hit"
const SNAP_ID := &"wl_snap"
const BURN_ID := &"status_burn_b"
const FALLEN_EVENT := &"warlord_banner_fallen"
const FELL_TIME := 0
const FELL_CHARGE := 1
## The pack scenes' sizes.
const LIFT_SCALE := 0.9
const RAGE_PER_M := 0.55
const HAND_SCALE := 0.3
const HIT_SCALE := 0.75
const SNAP_SCALE := 0.9
const BURN_SCALE := 0.6
## The ring's band (m) and its look standing.
const EDGE_M := 0.11
const EDGE_ALPHA := 0.8
const FILL_ALPHA := 0.06
## The cloth starts to burn over its last BURN_TICKS standing.
const BURN_TICKS := 90.0
## After its fall (s): burnt away and sunk; snapped, the top's flight.
const FADE_S := 0.9
const SNAP_S := 0.8
const SINK_M := 1.2
## The hand: out along the aim and to the right of the hero, at the shots' height (HeroCastFx's hand).
const HAND_UP := SimPlane.CORE_HEIGHT + 0.12

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
var _banner := {}
var _boss_at := Vector3.ZERO
var _boss_r := 1.2
var _hand := Vector3.ZERO
var _last_seq := 0
var _primed := false
var _clock := 0.0
## The banner after its fall, drawn from what was last seen: [how it fell, seconds since, where it stood].
var _fallen: Array = []
var _ring_mi: MeshInstance3D
var _model := {}
var _hits := 0


func _init() -> void:
	name = "WarBannerViews"
	_ring_mi = WarlordLooks.ring(self, WarlordLooks.BANNER_RING)
	_model = WarlordLooks.banner(self)
	(_model["root"] as Node3D).set_meta(ShaderWarmup.WARM_META, true)


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	var wl := reader.boss_warlord()
	var was := _banner
	_banner = wl.get("banner", {})
	var boss := int(wl.get("boss", -1))
	if boss >= 0:
		_boss_at = SimPlane.to_3d(reader.actor_pos(boss))
		_boss_r = reader.actor_radius(boss)
	var dir := Kin.dir(reader.aim_angle())
	_hand = SimPlane.to_3d(
		(
			reader.player_pos()
			+ dir * HeroCastFx.MUZZLE_M
			+ Vector2(dir.y, -dir.x) * HeroCastFx.HAND_M
		),
		HAND_UP
	)
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # joining a fight under way replays nothing that already happened
	var hero := reader.actor_id(0)
	var boss_id := reader.actor_id(boss) if boss >= 0 else -1
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == FALLEN_EVENT:
			if e.amount == FELL_TIME or e.amount == FELL_CHARGE:
				var at: Vector2 = was.get("centre", e.pos)
				_fallen = [e.amount, 0.0, SimPlane.to_3d(at)]
				if e.amount == FELL_CHARGE:
					_spawn(SNAP_ID, &"impact", SimPlane.to_3d(at, 1.6), SNAP_SCALE)
		elif (
			boss_id >= 0
			and e.target_id == boss_id
			and HitFeel.player_hit(e, hero)
			and bool(_banner.get("hero_inside", false))
		):
			_hits += 1
			_spawn(HIT_ID, &"hit", SimPlane.to_3d(e.pos, SimPlane.CORE_HEIGHT), HIT_SCALE)


func _spawn(id: StringName, family: StringName, at: Vector3, scale: float) -> void:
	if pack_fx != null and pack_fx.has_id(id) and pack_fx.has_room(family):
		pack_fx.spawn(id, at, scale)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	if _banner.is_empty() and _fallen.is_empty() and hold.count() == 0:
		if quiet:
			return
		quiet = true
		_ring_mi.visible = false
		(_model["root"] as Node3D).visible = false
		return
	quiet = false
	var still := ViewPrefs.reduced_motion
	_clock += delta * (0.0 if still else 1.0)
	hold.begin()
	if not _banner.is_empty():
		_fallen = []
		_draw_standing(still)
	elif not _fallen.is_empty():
		_draw_fallen(delta, still)
	else:
		_ring_mi.visible = false
		(_model["root"] as Node3D).visible = false
	hold.end()


func _draw_standing(still: bool) -> void:
	var cast := int(_banner["cast"])
	var share := 1.0 if cast < 0 else float(cast) / 1000.0
	var at := SimPlane.to_3d(_banner["centre"])
	var radius := float(_banner["radius"])
	var root := _model["root"] as Node3D
	var top := _model["top"] as Node3D
	root.visible = true
	root.position = at
	root.rotation = Vector3(0, 0, (1.0 - ease(share, 0.5)) * PI * 0.48)  # raised from lying to upright
	root.scale = Vector3.ONE
	top.position = Vector3(0, float(_model["snap_y"]), 0)
	top.rotation = Vector3.ZERO
	var left := int(_banner["left"])
	var burn := 0.0 if left < 0 else clampf(1.0 - float(left) / BURN_TICKS, 0.0, 1.0) * 0.35
	_cloth(still, burn)
	_ring_mi.visible = true
	_ring_mi.position = at + Vector3(0, 0.04, 0)
	_ring_mi.scale = Vector3.ONE * radius
	WarlordLooks.param(_ring_mi, &"alpha", share)
	WarlordLooks.param(_ring_mi, &"edge", EDGE_M / maxf(radius, 0.1))
	WarlordLooks.param(_ring_mi, &"edge_alpha", EDGE_ALPHA)
	WarlordLooks.param(_ring_mi, &"fill_alpha", FILL_ALPHA)
	WarlordLooks.param(_ring_mi, &"clock", _clock)
	if cast >= 0:
		hold.put(&"cast", CAST_ID, &"status", WarlordLooks.at(at + Vector3(0, 0.06, 0), LIFT_SCALE))
		return
	if burn > 0.0:
		hold.put(
			&"burn", BURN_ID, &"status", WarlordLooks.at(at + Vector3(0, 1.5, 0), BURN_SCALE * burn)
		)
	if bool(_banner["boss_inside"]):
		hold.put(
			&"rage",
			RAGE_ID,
			&"status",
			WarlordLooks.at(_boss_at + Vector3(0, 0.08, 0), _boss_r * RAGE_PER_M + 0.3)
		)
	if bool(_banner["hero_inside"]):
		hold.put(&"hand", HAND_ID, &"status", WarlordLooks.at(_hand, HAND_SCALE))


func _cloth(still: bool, burn: float) -> void:
	var m := _model["cloth"] as ShaderMaterial
	m.set_shader_parameter("wave", 0.0 if still else 1.0)
	m.set_shader_parameter("burn", burn)
	m.set_shader_parameter("clock", _clock)


func _draw_fallen(delta: float, still: bool) -> void:
	var why := int(_fallen[0])
	var t := float(_fallen[1]) + delta
	_fallen[1] = t
	var at: Vector3 = _fallen[2]
	var root := _model["root"] as Node3D
	var top := _model["top"] as Node3D
	var span := SNAP_S if why == FELL_CHARGE else FADE_S
	var u := clampf(t / span, 0.0, 1.0)
	_ring_mi.visible = u < 1.0
	WarlordLooks.param(_ring_mi, &"alpha", 1.0 - u)
	if u >= 1.0:
		root.visible = false
		_fallen = []
		return
	root.visible = true
	if why == FELL_CHARGE:
		# The top flies off, tumbling (stilled with reduced motion); the stump sinks at once.
		root.position = at - Vector3(0, SINK_M * u * 1.5, 0)
		top.position = Vector3(0.9 * t, float(_model["snap_y"]) + 2.2 * t - 4.0 * t * t, 0.6 * t)
		top.rotation = Vector3(0, 0, 0.0 if still else -5.0 * t)
		_cloth(still, 0.0)
		return
	root.position = at - Vector3(0, SINK_M * u * u, 0)
	_cloth(still, 0.35 + 0.65 * u)
	hold.put(&"burn", BURN_ID, &"status", WarlordLooks.at(at + Vector3(0, 1.5, 0), BURN_SCALE))


# --- tests and the shot scripts ----------------------------------------------------------------------------------


## The banner's parts: {"root", "top" (what a charge snaps off), "snap_y", "cloth" (its material), "from_model"}.
func banner_model() -> Dictionary:
	return _model


## The banner's model shown now (upright, rising or falling).
func banner_shown() -> bool:
	return (_model["root"] as Node3D).visible


## Where the pole stands (sim) and how far it is raised (0 lying .. 1 upright).
func pole() -> Vector2:
	return SimPlane.to_sim((_model["root"] as Node3D).position)


func raised() -> float:
	return 1.0 - (_model["root"] as Node3D).rotation.z / (PI * 0.48)


## The ring drawn now: [centre (sim), radius], or [] none.
func ring_circle() -> Array:
	if not _ring_mi.visible:
		return []
	return [SimPlane.to_sim(_ring_mi.position), _ring_mi.scale.x]


## The Warlord's enraged read (its embers) and the hero's warm hand, now.
func boss_enraged() -> bool:
	return hold.has(&"rage")


func hero_warmed() -> bool:
	return hold.has(&"hand")


## The extra warm bursts on the hero's hits while it stood inside.
func warm_hits() -> int:
	return _hits


## How it last fell (-1 none showing): FELL_TIME or FELL_CHARGE.
func falling() -> int:
	return int(_fallen[0]) if not _fallen.is_empty() else -1
