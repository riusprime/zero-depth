class_name NemesisAvatar
extends FinalBodyAvatar
## The final boss's last body, the hero's nemesis: the owner's small dark hooded figure
## (assets/models/bosses/final_boss_nemesis.glb), one mesh skinned to a full skeleton (the spine and the hood, legs and
## feet, sleeves that are the front of its capes, chains of cloak bones; scripts/assets/boss_anim/final_nemesis) that
## carries its own animations in the hero's motion vocabulary. "idle", "walk" (a run), "dash", "flinch" and "death"
## replace the code clips of those names; OWNER_PLAYS says which animation each attack plays (the slash, the shot,
## the cast) and that its rise is "form": it starts on one knee where the Prism fell in a heap, lifts its head,
## stands and drops into its stance. What the avatar adds is game state:
## - its weapon: a dark copy of the run's (WorldReader.nemesis "weapon": a Blade or a Gun) in its own colours (black
##   steel, a violet-red edge; never the hero's), held on the right hand's bone, so the animations swing and aim it;
## - its dash: while the sim says it dashes ("dashing") the file's dash plays to its held pose and stays there, and
##   plays out once the dash ends;
## - a card's cast: the clips' "sigil" lights its eyes and edge (the card itself is NemesisViews').
## The moves the file has no animation for (NemesisClips: the shielded hold, the stagger, the roar) turn its bones
## over the file's idle (BossAvatar). Without the model, a code-made hooded stand-in with the same weapon at its
## side. Reads only (EI-07).

const HEIGHT := 1.5
const WALK_SPEED := 5.2
## The metres one loop of the file's run covers at the size the game draws it (1.538 m at the model's 1.5 m, times
## BossModels.SIZE_SCALE), so its feet don't slide.
const STRIDE := 2.0
## The file's animations by the clip that plays them, with the seconds of each attack's strike pose and of the end of
## its active part. A combo's later swings replay the same cut (the active part cycles once per swing). The rise
## plays "form" straight through: it is standing when the intro ends.
const OWNER_PLAYS := {
	&"mimic_combo": {"anim": &"slash", "strike": 0.7, "recover": 0.833},
	&"mimic_shots": {"anim": &"shoot", "strike": 0.8, "recover": 1.033},
	&"card_cast": {"anim": &"cast", "strike": 1.0, "recover": 1.2},
	&"rise": {"anim": &"form"},
}
## The file's dash, in its seconds: it is in its pose at DASH_IN, holds it until DASH_HELD and is out at
## DASH_LENGTH. A dash of the sim's is short (0.2 s), so the way in plays DASH_IN_RATE times as fast, and what is
## left of the hold when the dash ends (its cloak still moves through it) is run through DASH_CUT_RATE times as fast
## before the way out.
const DASH_IN := 0.133
const DASH_HELD := 0.433
const DASH_LENGTH := 0.6
const DASH_IN_RATE := 2.0
const DASH_CUT_RATE := 6.0
## The bone its weapon is held on (the right hand: it carries no skin, it is the mount).
const GRIP := &"hand_R"
const MODEL_CHEST := Vector3(0.25, 0.9, 0.0)
const CLOAK := Color("#2B2530")
const EYE := Color("#FF3A3A")
## Its weapon's colours: black steel and a violet-red edge (off the hero's cyan).
const STEEL := Color("#1A1620")
const EDGE := Color("#C23CFF")
## Where the stand-in's weapon hangs (model frame, metres), and the blade's length.
const HAND := Vector3(0.18, 0.78, 0.3)
const BLADE_LEN := 0.85
## The edge's glow at "sigil" 1.
const SIGIL_GLOW := 0.35

var stand_in := Node3D.new()
## The weapon held: &"blade" or &"gun" (the run's), its node and its two forms.
var weapon_kind := &"blade"
var weapon: Node3D
var blade_prop: Node3D
var gun_prop: Node3D
var _dashing := false
var _dash_w := 0.0
## Seconds into the file's dash.
var _dash_s := 0.0
## The grip's bone (-1 on the stand-in), the skeleton's space in the pivot's, and what stands the weapon in the
## model's frame on that bone: at rest it points along the front, its top up; the animations turn it from there.
var _grip := -1
var _skel_in_pivot := Transform3D.IDENTITY
var _grip_fix := Transform3D.IDENTITY


func model_id() -> StringName:
	return &"final_boss_nemesis"


func _code_nodes() -> Array[Node]:
	return [stand_in]


func _clip_library() -> Dictionary:
	return NemesisClips.library()


func _owner_plays() -> Dictionary:
	return OWNER_PLAYS


func _walk_speed() -> float:
	return WALK_SPEED


