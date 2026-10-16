class_name NemesisViews
extends Node3D
## v0.8.0 FB3 (owner F6 "Weapon + dash + 2-3 cards"; FINAL_BOSS.md F6): the Nemesis's tells beside its avatar, read from
## the sim (WorldReader.nemesis; EI-07), never decided here:
## - a card's cast: through its windup the card's own name (the player's card, tr of its name key) floats over the
##   Nemesis's head and a violet sigil opens at its feet, brightening until the cast lands (its parts on the ground are
##   TelegraphViews', its shots FireballViews', its strikes BossStrikeViews');
## - its dash: dark afterimages left along its way, fading (as the hero's DashTrail, in the Nemesis's colours).
## Ticks are the sim's (the views pause with it); reduced motion: no pulse, the afterimages still fade.

const SIGIL := Color(0.75, 0.2, 1.0)
const GHOST := Color(0.16, 0.06, 0.22)
## The card's name floats this high (m); the sigil's radius (m).
const LABEL_Y := 2.1
const SIGIL_R := 1.1
## An afterimage every GHOST_EVERY ticks of a dash, at most GHOSTS alive, each fading over GHOST_TICKS.
const GHOST_EVERY := 2
const GHOSTS := 8
const GHOST_TICKS := 18

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


func _process(delta: float) -> void:
	_t += delta
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


## Afterimages showing now.
func ghost_count() -> int:
	var n := 0
	for g in _ghosts:
		n += 1 if g.visible else 0
	return n
