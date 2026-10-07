class_name ThemePalette
extends RefCounted
## Fixed actor tokens (docs/art/ART_DIRECTION.md §2). Biome tokens live in BiomeDefinition.palette.
## Adapted from Deathventory's closed role table: an unknown role is magenta, so it shows up at once.

## The UI theme. Main applies it to the window at boot: as a project setting it would load before a fresh
## checkout's first import has produced the font, and that import would report errors.
const UI_THEME := "res://src/presentation/theme/default_theme.tres"
const ROLES := {
	&"player_body": Color("#F2F2F2"),
	&"player_core": Color("#2BC4E2"),
	&"player_bar": Color("#F2F2F2"),
	&"enemy_body": Color("#E25A4C"),
	&"enemy_bar": Color("#DF3731"),
	&"proj_hostile": Color("#FBD07A"),
	&"telegraph_hostile": Color("#FF6A3D"),
	&"hazard": Color("#E0892B"),
}
const UNKNOWN := Color(1, 0, 1)
## Colour-blind modes (v0.3.0 O; starting values): role overrides per mode, picked so the roles that must read apart
## (player, enemy, telegraph, hostile shot, hazard, the HP bars) stay apart under that deficiency's simulation
## (tests/unit/presentation/test_colour_modes.gd). Protanopia and deuteranopia share a blue / amber / white set.
const RED_GREEN := {
	&"player_core": Color("#1E64FF"),
	&"enemy_body": Color("#D98E04"),
	&"enemy_bar": Color("#D98E04"),
	&"proj_hostile": Color("#FFE500"),
	&"telegraph_hostile": Color("#F2F2F2"),
	&"hazard": Color("#8A5CFF"),
}
const MODES := {
	&"protanopia": RED_GREEN,
	&"deuteranopia": RED_GREEN,
	&"tritanopia":
	{
		&"player_core": Color("#19B8B0"),
		&"enemy_body": Color("#E0303A"),
		&"enemy_bar": Color("#E0303A"),
		&"proj_hostile": Color("#FFFFFF"),
		&"telegraph_hostile": Color("#FF8FA8"),
		&"hazard": Color("#C02AA8"),
	},
}

## The active colour-blind mode (&"off" or a MODES key). Views read colours when they build, so a change shows on
## the next floor (the Options screen says so).
static var mode := &"off"


static func color(role: StringName) -> Color:
	var over: Dictionary = MODES.get(mode, {})
	if over.has(role):
		return over[role]
	return ROLES.get(role, UNKNOWN)
