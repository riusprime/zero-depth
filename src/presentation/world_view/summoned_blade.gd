class_name SummonedBlade
extends Node3D
## The Blade as the hero summons it (docs/art/requests/PENDING_ASSETS.md §9): the owner's model (assets/models/fx/
## hero_blade.glb, scripts/assets/hero_blade_prep.py), never carried. The hero's power is runes, not steel, so:
## - on each swing it forms in a flash of blue runes at its hilt, already at the start of the arc;
## - it sweeps the arc in one motion with no hand, its tip on the slash's tip (KitView's blade as drawn: the same yaw,
##   centre and reach the sim hits with, WorldReader.swing_shape), the slash trailing it as before;
## - it spans the whole slash, from the body to the tip: its pommel sits on KitView's hidden root (inside the poncho,
##   the grip leaving the body where a hand would hold it) and the model is scaled uniformly to reach the tip, so a
##   longer reach (the finisher, Lunge Cleave) draws a larger blade, never a stretched one. A thrust's pull-back draws
##   the blade shorter, growing out of the hand as it stabs;
## - at the end of the recovery it breaks into blue motes and is gone; between swings nothing shows;
## - the finisher spin and the Lunge Cleave keep it out for their whole move: the spin through KitView's pivot, the
##   cleave from WorldReader.skill_state() along the same sweep SkillVisuals draws (cleave_progress), held at the arc's
##   starting edge while the lunge drives in, crossing it as the cleave lands, held through its hold and fade.
## The flash and the motes travel with the hero for their whole life: each is moved every sync (the flash on the hilt
## while the blade is out, then with the hero; the motes with the hero), so a walking or lunging hero never leaves
## runes behind. A pooled pack instance is taken from where it last played, so each starts with its interpolation
## reset (it would draw one frame between there and here). A newer flash takes the hilt; an older one still alive
## keeps its place by the hero.
## Matte, lit like the walls (BossPieceModels.matte); only its edge glows pale blue-white. One holder with the model's
## two meshes, built once and reused for every swing (nothing is made or freed per swing); the flash and the motes are
## pack effects (PD-13: data/vfx/pack_fx_bl.tres, magic_orb_flash_vfx_01 and ice_mist_vfx_03 tinted blue), warmed
## with the pack, and the holder is marked for ShaderWarmup.
## Reduced motion: no flash and no motes; the blade still shows the arc. Without the model (missing art), nothing
## draws and KitView's laser blade stays. Presentation only (EI-07): it reads the reader and KitView, its timing is
## sim ticks, and it decides nothing.

## What shows: nothing, the combo swing (on KitView's pivot) or the Lunge Cleave.
enum { NONE, SWING, CLEAVE }

const MODEL_ID := &"hero_blade"
## The edge's glow: pale blue-white, and its strength.
const EDGE_GLOW := Color(0.78, 0.9, 1.0)
const EDGE_ENERGY := 1.6
## The rune flash's and the motes' colour, and their sizes (the pack scenes' scale).
const RUNE := Color(0.55, 0.8, 1.0)
const FLASH_SCALE := 0.25
const MOTES_SCALE := 0.3
## The flash and the motes play this many times faster than their scenes: quick, readability first.
const FLASH_SPEED := 1.6
const MOTES_SPEED := 4.0
const FLASH_ID := &"bl_form"
const MOTES_ID := &"bl_motes"
## Where along the blade (0 the pommel, 1 the tip) the motes break from.
const MOTES_AT := 0.6
## The shortest the blade draws (m): a thrust's deepest pull-back never folds it into the body.
const MIN_SPAN_M := 0.4

## Flashes and mote bursts played, and swings and cleaves the blade was shown for (tests).
var flashes := 0
var motes := 0
var forms := 0
var _kit: KitView
var _holder := Node3D.new()
var _length := 0.0
var _span := 0.0
var _has_model := false
var _mode := NONE
var _last_t := 0
var _last_step := -1
var _last_cleave := -1
## The hero's centre at blade height as of the last sync.
var _centre := Vector3.ZERO
## The flashes and motes still playing: [node, offset from the hero's centre, on the hilt].
var _riders: Array = []


