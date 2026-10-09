class_name Minimap
extends Control
## The minimap (PLAN v0.3.0 MM, owner L30): a corner map under the shard counter that reveals rooms as you enter
## them, and the full map while the map action is held (Tab / pad Select). Both draw one MinimapState; the HUD calls
## sync() each tick. Presentation only: it reads WorldReader and the held action, and decides nothing.

const ACTION := &"map"

var state := MinimapState.new()
var corner := MinimapView.new(false)
var full_map := MinimapView.new(true)
var _reader: WorldReader


func _init() -> void:
	name = "MinimapRoot"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for v: MinimapView in [corner, full_map]:
		v.state = state
		add_child(v)
	corner.visible = false


func sync(reader: WorldReader) -> void:
	_reader = reader
	corner.reader = reader
	full_map.reader = reader
	state.update(reader)
	_show()


func _process(_delta: float) -> void:
	_show()


## The full map is up while the action is held; the corner map otherwise. Neither without a floor.
func full_map_showing() -> bool:
	return full_map.visible


func _show() -> void:
	var on_floor := _reader != null and _reader.has_floor() and not _reader.minimap_blind()  # CU
	var held := on_floor and InputMap.has_action(ACTION) and Input.is_action_pressed(ACTION)
	full_map.visible = held
	corner.visible = on_floor and not held
	corner.refresh()
	full_map.refresh()
