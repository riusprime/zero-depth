class_name StarboundHud
extends HBoxContainer
## v0.10.5 W3-P10b (owner W7, V3: "Echo Cast, Rising Edge and Fervour add nothing in the world, only a stack count
## on the HUD's buff row"): the buff row of the three Starbound cards that build up, at the bottom right above the
## combo row (LIFT). Each held card is its icon (AstralCardArt.icon: icon_<card id>, else icon_unknown) and a number:
## Rising Edge the crits and Fervour the kills counted since the room was cleared, Echo Cast its stacks. A card not
## held, or a counter at 0, shows nothing. Reads only (EI-07); numbers only, no words.

const ICON := 32.0
## Its bottom edge above the screen's, over the item row and the combo row (Hud).
const LIFT := Hud.ITEMS_LIFT + 2 * (Hud.ROW_ICON + 12)
## The cards shown, in order (WorldReader.STARBOUND_*).
const SHOWN: Array[int] = [
	WorldReader.STARBOUND_RISING_EDGE,
	WorldReader.STARBOUND_ECHO_CAST,
	WorldReader.STARBOUND_FERVOUR
]

var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var _boxes: Array[HBoxContainer] = []


func _init() -> void:
	name = "StarboundRow"
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 12)
	for k in SHOWN.size():
		var box := HBoxContainer.new()
		box.name = "Starbound%d" % SHOWN[k]
		box.add_theme_constant_override("separation", 4)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(ICON, ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = AstralCardArt.STARBOUND_BLUE.lerp(Color.WHITE, 0.4)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var count := Label.new()
		count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # a number
		count.add_theme_font_size_override("font_size", HudStyle.MIN_LABEL)
		count.add_theme_color_override("font_color", AstralCardArt.STARBOUND_BLUE.lightened(0.3))
		count.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		count.add_theme_constant_override("outline_size", 3)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		box.add_child(count)
		box.visible = false
		add_child(box)
		_icons.append(icon)
		_counts.append(count)
		_boxes.append(box)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -28
	offset_right = -28
	offset_top = -LIFT
	offset_bottom = -LIFT


func sync(reader: WorldReader) -> void:
	var sb := reader.starbound()
	var cards: Array = sb["cards"]
	for k in SHOWN.size():
		var card := SHOWN[k]
		var n := 0
		var id := &""
		if card < cards.size():
			var c: Dictionary = cards[card]
			id = c["id"]
			if int(c["picks"]) > 0:
				match card:
					WorldReader.STARBOUND_RISING_EDGE:
						n = int(sb["crits"])
					WorldReader.STARBOUND_FERVOUR:
						n = int(sb["kills"])
					_:
						n = int(c["stacks"])
		_boxes[k].visible = n > 0
		if n > 0:
			if _icons[k].texture == null:
				_icons[k].texture = AstralCardArt.icon(id)
			_counts[k].text = str(n)


## Card `card`'s number shown now ("" when hidden; the tests).
func count_text(card: int) -> String:
	var k := SHOWN.find(card)
	return _counts[k].text if k >= 0 and _boxes[k].visible else ""
