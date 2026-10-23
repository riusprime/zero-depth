class_name HubDefinition
extends ContentDef
## v0.9.0 HB (owner Q27; HUB_MOCKUPS option A, the Rune Ring, owner "3. option A"): the hub between runs
## (CONTENT_SCHEMA §11). One round plaza: the Portal Machine in the centre, the stations on the rim, 16 floor runes
## ringing the machine (lit one per collectible: CL), and a sealed gate in the north rim to a small alcove (opened by
## a profile flag). Everything is on the hub's plan: metres from the centre, +y north (the screen's top), +x east.

@export var radius_m := 12.5
## The rim wall's thickness (m) and how many straight pieces make its circle.
@export var wall_m := 0.8
@export var wall_pieces := 36
## Where the hero appears (the plan's south, on the walk line to the machine).
@export var spawn := Vector2(0.0, -10.4)
## The machine: its solid base's half size (a plan square, m), the radius the hero must be inside for its prompt (m).
@export var machine_core_m := 2.0
@export var machine_reach_m := 3.8
@export var machine_name_key: StringName = &"HUB_PORTAL_MACHINE"
@export var machine_prompt_key: StringName = &"HUB_PROMPT_PORTAL"
## The floor runes: how many, on what ring (m), and the flag that lights rune i (`%d` is i + 1).
@export var rune_count := 16
@export var rune_ring_m := 5.4
@export var rune_flag := "count:collectibles:%d"
## The sealed gate in the north rim (its gap in the wall, m) and the alcove past it (centre, radius).
@export var gate_half_m := 1.6
@export var alcove_at := Vector2(0.0, 15.2)
@export var alcove_r := 2.2
## The stations on the rim (HubStationDefinition) and the hub's evolving states (HubStateDefinition). The state ids
## the view knows: gate_open, machine_looped, trophy_lit, trophy_crown.
@export var stations: Array[HubStationDefinition] = []
@export var states: Array[HubStateDefinition] = []


func category() -> StringName:
	return &"hub"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	check_positive(issues, "radius_m", radius_m)
	check_positive(issues, "machine_reach_m", machine_reach_m)
	if machine_core_m >= machine_reach_m:
		issues.append(
			ValidationIssue.new(
				&"hub_reach", resource_path, "the machine's reach is inside its core"
			)
		)
	if spawn.length() >= radius_m - wall_m or spawn.length() <= machine_reach_m:
		issues.append(
			ValidationIssue.new(&"hub_spawn", resource_path, "the spawn is off the walkable plaza")
		)
	if not HubStateDefinition.flag_ok(rune_flag) or not rune_flag.contains("%d"):
		issues.append(ValidationIssue.new(&"hub_flag", resource_path, "rune_flag: %s" % rune_flag))
	var seen := {}
	for s in stations:
		if s == null or String(s.id).is_empty() or seen.has(s.id):
			issues.append(
				ValidationIssue.new(
					&"hub_station", resource_path, "a station id is empty or repeated"
				)
			)
			continue
		seen[s.id] = true
		if not s.panel in HubStationDefinition.PANELS:
			issues.append(
				ValidationIssue.new(
					&"hub_panel", resource_path, "%s: unknown panel %s" % [s.id, s.panel]
				)
			)
		if String(s.name_key).is_empty() or String(s.prompt_key).is_empty():
			issues.append(
				ValidationIssue.new(&"hub_keys", resource_path, "%s needs its keys" % s.id)
			)
		if (s.at.abs() + s.half).length() > radius_m - wall_m:  # its farthest corner
			issues.append(
				ValidationIssue.new(&"hub_station_out", resource_path, "%s is past the rim" % s.id)
			)
	var state_ids := {}
	for st in states:
		if st == null or state_ids.has(st.id) or not HubStateDefinition.flag_ok(st.flag):
			issues.append(
				ValidationIssue.new(
					&"hub_state", resource_path, "a state is repeated or its flag is malformed"
				)
			)
			continue
		state_ids[st.id] = true
	return issues
