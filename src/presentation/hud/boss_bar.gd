class_name BossBar
extends Control
## The boss bar (PLAN v0.3.0 C) across the top of the HUD while a boss is alive: its name, its HP with a mark at each
## later phase's threshold, and its stagger meter under it (bright and labelled while it is staggered). Reads the
## sim through WorldReader only; hidden when no boss is alive.
## v0.3.0 BX (L22): while the boss rises the bar fills from empty to full over exactly its intro ticks
## (WorldReader.boss_intro_permille), then shows its real HP.
## v0.3.5 F15: calmer; plain type, a thin bar on a faint track, a hairline stagger meter.
## v0.5.5 A5 (Ember stone): in HudStyle.EMBER the bar sits on a stone slab with the ember line (HudStyle.draw_plate).
## v0.8.0 FB1 (owner O16; FINAL_BOSS.md F3): the final boss is one bar split in three named segments (its bodies), under
## the fight's name: a body already beaten is an empty segment, the one fighting is its HP (empty while it shatters,
## filling as the next rises), the ones to come are full; "SHATTERED" shows through the shatter.

const BAR := Vector2(560, 8)
const STAGGER := Vector2(560, 3)

var _name := Label.new()
var _hp_back := ColorRect.new()
var _hp_fill := ColorRect.new()
var _stagger_back := ColorRect.new()
var _stagger_fill := ColorRect.new()
var _stagger_label := Label.new()
var _marks: Array[ColorRect] = []
var _boss_key := &""
## v0.8.0 FB1: the final boss's segments (fills and names), built when a fight shows.
var _segments: Array[ColorRect] = []
var _segment_names: Array[Label] = []


