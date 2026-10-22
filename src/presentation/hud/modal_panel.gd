class_name ModalPanel
extends Control
## What the modal choice panels share (audit P-11): the pick, event, shop and swap panels. Each opens and closes from
## the sim's state, shows what the sim offers and sends the player's answer as input (`picked` -> InputLatch.note_pick
## -> InputFrame.pick); none decides anything (EI-07).

signal picked(value: int)

## Off while a menu (pause) or another panel sits over this one.
var input_enabled := true
var _open := false
## An answer went out: the panel waits for the sim (each panel says when it takes input again).
var _sent := false
var _focus := 0


func is_open() -> bool:
	return _open


func focus_index() -> int:
	return _focus


## Sends one answer as input.
func _send(value: int) -> void:
	_sent = true
	picked.emit(value)


## While the sim's choice is not open (`open_now` false): closes the panel if it was open and returns true (the
## caller's sync stops there).
func _closed(open_now: bool) -> bool:
	if open_now:
		return false
	if _open:
		_open = false
		_sent = false
		visible = false
		_on_closed()
	return true


## A panel's own clean-up when it closes.
func _on_closed() -> void:
	pass


## The dim over the game (it takes the clicks the panel doesn't), `alpha` dark.
func _add_dim(dim: ColorRect, alpha: float) -> void:
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, alpha)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)


## The panel's column, centred on the screen, its rows `separation` px apart.
func _centred_column(col: VBoxContainer, separation: int) -> VBoxContainer:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", separation)
	centre.add_child(col)
	return col


## Centred, already translated (the panel words them) and click-through.
static func style_labels(labels: Array) -> void:
	for l: Label in labels:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
