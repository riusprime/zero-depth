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


static func color(role: StringName) -> Color:
	return ROLES.get(role, UNKNOWN)
