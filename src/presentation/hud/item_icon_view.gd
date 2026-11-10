class_name ItemIconView
extends Control
## One item's symbol (ItemIcons) as a Control, optionally on a small dark rounded tile.

var item_id := &""
var color := Color.WHITE
var tile := false
## Shapes drawn the last time this redrew (tests read it).
var drawn := 0


func _init(p_id: StringName = &"", p_color: Color = Color.WHITE, p_tile := false) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_item(p_id, p_color)
	tile = p_tile


func set_item(id: StringName, c: Color) -> void:
	item_id = id
	color = c
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var col := HudStyle.tone(color)  # Toward Astral's silver
	if tile:  # Astral's tile
		HudStyle.draw_astral_tile(self, r, color)
		r = r.grow(-size.x * 0.16)
	drawn = ItemIcons.draw(self, item_id, r, col)
