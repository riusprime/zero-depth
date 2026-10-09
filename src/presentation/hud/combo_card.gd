class_name ComboCard
extends ItemCard
## The card a named combo shows when it unlocks (v0.3.0 G): the item card's plaque and motion (v0.6.1 R1: the
## crystal plaque nearest the combo's own colour, Plaques.nearest) and both items' icons (ComboIconView) in place of
## one. It shows text it is given (already translated); it decides nothing about the game.

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
	show_item(id, title, sentence, c, caption, Plaques.nearest(c))
	icon.visible = false


## The two item ids the card shows ([] when hidden).
func pair_ids() -> Array[StringName]:
	if not is_showing():
		return []
	return [pair.item_a, pair.item_b]
