class_name InteractPromptHud
extends Control
## v0.9.0 IX (owner W34, W13 §13): the one shared prompt for the shared interactables (the final approach's rune
## pylons, the timed doors' switches, the puzzles to come), as the boss door's (BossDoorHud). It shows the prompt key
## of the entry the interact press would reach now (WorldReader.interact_prompt_key: the sim's own pick, so the prompt
## never names what the press won't do). Short, no explanation (the owner's style): "Awaken", "Activate". Reads only;
## the press goes out as input. (v0.9.0 FA's FinalApproachHud, generalised.)

var _prompt := InteractPrompt.new()


func _init() -> void:
	name = "InteractPrompt"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)


func sync(reader: WorldReader) -> void:
	var key := reader.interact_prompt_key()
	if key == &"":
		_prompt.hide_prompt()
		return
	var args := reader.interact_prompt_args()  # v0.9.0 SH, HF: a shrine's cost, the fountain's heal
	var line := tr(key) % args if not args.is_empty() else tr(key)
	# A state with nothing to press (Blood too weak, the dry fountain) shows its line without the button.
	_prompt.show_prompt(
		reader, line, false, Color.WHITE, key != &"SHRINE_BLOOD_LOW" and key != &"FOUNTAIN_FULL"
	)


## The prompt shown now ("" when none).
func prompt_text() -> String:
	return _prompt.text()
