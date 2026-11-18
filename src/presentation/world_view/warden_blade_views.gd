class_name WardenBladeViews
extends Node3D
## The Twin Wardens' blades and rifts, drawn from WorldReader.boss_wardens (EI-07: where the swords stand, when each
## cuts, where the rifts open and which one he leaves by are the sim's, BossShadowSwords, BossWardenAmber, BossRift).
## - Shadow Swords: a dark blade hangs over each sword's spot, pointing along its line (the line itself is the
##   ordinary telegraph, in the tw_swords look), with the pack's violet flare at its hilt. On its cut it flies down its
##   line, a dark slash with a violet edge runs along the line and fades, and the pack's hit bursts where it cut.
## - The side dash: a short amber afterimage streak from where the dash began to where he is, fading
##   after it (no smoke at his feet).
## - Through the Rift: three violet portals (the pack's ripple) at the reader's spots, opening as they appear; he sinks
##   into the entry one (his avatar sinks while the sim hides him) in a flash; for the last moments the exit, and only
##   the exit, glows (the pack's light pillar) with its lane on the floor; he bursts out of it in a flash (the
##   charge's lane and its end circle are TelegraphViews' and ChargeBurstViews'); the portals shrink away as they close.
## Every slot is built hidden at the start. Reduced motion stills the flows. Nothing here decides an outcome.

const BLADES := 5
const PORTALS := 3
const VIOLET := WardenLooks.VIOLET
const AMBER := WardenLooks.AMBER
const FLARE_ID := &"tw_rift_flash"
const SLASH_ID := &"tw_slash"
const PORTAL_ID := &"tw_portal"
const EXIT_ID := &"tw_portal_exit"
const EFFECT_CUT := &"warden_sword_cut"
const EFFECT_ENTER := &"warden_rift_enter"
const EFFECT_EXIT := &"warden_rift_exit"
## The blades hang this high (m) and their slash fades over SLASH_S; a blade flies its line in FLY_S.
const BLADE_H := 1.3
const SLASH_S := 0.4
const FLY_S := 0.12
## The dash streak's fade (s) and width (m).
const STREAK_S := 0.35
const STREAK_W := 1.2
## The portal's scale per metre of radius (the ripple is about 1.7 m across at 1) and its open/close (s).
const PORTAL_PER_M := 0.6
const OPEN_S := 0.35

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
var quiet := false
var _st := {}
var _lead_at := Vector2.ZERO
var _blades: Array[MeshInstance3D] = []
var _slashes: Array[MeshInstance3D] = []
## Per sword: seconds since its cut (-1 not cut), and the line it cut along.
var _cut_t: Array[float] = []
var _lines: Array = []
var _streak: MeshInstance3D
var _streak_from := Vector2.ZERO
var _streak_t := 1.0
var _dashing := false
var _exit_lane: MeshInstance3D
var _exit_end: MeshInstance3D
## The portals as drawn: [centre, radius, entry, exit] and how open they are (0..1).
var _portals: Array = []
var _open := 0.0
var _last_seq := 0
var _primed := false
var _clock := 0.0


