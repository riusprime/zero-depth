class_name CardFlights
extends Control
## v0.8.0 N8 (owner O62, "when it's picked, its icon flies to its slot on the HUD"): the layer the picked cards'
## icons fly over (CardFly), and where each lands: the HUD slot the card went to, read from the sim after the take
## (EI-07: it only reads):
## - an ability card: its ability square when it has one (Blink, Aegis; AbilitySquares), else the HP plate;
## - a card in the wand (a wand card, a modifier): its pip in the build row (BuildHud);
## - a mod held outside the wand: its icon in the carried row, bottom right;
## - anything else (a stat card, a curse): the HP plate.
## Under reduced motion nothing flies.

var squares: AbilitySquares
var build: BuildHud
var items: Control
var plate: Control


func _init() -> void:
	name = "CardFlights"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Flies card `code`'s icon from `from` (global px) to its HUD slot. Returns the flight (null under reduced motion).
func launch(reader: WorldReader, code: int, from: Rect2) -> CardFly:
	if HudStyle.reduced_motion or reader == null:
		return null
	var info := reader.card_info(code)
	var id: StringName = info["id"]
	var c := (
		ItemLooks.color_of_id(id)
		if int(info["type"]) == WorldReader.CARD_MOD
		else AbilityIcons.color(id)
	)
	var start := Rect2(from.get_center() - from.size * 0.3, from.size * 0.6)  # the icon, not its socket
	var f := CardFly.new(id, c, start, slot_rect_for(reader, code))
	add_child(f)
	return f


## The HUD rect (global px) card `code` landed in (see the class comment).
func slot_rect_for(reader: WorldReader, code: int) -> Rect2:
	var info := reader.card_info(code)
	if int(info["type"]) == WorldReader.CARD_ABILITY and squares != null:
		var sq := squares.rect_of(&"blink")
		if sq.size.x > 0.0 and (info["id"] == &"blink" or info["id"] == &"aegis"):
			return sq
	if build != null and build.is_visible_in_tree():
		var slots: Array = reader.build()["slots"]
		for k in slots.size():
			if int(slots[k]["code"]) == code and k < WorldReader.MOD_SLOTS:
				return build.pip_rect(k)
	if int(info["type"]) == WorldReader.CARD_MOD and items != null:
		var owned := reader.items_owned()
		var at := owned.find(code)
		if at >= 0 and at < items.get_child_count():
			return (items.get_child(at) as Control).get_global_rect()
	if plate != null:
		return plate.get_global_rect()
	return Rect2(Vector2(40, get_viewport_rect().size.y - 120), Vector2(60, 60))


func flying() -> int:
	return get_child_count()
