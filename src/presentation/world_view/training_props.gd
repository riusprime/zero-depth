class_name TrainingProps
extends Node3D
## The Training Room's own pieces, in the hub's look (HubProps: its stone and its blue glow):
## the terminal (a stone lectern with a lit blue screen) and the way back to the hub (a blue pool on the floor between
## two low stone posts, at the room's top corner). Drawn at sim points the app hands over (TrainingRoom); the terminal
## brightens while the hero stands at it (focus). Presentation only (EI-07): it reads nothing and decides nothing.

var terminal := Node3D.new()
var exit_pad := Node3D.new()
var _screen_glow: Dictionary
var _exit_glow: Dictionary


## `terminal_at` and `exit_at` on the sim plane; `inward` the way from the exit into the room (the posts stand
## across it).
func setup(terminal_at: Vector2, exit_at: Vector2, inward: Vector2) -> void:
	name = "TrainingProps"
	terminal.name = "Terminal"
	terminal.position = SimPlane.to_3d(terminal_at)
	add_child(terminal)
	HubProps.box(
		terminal,
		"Base",
		Vector3(0.9, 0.18, 0.9),
		HubProps.stone(HubProps.STONE_DARK),
		Vector3(0, 0.09, 0)
	)
	HubProps.box(
		terminal,
		"Column",
		Vector3(0.5, 1.0, 0.5),
		HubProps.stone(HubProps.STONE),
		Vector3(0, 0.6, 0)
	)
	var top := HubProps.box(
		terminal,
		"Top",
		Vector3(0.95, 0.12, 0.7),
		HubProps.stone(HubProps.STONE_LIT),
		Vector3(0, 1.15, 0)
	)
	top.rotation.x = -0.45
	var screen := HubProps.box(
		terminal,
		"Screen",
		Vector3(0.78, 0.03, 0.52),
		HubProps.emissive(HubProps.BLUE, 2.4),
		Vector3(0, 1.22, 0.03)
	)
	screen.rotation.x = -0.45
	_screen_glow = HubProps.glow(
		terminal, "Glow", HubProps.BLUE, HubProps.BLUE_CORE, Vector3(0, 1.45, 0), 1.2
	)
	exit_pad.name = "ExitPad"
	exit_pad.position = SimPlane.to_3d(exit_at)
	add_child(exit_pad)
	HubProps.floor_pool(exit_pad, "Pool", HubProps.BLUE, Vector3(0, 0.03, 0), 2.6)
	_exit_glow = HubProps.glow(
		exit_pad, "Glow", HubProps.BLUE, HubProps.BLUE_CORE, Vector3(0, 0.9, 0), 1.4
	)
	var across := Vector2(-inward.y, inward.x) * 1.25
	for side in [-1.0, 1.0]:
		var p := SimPlane.to_3d(across * side)
		HubProps.box(
			exit_pad,
			"Post%d" % (0 if side < 0.0 else 1),
			Vector3(0.45, 1.3, 0.45),
			HubProps.stone(HubProps.STONE),
			Vector3(p.x, 0.65, p.z)
		)
	focus(false)


## The hero stands at the terminal (brighter) or not.
func focus(on: bool) -> void:
	HubProps.set_glow(_screen_glow, 1.4 if on else 0.8)
	HubProps.set_glow(_exit_glow, 0.9)
