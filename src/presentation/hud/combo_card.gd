class_name ComboCard
extends ItemCard
## The card a named combo shows when it unlocks (v0.3.0 G): the item card's style and motion with a special frame
## (v0.3.5 F16: a thin, even outline in the combo's colour; no shadow, no side bar) and both items' icons
## (ComboIconView) in place of one. It shows text it is given (already translated); it decides nothing about the game.

var pair := ComboIconView.new()


func _init() -> void:
	super()
	name = "ComboCard"
	icon.visible = false
	pair.custom_minimum_size = Vector2(ICON, ICON)
	pair.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := icon.get_parent()
	row.add_child(pair)
	row.move_child(pair, 0)


## Shows combo `id` (items `a` and `b`) with an already-translated `title`, `sentence` and `caption`.
func show_combo(
	id: StringName, a: StringName, b: StringName, title: String, sentence: String, caption: String
) -> void:
	var c := ItemLooks.combo_color(id)
	pair.set_combo(a, b, c)
	show_item(id, title, sentence, c, caption)
	icon.visible = false
	CardStyle.apply(_box, c, true)
	if CardStyle.current != CardStyle.Look.RULE:
		_box.border_color = Color(c, 0.9)


## The two item ids the card shows ([] when hidden).
func pair_ids() -> Array[StringName]:
	if not is_showing():
		return []
	return [pair.item_a, pair.item_b]
