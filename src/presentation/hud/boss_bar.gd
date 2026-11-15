class_name BossBar
extends Control
## The boss bar (PLAN v0.3.0 C) across the top of the HUD while a boss is alive: its name, its HP and its phase
## ("Phase 2 / 3"). Reads the sim through WorldReader only; hidden when no boss is alive.
## No state in words (the owner: a fight's mechanics are found by playing, from arrows, glows, colour and motion): each
## state the sim reports is a tone of the fill (BossBarTones): the phase gate breathes pale, a boss that takes more
## damage now shimmers hot gold, one that can't be hurt turns steel blue with a pip under the bar's right end for each
## shield still to pass, the Hive Lens fed by its drones turns a muted rose with a pink pip for each drone feeding it,
## the Lantern Shade's bar darkens in the dark and turns lantern gold in a lit pool, The Fallen's mimic window breathes
## violet as it comes and shimmers violet while open.
## While the boss rises the bar fills from empty to full over exactly its intro ticks
## (WorldReader.boss_intro_permille), then shows its real HP.
## The HP is a HudBar (HealthBarTrail: the damage chunk that holds from the burst's first
## hit, then drains; heals grow). One full bar per phase (WorldReader.boss_phase_permille): full at each phase's
## start, refilling (animated) when the phase changes. The final
## boss shows one bar per body (Colossus, Prism, The Fallen) under the fight's name, the line naming the body only
## (owner O59: no count, no marks, nothing hinting how many bodies remain, so each new body is a surprise); each body's
## rise fills it (the sim's own rise, L22).
## UI style Astral: no slab: the name in letter-spaced Cinzel between two stars
## and fading hairlines, a small crescent over it, and the bar as one continuous fill in a hairline frame
## (AstralHudParts.bar) in the colour mode's enemy colour; the phase line under it in Cinzel, Astral's tones.

const BAR := Vector2(560, 8)
## The shields' pips under the bar's right end (px).
const PIP_R := 4.0
const PIP_GAP := 6.0

var _name := Label.new()
var _hp := HudBar.new()
## The phase (or the final boss's body) line.
var _sub := Label.new()
var _boss_id := -1
var _phase_key := -1
var _invulnerable := false
## The light's per-mille shown (WorldReader.boss_light_permille; 1000 none).
var _light := 1000
## The fill's tone now (BossBarTones), the shields still to pass (pips), and the pulse's clock (s, a look only).
var _tone := BossBarTones.NONE
var _pips := 0
var _clock := 0.0


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
	_sub.name = "PhaseLine"
	_sub.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_sub.position = Vector2(0, 26 + BAR.y + 6)
	_sub.size = Vector2(BAR.x * 0.5, 22)
	HudStyle.style_label(_sub, 13)
	add_child(_sub)
	visible = false
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudStyle.serif_label(_name, 18, 5, HudStyle.A_TEXT)
	# The line under the bar in Cinzel too, in Astral's tones (no violet, no steel)
	HudStyle.serif_label(_sub, 16, 3, HudStyle.A_DIM)
	_sub.size.y = 22
	_name.resized.connect(queue_redraw)


func sync(reader: WorldReader) -> void:
	var i := reader.boss_index()
	visible = i >= 0
	if i < 0:
		_boss_id = -1
		_tone = BossBarTones.NONE
		return
	var final := reader.final_fight()
	_sync_hp(reader, i, final)
	var was := _tone
	_tone = BossBarTones.tone_of(reader, i, final)
	var pips := reader.boss_shields_left(i) if _invulnerable else 0
	if _tone == BossBarTones.FED:
		pips = BossBarTones.feeders(reader, i)
	if pips != _pips or (was != _tone and pips > 0):
		_pips = pips
		queue_redraw()
	_paint()
	if not final:
		# every sync, so a language switch renames the boss at once
		_set_name(tr(reader.boss_name_key(i)))
		var n := reader.boss_phase_thresholds(i).size()
		_sub.text = tr("HUD_BOSS_PHASE") % [reader.boss_phase(i) + 1, n] if n > 1 else ""
		return
	# v0.8.0 FB1 / N4: the final boss: the fight's name over one bar for the body fighting now.
	_set_name(tr(reader.final_name_key()))
	# owner O59: the body's name only, never a count: the bodies to come are a surprise
	_sub.text = tr(reader.final_segment_name_key(reader.final_phase()))


func _process(delta: float) -> void:
	if not visible or _tone == BossBarTones.NONE:
		return
	_clock += delta
	_paint()


## The fill's colour for the tone now (a pulsing tone pulses with the clock).
func _paint() -> void:
	_hp.color = BossBarTones.color_of(
		_tone, ThemePalette.color(&"enemy_bar"), _clock, HudStyle.reduced_motion
	)


## The name (a new one redraws the name's ornaments; an unchanged one writes nothing).
func _set_name(t: String) -> void:
	if _name.text != t:
		_name.text = t
		queue_redraw()


## The bar's fill (this phase's HP, or this body's) and its motion.
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
	_light = 1000 if _invulnerable else reader.boss_light_permille(i)


## The fill's tone now (BossBarTones: NONE, PHASE_SHIFT, VULNERABLE, INVULNERABLE, DARK, LIT, FALLEN_WARN,
## FALLEN_OPEN; tests and shots).
func tone() -> StringName:
	return _tone


## The pips drawn under the bar: the shields still to pass, or the drones feeding the Hive Lens (0 otherwise; tests).
func shield_pips() -> int:
	return _pips


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


## The phase or body line (tests).
func phase_text() -> String:
	return _sub.text


func boss_name() -> String:
	return _name.text


## The bar's lowest line's bottom (px, in its parent; Hud stacks the phase line under it).
func bottom() -> float:
	return position.y + _sub.position.y + _sub.get_combined_minimum_size().y


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
	# A pip for each shield still to pass (or each drone feeding the Hive Lens), right-aligned under the bar
	var pip := BossBarTones.LENS_PIP if _tone == BossBarTones.FED else BossBarTones.STEEL
	for k in _pips:
		var p := Vector2(BAR.x - PIP_R - k * (PIP_R * 2.0 + PIP_GAP), 26 + BAR.y + 10 + PIP_R)
		draw_circle(p, PIP_R, pip)
		draw_arc(p, PIP_R + 1.5, 0.0, TAU, 16, Color(HudStyle.A_INK, 0.8), 1.0, true)
