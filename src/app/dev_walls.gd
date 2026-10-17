class_name DevWalls
extends RefCounted
## v0.8.0 N10 (owners O66, O67), N13 (D50): the dev panel's Walls button cycles the wall style (ViewPrefs.wall_style:
## a (the game's) / old / b (comparisons)); the floor built next (Restart floor) draws it. Here, in the app layer,
## because the debug panel never reaches presentation.


static func wire(panel: DevPanel) -> void:
	panel.show_wall_style(String(ViewPrefs.wall_style))
	panel.wall_style_requested.connect(
		func() -> void: panel.show_wall_style(String(ViewPrefs.next_wall_style()))
	)
