class_name PlaqueBox
extends StoneBox
## A wide stone plaque (Plaques) as a style box (v0.6.1 R1 as the owner's crystal plaques; v0.8.0 MU, owner O14, a
## carved Ember stone slab, StoneBox): chipped edges, the ember glow under it, and a glowing inlay groove along its
## foot in the plaque's colour (a family's, CardFrames), with a gold rim inlay on the gold plaque (an epic card, the
## banner). It fits any width and height; its content margins put the text inside, clear of the groove. `focused`
## lights it (the glow grows, the lower edge lights up); an unfocused plaque is drawn a little dimmer.
## Presentation only (EI-07).

## Margins as shares of the plaque's height: the sides, the top, and the foot (which holds the groove).
const SIDE := 0.2
const TOP := 0.16
const FOOT := 0.22
## The groove's height above the foot, as a share of the height.
const GROOVE := 0.11

var plaque := &"amber"
## The plaque's height (px); its margins follow it.
var height := 100.0
var pad := 0.0
var focused := true


func _init(p_plaque: StringName = &"amber", p_height: float = 100.0, p_pad: float = 0.0) -> void:
	height = p_height
	pad = p_pad
	cut = clampf(p_height * 0.14, 6.0, 16.0)
	chip = clampf(p_height * 0.03, 1.5, 3.5)
	pattern = int(p_height * 13.0) % 97
	cracks = 2
	_margins()
	set_plaque(p_plaque)
	_apply()


func set_plaque(p: StringName) -> void:
	plaque = p
	inlay = Plaques.tint(p)
	inlay_y = height * GROOVE
	rim = EmberStone.GOLD if p == &"gold" else Color(0, 0, 0, 0)


func set_focused(on: bool) -> void:
	if on == focused:
		return
	focused = on
	_apply()


## The face's brightness now (1 focused, Plaques.IDLE otherwise).
func tint() -> float:
	return dim


## The smallest a host should be (px): wide enough for the cut corners and the groove.
func natural_size() -> Vector2:
	return Vector2(height * 2.0, height)


## The content margins of a plaque `h` px tall with `p` px of extra side padding: left, top, right, bottom.
static func margins(h: float, p: float = 0.0) -> Vector4:
	return Vector4(h * SIDE + p, h * TOP, h * SIDE + p, h * FOOT)


func _apply() -> void:
	focus = 1.0 if focused else 0.0
	under = 0.3
	dim = 1.0 if focused else Plaques.IDLE


func _margins() -> void:
	var m := margins(height, pad)
	content_margin_left = m.x
	content_margin_top = m.y
	content_margin_right = m.z
	content_margin_bottom = m.w
