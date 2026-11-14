class_name BossBar
extends Control
## The boss bar (PLAN v0.3.0 C) across the top of the HUD while a boss is alive: its name, its HP, and the label over
## it ("PHASE SHIFT" through a phase change; "STUNNED · VULNERABLE" while a broken quake pillar stuns
## the Gatekeeper; bosses have no stagger meter). Reads the sim through
## WorldReader only; hidden when no boss is alive.
## While the boss rises the bar fills from empty to full over exactly its intro ticks
## (WorldReader.boss_intro_permille), then shows its real HP.
## Calmer; plain type, a thin bar on a faint track, a hairline stagger meter.
## Under the bar, The Fallen's mimic window line (its warning, then the window and the seconds
## left; WorldReader.final_pace), empty otherwise.
## The HP is a HudBar (HealthBarTrail: the damage chunk that holds from the burst's first
## hit, then drains; heals grow). One full bar per phase (WorldReader.boss_phase_permille): full at each phase's
## start, refilling (animated) when the phase changes; the line under it names the phase ("Phase 2 / 3"). The final
## boss shows one bar per body (Colossus, Prism, The Fallen) under the fight's name, the line naming the body only
## (owner O59: no count, no marks, nothing hinting how many bodies remain, so each new body is a surprise); each body's
## rise fills it (the sim's own rise, L22). Replaces FB1's three segments. While
## the sim says the boss can't be hurt (WorldReader.boss_invulnerable) the bar turns INVULNERABLE's colour and says
## "Invulnerable", with the shields still to pass (WorldReader.boss_shields_left) when there are any.
## UI style Astral: no slab: the name in letter-spaced Cinzel between two stars
## and fading hairlines, a small crescent over it, and the bar as one continuous fill in a hairline frame
## (AstralHudParts.bar) in the colour mode's enemy colour; the lines under it in Atkinson. Same reads.
## The lines under the bar (the phase, Invulnerable, The Fallen's window) in Cinzel, Astral's tones.

const BAR := Vector2(560, 8)
## The bar while the boss can't be hurt: a cold steel blue, far from the HP red (and from the stagger's gold).
const INVULNERABLE := Color("#8FB8E8")
## The Lantern Shade's bar in the dark (the HP colour darkened by DIM) and in a lit pool (lantern gold).
const DIM := 0.55
const LIT := Color("#FFC15A")
## The Twin Wardens' bar owner per phase (the line under the bar).
const TWIN_LEADS: Array[String] = [
	"HUD_TWIN_LEADS_AMBER", "HUD_TWIN_LEADS_VIOLET", "HUD_TWIN_LEADS_BOTH"
]

var _name := Label.new()
var _hp := HudBar.new()
var _stagger_label := Label.new()
## The phase (or the final boss's body) line, and the invulnerable line.
var _sub := Label.new()
var _shield := Label.new()
var _boss_id := -1
var _phase_key := -1
var _invulnerable := false
## The light's per-mille shown (WorldReader.boss_light_permille; 1000 none).
var _light := 1000
## The Fallen's window line.
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
	HudStyle.serif_label(_name, 18, 5, HudStyle.A_TEXT)
	HudStyle.serif_label(_stagger_label, 13, 3, HudStyle.A_ACCENT)
	# The lines under the bar in Cinzel too, in Astral's tones (no violet, no steel)
	HudStyle.serif_label(_sub, 16, 3, HudStyle.A_DIM)
	HudStyle.serif_label(_shield, 16, 3, HudStyle.A_ACCENT)
	HudStyle.serif_label(_fallen, 18, 4, HudStyle.A_LINE_HI)
	for l: Label in [_sub, _shield]:
		l.size.y = 22
	_name.resized.connect(queue_redraw)


func sync(reader: WorldReader) -> void:
	var i := reader.boss_index()
	visible = i >= 0
	if i < 0:
		_boss_id = -1
		return
	var final := reader.final_fight()
	_sync_hp(reader, i, final)
	_stagger_label.text = ""
	if reader.boss_in_gate(i):  # The phase gate's transition
		_stagger_label.text = tr("HUD_BOSS_PHASE_SHIFT")
	elif reader.boss_stunned(i):  # Q9 a: a broken quake pillar stunned it (it takes more damage)
		_stagger_label.text = tr("HUD_BOSS_STUNNED")
	if not final:
		_fallen.text = ""
		# every sync, so a language switch renames the boss at once
		_set_name(tr(reader.boss_name_key(i)))
		var n := reader.boss_phase_thresholds(i).size()
		_sub.text = tr("HUD_BOSS_PHASE") % [reader.boss_phase(i) + 1, n] if n > 1 else ""
		_twin_lines(reader, i)
		return
	# v0.8.0 FB1 / N4: the final boss: the fight's name over one bar for the body fighting now.
	_set_name(tr(reader.final_name_key()))
	# owner O59: the body's name only, never a count: the bodies to come are a surprise
	_sub.text = tr(reader.final_segment_name_key(reader.final_phase()))
	if reader.final_shattering():
		_stagger_label.text = tr("HUD_FINAL_SHATTER")
	var pace := reader.final_pace()  # The Fallen's window
	match int(pace.get("window", WorldReader.FALLEN_OFF)):
		WorldReader.FALLEN_WARN:
			_fallen.text = tr("HUD_FALLEN_WARN")
		WorldReader.FALLEN_ON:
			_fallen.text = tr("HUD_FALLEN_WINDOW") % ceili(int(pace["window_left"]) / 60.0)
		_:
			_fallen.text = ""