func _stride() -> float:
	return STRIDE


## The length the file's idle was made at, so it plays as made.
func _idle_seconds() -> float:
	return 3.0


func _weak_point_at() -> Vector3:
	return MODEL_CHEST if imported != null else Vector3(0.3, 0.8, 0)


func _weak_bone() -> StringName:
	return &"chest"


## 0..1: how far into its dash pose it is (tests).
func dash_amount() -> float:
	return _dash_w


## Seconds into the file's dash animation (tests): it stops at DASH_HELD while the sim says it dashes.
func dash_seconds() -> float:
	return _dash_s


func sync(reader: WorldReader, i: int) -> void:
	var n := reader.nemesis(i)
	if not n.is_empty():
		_set_weapon(n["weapon"])
		_dashing = bool(n["dashing"])
	super(reader, i)


## Plain values (tests, renders): "weapon" (&"blade" or &"gun"), "dashing" (bool).
func apply_state(s: Dictionary) -> void:
	if s.has("weapon"):
		_set_weapon(s["weapon"])
	if s.has("dashing"):
		_dashing = bool(s["dashing"])
	super(s)


func _set_weapon(kind: StringName) -> void:
	weapon_kind = kind
	if weapon != null:
		blade_prop.visible = kind != &"gun"
		gun_prop.visible = kind == &"gun"


func _build_body() -> void:
	super()
	_make_weapon()


func _build() -> void:
	var p := parts
	stand_in.name = "StandIn"
	model.add_child(stand_in)
	p.piece(stand_in, BossParts.crystal(1.3, 0.45, 41), Vector3(0, 0.0, 0), CLOAK)
	p.glow(stand_in, BossParts.block(Vector3(0.06, 0.08, 0.2), 6), Vector3(0.3, 1.0, 0), EYE, 2.5)


## The weapon: its length along the front, its top up, its grip at its own origin. On the owner's model it sits
## under the body's pivot and is put on the right hand's bone every frame (_after_bones); on the stand-in it hangs
## at its side.
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
	# The barrel runs on from the body to the muzzle's glow.
	parts.piece(gun_prop, BossParts.tube(0.28, 0.035, 14), Vector3(0.24, 0.03, 0), STEEL)
	parts.glow(gun_prop, BossParts.orb(0.04, 15), Vector3(0.52, 0.03, 0), EDGE, 3.0)
	_set_weapon(weapon_kind)
	if poser != null and poser.has_bone(GRIP):
		_grip = poser.index_of(GRIP)
		_skel_in_pivot = BossModels.relative_transform(pivot, skeleton)
		var rest := _skel_in_pivot * skeleton.get_bone_global_rest(_grip)
		_grip_fix = rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin)


## The stand-in: the weapon carried at its side, the blade low, the gun hanging.
func _pose(dt: float) -> void:
	_advance_dash(dt)
	weapon.rotation = Vector3(0, -0.4, -0.6) if weapon_kind == &"gun" else Vector3(0, 0, 0.25)


func _pose_final(dt: float) -> void:
	_advance_dash(dt)


## The dash takes the shielded hold's layer while it shows (the Nemesis has no shielded move): over the run and an
## attack's last frames, under a flinch and the death.
func _animate(dt: float) -> void:
	super(dt)
	if _dash_w > 0.0 and not _dying:
		animator.set_layer(BossAnimator.SHIELD, &"dash", _dash_s / DASH_LENGTH, _dash_w)


## The weapon is put in the hand where this frame's pose holds it.
func _after_bones() -> void:
	if _grip >= 0:
		weapon.transform = _skel_in_pivot * skeleton.get_bone_global_pose(_grip) * _grip_fix


func _extra_glow() -> float:
	var sigil := animator.param(&"sigil") if animator != null else 0.0
	return super() + SIGIL_GLOW * 0.1 * clampf(sigil, 0.0, 1.0)


## The dash's clock: in to the held pose and held there while the sim dashes; then quickly through what is left of
## the hold and out, the layer fading with it.
func _advance_dash(dt: float) -> void:
	if _dashing:
		_dash_w = move_toward(_dash_w, 1.0, dt * 12.0)
		var rate := DASH_IN_RATE if _dash_s < DASH_IN else 1.0
		_dash_s = minf(DASH_HELD, _dash_s + dt * rate)
		return
	_dash_w = move_toward(_dash_w, 0.0, dt * 5.0)
	if _dash_w <= 0.0:
		_dash_s = 0.0
	elif _dash_s < DASH_HELD:
		_dash_s = minf(DASH_HELD, _dash_s + dt * DASH_CUT_RATE)
	else:
		_dash_s = minf(DASH_LENGTH, _dash_s + dt)
