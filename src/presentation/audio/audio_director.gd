class_name AudioDirector
extends Node
## Plays the game's sounds (PLAN v0.3.0 L27, presentation only, EI-07): world SFX from AudioEvents after every
## tick, the biome's ambience loop with a crossfade on a floor change, menu sounds, and the caption line. Voices
## are limited per cue (SfxMixer); each play is pitched a little by presentation's own RNG; world sounds are
## panned by where they happen on screen; boss telegraphs duck the world sounds so the warning reads.
## A file named like a cue in user://audio_override/ or res://assets/audio/override/ (.wav or .ogg) replaces the
## shipped one (docs/audio/README.md). Every cue's sound loads ahead, on a loader thread from boot, and a floor's
## build waits for what is left (AudioStreamBank); sounds play on players made once (AudioVoicePool), so a busy
## fight frame neither reads the disk nor makes nodes.

const CUES_DIR := "res://data/audio/cues"
const BUS_NAMES := {&"sfx": "SFX", &"ui": "UI", &"ambience": "Ambience"}
## How far the sfx bus drops under a ducking cue, and how fast it moves (dB per second). Starting values.
const DUCK_DB := -9.0
const DUCK_RATE_DB := 60.0
## Ambience crossfade length on a floor change (seconds, starting value).
const AMBIENCE_FADE_S := 1.5
const SILENT_DB := -60.0
## A menu focus move right after a confirm or back is the new menu taking focus: no tick on top.
const UI_MOVE_QUIET_S := 0.12
## How long a caption stays up (seconds).
const CAPTION_S := 2.5
const LOG_MAX := 256
## The held sounds the game turns on and off in a fight (the Laser's hum): their players are made at boot.
const HELD_CUES: Array[StringName] = [&"laser_loop"]

## Cue id -> AudioCueDefinition.
var cues := {}
## Every cue that was allowed to play, newest last (tests read it; trimmed to LOG_MAX).
var played_log: Array[StringName] = []
var mixer := SfxMixer.new()
var events := AudioEvents.new()
var profile: ProfileStore
## The caption line's text while one is up ("" when none).
var caption_text := ""
## Captions follow the profile's "captions" setting; tests may force them.
var captions_forced := -1

var _reader: WorldReader
var _now := 0.0
var _rng := RandomNumberGenerator.new()
var _bank := AudioStreamBank.new()
var _pool := AudioVoicePool.new()
var _duck_until := 0.0
var _duck_db := 0.0
var _ambience_id := &""
var _amb_players: Array[AudioStreamPlayer] = []
var _amb_target: Array[float] = [SILENT_DB, SILENT_DB]
var _amb_active := 0
var _ui_quiet_until := -1.0
var _caption_until := 0.0
var _caption_layer := CanvasLayer.new()
var _caption_label := Label.new()
## The held sounds playing now (cue id -> its looping player; hold()).
var _held := {}
## Cue id -> the looping player its held sound uses, made on its first hold and kept.
var _held_players := {}


func _init() -> void:
	name = "Audio"
	_rng.seed = 7  # presentation's own stream: pitch jitter never touches the sim (EI-05)
	for path in ContentScanner.scan(CUES_DIR):
		var c := load(path) as AudioCueDefinition
		if c != null:
			cues[c.id] = c


func _ready() -> void:
	GameSettings.ensure_buses()
	for k in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Ambience%d" % k
		p.bus = BUS_NAMES[&"ambience"]
		p.volume_db = SILENT_DB
		add_child(p)
		_amb_players.append(p)
	_build_caption()
	_bank.warm(cues)
	_pool.build(self, cues)
	for id in HELD_CUES:
		if cues.has(id):
			_held_player(id)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	get_tree().node_added.connect(_on_node_added)


func setup(p_profile: ProfileStore) -> void:
	profile = p_profile


## A floor starts: its sounds come from `reader` from now on, and its biome's loop fades in.
func attach(reader: WorldReader, biome: StringName) -> void:
	finish_warm()
	_reader = reader
	events.prime(reader)
	set_ambience(biome)
	play(&"floor_enter")


## Waits for every cue's sound still loading (a floor's build, behind its cover).
func finish_warm() -> void:
	_bank.finish()


func detach() -> void:
	_reader = null
	for id: StringName in _held.keys():
		hold(id, false)


## The Laser's `laser_loop`: a held sound, one looping voice of cue `id` while `on`; it starts once (logged
## in played_log) and stops when `on` goes false. A missing file plays nothing.
func hold(id: StringName, on: bool) -> void:
	var p: AudioStreamPlayer = _held.get(id)
	if not on:
		if p != null:
			_held.erase(id)
			p.stop()
		return
	if p != null:
		return
	var cue: AudioCueDefinition = cues.get(id)
	if cue == null:
		return
	p = _held_player(id)
	p.stream = _bank.looped_stream(id, cue)
	p.volume_db = cue.volume_db
	p.bus = BUS_NAMES[cue.bus]
	_held[id] = p
	_log(id)
	if is_inside_tree() and p.stream != null:
		p.play()


func _held_player(id: StringName) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = _held_players.get(id)
	if p == null:
		p = AudioStreamPlayer.new()
		p.name = "Held_%s" % id
		_held_players[id] = p
		add_child(p)
	return p


## Whether held sound `id` is on now (tests).
func holding(id: StringName) -> bool:
	return _held.has(id)


## Called after every tick (SimDriver.ticked); a reader from a floor already left is ignored.
func sync(reader: WorldReader = null) -> void:
	if _reader == null or (reader != null and reader != _reader):
		return
	for req: Array in events.collect(_reader):
		play(req[0], req[1], req[2])
	hold(&"laser_loop", _reader.beam_firing())  # The beam's hum while it fires


