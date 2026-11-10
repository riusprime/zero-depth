class_name HubFlow
extends RefCounted
## How Main opens the hub, from Play, the end panel or the pause menu. A
## station's interact opens its panel (open_station; Back returns to the hub). It reads the profile, never the run's
## save. Kept apart from Main (its file stays under the length cap), like TrainingFlow.


## The hub: the stage and any menu gone, the hub session built and wired to Main, the cover opened on it.
static func open(main: Main) -> void:
	main.saves.close()
	main._end_stage()
	main._end_hub()
	main._set_menu(null)
	var repo := main._content()
	var hub := HubSession.new()
	main.hub = hub
	main.add_child(hub)
	hub.setup(
		repo, main.profile, [main.codex, main.achievements, main.codex_catalog(repo)], main.ui
	)
	hub.station_used.connect(open_station.bind(main))
	hub.options_requested.connect(main.show_options.bind(hub.open_pause))
	hub.main_menu_requested.connect(main.show_main_menu)
	hub.cue_requested.connect(main.audio.play)  # The Runic Stone's hum
	hub.training_requested.connect(TrainingFlow.enter.bind(main))  # The south door
	main.loads.cover.unveil(Main.FADE_SECONDS)
	main.audio.set_ambience(HubSession.BIOME)


## A station was used: the Portal Machine's build pick, or the Rune Archive's Codex (on its collectibles).
static func open_station(_id: StringName, panel: StringName, main: Main) -> void:
	match panel:
		&"portal":
			main.show_build_picker()
		&"codex", &"achievements":
			main.show_codex(CodexView.page_of(panel))
