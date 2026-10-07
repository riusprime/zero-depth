class_name ItemLooks
extends RefCounted
## One colour per item kind, used by the pedestal gem, the HUD list and the attack visuals it changes
## (PLAN v0.2.0 "Items": every item changes how you attack *and* how you look).

const COLORS := {
	WorldReader.ITEM_LONG_EDGE: Color("#7FE7FF"),
	WorldReader.ITEM_TWIN_ARC: Color("#B9A7FF"),
	WorldReader.ITEM_EMBER_EDGE: Color("#FF7A3D"),
	WorldReader.ITEM_SPLINTER_SHOT: Color("#9DFF8A"),
	WorldReader.ITEM_RAPID_COIL: Color("#FFE36A"),
	WorldReader.ITEM_RICOCHET_CORE: Color("#FFFFFF"),
	WorldReader.ITEM_KINETIC_DASH: Color("#4FD8FF"),
	WorldReader.ITEM_OVERCHARGE: Color("#FF5FD2"),
}


static func color(kind: int) -> Color:
	return COLORS.get(kind, Color.WHITE)
