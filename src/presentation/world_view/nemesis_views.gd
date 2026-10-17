class_name NemesisViews
extends Node3D
## v0.8.0 FB3 (owner F6 "Weapon + dash + 2-3 cards"; FINAL_BOSS.md F6): the Nemesis's tells beside its avatar, read from
## the sim (WorldReader.nemesis; EI-07), never decided here:
## - a card's cast: through its windup the card's own name (the player's card, tr of its name key) floats over the
##   Nemesis's head and a violet sigil opens at its feet, brightening until the cast lands (its parts on the ground are
##   TelegraphViews', its shots FireballViews', its strikes BossStrikeViews');
## - its dash: dark afterimages left along its way, fading (as the hero's DashTrail, in the Nemesis's colours).
## Ticks are the sim's (the views pause with it); reduced motion: no pulse, the afterimages still fade.
## v0.8.0 N2 (owner O52; WorldReader.final_pace): The Fallen's mimic window: through its warning a thin violet ring
## pulses at the hero's feet and at The Fallen's, closing in; through the window both rings burn solid and a violet
## thread joins them (your power is tied to its level), fading as the window ends.

const SIGIL := Color(0.75, 0.2, 1.0)
const GHOST := Color(0.16, 0.06, 0.22)
## The card's name floats this high (m); the sigil's radius (m).
const LABEL_Y := 2.1
const SIGIL_R := 1.1
## An afterimage every GHOST_EVERY ticks of a dash, at most GHOSTS alive, each fading over GHOST_TICKS.
const GHOST_EVERY := 2
const GHOSTS := 8
const GHOST_TICKS := 18
## v0.8.0 N2: the window cue's colour and its rings' radius (m).
const CUE := Color(0.82, 0.45, 1.0)
const CUE_R := 1.0

var label := Label3D.new()
var _sigil := MeshInstance3D.new()
var _sigil_mat := StandardMaterial3D.new()
## v0.8.0 TX1: the owner's sigil (FxTextures.sigil_material; null: the code disc).
var _sigil_tex: ShaderMaterial
var _ghosts: Array[MeshInstance3D] = []
var _ghost_mats: Array[StandardMaterial3D] = []
var _ghost_tick := PackedInt32Array()
var _next := 0
var _tick := 0
var _casting := -1
var _progress := 0.0
var _t := 0.0
## v0.8.0 N2: the window cue (the rings at the hero's and The Fallen's feet, the thread between them).
var _cue_hero := MeshInstance3D.new()
var _cue_body := MeshInstance3D.new()
var _cue_link := MeshInstance3D.new()
var _cue_mat := StandardMaterial3D.new()
var _cue_state := 0
var _cue_left := 0.0


func _init() -> void:
	name = "NemesisViews"
	label.name = "CardName"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = 0.006
	label.font_size = 48
	label.outline_size = 12
	label.modulate = Color(0.92, 0.75, 1.0)
	label.outline_modulate = Color(0.06, 0.0, 0.1)
	label.visible = false
	add_child(label)
	var disc := CylinderMesh.new()
	disc.top_radius = SIGIL_R
	disc.bottom_radius = SIGIL_R
	disc.height = 0.02
	disc.radial_segments = 40
	_sigil.mesh = disc
	_sigil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sigil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sigil_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_sigil_mat.albedo_color = Color(SIGIL, 0.0)
	_sigil.material_override = _sigil_mat
	_sigil_tex = FxTextures.sigil_material(SIGIL, 0)  # v0.8.0 TX1: the owner's sigil, in its violet
	if _sigil_tex != null:
		_sigil.mesh = FxTextures.floor_quad(SIGIL_R * 2.3)
		_sigil.material_override = _sigil_tex
	_sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sigil.visible = false
	add_child(_sigil)
	var body := CapsuleMesh.new()
	body.radius = 0.28
	body.height = 1.3
	for k in GHOSTS:
		var g := MeshInstance3D.new()
		g.mesh = body
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(GHOST, 0.0)
		g.material_override = m
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visible = false
		add_child(g)
		_ghosts.append(g)
		_ghost_mats.append(m)
		_ghost_tick.append(-1000)
	_build_cue()


func _build_cue() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = CUE_R - 0.07
	ring.outer_radius = CUE_R
	ring.rings = 32
	ring.ring_segments = 6
	_cue_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cue_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cue_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_cue_mat.albedo_color = Color(CUE, 0.0)
	for m: MeshInstance3D in [_cue_hero, _cue_body]:
		m.mesh = ring
		m.material_override = _cue_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
	_cue_hero.name = "FallenCueHero"
	_cue_body.name = "FallenCueBody"
	var link := BoxMesh.new()
	link.size = Vector3(0.06, 0.06, 1.0)
	_cue_link.name = "FallenCueLink"
	_cue_link.mesh = link
	_cue_link.material_override = _cue_mat
	_cue_link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cue_link.visible = false
	add_child(_cue_link)


