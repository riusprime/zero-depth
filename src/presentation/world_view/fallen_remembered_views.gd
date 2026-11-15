class_name FallenRememberedViews
extends Node3D
## The Fallen remembering a boss the run killed, drawn from WorldReader.boss_fallen (EI-07: which mechanic, when it
## is cast and runs, where the shade stands and where the dash goes are the sim's, BossRemembered). No word says
## whose mechanic it is: the colours and the ghost do (the owner: the player discovers it while playing).
## - The cast: a ghost of the boss it remembers rises over it (FallenLooks.ghost: that boss's own model drawn as
##   light in its colours; the Twin Wardens as their pair), fading in, standing, then fading out as the cast ends,
##   with the pack's pillar of light (tw_portal_exit) in those colours at its feet.
## - While the mechanic runs: a ring of that colour at its feet (the pack's rim, tw_ward_rim), so the room's new
##   effects and the body that casts them read as one. Under the ward the dome takes its place (WardenWardViews).
## - The quake pillars: while its dash line shows aimed at the hero, a strip along it in the Gatekeeper's colour; one
##   that runs into a pillar glows brighter, and white-hot from where it meets the pillar to the pillar's middle.
## - The ward: the amber Warden's shade, a ghost of his model in amber, where the sim puts it, facing its charge,
##   brightening through the wind-up. Its lane, end circle and burst are WardenWardViews' and ChargeBurstViews'.
## The mechanics' own pieces (the wave and orbs, the strips, the pillars, the stun) are their bosses' views, which
## read the same readers. Every ghost is built hidden on the first sync of the final arena or of a world that holds
## the final fight (the Playground), before the floor's shader warm-up, which draws them (marked), so the first cast
## builds and compiles nothing; the models were read with the stage. Reduced motion stills the bands, the
## bob and the pulse. Nothing here decides an outcome.

const PILLAR_ID := &"tw_portal_exit"
const AURA_ID := &"tw_ward_rim"
## The emblem's height (m), how high it rises over the body's feet through the cast (m), and its bob.
const EMBLEM_H := 2.0
const EMBLEM_FROM := 1.9
const EMBLEM_TO := 3.1
const EMBLEM_BOB := 0.06
## The pair of Wardens stands this far apart (m) in their emblem.
const PAIR_GAP := 0.55
## The cast's fade in and out, as shares of it.
const FADE_IN := 0.25
const FADE_OUT := 0.2
const EMBLEM_ALPHA := 0.85
## The pack scenes' scale: the pillar of light at the feet, the ring per metre of the body's radius.
const PILLAR_SCALE := 1.3
const AURA_PER_M := 0.55
const AURA_GROW_M := 0.6
## The shade: its height (m) and its light through the wind-up and the run.
const SHADE_H := 2.6
const SHADE_ALPHA := 0.4
const SHADE_RUN_ALPHA := 0.7
## The dash line: its glow, and how far before the pillar it turns white-hot (m).
const LINE_GLOW := 1.2
const LINE_THROUGH_GLOW := 2.0
const HOT_GLOW := 3.0
const HOT_LEAD_M := 0.8
const HOT := Color(1.0, 0.96, 0.86)

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
var _st := {}
var _body_at := Vector2.ZERO
var _body_r := 0.6
var _pillars: Array = []
var _clock := 0.0
var _built := false
## Source id -> [the ghost nodes, their materials] of its emblem.
var _emblems := {}
var _shade: Node3D = null
var _shade_mat: ShaderMaterial = null
var _line: MeshInstance3D
var _hot: MeshInstance3D
var _cam_yaw := 0.0
## The source whose ring and pillar of light were drawn this frame (&"" none), for the tests.
var _aura := &""
var _pillar := &""


