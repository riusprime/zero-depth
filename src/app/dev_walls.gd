class_name DevWalls
extends RefCounted
## v0.8.0 N10 (owners O66, O67; G2 prototype): the dev panel's Walls button cycles the wall style
## (ViewPrefs.wall_style: auto / old / a / b); the floor built next (Restart floor) draws it. Here, in the app layer,
## because the debug panel never reaches presentation.


static func wire(panel: DevPanel) -> void:
	panel.show_wall_style(String(ViewPrefs.wall_style))
	panel.wall_style_requested.connect(
		func() -> void: panel.show_wall_style(String(ViewPrefs.next_wall_style()))
	)
