class_name BossBar
extends Control
## The boss bar (PLAN v0.3.0 C) across the top of the HUD while a boss is alive: its name, its HP, and the label over
## it ("PHASE SHIFT" through a phase change; v0.9.5 BH1: bosses have no stagger meter). Reads the sim through
## WorldReader only; hidden when no boss is alive.
## v0.3.0 BX (L22): while the boss rises the bar fills from empty to full over exactly its intro ticks
## (WorldReader.boss_intro_permille), then shows its real HP.
## v0.3.5 F15: calmer; plain type, a thin bar on a faint track, a hairline stagger meter.
## v0.5.5 A5 (Ember stone): in HudStyle.EMBER the bar sits on a stone slab with the ember line (HudStyle.draw_plate).
## v0.8.0 N2 (owner O52): under the bar, The Fallen's mimic window line (its warning, then the window and the seconds
## left; WorldReader.final_pace), empty otherwise.
## v0.8.0 N4 (owner O56, O57): the HP is a HudBar (HealthBarTrail: the damage chunk that holds from the burst's first
## hit, then drains; heals grow). One full bar per phase (WorldReader.boss_phase_permille): full at each phase's
## start, refilling (animated) when the phase changes; the line under it names the phase ("Phase 2 / 3"). The final
## boss shows one bar per body (Colossus, Prism, The Fallen) under the fight's name, the line naming the body only
## (owner O59: no count, no marks, nothing hinting how many bodies remain, so each new body is a surprise); each body's
## rise fills it (the sim's own rise, L22). Replaces FB1's three segments. While
## the sim says the boss can't be hurt (WorldReader.boss_invulnerable) the bar turns INVULNERABLE's colour and says
## "Invulnerable", with the shields still to pass (WorldReader.boss_shields_left) when there are any.

const BAR := Vector2(560, 8)
## The bar while the boss can't be hurt: a cold steel blue, far from the HP red (and from the stagger's gold).
const INVULNERABLE := Color("#8FB8E8")

var _name := Label.new()
var _hp := HudBar.new()
var _stagger_label := Label.new()
## v0.8.0 N4: the phase (or the final boss's body) line, and the invulnerable line.
var _sub := Label.new()
var _shield := Label.new()
var _boss_id := -1
var _phase_key := -1
var _invulnerable := false
## v0.8.0 N2: The Fallen's window line.
var _fallen := Label.new()


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
	_hp.name = "Hp"
	_hp.color = ThemePalette.color(&"enemy_bar")
	_hp.position = Vector2(0, 26)
	_hp.size = BAR
	add_child(_hp)
	_stagger_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_stagger_label.position = Vector2(BAR.x + 10, 26 + BAR.y - 10)
	HudStyle.style_label(_stagger_label, 14)
	add_child(_stagger_label)
	_sub.name = "PhaseLine"
	_sub.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_sub.position = Vector2(0, 26 + BAR.y + 6)
	_sub.size = Vector2(BAR.x * 0.5, 18)
	HudStyle.style_label(_sub, 13)
	add_child(_sub)
	_shield.name = "InvulnerableLine"
	_shield.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_shield.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shield.position = Vector2(BAR.x * 0.5, 26 + BAR.y + 6)
	_shield.size = Vector2(BAR.x * 0.5, 18)
	HudStyle.style_label(_shield, 14)
	_shield.add_theme_color_override("font_color", INVULNERABLE.lightened(0.25))
	add_child(_shield)
	_fallen.name = "FallenLine"
	_fallen.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_fallen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fallen.position = Vector2(-120, 26 + BAR.y + 26)
	_fallen.size = Vector2(BAR.x + 240, 22)
	HudStyle.style_label(_fallen, 16)
	_fallen.add_theme_color_override("font_color", Color(0.86, 0.66, 1.0))
	add_child(_fallen)
	visible = false
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func sync(reader: WorldReader) -> void:
	var i := reader.boss_index()
	visible = i >= 0
	if i < 0:
		_boss_id = -1
		return
	var final := reader.final_fight()
	_sync_hp(reader, i, final)
	_stagger_label.text = ""
	if reader.boss_in_gate(i):  # v0.5.5 DS (D7): the phase gate's transition
		_stagger_label.text = tr("HUD_BOSS_PHASE_SHIFT")
	if not final:
		_fallen.text = ""
		# every sync, so a language switch renames the boss at once (v0.6.0 UP)
		_name.text = tr(reader.boss_name_key(i))
		var n := reader.boss_phase_thresholds(i).size()
		_sub.text = tr("HUD_BOSS_PHASE") % [reader.boss_phase(i) + 1, n] if n > 1 else ""
		return
	# v0.8.0 FB1 / N4: the final boss: the fight's name over one bar for the body fighting now.
	_name.text = tr(reader.final_name_key())
	# owner O59: the body's name only, never a count: the bodies to come are a surprise
	_sub.text = tr(reader.final_segment_name_key(reader.final_phase()))
	if reader.final_shattering():
		_stagger_label.text = tr("HUD_FINAL_SHATTER")
	var pace := reader.final_pace()  # v0.8.0 N2 (O52): The Fallen's window
	match int(pace.get("window", WorldReader.FALLEN_OFF)):
		WorldReader.FALLEN_WARN:
			_fallen.text = tr("HUD_FALLEN_WARN")
		WorldReader.FALLEN_ON:
			_fallen.text = tr("HUD_FALLEN_WINDOW") % ceili(int(pace["window_left"]) / 60.0)
		_:
			_fallen.text = ""