func _init() -> void:
	name = "FallenRememberedViews"
	_line = WardenLooks.floor_mesh(self, false, FallenLooks.colours(&"gatekeeper")[0])
	_hot = WardenLooks.floor_mesh(self, false, HOT)


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	if not _built and (reader.final_arena() or reader.final_fight()):
		build()
	_st = reader.boss_fallen()
	_pillars = []
	if _st.is_empty():
		return
	var i := int(_st["boss"])
	_body_at = reader.actor_pos(i)
	_body_r = reader.actor_radius(i)
	if not (_st["pillar_dash"] as Dictionary).is_empty():
		_pillars = reader.boss_quake_pillars()


## Builds every ghost hidden (the first sync of a final fight; tests call it).
func build() -> void:
	if _built:
		return
	_built = true
	for source: StringName in FallenLooks.MODELS:
		var nodes: Array[Node3D] = []
		var mats: Array[ShaderMaterial] = []
		var rows: Array = FallenLooks.MODELS[source]
		for k in rows.size():
			var row: Array = rows[k]
			var mat := FallenLooks.ghost_material(FallenLooks.colours(source)[int(row[1])])
			var g := FallenLooks.ghost(row[0], mat, EMBLEM_H)
			if g == null:
				continue
			g.position.z = PAIR_GAP * (float(k) - 0.5 * float(rows.size() - 1)) * 2.0
			nodes.append(g)
			mats.append(mat)
		if nodes.is_empty():
			continue
		var holder := Node3D.new()
		holder.name = "Emblem_%s" % source
		holder.visible = false
		holder.set_meta(ShaderWarmup.WARM_META, true)
		add_child(holder)
		for g in nodes:
			holder.add_child(g)
			g.visible = true
		_emblems[source] = [holder, mats]
	_shade_mat = FallenLooks.ghost_material(WardenLooks.AMBER)
	_shade = FallenLooks.ghost(FallenLooks.SHADE_MODEL, _shade_mat, SHADE_H)
	if _shade != null:
		_shade.set_meta(ShaderWarmup.WARM_META, true)
		add_child(_shade)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	var idle := _st.is_empty() or int(_st["running"]) == WorldReader.FALLEN_NONE
	if idle and _st.get("shade", {}).is_empty():
		if quiet:
			return
		quiet = true
	else:
		quiet = false
	_clock += delta * (0.0 if ViewPrefs.reduced_motion else 1.0)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var back := cam.global_basis.z  # toward the camera
		_cam_yaw = atan2(-back.z, back.x)
	hold.begin()
	_aura = &""
	_pillar = &""
	_draw_emblem()
	_draw_aura()
	_draw_line()
	_draw_shade()
	hold.end()


func _source() -> StringName:
	return _st.get("source", &"") if not _st.is_empty() else &""


func _draw_emblem() -> void:
	var source := _source()
	var cast := int(_st.get("cast", -1))
	for key: StringName in _emblems:
		var on := key == source and cast >= 0
		var e: Array = _emblems[key]
		var holder: Node3D = e[0]
		holder.visible = on
		if not on:
			continue
		var u := float(cast) / 1000.0
		var a := emblem_alpha(u)
		var bob := 0.0 if ViewPrefs.reduced_motion else EMBLEM_BOB * sin(_clock * 2.2)
		holder.position = SimPlane.to_3d(
			_body_at, lerpf(EMBLEM_FROM, EMBLEM_TO, ease(u, 0.5)) + bob
		)
		holder.rotation.y = _cam_yaw
		holder.scale = Vector3.ONE * lerpf(0.7, 1.0, ease(u, 0.4))
		for m: ShaderMaterial in e[1]:
			m.set_shader_parameter("alpha", a)
			m.set_shader_parameter("clock", _clock)
	if cast >= 0 and source != &"":
		_pillar = source
		hold.put(
			&"pillar",
			PILLAR_ID,
			&"area",
			WardenLooks.at(SimPlane.to_3d(_body_at, 0.05), PILLAR_SCALE),
			FallenLooks.pack_colours(source)
		)


## The emblem's light at share `u` of the cast: it fades in, stands, and fades out as the cast ends.
static func emblem_alpha(u: float) -> float:
	var a := minf(clampf(u / FADE_IN, 0.0, 1.0), clampf((1.0 - u) / FADE_OUT, 0.0, 1.0))
	return EMBLEM_ALPHA * maxf(a, 0.15)