func _process(delta: float) -> void:
	advance(delta)


## Moves the director's clock: voices end, the duck and the ambience fade move, the caption times out.
func advance(delta: float) -> void:
	_now += delta
	_bank.poll()
	var duck_target := DUCK_DB if _now < _duck_until else 0.0
	_duck_db = move_toward(_duck_db, duck_target, DUCK_RATE_DB * delta)
	var sfx_bus := AudioServer.get_bus_index(BUS_NAMES[&"sfx"])
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, _duck_db)
	var step := (0.0 - SILENT_DB) * delta / AMBIENCE_FADE_S
	for k in _amb_players.size():
		var p := _amb_players[k]
		p.volume_db = move_toward(p.volume_db, _amb_target[k], step)
		if p.playing and _amb_target[k] <= SILENT_DB and p.volume_db <= SILENT_DB:
			p.stop()
	if caption_text != "" and _now >= _caption_until:
		caption_text = ""
		_caption_layer.visible = false


## Plays cue `id` (at sim-plane `pos` when given; null = not positional), unless its voice limit or cooldown
## refuses. Returns whether it was allowed. A cue whose file is missing still shows its caption.
func play(id: StringName, pos: Variant = null, pitch: float = 1.0) -> bool:
	var cue: AudioCueDefinition = cues.get(id)
	if cue == null:
		return false
	if id == &"ui_move" and _now < _ui_quiet_until:
		return false
	if not mixer.allows(cue, _now):
		return false
	var stream := stream_for(id)
	var ps := pitch * (1.0 + _rng.randf_range(-cue.pitch_jitter, cue.pitch_jitter))
	var seconds := (stream.get_length() / ps) if stream != null else 0.5
	mixer.note_play(cue, _now, seconds)
	if cue.duck:
		_duck_until = maxf(_duck_until, _now + seconds)
	if id == &"ui_confirm" or id == &"ui_back":
		_ui_quiet_until = _now + UI_MOVE_QUIET_S
	if cue.caption_key != &"":
		show_caption(cue.caption_key)
	_log(id)
	if stream != null and is_inside_tree():
		var panned := pos is Vector2 and cue.bus == &"sfx"
		var at := SimPlane.to_3d(pos, 0.5) if panned else Vector3.ZERO
		_pool.start(stream, cue.volume_db, ps, BUS_NAMES[cue.bus], panned, at, _now, seconds)
	return true


func _log(id: StringName) -> void:
	played_log.append(id)
	if played_log.size() > LOG_MAX:
		played_log.pop_front()


## The stream for cue `id`: an override file when one exists, else the shipped file (loaded ahead).
func stream_for(id: StringName) -> AudioStream:
	return _bank.stream(id, cues.get(id))


## How many players the one-shot sounds have, and how many sound at the director's clock now (tests).
func voice_pool_size() -> int:
	return _pool.size()


func voices_busy() -> int:
	return _pool.busy(_now)


## Fades the biome loop `biome` in (and the current one out) over AMBIENCE_FADE_S; &"" fades to silence.
func set_ambience(biome: StringName) -> void:
	if biome == _ambience_id:
		return
	_ambience_id = biome
	_amb_target[_amb_active] = SILENT_DB
	var cue: AudioCueDefinition = cues.get(biome)
	if cue == null or cue.kind != &"ambience" or _amb_players.is_empty():
		return
	_amb_active = 1 - _amb_active
	var p := _amb_players[_amb_active]
	p.stream = stream_for(biome)
	p.volume_db = SILENT_DB
	_amb_target[_amb_active] = cue.volume_db
	if p.stream != null:
		p.play()


func ambience_id() -> StringName:
	return _ambience_id


## The ambience player that is fading in or holding (tests read its stream and volume).
func ambience_player() -> AudioStreamPlayer:
	return _amb_players[_amb_active] if not _amb_players.is_empty() else null


func captions_on() -> bool:
	if captions_forced >= 0:
		return captions_forced == 1
	return profile != null and String(GameSettings.get_value(profile, "captions")) == "on"


func show_caption(key: StringName) -> void:
	if not captions_on():
		return
	caption_text = tr(key)
	_caption_label.text = caption_text
	_caption_layer.visible = true
	_caption_until = _now + CAPTION_S


func _build_caption() -> void:
	_caption_layer.name = "Captions"
	_caption_layer.layer = 40
	_caption_layer.visible = false
	add_child(_caption_layer)
	var panel := PanelContainer.new()
	panel.name = "CaptionPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -24
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.04, 0.06, 0.72)
	bg.set_content_margin_all(6)
	bg.content_margin_left = 14
	bg.content_margin_right = 14
	panel.add_theme_stylebox_override("panel", bg)
	_caption_label.name = "Caption"
	_caption_label.add_theme_font_size_override("font_size", 18)
	_caption_label.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_caption_label)
	_caption_layer.add_child(panel)


# --- menus ---------------------------------------------------------------------------------------------------


func _on_focus_changed(_c: Control) -> void:
	play(&"ui_move")


## Every button in the game confirms with a sound; one named "Back" goes back.
func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta(&"ui_sfx"):
		n.set_meta(&"ui_sfx", true)
		(n as BaseButton).pressed.connect(_on_button_pressed.bind(n))


func _on_button_pressed(b: BaseButton) -> void:
	play(&"ui_back" if b.name == &"Back" else &"ui_confirm")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and get_viewport().gui_get_focus_owner() != null:
		play(&"ui_back")
