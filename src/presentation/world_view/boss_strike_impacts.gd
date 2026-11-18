class_name BossStrikeImpacts
extends RefCounted
## The stone impacts of BossStrikeViews' strikes, played once on the tick a strike lands, in the game's own faceted
## stone (GroundSlamViews, as the amber Warden's charge slams; PD-13: a physical hit on stone): the craters, the
## landings, the eruptions, the shells and the drops slam into the floor sized to the hit, each boss with only its own
## small touch (STYLES); the swings that scrape the floor kick grit and dust along their arc; the light pulses that
## hit the floor kick a ring of chips. Presentation only: where and when are the strike's (the telegraph's geometry on
## the tick the sim resolves it).

const ORANGE_FLASH := Color(1.0, 0.5, 0.2, 0.75)
const GOLD_FLASH := Color(1.0, 0.8, 0.38, 0.8)
## The Brood Mother's acid among the chips, and the Tidecaller's water thrown up with them.
const ACID := Color(0.4, 0.48, 0.14)
const SPRAY := Color(0.8, 0.9, 0.96)
const CHIPS := GroundSlamViews.P_GRIT | GroundSlamViews.P_DUST
const NO_PLATES := (
	GroundSlamViews.P_BIG | GroundSlamViews.P_MID | GroundSlamViews.P_GRIT | GroundSlamViews.P_DUST
)
## Look -> the slam's style (GroundSlamViews.slam) for the strikes that slam the floor.
const STYLES := {
	&"gk_slam": {},
	&"cl_slam": {},
	&"cl_leap": {},
	&"cl_boulder": {},
	&"tw_slam": {},
	&"cl_spikes": {"amount": 0.6},
	&"bm_leap": {"flecks": ACID},
	&"bm_burrow": {"flecks": ACID},
	&"tc_undertow": {"spray": SPRAY},
	&"se_mortar": {"amount": 0.35, "flash": ORANGE_FLASH},
	&"se_barrage": {"amount": 0.5, "flash": ORANGE_FLASH},
	&"se_deploy": {"parts": CHIPS, "amount": 0.5},
	&"fd_bombs": {"parts": GroundSlamViews.P_DUST, "amount": 0.7},
	&"fd_vent": {"parts": NO_PLATES, "amount": 0.8, "flash": ORANGE_FLASH},
	&"cj_verdict": {"flash": GOLD_FLASH},
	&"cj_gavel": {"parts": CHIPS},
	&"hl_flare": {"parts": CHIPS},
}
## The swings whose arc scrapes the floor: grit and dust along it as the swing passes.
const ARC_KICKS: Array[StringName] = [&"gk_sweep", &"cl_fists", &"wl_bash"]
## A swing's sweep (ticks: BossStrikeShapes._arc's), the points kicked along it, their size.
const SWEEP_TICKS := 7.0
const ARC_POINTS := 7
const ARC_SIZE := 0.32
## A light pulse's chips: how far out (share of its reach) and how many points.
const RING_AT := 0.4
const RING_POINTS := 16
const RING_SIZE := 0.3
## A ring blast slams no wider than this (m): the chunks are sized to the radius.
const MAX_RING_M := 6.0


## Strike `s` (BossStrikeViews' row) just landed: its impact into `slams`, if its look has one.
static func spawn(slams: GroundSlamViews, s: Dictionary) -> void:
	var look: StringName = s.get("look", &"")
	if ARC_KICKS.has(look) and s.has("arc"):
		_arc(slams, s["arc"])
		return
	if not STYLES.has(look):
		return
	var style: Dictionary = STYLES[look]
	if s.has("discs"):
		for d: Array in s["discs"]:
			slams.slam(SimPlane.to_3d(d[0], 0.0), float(d[1]), style)
	elif s.has("ring"):
		var g: Array = s["ring"]
		var reach := minf(float(g[2]), float(g[1]) + 16.0)
		if int(style.get("parts", GroundSlamViews.P_ALL)) == CHIPS:
			_ring(slams, g[0], lerpf(float(g[1]), reach, RING_AT), style)
		else:
			slams.slam(SimPlane.to_3d(g[0], 0.0), clampf(reach, 1.0, MAX_RING_M), style)
	elif s.has("lanes"):
		for o: Obb in s["lanes"]:
			slams.slam(SimPlane.to_3d(o.center, 0.0), maxf(o.half.x, o.half.y) * 1.1, style)


## Grit and dust along a swing's arc at its reach, each point as the swing's head passes it.
static func _arc(slams: GroundSlamViews, g: Array) -> void:
	var c: Vector2 = g[0]
	var rr := float(g[2]) * 0.92
	var points := []
	var delays := []
	for k in ARC_POINTS:
		var t := (k + 0.5) / ARC_POINTS
		var b := lerpf(float(g[3]), float(g[4]), t)
		points.append(SimPlane.to_3d(c + Vector2(cos(b), sin(b)) * rr, 0.0))
		delays.append(t * SWEEP_TICKS / 60.0)
	slams.kick(points, ARC_SIZE, delays)


## A ring of chips kicked out round `c` at `r` m.
static func _ring(slams: GroundSlamViews, c: Vector2, r: float, style: Dictionary) -> void:
	var points := []
	for k in RING_POINTS:
		var a := TAU * k / RING_POINTS
		points.append(SimPlane.to_3d(c + Vector2(cos(a), sin(a)) * r, 0.0))
	slams.kick(points, RING_SIZE, [], style)
