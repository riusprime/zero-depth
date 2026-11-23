class_name FallenTheftHud
extends Control
## The Fallen's theft on the HUD's wand row, wordless (the owner: the player discovers it from glows and motion): the
## pip of a card it holds is drawn dark under a violet lock glow that breathes, and the card's icon flies from its pip
## to The Fallen as it is taken and back to the pip as it returns (CardFly, the picked cards' flight). Reads
## WorldReader.boss_fallen ("taken", the body) in the final fight only; decides nothing (EI-07). Under reduced motion
## the glow is still and nothing flies.

const VIOLET := Color(0.72, 0.36, 1.0)
const DARK := Color(0.04, 0.02, 0.07, 0.72)
## The glow's rings past the pip's edge (px) and how fast it breathes (Hz).
const GLOW_PX := 7.0
const RINGS := 4
const BREATHE_HZ := 0.8
## The icon's size on its way to and from The Fallen (px).
const FLY_PX := 40.0

var build: BuildHud
## Where flights go (the HUD's flight layer; this node when unset).
var layer: Control
## The world's projection (tests set it; else the viewport's camera).
var project: Callable
var _dark: PackedInt32Array = PackedInt32Array()
var _held: PackedInt32Array = PackedInt32Array()
var _boss_px := Vector2(-1.0, -1.0)
var _t := 0.0
var _flown := 0


func _init() -> void:
	name = "FallenTheftHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func sync(reader: WorldReader) -> void:
	var dark := PackedInt32Array()
	var held := PackedInt32Array()
	var st := {} if not (reader.final_fight() or not _held.is_empty()) else reader.boss_fallen()
	if not st.is_empty():
		_boss_px = _to_screen(reader.actor_pos(int(st["boss"])))
		for c: Dictionary in st.get("taken", []):
			dark.append(int(c["slot"]))
			held.append(int(c["code"]))
	for k in held.size():
		if not _held.has(held[k]):
			_fly(reader, held[k], dark[k], true)
	for code in _held:
		if not held.has(code):
			_fly(reader, code, _slot_of(reader, code), false)
	_held = held
	if dark != _dark:
		_dark = dark
		queue_redraw()


## The wand slot card `code` sits in (-1 none).
func _slot_of(reader: WorldReader, code: int) -> int:
	var cards: Array = reader.wand().get("cards", [])
	for k in cards.size():
		if int(cards[k]["code"]) == code:
			return k
	return -1


func _process(delta: float) -> void:
	if _dark.is_empty():
		return
	if not HudStyle.reduced_motion:
		_t += delta
	queue_redraw()


## Card `code`'s icon flies from its pip (wand slot `slot`) to The Fallen (`away`) or back.
func _fly(reader: WorldReader, code: int, slot: int, away: bool) -> void:
	if HudStyle.reduced_motion or build == null or _boss_px.x < 0.0:
		return
	if slot < 0 or slot >= WorldReader.MOD_SLOTS:
		return
	var pip := build.pip_rect(slot)
	if pip.size.x <= 0.0:
		return
	var boss := Rect2(_boss_px - Vector2(FLY_PX, FLY_PX) * 0.5, Vector2(FLY_PX, FLY_PX))
	var info := reader.card_info(code)
	var f := CardFly.new(
		info["id"], ItemLooks.color_of_id(info["id"]), pip if away else boss, boss if away else pip
	)
	(layer if layer != null else self).add_child(f)
	_flown += 1


func _to_screen(sim: Vector2) -> Vector2:
	if project.is_valid():
		return project.call(sim)
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	if cam == null:
		return Vector2(-1.0, -1.0)
	return cam.unproject_position(SimPlane.to_3d(sim))


func _draw() -> void:
	if build == null:
		return
	var breathe := 0.5 + 0.5 * sin(_t * TAU * BREATHE_HZ)
	var inv := get_global_transform().affine_inverse()
	for k in _dark:
		if k >= WorldReader.MOD_SLOTS:
			continue
		var r := build.pip_rect(k)
		if r.size.x <= 0.0:
			continue
		var c := inv * r.get_center()
		var half := r.size.x * 0.5
		for n in RINGS:  # The violet lock glow, softest outermost
			var grow := GLOW_PX * float(RINGS - n) / float(RINGS)
			var a := (0.10 + 0.08 * breathe) * float(n + 1) / float(RINGS)
			draw_circle(c, half + grow, Color(VIOLET, a))
		draw_circle(c, half * 0.92, DARK)  # The pip goes dark
		draw_arc(c, half * 0.92, 0.0, TAU, 24, Color(VIOLET, 0.55 + 0.35 * breathe), 2.0, true)


# --- tests ------------------------------------------------------------------------------------------------------------


## The wand slots drawn dark now.
func dark_slots() -> PackedInt32Array:
	return _dark


## Card flights launched so far (away and back).
func flown() -> int:
	return _flown