func _init() -> void:
	name = "BossBar"
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	position = Vector2(-BAR.x * 0.5, 100)
	custom_minimum_size = Vector2(BAR.x, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.name = "BossName"
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.size = Vector2(BAR.x, 24)
	HudStyle.style_label(_name, 18)
	add_child(_name)
	_hp_back.color = Color(0, 0, 0, 0.42)
	_hp_back.position = Vector2(0, 26)
	_hp_back.size = BAR
	add_child(_hp_back)
	_hp_fill.name = "Hp"
	_hp_fill.color = ThemePalette.color(&"enemy_bar")
	_hp_fill.size = BAR
	_hp_back.add_child(_hp_fill)
	_stagger_back.color = Color(0, 0, 0, 0.35)
	_stagger_back.position = Vector2(0, 26 + BAR.y + 3)
	_stagger_back.size = STAGGER
	add_child(_stagger_back)
	_stagger_fill.name = "Stagger"
	_stagger_fill.color = Color("#E8C15A")
	_stagger_fill.size = Vector2(0, STAGGER.y)
	_stagger_back.add_child(_stagger_fill)
	_stagger_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_stagger_label.position = Vector2(BAR.x + 10, 26 + BAR.y - 10)
	HudStyle.style_label(_stagger_label, 14)
	add_child(_stagger_label)
	visible = false
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func sync(reader: WorldReader) -> void:
	var i := reader.boss_index()
	visible = i >= 0
	if i < 0:
		return
	if reader.final_fight():  # v0.8.0 FB1: one bar, three bodies
		_sync_final(reader, i)
		return
	_show_segments(0)
	var key := reader.boss_name_key(i)
	if key != _boss_key:
		_boss_key = key
		_build_marks(reader.boss_phase_thresholds(i))
	_name.text = tr(key)  # every sync, so a language switch renames the boss at once (v0.6.0 UP)
	var frac := clampf(float(reader.actor_hp(i)) / maxf(1.0, reader.actor_max_hp(i)), 0.0, 1.0)
	frac *= reader.boss_intro_permille(i) / 1000.0
	_hp_fill.size = Vector2(BAR.x * frac, BAR.y)
	var st := reader.boss_stagger_permille(i)
	var staggered := reader.boss_staggered(i)
	_stagger_fill.size = Vector2(STAGGER.x * st / 1000.0, STAGGER.y)
	_stagger_fill.color = Color("#FFE38A") if staggered else Color("#E8C15A")
	_stagger_label.text = tr("HUD_BOSS_STAGGERED") if staggered else ""
	if reader.boss_in_gate(i):  # v0.5.5 DS (D7): the phase gate's transition
		_stagger_label.text = tr("HUD_BOSS_PHASE_SHIFT")


## v0.8.0 FB1: the final boss's bar: the fight's name, a segment per body with its name under it, the current body's
## stagger meter, and its status (SHATTERED through a shatter, PHASE SHIFT through its own gate).
func _sync_final(reader: WorldReader, i: int) -> void:
	var n := reader.final_phases()
	if _segments.size() != n or _boss_key != reader.final_name_key():
		_boss_key = reader.final_name_key()
		_build_marks(PackedInt32Array())
		_build_segments(n)
	_show_segments(n)
	_name.text = tr(_boss_key)
	_hp_fill.size = Vector2.ZERO
	var w := (BAR.x - 6.0 * (n - 1)) / maxf(1.0, n)
	var cur := reader.final_phase()
	for k in n:
		var f := reader.final_segment_permille(k) / 1000.0
		_segments[k].size = Vector2(w * f, BAR.y)
		_segment_names[k].text = tr(reader.final_segment_name_key(k))
		_segment_names[k].modulate.a = 1.0 if k == cur else 0.55
	var st := reader.boss_stagger_permille(i)
	var staggered := reader.boss_staggered(i)
	_stagger_fill.size = Vector2(STAGGER.x * st / 1000.0, STAGGER.y)
	_stagger_label.text = tr("HUD_BOSS_STAGGERED") if staggered else ""
	if reader.boss_in_gate(i):
		_stagger_label.text = tr("HUD_BOSS_PHASE_SHIFT")
	if reader.final_shattering():
		_stagger_label.text = tr("HUD_FINAL_SHATTER")


func _build_segments(n: int) -> void:
	for c: Control in _segments:
		var back := c.get_parent()
		back.get_parent().remove_child(back)
		back.queue_free()
	for c: Control in _segment_names:
		remove_child(c)
		c.queue_free()
	_segments.clear()
	_segment_names.clear()
	var w := (BAR.x - 6.0 * (n - 1)) / maxf(1.0, n)
	for k in n:
		var back := ColorRect.new()
		back.name = "Segment%d" % k
		back.color = Color(0, 0, 0, 0.42)
		back.position = Vector2(k * (w + 6.0), 26)
		back.size = Vector2(w, BAR.y)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(back)
		var fill := ColorRect.new()
		fill.color = ThemePalette.color(&"enemy_bar")
		fill.size = Vector2(w, BAR.y)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_child(fill)
		_segments.append(fill)
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(k * (w + 6.0), 26 + BAR.y + 6)
		label.size = Vector2(w, 18)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		HudStyle.style_label(label, 13)
		add_child(label)
		_segment_names.append(label)


## The plain bar's track shows without segments; the segments only in a final fight.
func _show_segments(n: int) -> void:
	_hp_back.visible = n == 0
	for k in _segments.size():
		(_segments[k].get_parent() as Control).visible = n > 0
		_segment_names[k].visible = n > 0


## v0.8.0 FB1: the fill of the final boss's segment k shown (0..1; tests).
func segment_fraction(k: int) -> float:
	if k < 0 or k >= _segments.size():
		return 0.0
	var w := (_segments[k].get_parent() as Control).size.x
	return _segments[k].size.x / maxf(1.0, w)


## v0.8.0 FB1: the segments shown (0 outside a final fight).
func segment_count() -> int:
	return _segments.size() if _hp_back.visible == false else 0


## The HP fraction shown (tests).
func hp_fraction() -> float:
	return _hp_fill.size.x / BAR.x


## The line beside the stagger meter (STAGGERED, PHASE SHIFT or empty; tests).
func status_text() -> String:
	return _stagger_label.text


## The stagger fraction shown (tests).
func stagger_fraction() -> float:
	return _stagger_fill.size.x / STAGGER.x


func boss_name() -> String:
	return _name.text


func _draw() -> void:
	if HudStyle.current == HudStyle.Style.EMBER:
		var h := 26.0 + BAR.y + 3.0 + STAGGER.y
		HudStyle.draw_plate(self, Rect2(-18, -4, BAR.x + 36, h + 16), true)


func _build_marks(thresholds: PackedInt32Array) -> void:
	for m in _marks:
		_hp_back.remove_child(m)  # out now, so the last boss's marks don't draw beside the new ones this frame
		m.queue_free()
	_marks.clear()
	for k in range(1, thresholds.size()):
		var m := ColorRect.new()
		m.color = Color(1, 1, 1, 0.55)
		m.size = Vector2(2, BAR.y)
		m.position = Vector2(BAR.x * thresholds[k] / 1000.0 - 1.0, 0)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hp_back.add_child(m)
		_marks.append(m)