func _init(p_kit: KitView = null) -> void:
	name = "SummonedBlade"
	_kit = p_kit
	_holder.name = "Blade"
	_holder.visible = false
	_holder.set_meta(ShaderWarmup.WARM_META, true)
	add_child(_holder)
	_build()


func _build() -> void:
	var piece := BossPieceModels.get_piece(MODEL_ID, ["steel", "edge"])
	if piece.is_empty():
		return
	var steel := BossPieceModels.put(piece, "steel", _holder)
	var edge_mat := BossPieceModels.matte(piece["texture"])
	edge_mat.emission_enabled = true
	edge_mat.emission = EDGE_GLOW
	edge_mat.emission_energy_multiplier = EDGE_ENERGY
	var edge := BossPieceModels.put(piece, "edge", _holder, edge_mat)
	for mi: MeshInstance3D in [steel, edge]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_length = maxf(steel.mesh.get_aabb().end.x, edge.mesh.get_aabb().end.x)
	_span = _length
	_has_model = _length > 0.0


## The owner's model is there (else KitView's laser blade draws the swing).
func has_model() -> bool:
	return _has_model


func sync(reader: WorldReader) -> void:
	if not _has_model:
		return
	_centre = SimPlane.to_3d(reader.player_pos(), KitView.BLADE_HEIGHT)
	_sync_blade(reader)
	_follow()


func _sync_blade(reader: WorldReader) -> void:
	var was := _mode
	var t := reader.swing_tick()
	var dead := reader.player_dead()
	var root := reader.player_radius() * KitView.ROOT_FRACTION
	if t > 0 and not dead and _kit != null and _kit.blade_visible():
		var fresh := was != SWING or t < _last_t or reader.combo_step() != _last_step
		_last_t = t
		_last_step = reader.combo_step()
		_mode = SWING
		# The tip as KitView draws it, measured from the hero's centre (a thrust pulls the pivot back).
		_place(_centre, _kit.blade_yaw(), _kit.blade_tip_m() - _kit.blade_offset(), root)
		if fresh:
			_form()
		return
	_last_t = 0
	var cleave := _cleave_pose(reader) if not dead else []
	if not cleave.is_empty():
		var fresh := was != CLEAVE or int(cleave[3]) != _last_cleave
		_last_cleave = int(cleave[3])
		_mode = CLEAVE
		_place(cleave[0], cleave[1], cleave[2], root)
		if fresh:
			_form()
		return
	if was != NONE:
		_break()
	_mode = NONE


## The cleave's blade: [centre (3D), yaw, tip radius m, the use's start tick], or [] when no cleave is out. It is out
## from the lunge's first tick until the sweep has faded (SkillVisuals.cleave_progress's hold and fade).
func _cleave_pose(reader: WorldReader) -> Array:
	var s := reader.skill_state()
	if s.is_empty() or int(s["kind"]) != WorldReader.SKILL_LUNGE_CLEAVE:
		return []
	var running := int(s["running"])
	var hit := int(s["hit_tick"])
	var since := reader.tick() - hit if hit >= 0 and running == 0 else -1
	if (
		running <= 0
		and (since < 0 or since >= SkillVisuals.CLEAVE_HOLD_TICKS + SkillVisuals.CLEAVE_FADE_TICKS)
	):
		return []
	var p := SkillVisuals.cleave_progress(running, int(s["move_ticks"]), since).x
	var half := TAU * float(s["half_arc"]) / 4096.0
	var yaw := SimPlane.yaw_of(int(s["angle"])) - half + 2.0 * half * p
	var centre: Vector2 = reader.player_pos() if running > 0 else s["hit_pos"]
	var tip := reader.player_radius() + float(s["reach_m"])
	return [SimPlane.to_3d(centre, KitView.BLADE_HEIGHT), yaw, tip, int(s["tick"])]