## v0.8.0 N4: the bar's fill (this phase's HP, or this body's), its motion and its invulnerable look.
func _sync_hp(reader: WorldReader, i: int, final: bool) -> void:
	var frac := reader.boss_phase_permille(i) / 1000.0
	var intro := reader.boss_intro_permille(i)
	frac *= intro / 1000.0
	var id := reader.actor_id(i)
	var key := reader.boss_phase(i) + (16 * reader.final_phase() if final else 0)
	if id != _boss_id or intro < 1000:
		_hp.set_fraction(frac, true)  # a new boss or body, or its rise (the sim's own fill, L22): shown as is
	elif key != _phase_key:
		_hp.set_fraction(0.0, true)  # a new phase: the bar empties and refills to its new full (animated)
		_hp.set_fraction(frac)
	else:
		_hp.set_fraction(frac)
	_boss_id = id
	_phase_key = key
	_invulnerable = reader.boss_invulnerable(i)
	_hp.color = INVULNERABLE if _invulnerable else ThemePalette.color(&"enemy_bar")
	if not _invulnerable:
		_shield.text = ""
		return
	var left := reader.boss_shields_left(i)
	var line := tr("HUD_BOSS_INVULNERABLE")
	if left == 1:
		line += "  ·  " + tr("HUD_BOSS_SHIELD_ONE")
	elif left > 1:
		line += "  ·  " + tr("HUD_BOSS_SHIELDS") % left
	_shield.text = line


## The HP fraction the bar goes to (this phase's, 0..1; tests).
func hp_fraction() -> float:
	return _hp.fraction()


## v0.8.0 N4: the fill drawn now (a refill grows it; tests).
func shown_fraction() -> float:
	return _hp.shown_fraction()


## v0.8.0 N4: the damage chunk's share of the bar drawn now (tests).
func chunk_fraction() -> float:
	return _hp.chunk_fraction()


## v0.8.0 N4: the bar (its trail, its colour; tests and shots).
func hp_bar() -> HudBar:
	return _hp


## v0.8.0 N4: the bar shows the invulnerable look.
func invulnerable() -> bool:
	return _invulnerable


## v0.8.0 N4: the invulnerable line ("" when the boss can be hurt; tests).
func shield_text() -> String:
	return _shield.text


## v0.8.0 N4: the phase or body line (tests).
func phase_text() -> String:
	return _sub.text


## The line over the bar (PHASE SHIFT or empty; tests).
func status_text() -> String:
	return _stagger_label.text


## v0.8.0 N2: The Fallen's window line ("" none; tests).
func fallen_text() -> String:
	return _fallen.text


func boss_name() -> String:
	return _name.text


func _draw() -> void:
	if HudStyle.current == HudStyle.Style.EMBER:
		var h := 26.0 + BAR.y + 6.0 + 18.0
		HudStyle.draw_plate(self, Rect2(-18, -4, BAR.x + 36, h + 10), true)
