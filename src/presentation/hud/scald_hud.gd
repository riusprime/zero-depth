class_name ScaldHud
extends Control
## The hero's scald gauge in the Foundry's last phase (WorldReader.boss_forge "scald"), over the HP plate's right end:
## a small dark thermometer, no words (the owner: the player discovers the mechanic by playing). Its fill rises with
## `gauge / max`, orange turning white-hot near the top; while the hero burns the bulb and the tube's rim pulse red;
## while a slab cools it a blue tick points down beside the tube and the fill's top edge turns blue. Hidden before
## the scald's phase and after the fight. It is not the Overclock heat meter (HeatMeter, the weapon's own heat: a
## straight bar at the bottom centre in Astral's silver-to-rose tones): another place, another shape, another colour
## family. Reads only (EI-07); never takes the mouse.

const SIZE := Vector2(30, 76)
const GAP := 8.0
const INK := Color("#2A1610")
const RIM := Color("#8A7466")
const ORANGE := Color("#FF7A2A")
const WHITE_HOT := Color("#FFF0D2")
const BURN := Color("#FF3B2A")
const COOL := Color("#7FC4E8")
const TUBE_W := 10.0
const BULB_R := 9.0
const PULSE_HZ := 3.0

## The plate this one sits over (Hud's HP corner).
var above: Control = null
var _share := 0.0
var _burning := false
var _draining := false
var _t := 0.0


func _init() -> void:
	name = "Scald"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	custom_minimum_size = SIZE
	size = SIZE
	visible = false
	set_process(false)


func sync(reader: WorldReader) -> void:
	var scald: Dictionary = reader.boss_forge().get("scald", {})
	var shown := not scald.is_empty()
	var share := ForgeHeroViews.share_of(scald)
	var burning := bool(scald.get("burning", false))
	var draining := bool(scald.get("draining", false))
	if shown != visible or share != _share or burning != _burning or draining != _draining:
		visible = shown
		_share = share
		_burning = burning
		_draining = draining
		set_process(shown and (burning or draining))
		queue_redraw()
	if visible and above != null:
		var r := above.get_global_rect()
		global_position = Vector2(r.end.x - SIZE.x - 8.0, r.position.y - SIZE.y - GAP)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## 0..1: the fill drawn.
func fill() -> float:
	return _share if visible else 0.0


## The state drawn: &"" hidden, &"burning", &"draining" or &"filling".
func state() -> StringName:
	if not visible:
		return &""
	if _burning:
		return &"burning"
	return &"draining" if _draining else &"filling"


## The fill's colour at share `s`: orange, white-hot near the top.
static func fill_color(s: float) -> Color:
	return ORANGE.lerp(WHITE_HOT, clampf((s - 0.55) / 0.45, 0.0, 1.0))


func _draw() -> void:
	if not visible:
		return
	var cx := SIZE.x * 0.5 - 3.0
	var bulb := Vector2(cx, SIZE.y - BULB_R - 2.0)
	var top := 4.0
	var tube := Rect2(cx - TUBE_W * 0.5, top, TUBE_W, bulb.y - top)
	var beat := 0.5 + 0.5 * sin(_t * TAU * PULSE_HZ) if not HudStyle.reduced_motion else 0.5
	var rim := RIM.lerp(BURN, beat) if _burning else RIM
	draw_rect(tube.grow(2.0), rim, true)
	draw_circle(bulb, BULB_R + 2.0, rim)
	draw_rect(tube, INK, true)
	draw_circle(bulb, BULB_R, INK)
	var c := fill_color(_share)
	if _share > 0.0 or _burning:
		draw_circle(bulb, BULB_R - 2.5, BURN.lerp(WHITE_HOT, beat * 0.5) if _burning else c)
	var h := (tube.size.y - 2.0) * _share
	if h > 0.5:
		var fill_r := Rect2(tube.position.x + 2.0, tube.end.y - h, TUBE_W - 4.0, h + 2.0)
		draw_rect(fill_r, c, true)
		if _draining:
			draw_rect(Rect2(fill_r.position, Vector2(fill_r.size.x, 2.0)), COOL, true)
	if _draining:
		var x := tube.end.x + 6.0
		var y := tube.position.y + tube.size.y * 0.35 + 3.0 * beat
		draw_line(Vector2(x, y - 7.0), Vector2(x, y + 4.0), COOL, 2.0, true)
		draw_line(Vector2(x - 4.0, y), Vector2(x, y + 5.0), COOL, 2.0, true)
		draw_line(Vector2(x + 4.0, y), Vector2(x, y + 5.0), COOL, 2.0, true)
