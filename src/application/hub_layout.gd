class_name HubLayout
extends RefCounted
## v0.9.0 HB: the hub's plan (HubDefinition) on the sim plane. The plan's north is the top of the screen in the iso
## view (IsoRig's yaw 45°: the camera looks toward sim (-1, +1)), so a plan point (x, y) lies at sim
## ((x - y), (x + y)) / √2 and every plan-square box is a sim box turned 45° (angle 512 of 4096). Pure geometry, read
## by the hub's World (HubScenario: the walls), its view (where each thing stands) and its session (which station
## the hero stands at). Nothing here writes a profile or a save.

const SQRT_HALF := 0.70710678
## A box on the plan is turned this much on the sim plane (1/4096 turns).
const PLAN_ANGLE := 512
## The station id the machine answers to (its panel is the run's start: the build pick).
const MACHINE := &"portal"

var hub: HubDefinition
var gate_open := false


func _init(p_hub: HubDefinition, p_gate_open: bool = false) -> void:
	hub = p_hub
	gate_open = p_gate_open


## A plan point on the sim plane.
static func to_sim(plan: Vector2) -> Vector2:
	return Vector2(plan.x - plan.y, plan.x + plan.y) * SQRT_HALF


## A sim point on the plan.
static func to_plan(sim: Vector2) -> Vector2:
	return Vector2(sim.x + sim.y, sim.y - sim.x) * SQRT_HALF


func spawn() -> Vector2:
	return to_sim(hub.spawn)


func station(id: StringName) -> HubStationDefinition:
	for s in hub.stations:
		if s.id == id:
			return s
	return null


## Every blocking box: the rim (with its gate gap, the gate's slab across it while sealed), the alcove's walls past
## the gate, the machine's core and each station's footprint.
func walls() -> Array[Obb]:
	var out: Array[Obb] = []
	var n := maxi(8, hub.wall_pieces)
	var r := hub.radius_m + hub.wall_m * 0.5
	var piece := TAU * r / n * 0.5 + 0.05  # half a piece's length, overlapping its neighbours a little
	for k in n:
		var a := TAU * (k + 0.5) / n  # plan angle from east, counter-clockwise
		var c := Vector2(cos(a), sin(a)) * r
		if absf(c.x) < hub.gate_half_m + piece and c.y > 0.0:
			continue  # the gate's gap in the north rim
		out.append(_plan_box(c, Vector2(hub.wall_m * 0.5, piece), a))
	# The gate's posts either side of the gap, and its slab while sealed.
	var gy := hub.radius_m + hub.wall_m * 0.5
	var post_x := hub.gate_half_m + 0.45
	for side in [-1.0, 1.0]:
		out.append(
			_plan_box(Vector2(side * post_x, gy), Vector2(0.45, hub.wall_m * 0.5 + 0.3), 0.0)
		)
	if not gate_open:
		out.append(_plan_box(Vector2(0, gy), Vector2(hub.gate_half_m, hub.wall_m * 0.5), 0.0))
	# The alcove: a short corridor from the gate to a small round room, walled in.
	var ac := hub.alcove_at
	var ar := hub.alcove_r + 0.4
	var lane_y0 := gy + hub.wall_m * 0.5
	var lane_y1 := ac.y - hub.alcove_r * 0.8
	var lane_mid := (lane_y0 + lane_y1) * 0.5
	var lane_half := maxf(0.2, (lane_y1 - lane_y0) * 0.5)
	for side in [-1.0, 1.0]:
		out.append(
			_plan_box(
				Vector2(side * (hub.gate_half_m + 0.3), lane_mid), Vector2(0.3, lane_half), 0.0
			)
		)
	for k in 12:
		var a := TAU * (k + 0.5) / 12.0
		var c := ac + Vector2(cos(a), sin(a)) * ar
		if c.y < ac.y - hub.alcove_r * 0.6 and absf(c.x - ac.x) < hub.gate_half_m + 0.3:
			continue  # its doorway onto the corridor
		out.append(_plan_box(c, Vector2(0.3, TAU * ar / 24.0 + 0.1), a))
	# The machine's core: an octagon of boxes would be rounder, but one turned square reads the same at this size.
	out.append(_plan_box(Vector2.ZERO, Vector2.ONE * hub.machine_core_m, PI * 0.25))
	for s in hub.stations:
		out.append(_plan_box(s.at, s.half, 0.0))
	return out


## The station the hero at sim `pos` stands at (its prompt shows, the interact opens it), or &"": the machine when
## inside its reach, else the nearest station whose footprint is within its reach.
func station_at(pos: Vector2) -> StringName:
	var p := to_plan(pos)
	if p.length() <= hub.machine_reach_m:
		return MACHINE
	var best := &""
	var best_d := INF
	for s in hub.stations:
		var d := _box_gap(p, s.at, s.half)
		if d <= s.reach_m and d < best_d:
			best = s.id
			best_d = d
	return best


## The name and prompt keys of station `id` (the machine's from the hub).
func keys_of(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = [&"", &""]
	var s := station(id)
	if id == MACHINE:
		out = [hub.machine_name_key, hub.machine_prompt_key]
	elif s != null:
		out = [s.name_key, s.prompt_key]
	return out


## The panel station `id` opens.
func panel_of(id: StringName) -> StringName:
	if id == MACHINE:
		return &"portal"
	var s := station(id)
	return s.panel if s != null else &""


## Where the floor runes stand on the plan, in order (rune 0 due south of the machine, then clockwise from above).
func rune_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in hub.rune_count:
		var a := -PI * 0.5 - TAU * i / float(hub.rune_count)
		out.append(Vector2(cos(a), sin(a)) * hub.rune_ring_m)
	return out


## The distance from plan point `p` to a plan box's edge (0 inside).
static func _box_gap(p: Vector2, at: Vector2, half: Vector2) -> float:
	var d := ((p - at).abs() - half).max(Vector2.ZERO)
	return d.length()


## A box on the plan (centre, half size, turned `plan_angle` radians counter-clockwise) as a sim Obb.
static func _plan_box(c: Vector2, half: Vector2, plan_angle: float) -> Obb:
	var turns := int(round(plan_angle / TAU * 4096.0))
	return Obb.make(to_sim(c), half, PLAN_ANGLE + turns)