func sync(reader: WorldReader) -> void:
	_tick = reader.tick()
	var i := reader.boss_index()
	var n := reader.nemesis(i) if i >= 0 else {}
	_casting = int(n.get("casting", -1))
	_progress = float(n.get("cast_progress", 0)) / 1000.0
	if n.is_empty() or _casting < 0:
		label.visible = false
		_sigil.visible = false
	else:
		var cards: Array = n["cards"]
		var c: Dictionary = cards[_casting] if _casting < cards.size() else {}
		var info := reader.card_info(int(c.get("code", -1))) if not c.is_empty() else {}
		label.text = tr(StringName(info.get("name_key", &""))) if not info.is_empty() else ""
		label.visible = label.text != ""
		var at := reader.actor_pos(i)
		label.position = SimPlane.to_3d(at, LABEL_Y)
		_sigil.position = SimPlane.to_3d(at, 0.03)
		_sigil.visible = true
	if not n.is_empty() and bool(n["dashing"]) and _tick % GHOST_EVERY == 0:
		var g := _ghosts[_next]
		g.position = SimPlane.to_3d(reader.actor_pos(i), 0.75)
		_ghost_tick[_next] = _tick
		g.visible = true
		_next = (_next + 1) % GHOSTS
	_fade()
	_sync_cue(reader, i)


## v0.8.0 N2: the window cue from WorldReader.final_pace (its state and the ticks left of it).
func _sync_cue(reader: WorldReader, i: int) -> void:
	var pace := (
		reader.final_pace() if i >= 0 and reader.actor_kind(i) == WorldReader.KIND_NEMESIS else {}
	)
	_cue_state = int(pace.get("window", WorldReader.FALLEN_OFF))
	var on := _cue_state != WorldReader.FALLEN_OFF
	_cue_hero.visible = on
	_cue_body.visible = on
	_cue_link.visible = _cue_state == WorldReader.FALLEN_ON
	if not on:
		return
	_cue_left = float(pace["window_left"]) / maxf(1.0, float(pace["window_len"]))
	var hero := reader.player_pos()
	var body := reader.actor_pos(i)
	_cue_hero.position = SimPlane.to_3d(hero, 0.05)
	_cue_body.position = SimPlane.to_3d(body, 0.05)
	var a := SimPlane.to_3d(hero, 0.9)
	var b := SimPlane.to_3d(body, 0.9)
	var d := b - a
	if d.length() > 0.05:
		_cue_link.position = (a + b) * 0.5
		_cue_link.look_at_from_position(_cue_link.position, b, Vector3.UP)
		_cue_link.scale = Vector3(1, 1, d.length())


func _process(delta: float) -> void:
	_t += delta
	if _cue_state == WorldReader.FALLEN_WARN:  # the warning: a pulse closing in as the window nears
		var pulse := 1.0 if ViewPrefs.reduced_motion else 0.6 + 0.4 * absf(sin(_t * 10.0))
		_cue_mat.albedo_color = Color(CUE, 0.55 * pulse)
		var s := 1.0 + 0.8 * _cue_left
		_cue_hero.scale = Vector3(s, 1, s)
		_cue_body.scale = Vector3(s, 1, s)
	elif _cue_state == WorldReader.FALLEN_ON:  # the window: solid, fading over its last part
		_cue_mat.albedo_color = Color(CUE, clampf(0.35 + 0.6 * _cue_left * 2.0, 0.35, 0.9))
		_cue_hero.scale = Vector3.ONE
		_cue_body.scale = Vector3.ONE
	if _sigil.visible:
		var pulse := 1.0 if ViewPrefs.reduced_motion else 0.8 + 0.2 * sin(_t * 9.0)
		_sigil_mat.albedo_color = Color(SIGIL, clampf(0.15 + 0.6 * _progress, 0.0, 0.8) * pulse)
		if _sigil_tex != null:
			_sigil_tex.set_shader_parameter("alpha", _sigil_mat.albedo_color.a)
			_sigil_tex.set_shader_parameter(
				"turn", 0.0 if ViewPrefs.reduced_motion else _progress * 1.2
			)
		_sigil.scale = Vector3.ONE * (0.6 + 0.4 * _progress)


func _fade() -> void:
	for k in GHOSTS:
		var age := _tick - _ghost_tick[k]
		var g := _ghosts[k]
		if age < 0 or age > GHOST_TICKS:
			g.visible = false
			continue
		_ghost_mats[k].albedo_color = Color(GHOST, 0.55 * (1.0 - float(age) / GHOST_TICKS))


# --- Counts (tests and the tour) ---------------------------------------------------------------------------------


## The card name showing over the Nemesis ("" none).
func card_shown() -> String:
	return label.text if label.visible else ""


func sigil_shown() -> bool:
	return _sigil.visible


## v0.8.0 N2: the window cue showing (0 none, 1 the warning's rings, 2 the window's rings and thread; tests).
func cue_shown() -> int:
	if not _cue_hero.visible:
		return 0
	return 2 if _cue_link.visible else 1


## Afterimages showing now.
func ghost_count() -> int:
	var n := 0
	for g in _ghosts:
		n += 1 if g.visible else 0
	return n