func _init() -> void:
	name = "WardenBladeViews"
	var blade := PrismMesh.new()
	blade.size = Vector3(0.22, 1.7, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = WardenLooks.SHADOW
	mat.emission_enabled = true
	mat.emission = VIOLET
	mat.emission_energy_multiplier = 0.9
	mat.rim_enabled = true
	mat.rim = 1.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blade.material = mat
	for k in BLADES:
		var mi := MeshInstance3D.new()
		mi.mesh = blade
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_blades.append(mi)
		_slashes.append(WardenLooks.floor_mesh(self, false, Color(0.55, 0.2, 1.0)))
		_cut_t.append(-1.0)
		_lines.append([Vector2.ZERO, Vector2.ZERO, 0.5])
	_streak = WardenLooks.floor_mesh(self, false, AMBER)
	_exit_lane = WardenLooks.floor_mesh(self, false, VIOLET)
	_exit_end = WardenLooks.floor_mesh(self, true, WardenLooks.DANGER)


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	_st = reader.boss_wardens()
	if not _st.is_empty():
		_lead_at = reader.actor_pos(int(_st["lead"]))
	var dashing := int(_st.get("dash", 0)) > 0
	if dashing and not _dashing:
		_streak_from = _lead_at
	if dashing:
		_streak_t = 0.0
	_dashing = dashing
	var rows: Array = _st.get("swords", [])
	for k in BLADES:
		if k >= rows.size():
			continue
		var r: Dictionary = rows[k]
		_lines[k] = [r["from"], r["to"], float(r["half_width"])]
		if bool(r["cut"]) and _cut_t[k] < 0.0:
			_cut_t[k] = 0.0
		elif not bool(r["cut"]):
			_cut_t[k] = -1.0
	var rift: Dictionary = _st.get("rift", {})
	_portals = []
	for p: Dictionary in rift.get("rifts", []):
		_portals.append([p["centre"], float(p["radius"]), bool(p["entry"]), bool(p["exit"])])
	_events(reader)


func _events(reader: WorldReader) -> void:
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind != SimEvent.Kind.STATUS_APPLY:
			continue
		match e.effect_id:
			EFFECT_CUT:
				_spawn(SLASH_ID, &"hit", SimPlane.to_3d(e.pos, 0.6), 0.8)
			EFFECT_ENTER, EFFECT_EXIT:
				_spawn(
					FLARE_ID,
					&"hit",
					SimPlane.to_3d(_rift_of(e.effect_id == EFFECT_ENTER), 1.0),
					1.4
				)


## The entry rift's centre (or the exit's), else where the amber Warden stands.
func _rift_of(entry: bool) -> Vector2:
	var rift: Dictionary = _st.get("rift", {})
	for p: Dictionary in rift.get("rifts", []):
		if bool(p["entry"]) == entry and (entry or bool(p["exit"])):
			return p["centre"]
	return _lead_at


func _spawn(id: StringName, family: StringName, at: Vector3, scale: float) -> void:
	if pack_fx != null and pack_fx.has_id(id) and pack_fx.has_room(family):
		pack_fx.spawn(id, at, scale)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	var idle := _st.is_empty() and _streak_t >= 1.0 and _open <= 0.0 and hold.count() == 0
	idle = idle and _cut_t.all(func(t: float) -> bool: return t < 0.0 or t >= SLASH_S)
	if idle:
		if quiet:
			return
		quiet = true
	else:
		quiet = false
	_clock += delta * (0.0 if ViewPrefs.reduced_motion else 1.0)
	hold.begin()
	_draw_swords(delta)
	_draw_streak(delta)
	_draw_rift(delta)
	hold.end()


func _draw_swords(delta: float) -> void:
	var rows: Array = _st.get("swords", [])
	for k in BLADES:
		var live := k < rows.size()
		var line: Array = _lines[k]
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		var along := (to - from).normalized() if from.distance_to(to) > 0.001 else Vector2.RIGHT
		if _cut_t[k] >= 0.0:
			_cut_t[k] += delta
		var t := _cut_t[k]
		var blade := _blades[k]
		blade.visible = live and (t < 0.0 or t < FLY_S)
		if blade.visible:
			var f := clampf(t / FLY_S, 0.0, 1.0) if t >= 0.0 else 0.0
			var at := from.lerp(to, f)
			var bob := 0.0 if ViewPrefs.reduced_motion or t >= 0.0 else 0.08 * sin(_clock * 4.0 + k)
			var dir3 := SimPlane.to_3d(along)
			# The prism's tip is its +Y: point it down the line, tilted toward the floor.
			var tip := (dir3 + Vector3(0, -0.35, 0)).normalized()
			var side := tip.cross(Vector3.UP).normalized()
			blade.transform = Transform3D(
				Basis(side, tip, side.cross(tip)), SimPlane.to_3d(at, BLADE_H + bob)
			)
			hold.put(
				[&"flare", k],
				FLARE_ID,
				&"hit",
				WardenLooks.at(SimPlane.to_3d(at - along * 0.6, BLADE_H + bob), 0.35)
			)
		var slash := _slashes[k]
		slash.visible = t >= 0.0 and t < SLASH_S
		if slash.visible:
			WardenLooks.lay_strip(slash, from, to, float(line[2]) * 2.0, 0.08 + 0.002 * k)
			WardenLooks.param(slash, &"alpha", 1.0 - t / SLASH_S)
			WardenLooks.param(slash, &"glow", 1.8)
			WardenLooks.param(slash, &"clock", _clock)


func _draw_streak(delta: float) -> void:
	if not _dashing:
		_streak_t = minf(1.0, _streak_t + delta / STREAK_S)
	_streak.visible = _streak_t < 1.0 and _streak_from.distance_to(_lead_at) > 0.3
	if not _streak.visible:
		return
	WardenLooks.lay_strip(_streak, _streak_from, _lead_at, STREAK_W, 0.09)
	WardenLooks.param(_streak, &"alpha", 0.9 * (1.0 - _streak_t))
	WardenLooks.param(_streak, &"glow", 1.6)
	WardenLooks.param(_streak, &"clock", _clock)


func _draw_rift(delta: float) -> void:
	var rift: Dictionary = _st.get("rift", {})
	_open = move_toward(_open, 1.0 if not _portals.is_empty() else 0.0, delta / OPEN_S)
	if _portals.is_empty() and _open > 0.0:
		_open = 0.0  # the reader's rifts are gone with the set piece: nothing left to draw them on
	var grow := ease(_open, 0.5)
	for k in mini(PORTALS, _portals.size()):
		var p: Array = _portals[k]
		var at := SimPlane.to_3d(p[0], 0.06)
		var radius: float = p[1]
		hold.put(
			[&"portal", k], PORTAL_ID, &"area", WardenLooks.at(at, radius * PORTAL_PER_M * grow)
		)
		if bool(p[3]):
			hold.put([&"exit", k], EXIT_ID, &"area", WardenLooks.at(at, radius * 0.9))
	var lane: Array = rift.get("lane", [])
	_exit_lane.visible = lane.size() == 2
	if _exit_lane.visible:
		WardenLooks.lay_strip(_exit_lane, lane[0], lane[1], 2.2, 0.07)
		WardenLooks.param(_exit_lane, &"alpha", 0.9)
		WardenLooks.param(_exit_lane, &"glow", 1.6)
		WardenLooks.param(_exit_lane, &"clock", _clock)
	var burst := float(rift.get("burst_radius", 0.0))
	_exit_end.visible = _exit_lane.visible and burst > 0.0
	if _exit_end.visible:
		_exit_end.position = SimPlane.to_3d(lane[1], 0.05)
		_exit_end.scale = Vector3.ONE * burst
		WardenLooks.param(_exit_end, &"locked", 1.0)
		WardenLooks.param(_exit_end, &"clock", _clock)


## Tests and the shot scripts: what is drawn now.
func blades_shown() -> int:
	return _blades.filter(func(n: MeshInstance3D) -> bool: return n.visible).size()


## Blade k's spot on the sim plane (where it hangs before it cuts).
func blade_at(k: int) -> Vector2:
	return SimPlane.to_sim(_blades[k].position)


func slashes_shown() -> int:
	return _slashes.filter(func(n: MeshInstance3D) -> bool: return n.visible).size()


func streak_shown() -> bool:
	return _streak.visible


## The portals drawn: each [centre (sim), radius, entry, glowing exit].
func portals() -> Array:
	return _portals.slice(0, PORTALS)


## How many portals glow as the exit.
func exits_glowing() -> int:
	var n := 0
	for k in mini(PORTALS, _portals.size()):
		n += 1 if bool(_portals[k][3]) and hold.has([&"exit", k]) else 0
	return n


func exit_lane_shown() -> bool:
	return _exit_lane.visible


## The exit charge's burst circle: [centre (sim), radius], or [] while none shows.
func exit_end() -> Array:
	return [SimPlane.to_sim(_exit_end.position), _exit_end.scale.x] if _exit_end.visible else []
