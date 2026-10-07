class_name BossBar
extends Control
## The boss bar (PLAN v0.3.0 C) across the top of the HUD while a boss is alive: its name, its HP with a mark at each
## later phase's threshold, and its stagger meter under it (bright and labelled while it is staggered). Reads the
## sim through WorldReader only; hidden when no boss is alive.
## v0.3.0 BX (L22): while the boss rises the bar fills from empty to full over exactly its intro ticks
## (WorldReader.boss_intro_permille), then shows its real HP.

const BAR := Vector2(640, 18)
const STAGGER := Vector2(640, 7)

var _name := Label.new()
var _hp_back := ColorRect.new()
var _hp_fill := ColorRect.new()
var _stagger_back := ColorRect.new()
var _stagger_fill := ColorRect.new()
var _stagger_label := Label.new()
var _marks: Array[ColorRect] = []
var _boss_key := &""


func _init() -> void:
	name = "BossBar"
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	position = Vector2(-BAR.x * 0.5, 92)
	custom_minimum_size = Vector2(BAR.x, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.name = "BossName"
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.size = Vector2(BAR.x, 28)
	_name.add_theme_font_size_override("font_size", 24)
	add_child(_name)
	_hp_back.color = Color(0, 0, 0, 0.6)
	_hp_back.position = Vector2(0, 32)
	_hp_back.size = BAR
	add_child(_hp_back)
	_hp_fill.name = "Hp"
	_hp_fill.color = ThemePalette.color(&"enemy_bar")
	_hp_fill.size = BAR
	_hp_back.add_child(_hp_fill)
	_stagger_back.color = Color(0, 0, 0, 0.6)
	_stagger_back.position = Vector2(0, 32 + BAR.y + 4)
	_stagger_back.size = STAGGER
	add_child(_stagger_back)
	_stagger_fill.name = "Stagger"
	_stagger_fill.color = Color("#E8C15A")
	_stagger_fill.size = Vector2(0, STAGGER.y)
	_stagger_back.add_child(_stagger_fill)
	_stagger_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_stagger_label.position = Vector2(BAR.x + 10, 32 + BAR.y - 6)
	_stagger_label.add_theme_font_size_override("font_size", 16)
	add_child(_stagger_label)
	visible = false
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func sync(reader: WorldReader) -> void:
	var i := reader.boss_index()
	visible = i >= 0
	if i < 0:
		return
	var key := reader.boss_name_key(i)
	if key != _boss_key:
		_boss_key = key
		_name.text = tr(key)
		_build_marks(reader.boss_phase_thresholds(i))
	var frac := clampf(float(reader.actor_hp(i)) / maxf(1.0, reader.actor_max_hp(i)), 0.0, 1.0)
	frac *= reader.boss_intro_permille(i) / 1000.0
	_hp_fill.size = Vector2(BAR.x * frac, BAR.y)
	var st := reader.boss_stagger_permille(i)
	var staggered := reader.boss_staggered(i)
	_stagger_fill.size = Vector2(STAGGER.x * st / 1000.0, STAGGER.y)
	_stagger_fill.color = Color("#FFE38A") if staggered else Color("#E8C15A")
	_stagger_label.text = tr("HUD_BOSS_STAGGERED") if staggered else ""


## The HP fraction shown (tests).
func hp_fraction() -> float:
	return _hp_fill.size.x / BAR.x


## The stagger fraction shown (tests).
func stagger_fraction() -> float:
	return _stagger_fill.size.x / STAGGER.x


func boss_name() -> String:
	return _name.text


func _build_marks(thresholds: PackedInt32Array) -> void:
	for m in _marks:
		m.queue_free()
	_marks.clear()
	for k in range(1, thresholds.size()):
		var m := ColorRect.new()
		m.color = Color(1, 1, 1, 0.7)
		m.size = Vector2(2, BAR.y)
		m.position = Vector2(BAR.x * thresholds[k] / 1000.0 - 1.0, 0)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hp_back.add_child(m)
		_marks.append(m)