## The blade along `yaw` from `centre`: its pommel `root_m` out, its tip `tip_m` out, the model scaled uniformly
## to span the two.
func _place(centre: Vector3, yaw: float, tip_m: float, root_m: float) -> void:
	_span = maxf(tip_m - root_m, MIN_SPAN_M)
	var out := Vector3(cos(yaw), 0, -sin(yaw))
	_holder.position = centre + out * (tip_m - _span)
	_holder.rotation = Vector3(0, yaw, 0)
	_holder.scale = Vector3.ONE * (_span / _length)


## A new swing or cleave: the blade shows at once where the arc starts, in a flash of runes at its hilt.
func _form() -> void:
	forms += 1
	_holder.visible = true
	_holder.reset_physics_interpolation()
	for r: Array in _riders:  # the hilt is the new flash's; an older one stays by the hero
		r[2] = false
	if (
		not ViewPrefs.reduced_motion
		and _spawn(FLASH_ID, hilt_point(), FLASH_SCALE, FLASH_SPEED, true)
	):
		flashes += 1


## The move is over: the blade breaks into motes and is gone.
func _break() -> void:
	for r: Array in _riders:
		r[2] = false
	if (
		not ViewPrefs.reduced_motion
		and _spawn(
			MOTES_ID, _holder.position + _axis() * (_span * MOTES_AT), MOTES_SCALE, MOTES_SPEED
		)
	):
		motes += 1
	_holder.visible = false


func _spawn(id: StringName, at: Vector3, scale: float, speed: float, on_hilt := false) -> bool:
	var pack := _pack()
	if pack == null or not pack.has_id(id):
		return false
	var node := pack.spawn(id, at, scale, BladePack.colors_of(RUNE), -1.0, speed)
	if node == null:
		return false
	node.reset_physics_interpolation()
	for k in range(_riders.size() - 1, -1, -1):  # past its cap the pack hands back a live one: one rider each
		if _riders[k][0] == node:
			_riders.remove_at(k)
	_riders.append([node, at - _centre, on_hilt])
	return true


## Every flash and mote burst still playing moves with the hero (the newest flash on the hilt while the blade is
## out); the ones the pack has taken back are dropped.
func _follow() -> void:
	if _riders.is_empty():
		return
	var pack := _pack()
	for k in range(_riders.size() - 1, -1, -1):
		var r: Array = _riders[k]
		var node: Node3D = r[0] if is_instance_valid(r[0]) else null
		if pack == null or node == null or not pack.is_live(node):
			_riders.remove_at(k)
			continue
		if r[2] and _holder.visible:
			r[1] = hilt_point() - _centre
		node.global_position = _centre + r[1]


func _pack() -> PackFx:
	return BladePack.pack_of(self) if is_inside_tree() else null


func _axis() -> Vector3:
	var yaw := _holder.rotation.y
	return Vector3(cos(yaw), 0, -sin(yaw))


# --- Reads (tests, the swing spark) ----------------------------------------------------------------------------
func blade_visible() -> bool:
	return _holder.visible


## The blade's yaw (radians, SimPlane.yaw_of convention) as of the last sync.
func yaw() -> float:
	return _holder.rotation.y


## The hilt (the pommel end) and the tip as of the last sync (world space).
func hilt_point() -> Vector3:
	return _holder.position


func tip_point() -> Vector3:
	return _holder.position + _axis() * _span


## The model's own length (m), and the length it draws at now (its uniform scale times that).
func length_m() -> float:
	return _length


func span_m() -> float:
	return _span


## The flashes and motes moving with the hero now (tests).
func riders() -> int:
	return _riders.size()


## Where rider `k` stands now (world space; tests).
func rider_point(k: int) -> Vector3:
	return (_riders[k][0] as Node3D).global_position


## The nodes the blade is drawn with (tests: one pooled holder, never more).
func node_count() -> int:
	return _holder.get_child_count()
