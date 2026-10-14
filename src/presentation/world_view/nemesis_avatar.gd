class_name NemesisAvatar
extends FinalBodyAvatar
## v0.8.0 FB1 (FINAL_BOSS.md F6), FB3 (owner F6 "Weapon + dash + 2-3 cards": "it uses your weapon and dash, echoes your
## moves and casts the strongest 2–3 cards of your wand"): the final boss's last body, the owner's model
## assets/models/bosses/final_boss_nemesis.glb (the small dark hooded figure, the hero's nemesis), moved as a whole by
## NemesisClips in the hero's motion vocabulary (run, dash, slash, shoot, cast, hit, death; the owner's animated model
## replaces them by name). Its own layer after the clips (_pose_final):
## - its weapon: a dark copy of the run's (WorldReader.nemesis "weapon": a Blade or a Gun) in its right hand, in its own
##   colours (black steel, a violet-red edge; never the hero's), swung by the clips' "swing", raised by "aim" and kicked
##   by "recoil";
## - its dash: while the sim says it dashes ("dashing"), the dash clip's low lean, stretched along its way;
## - a card's cast: the clips' "sigil" lights its eyes and edge (the card itself is NemesisViews').
## Without the model, a code-made hooded stand-in with the same weapon. Reads only (EI-07).

const HEIGHT := 1.5
const MODEL_CHEST := Vector3(0.25, 0.9, 0.0)
const CLOAK := Color("#2B2530")
const EYE := Color("#FF3A3A")
## Its weapon's colours: black steel and a violet-red edge (off the hero's cyan).
const STEEL := Color("#1A1620")
const EDGE := Color("#C23CFF")
## The hand the weapon hangs from (model frame, metres), the blade's length, the swing's arc (radians at "swing" 1).
const HAND := Vector3(0.18, 0.78, 0.3)
const BLADE_LEN := 0.85
const SWING_ARC := 1.6
## Seconds the dash clip runs over (one dash of the hero's), and the edge's glow at "sigil" 1.
const DASH_SECONDS := 0.25
const SIGIL_GLOW := 0.35

var stand_in := Node3D.new()
## The weapon held: &"blade" or &"gun" (the run's), its node and its two forms.
var weapon_kind := &"blade"
var weapon: Node3D
var blade_prop: Node3D
var gun_prop: Node3D
var _dashing := false
var _dash_w := 0.0
var _dash_t := 0.0


func model_id() -> StringName:
	return &"final_boss_nemesis"


func _code_nodes() -> Array[Node]:
	return [stand_in]


func _clip_library() -> Dictionary:
	return NemesisClips.library()


func _walk_speed() -> float:
	return 5.2


func _stride() -> float:
	return 1.0


func _idle_seconds() -> float:
	return 1.4


func _weak_point_at() -> Vector3:
	return MODEL_CHEST if imported != null else Vector3(0.3, 0.8, 0)


func _weak_bone() -> StringName:
	return &"root"


## 0..1: how far into its dash pose it is (tests).
func dash_amount() -> float:
	return _dash_w


func sync(reader: WorldReader, i: int) -> void:
	var n := reader.nemesis(i)
	if not n.is_empty():
		_set_weapon(n["weapon"])
		_dashing = bool(n["dashing"])
	super(reader, i)


## Plain values (tests, renders): "weapon" (&"blade" or &"gun"), "dashing" (bool).
func apply_state(s: Dictionary) -> void:
	super(s)
	if s.has("weapon"):
		_set_weapon(s["weapon"])
	if s.has("dashing"):
		_dashing = bool(s["dashing"])


func _set_weapon(kind: StringName) -> void:
	weapon_kind = kind
	if weapon != null:
		blade_prop.visible = kind != &"gun"
		gun_prop.visible = kind == &"gun"


func _build() -> void:
	var p := parts
	stand_in.name = "StandIn"
	model.add_child(stand_in)
	p.piece(stand_in, BossParts.crystal(1.3, 0.45, 41), Vector3(0, 0.0, 0), CLOAK)
	p.glow(stand_in, BossParts.block(Vector3(0.06, 0.08, 0.2), 6), Vector3(0.3, 1.0, 0), EYE, 2.5)


