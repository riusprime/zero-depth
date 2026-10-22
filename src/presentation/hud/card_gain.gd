class_name CardGain
extends RefCounted
## v0.8.0 N8 (owner O62: "below, what gets better, with the old value and the new one … the upgrade numbers count up
## from the old value"): the line under a reward card's icon. Its numbers are the sim's own forecast
## (WorldReader.card_forecast: the same steps the take runs), so the card says what you get:
## - a stat card: "100% → 112%" (per mille as percent), max HP "100 → 110 HP";
## - an ability or a wand card: "Level 2 → 3", or "New · Level 1" for one not held;
## - any other card: no line.
## While a card is hovered or focused its new number counts up from the old one (value_at; COUNT_S); under reduced
## motion it shows the new number at once. Presentation only (EI-07).

const COUNT_S := 0.45


## The gain has a line to show.
static func shows(gain: Dictionary) -> bool:
	return int(gain.get("kind", WorldReader.GAIN_NONE)) != WorldReader.GAIN_NONE


## The new number `t` (0..1) of the way through the count-up: the old value at 0, the forecast's new value at 1
## (eased, rounded toward the old one so it never overshoots).
static func value_at(gain: Dictionary, t: float) -> int:
	var a := int(gain.get("old", 0))
	var b := int(gain.get("new", 0))
	if t >= 1.0:
		return b
	var e := 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 2.0)
	return a + int((b - a) * e)


## The line, translated through `ci`, with the new number at `value` (value_at).
static func text(ci: Object, gain: Dictionary, value: int) -> String:
	var old := int(gain.get("old", 0))
	match int(gain.get("kind", WorldReader.GAIN_NONE)):
		WorldReader.GAIN_LEVEL:
			if old <= 0:
				return ci.tr("UI_GAIN_LEVEL_NEW") % maxi(value, 1)
			return ci.tr("UI_GAIN_LEVEL") % [old, value]
		WorldReader.GAIN_HP:
			return ci.tr("UI_GAIN_HP") % [old, value]
		WorldReader.GAIN_PERMILLE:
			return ci.tr("UI_GAIN_ARROW") % [percent(ci, old), percent(ci, value)]
	return ""


## The full line (the forecast's new value).
static func final_text(ci: Object, gain: Dictionary) -> String:
	return text(ci, gain, int(gain.get("new", 0)))


static func percent(ci: Object, permille: int) -> String:
	return ci.tr("UI_GAIN_PERCENT") % GambleIcons.percent(permille)
