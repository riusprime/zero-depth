class_name DevGate
extends RefCounted
## v0.7.5 SM (ROADMAP §0.4 "Public releases only: the dev panel (F10) removed or locked"; LOCKED_DECISIONS EI-07
## dev-panel row: "in all builds until the release checklist removes or locks it"): one switch for the dev panels.
## The project setting `game/dev/panel_enabled` is ON (the owner's playtest builds keep F10, owner 2026-10-12: "All
## builds, hidden key"). project.godot also holds `game/dev/panel_enabled.public_release=false`, so an export preset
## that adds the custom feature `public_release` ships with F10 (and the debug-only ` panel) locked; nothing else
## changes. No preset has that feature yet.

const SETTING := "game/dev/panel_enabled"
## The export feature tag that locks the panels (project.godot's override).
const RELEASE_FEATURE := "public_release"


## The dev panels open in this build.
static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, true))