## The weapon in its hand (made on first pose, under the body's pivot so the clips swing it with the body).
func _make_weapon() -> void:
	var parent: Node3D = pivot if pivot != null else model
	weapon = Node3D.new()
	weapon.name = "Weapon"
	weapon.position = HAND
	parent.add_child(weapon)
	blade_prop = Node3D.new()
	blade_prop.name = "Blade"
	weapon.add_child(blade_prop)
	var bl := BossParts.block(Vector3(BLADE_LEN, 0.035, 0.09), 11, 0.1)
	parts.piece(blade_prop, bl, Vector3(BLADE_LEN * 0.5, 0, 0), STEEL)
	parts.glow(
		blade_prop,
		BossParts.block(Vector3(BLADE_LEN * 0.9, 0.012, 0.02), 12, 0.1),
		Vector3(BLADE_LEN * 0.5, 0.0, 0.05),
		EDGE,
		2.2
	)
	gun_prop = Node3D.new()
	gun_prop.name = "Gun"
	weapon.add_child(gun_prop)
	parts.piece(gun_prop, BossParts.block(Vector3(0.32, 0.12, 0.1), 13), Vector3(0.12, 0, 0), STEEL)
	parts.piece(
		gun_prop,
		BossParts.tube(0.28, 0.035, 14),
		Vector3(0.38, 0.03, 0),
		STEEL,
		Vector3(0, 0, -PI / 2)
	)
	parts.glow(gun_prop, BossParts.orb(0.04, 15), Vector3(0.52, 0.03, 0), EDGE, 3.0)
	_set_weapon(weapon_kind)


func _pose(dt: float) -> void:
	if weapon == null:
		_make_weapon()
	_advance_dash(dt)
	_pose_weapon(0.0, 0.0, 0.0)


func _pose_final(dt: float) -> void:
	if weapon == null:
		_make_weapon()
	_advance_dash(dt)
	var an := animator
	_pose_weapon(an.param(&"swing"), an.param(&"aim"), an.param(&"recoil"))
	_pose_dash()


func _extra_glow() -> float:
	var sigil := animator.param(&"sigil") if animator != null else 0.0
	return super() + SIGIL_GLOW * 0.1 * clampf(sigil, 0.0, 1.0)


func _advance_dash(dt: float) -> void:
	_dash_w = move_toward(_dash_w, 1.0 if _dashing else 0.0, dt * (12.0 if _dashing else 5.0))
	if _dashing:
		_dash_t = minf(0.8, _dash_t + dt / DASH_SECONDS)
	elif _dash_w <= 0.0:
		_dash_t = 0.0
	else:
		_dash_t = minf(1.0, _dash_t + dt / DASH_SECONDS)


## The blade swings across ("swing" -1..1), the gun comes up ("aim") and kicks ("recoil").
func _pose_weapon(swing: float, aim: float, recoil: float) -> void:
	if weapon_kind == &"gun":
		weapon.rotation = Vector3(0, -0.4 * (1.0 - aim), -0.6 * (1.0 - aim) + 0.35 * recoil)
		weapon.position = HAND + Vector3(0.12 * aim - 0.08 * recoil, 0.18 * aim, -0.1 * aim)
	else:
		weapon.rotation = Vector3(0.0, -SWING_ARC * 0.5 * swing, 0.25 - 0.2 * absf(swing))
		weapon.position = HAND


## The dash clip's lean on the whole body, weighted by how far into the dash it is.
func _pose_dash() -> void:
	if _dash_w <= 0.001 or pivot == null:
		return
	var c: BossClip = NemesisClips.library()[&"dash"]
	for k in c.targets.size():
		if c.targets[k] != BossClip.BODY:
			continue
		var v := c.value(k, _dash_t, ViewPrefs.reduced_motion) * _dash_w
		match c.channels[k]:
			BossClip.SHIFT:
				pivot.position += c.axes[k] * v
			BossClip.TURN:
				pivot.basis = Basis(c.axes[k], v) * pivot.basis
			BossClip.STRETCH:
				pivot.scale *= Vector3(1.0 + v, 1.0 - v * 0.5, 1.0 + v)
