class_name WandForecastView
extends VBoxContainer
## v0.10.5 O13 (owner P10; G2 pick A, evidence/O13_WAND_FORECAST.md): the wand forecast under the wand's row on the
## Build page and the Swap panel. A small caps title ("FORECAST", or "AFTER THE SWAP"), the spell read left to right in
## ember ("Bolt ×3 → big → burns → on hit: Bolt ×3, small size"), and its key numbers under it (shots per attack,
## damage each, damage per second, radius or reach). It shows what WorldReader.wand_forecast gives (WandForecast: the
## sim's own compile of that wand, EI-07) and decides nothing.

const TITLE_SIZE := 15
const SPELL_SIZE := 24
const NUMBERS_SIZE := 18

var _title := Label.new()
var _spell := Label.new()
var _numbers := Label.new()
var _forecast := {}


func _init() -> void:
	name = "Forecast"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	_title.name = "Title"
	_title.text = "UI_FORECAST_TITLE"
	_title.add_theme_font_override("font", HudStyle.font(true))
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_title.add_theme_color_override("font_color", MenuStyle.DIM)
	add_child(_title)
	_spell.name = "Spell"
	_spell.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_spell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spell.add_theme_font_override("font", HudStyle.font(true))
	_spell.add_theme_font_size_override("font_size", SPELL_SIZE)
	_spell.add_theme_color_override("font_color", HudStyle.EMBER_ACCENT)
	add_child(_spell)
	_numbers.name = "Numbers"
	_numbers.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_numbers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_numbers.add_theme_font_size_override("font_size", NUMBERS_SIZE)
	_numbers.add_theme_color_override("font_color", MenuStyle.TEXT)
	add_child(_numbers)
	for l: Label in [_title, _spell, _numbers]:
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))


## Shows `forecast` (WorldReader.wand_forecast; {} hides it). `after`: the Swap's title ("after the swap").
func show_forecast(forecast: Dictionary, after: bool = false) -> void:
	_forecast = forecast
	_title.text = "UI_FORECAST_AFTER" if after else "UI_FORECAST_TITLE"
	visible = not forecast.is_empty()
	_render()


func spell_text() -> String:
	return _spell.text


func numbers_text() -> String:
	return _numbers.text


## The numbers shown (WandForecast's "numbers"; {} when none).
func numbers() -> Dictionary:
	return _forecast.get("numbers", {})


func _render() -> void:
	var lines := WorldReader.wand_forecast_text(
		_forecast, func(k: StringName) -> String: return tr(k)
	)
	_spell.text = lines[0]
	_numbers.text = lines[1]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _forecast.is_empty():
		_render()
