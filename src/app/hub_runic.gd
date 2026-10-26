class_name HubRunic
extends Node
## v0.9.5 RS1 (RUNIC_STONE.md): the Runic Stone while the hub runs. HubSession hands it the tick (where the hero
## stands) and the interact press at the stone; it asks RunicStone (the profile's learned lines, the 7-press rule),
## draws through HubView (the veins, the pulse) and RuneBubble (the speech), and asks for the hum through
## `cue_requested` (Main plays it). Locked: no prompt, a faint "..." bubble, the press only hums. Awake: the prompt
## reads "Read", the press opens the newest line in runes, the next press the next one (round again), and walking
## away closes it. Nothing here touches a run or the sim; the profile is saved when a line is learned.

signal cue_requested(id: StringName, pos: Variant, pitch: float)

const STATION := &"runic"
## The low cue played by a press on the locked stone: the Void's hum, slowed.
const HUM_CUE := &"void_hum"
const HUM_PITCH := 0.55
const READ_KEY := &"HUB_PROMPT_RUNIC_READ"

var stone: RunicStone
var bubble := RuneBubble.new()
var session: HubSession


## `stores` = HubSession.setup's [CodexStore, AchievementStore, CodexCatalog].
func setup(p_session: HubSession, stores: Array) -> void:
	name = "HubRunic"
	session = p_session
	var lines: RunicLinesDefinition = session.repo.get_def(&"runic_lines", &"main")
	stone = RunicStone.new(session.profile, lines)
	if not stone.sync_from(stores[1], stores[0]).is_empty():
		session.profile.save_file()
	session.ui.add_child(bubble)
	session.view.set_runic(stone.is_awake())
	if stone.pending_pulse:  # S5: a line learned since the last visit: the stone pulses once on entry
		stone.pending_pulse = false
		session.view.pulse_runic()


func _exit_tree() -> void:
	if bubble != null and is_instance_valid(bubble):
		bubble.queue_free()


## The station's prompt keys at the stone: its name, and "Read" only while awake (none locked).
func keys(at: StringName, base: Array[StringName]) -> Array[StringName]:
	if at != STATION:
		return base
	return [base[0], READ_KEY if stone.is_awake() else &""]


## After every hub tick, with the station the hero stands at.
func tick(at: StringName) -> void:
	if at == STATION:
		if not stone.is_awake() and not bubble.is_open():
			bubble.show_dots()
	elif bubble.is_open():
		bubble.close()
		stone.walked_away()


## The interact press at the stone.
func press() -> void:
	if not stone.is_awake():
		cue_requested.emit(HUM_CUE, null, HUM_PITCH)
		return
	var learned := stone.press(session.driver.reader.tick())
	if learned:  # R3: the stone pulses and speaks the new line
		session.profile.save_file()
		session.view.pulse_runic()
		stone.pending_pulse = false
	var id := stone.read_next()
	bubble.show_line(RuneCipher.encode(stone.english(id)))


func _process(_delta: float) -> void:
	if not bubble.is_open() or session == null or session.view == null:
		return
	var cam := session.view.rig.camera
	var top := session.view.runic_top()
	if cam != null and not cam.is_position_behind(top):
		bubble.anchor_px = cam.unproject_position(top)