func _draw_aura() -> void:
	if _st.is_empty() or int(_st["stage"]) != 2:
		return
	if (
		int(_st["running"]) == WorldReader.FALLEN_WARD
		and not (_st["ward"] as Dictionary).is_empty()
	):
		if bool(_st["ward"]["up"]):
			return  # The dome stands on it instead
	var source := _source()
	_aura = source
	hold.put(
		[&"aura", source],
		AURA_ID,
		&"area",
		WardenLooks.at(SimPlane.to_3d(_body_at, 0.06), (_body_r + AURA_GROW_M) * AURA_PER_M),
		FallenLooks.pack_colours(source)
	)


func _draw_line() -> void:
	var dash: Dictionary = _st.get("pillar_dash", {})
	_line.visible = not dash.is_empty()
	_hot.visible = false
	if dash.is_empty():
		return
	var from: Vector2 = dash["from"]
	var to: Vector2 = dash["to"]
	var through := bool(dash["through"])
	var width := _body_r * 2.0
	WardenLooks.lay_strip(_line, from, to, width, 0.07)
	WardenLooks.param(_line, &"glow", LINE_THROUGH_GLOW if through else LINE_GLOW)
	WardenLooks.param(_line, &"alpha", 0.9 if through else 0.6)
	WardenLooks.param(_line, &"clock", _clock)
	if not through:
		return
	var best := -1.0
	var centre := Vector2.ZERO
	for q: Dictionary in _pillars:
		var t := FallenLooks.line_enters(from, to, q["center"], float(q["half"]), _body_r)
		if t >= 0.0 and (best < 0.0 or t < best):
			best = t
			centre = q["center"]
	if best < 0.0:
		return
	var at := from.lerp(to, best)
	var lead := (to - from).normalized() * HOT_LEAD_M
	_hot.visible = true
	WardenLooks.lay_strip(_hot, at - lead, centre, width * 0.8, 0.08)
	WardenLooks.param(_hot, &"glow", HOT_GLOW)
	WardenLooks.param(_hot, &"alpha", 1.0)
	WardenLooks.param(_hot, &"clock", _clock)


func _draw_shade() -> void:
	if _shade == null:
		return
	var sh: Dictionary = _st.get("shade", {}) if not _st.is_empty() else {}
	_shade.visible = not sh.is_empty()
	if sh.is_empty():
		return
	var o: Obb = sh["lane"]
	_shade.position = SimPlane.to_3d(sh["position"], 0.0)
	_shade.rotation.y = atan2(o.axis_u.y, o.axis_u.x)
	var p := float(sh["progress"]) / 1000.0
	var a := SHADE_RUN_ALPHA
	if int(sh["stage"]) == 1:
		var pulse := 0.0 if ViewPrefs.reduced_motion else 0.08 * sin(_clock * (4.0 + 8.0 * p))
		a = lerpf(SHADE_ALPHA, SHADE_RUN_ALPHA, p) + pulse
	_shade_mat.set_shader_parameter("alpha", a)
	_shade_mat.set_shader_parameter("clock", _clock)


## Tests and the shot scripts: what is drawn now.
func emblem_shown() -> StringName:
	for key: StringName in _emblems:
		if (_emblems[key][0] as Node3D).visible:
			return key
	return &""


func emblem_tint(source: StringName) -> Color:
	var mats: Array = _emblems[source][1]
	return (mats[0] as ShaderMaterial).get_shader_parameter("tint")


func emblems_built() -> int:
	return _emblems.size()


## The source whose ring stands at The Fallen's feet now (&"" none).
func aura_shown() -> StringName:
	return _aura


## The source whose pillar of light rises through the cast now (&"" none).
func pillar_shown() -> StringName:
	return _pillar


func line_shown() -> bool:
	return _line.visible


func line_hot() -> bool:
	return _hot.visible


func shade_shown() -> bool:
	return _shade != null and _shade.visible


func shade_position() -> Vector2:
	return SimPlane.to_sim(_shade.position)
