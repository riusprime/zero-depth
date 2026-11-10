class_name FpsCounter
extends CanvasLayer
## The frames-per-second readout in the top-right corner, above the HUD and the menus. It only reads the engine's
## frame rate, a few times a second so it neither costs anything nor flickers; while off it is hidden and idle.

const SETTING := "show_fps"
const REFRESH_SECONDS := 0.25
const MARGIN_RIGHT := 28
const MARGIN_TOP := 2
const FONT_SIZE := 18

var _label: Label
var _since := 0.0


func _init() -> void:
	name = "FpsCounter"
	layer = 100
	_label = HudStyle.label(FONT_SIZE)
	_label.name = "Value"
	HudStyle.font_color(_label, HudStyle.dim())
	_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.offset_right = -MARGIN_RIGHT
	_label.offset_top = MARGIN_TOP
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_label)
	_set_on(false)


## Follows the profile's Show FPS setting.
func apply(profile: ProfileStore) -> void:
	_set_on(GameSettings.get_value(profile, SETTING) == "on")


func shown_text() -> String:
	return _label.text


func _set_on(on: bool) -> void:
	visible = on
	set_process(on)
	if on:
		_refresh()


func _process(delta: float) -> void:
	_since += delta
	if _since >= REFRESH_SECONDS:
		_since = 0.0
		_refresh()


func _refresh() -> void:
	_label.text = tr("UI_FPS_VALUE") % int(Engine.get_frames_per_second())
