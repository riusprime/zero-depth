class_name ViewPrefs
extends RefCounted
## Presentation-only preferences from the profile's settings (v0.3.0 O): reduced motion and the colour-blind mode.
## They change how things look, never an outcome (EI-07). Main applies them at boot and whenever Options changes one.

## Reduced motion: no camera shake at all, and hit bursts throw half the sparks.
static var reduced_motion := false
## v0.6.0 MX3: the attack effects' density (Options "Effects density": low / medium / high): AttackFormView scales its
## particles and its per-frame mesh cap by it. Looks only.
static var effects_density := "high"
## v0.8.0 GF3 (owner O22): the Blade's hit-stop (HitStop: the hero's swing and the struck enemy held ~2 frames on a
## Blade hit, in the view only). Options -> Accessibility "Hit-stop"; reduced motion turns it off too.
static var hit_stop := true


static func apply_settings(profile: ProfileStore) -> void:
	reduced_motion = String(GameSettings.get_value(profile, "reduced_motion")) == "on"
	HudStyle.reduced_motion = reduced_motion  # v0.3.0 UI: steady HUD pulses
	var d := String(GameSettings.get_value(profile, "effects_density"))
	effects_density = d if GameSettings.EFFECTS_DENSITIES.has(d) else "high"
	hit_stop = String(GameSettings.get_value(profile, "hit_stop")) != "off"
	var m := StringName(String(GameSettings.get_value(profile, "colour_mode")))
	ThemePalette.mode = m if ThemePalette.MODES.has(m) else &"off"


## How many of `n` sparks a burst throws.
static func sparks(n: int) -> int:
	return maxi(1, (n + 1) / 2) if reduced_motion else n


## v0.8.0 GF3: whether a Blade hit holds the views (the option on, reduced motion off).
static func hit_stop_on() -> bool:
	return hit_stop and not reduced_motion