## The Twin Wardens' bar names whose bar it is (the amber Warden's, the violet's, both),
## and in their last phase which one is exposed now.
func _twin_lines(reader: WorldReader, i: int) -> void:
	var twin := reader.boss_twin(i)
	if twin.is_empty():
		return
	var ph := int(twin.get("phase", 0))
	_sub.text += "  ·  " + tr(TWIN_LEADS[clampi(ph, 0, TWIN_LEADS.size() - 1)])
	if ph >= 2 and _stagger_label.text == "":
		_stagger_label.text = tr(
			"HUD_TWIN_EXPOSED_AMBER" if twin.get("exposed", false) else "HUD_TWIN_EXPOSED_VIOLET"
		)


## The name (a new one redraws the name's ornaments; an unchanged one writes nothing).
func _set_name(t: String) -> void:
	if _name.text != t:
		_name.text = t
		queue_redraw()


## The bar's fill (this phase's HP, or this body's), its motion and its invulnerable look.
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
	_light = 1000 if _invulnerable else reader.boss_light_permille(i)
	if not _invulnerable:
		# The Lantern Shade's light: a dim bar and "In the dark · 40 %" in the dark, a bright
		# one and "In the light · 150 %" in a lit lantern's pool; nothing at 100 %.
		if _light < 1000:
			_hp.color = ThemePalette.color(&"enemy_bar").darkened(DIM)
			_shield.text = tr("HUD_SHADE_DARK") % (_light / 10)
		elif _light > 1000:
			_hp.color = LIT
			_shield.text = tr("HUD_SHADE_LIT") % (_light / 10)
		else:
			_shield.text = ""
		return
	var left := reader.boss_shields_left(i)
	var line := tr("HUD_BOSS_INVULNERABLE")
	if left == 1:
		line += "  ·  " + tr("HUD_BOSS_SHIELD_ONE")
	elif left > 1:
		line += "  ·  " + tr("HUD_BOSS_SHIELDS") % left
	_shield.text = line


## The label over the bar ("PHASE SHIFT", v0.11.0 O5: the Wardens' exposed one; tests).
func status_line() -> String:
	return _stagger_label.text


## The HP fraction the bar goes to (this phase's, 0..1; tests).
func hp_fraction() -> float:
	return _hp.fraction()


## The fill drawn now (a refill grows it; tests).
func shown_fraction() -> float:
	return _hp.shown_fraction()


## The damage chunk's share of the bar drawn now (tests).
func chunk_fraction() -> float:
	return _hp.chunk_fraction()


## The bar (its trail, its colour; tests and shots).
func hp_bar() -> HudBar:
	return _hp


## The bar shows the invulnerable look.
func invulnerable() -> bool:
	return _invulnerable


## The Lantern Shade's light per-mille the bar shows (1000: none; tests).
func light_permille() -> int:
	return _light


## The invulnerable line ("" when the boss can be hurt; tests).
func shield_text() -> String:
	return _shield.text


## The phase or body line (tests).
func phase_text() -> String:
	return _sub.text


## The line over the bar (PHASE SHIFT or empty; tests).
func status_text() -> String:
	return _stagger_label.text


## The Fallen's window line ("" none; tests).
func fallen_text() -> String:
	return _fallen.text


func boss_name() -> String:
	return _name.text


## The bar's lowest line's bottom (px, in its parent; Hud stacks the phase line under it).
func bottom() -> float:
	var low: Label = _fallen if _fallen.text != "" else _sub
	return position.y + low.position.y + low.get_combined_minimum_size().y


func _draw() -> void:
	# The name's stars and rules, a crescent over it
	var f := _name.get_theme_font(&"font")
	var tw := f.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var cx := roundf(BAR.x * 0.5)
	var y := 13.5
	for sx: float in [-1.0, 1.0]:
		var ox := roundf(cx + sx * (tw * 0.5 + 22.0)) + 0.5
		AstralChrome.star4(self, Vector2(ox, y), 6.0, HudStyle.A_METAL, 0.2)
		AstralChrome.rule1(self, ox + sx * 12.0, 13.0, sx * 96.0, Color(HudStyle.A_METAL, 0.6))
	AstralChrome.crescent(self, Vector2(cx + 0.5, -6.0), 5.0, Color(HudStyle.A_METAL, 0.85))
