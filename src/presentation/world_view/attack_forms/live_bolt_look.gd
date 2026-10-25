class_name LiveBoltLook
extends RefCounted
## v0.8.0 HV (owner O89: "lag mostly comes from shooting hordes with multiple modifiers"): a live player bolt's look
## read once and typed, so each bolt drawn a frame costs no string-key look-ups, cue scans, new points Array or new
## Dictionary (AttackFormCanvas drew up to LIVE_BOLTS_MAX of them a frame that way). It is kept on the look itself
## (under KEY) the first time a bolt of that look draws. draw() lays a live bolt out exactly as
## AttackFormCanvas._draw_live_bolt did; off_screen() is the camera test for one (ScreenCull).

const KEY := &"hv_live"
## v0.9.0 VX V18: a live bolt drawn at least this much bigger than its look (the Lance's ball near full charge: Lance
## grows it to 2x) takes the long trail.
const FULL_CHARGE_SCALE := 1.8

var streak := false
## v0.9.0 VX V36: a Spiral bolt (the helix cue) takes the long trail too, so its corkscrew reads.
var helix := false
## v0.9.0 VX V6: the first element and its effects-layer kind (the accent the layer draws on a live Orb).
var element := &""
var accent := &""
var tether := false
var mine := false
var thick := 0.0
var length := 0.0
var energy := 0.0
var edge := Color()
var rim := Color()
var no_particles := true
## The VfxLayer kind (AttackFormCanvas._vfx_kind), read again if the canvas's layer changes.
var kind := &""
var kind_read := false
var kind_for: Object = null


## The look's LiveBoltLook (built the first time, then kept on the look), its VfxLayer kind read for canvas `c`'s
## layer.
static func of(look: Dictionary, c: AttackFormCanvas) -> LiveBoltLook:
	var info: LiveBoltLook = look.get(KEY)
	if info == null:
		info = _build(look)
	if not info.kind_read or info.kind_for != c.vfx:
		info.kind = c._vfx_kind(look)
		info.kind_for = c.vfx
		info.kind_read = true
	return info


static func _build(look: Dictionary) -> LiveBoltLook:
	var info := LiveBoltLook.new()
	var cues: Array = look["cues"]
	info.streak = cues.has(&"streak")
	info.helix = cues.has(&"helix")
	info.element = ElementLooks.first(PackedStringArray(look["elements"]))
	info.accent = ElementLooks.kind(info.element)
	info.tether = cues.has(&"tether")
	info.mine = cues.has(&"mine")
	info.thick = float(look["thick"])
	info.length = float(look["length"])
	info.energy = float(look["energy"])
	info.edge = look["edge"]
	info.rim = look["rim"]
	info.no_particles = (look["particles"] as Array).is_empty()
	look[KEY] = info
	return info


## Whether live bolt `b` (its trail, its rim and particles, a mine's ring) is wholly out of the picture (ScreenCull:
## past its reach + the margin). A bolt with a tether back to the hero always draws (its line may cross the screen).
static func off_screen(cull: ScreenCull, b: Dictionary, info: LiveBoltLook) -> bool:
	if cull == null or not cull.active or info.tether:
		return false
	var p: Vector2 = b["pos"]
	var trail: PackedVector2Array = b["trail"]
	var tail := trail[0] if not trail.is_empty() else p
	var size := float(b.get("scale", 1.0))
	var reach := (p - tail).length() * 0.5 + (info.length + 1.0) * size
	var mid := SimPlane.to_3d((p + tail) * 0.5, AttackFormCanvas.BOLT_H)
	return not cull.shows(mid, reach)


## Lays out live bolt `b` on canvas `c` at `now`: its trail, its element rim round the dart (ActorViews draws the dart),
## a returning bolt's tether, a waiting mine's ring and its particles. The same output as before HV.
static func draw(c: AttackFormCanvas, b: Dictionary, info: LiveBoltLook, now: float) -> void:
	var look: Dictionary = b["look"]
	var h := AttackFormCanvas.BOLT_H
	var trail: PackedVector2Array = b["trail"]
	var size := float(b.get("scale", 1.0))  # v0.6.5 WN3: a charged shot, the charging orb
	# v0.9.0 VX V18 (a full-charge Lance ball reads heavier) and V36 (a Spiral bolt's corkscrew reads): the long trail.
	var long := info.streak or info.helix or size >= FULL_CHARGE_SCALE
	var cap := AttackFormCanvas.STREAK_SEGMENTS if long else AttackFormCanvas.TAIL_SEGMENTS
	var segs := mini(trail.size() - 1, cap)
	var w: float = info.thick * 2.2 * size
	var n := trail.size()
	for j in segs:
		var a := SimPlane.to_3d(trail[n - 1 - j], h)
		var t := SimPlane.to_3d(trail[n - 2 - j], h)
		var f := 1.0 - float(j) / maxi(segs, 1)
		c._put_in(
			c._bolt_edge,
			AttackFormCanvas.segment(t, a, w * (0.5 + 0.5 * f)),
			AttackFormCanvas.lit_color(info.edge, 0.6 * f, info.energy)
		)
	var at := SimPlane.to_3d(b["pos"], h)
	var heading := (b["vel"] as Vector2).angle()
	var scl := Vector3(info.length * 1.25, info.thick * 1.8, info.thick * 1.8) * size
	c._put_in(
		c._bolt_core,
		Transform3D(Basis(Vector3.UP, heading) * Basis.from_scale(scl), at),
		AttackFormCanvas.lit_color(info.rim, 0.45, info.energy)
	)
	if info.tether:
		c._put_in(
			c.pools[&"cue"],
			AttackFormCanvas.segment(SimPlane.to_3d(c._player, h), at, 0.035),
			AttackFormCanvas.lit_color(info.edge, 0.4, 1.4)
		)
	var pts := c._pts
	pts.clear()
	pts.append(at)
	if info.mine and (b["vel"] as Vector2).length() < 0.0001:  # v0.6.5 WN3: a waiting mine
		var ground := SimPlane.to_3d(b["pos"], AttackFormCanvas.GROUND_H)
		c._ring_at(ground, AttackFormCanvas.MINE_RING_M, look, 0.6, pts)
	if info.accent != &"" and c.vfx != null and int(b["id"]) >= 0:
		# v0.9.0 VX V6 (the element's particles never drew on a live Orb with the layer on): its accent from the
		# layer's pools (Fire embers and smoke, a Lightning crackle, Frost shards and glints, Venom and Bleed drips);
		# none at Low (HeroFx.LOW), the pulse and trail stay. LIVE_BOLTS_MAX caps the bolts that get it.
		var v: Vector2 = b["vel"]
		var dir := (
			SimPlane.to_3d(v.normalized(), 0.0) if v.length_squared() > 1e-8 else Vector3.ZERO
		)
		HeroFx.accent(c.vfx, info.accent, info.element, at, dir, int(b["id"]) * 13 + 5, size)
	if info.no_particles or info.kind != &"":
		return  # _emit's own early outs: no particles, or the VfxLayer draws this element's
	c._emit_parts(int(b["id"]), look, look["particles"], pts, now, 1.0)
