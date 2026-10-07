class_name ViewPrefs
extends RefCounted
## Presentation-only preferences from the profile's settings (v0.3.0 O): reduced motion and the colour-blind mode.
## They change how things look, never an outcome (EI-07). Main applies them at boot and whenever Options changes one.

## Reduced motion: no camera shake at all, and hit bursts throw half the sparks.
static var reduced_motion := false


static func apply_settings(profile: ProfileStore) -> void:
	reduced_motion = String(GameSettings.get_value(profile, "reduced_motion")) == "on"
	HudStyle.reduced_motion = reduced_motion  # v0.3.0 UI: steady HUD pulses, no glitch echoes
	var m := StringName(String(GameSettings.get_value(profile, "colour_mode")))
	ThemePalette.mode = m if ThemePalette.MODES.has(m) else &"off"


## How many of `n` sparks a burst throws.
static func sparks(n: int) -> int:
	return maxi(1, (n + 1) / 2) if reduced_motion else n
