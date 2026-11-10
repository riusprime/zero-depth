class_name ViewPrefs
extends RefCounted
## Presentation-only preferences from the profile's settings: reduced motion and the colour-blind mode.
## They change how things look, never an outcome (EI-07). Main applies them at boot and whenever Options changes one.

## Reduced motion: no camera shake at all, and hit bursts throw half the sparks.
static var reduced_motion := false
## The attack effects' density (Options "Effects density": low / medium / high): AttackFormView scales its
## particles and its per-frame mesh cap by it. Looks only.
static var effects_density := "high"
## The Blade's hit-stop (HitStop: the hero's swing and the struck enemy held ~2 frames on a
## Blade hit, in the view only). Options -> Accessibility "Hit-stop"; reduced motion turns it off too.
static var hit_stop := true
## How a normal or elite enemy casts its shadow (EnemyShadows.MODES): "proxy", one
## shadow-only mesh shaped like it, or "blob", a soft disc on the floor. Read when an enemy is built. Not in Options
## yet (the owner picks from the shots); GameSettings key "enemy_shadows".
static var enemy_shadows := "proxy"
## The VatCrowd.KINDS enemies (W3-V4a: every kind it lists)
## drawn as one MultiMesh per look posed from baked textures (VatCrowd) instead of a node per piece. On by default
## (owner, 2026-11-06: "Yes, make it default"); "off" is the old path. GameSettings key "enemy_vat", the launch flag
## `-- --enemy-vat=on|off` over it, and the dev panel's switch (rebuilds those enemies at once).
static var enemy_vat := false  # until apply_settings reads the profile (the game: on unless "off")


static func apply_settings(profile: ProfileStore) -> void:
	DebugApi.register_view_switch(
		&"enemy_vat", "UI_DEV_ENEMY_VAT", flip_enemy_vat, func() -> bool: return enemy_vat
	)
	reduced_motion = String(GameSettings.get_value(profile, "reduced_motion")) == "on"
	HudStyle.reduced_motion = reduced_motion  # Steady HUD pulses
	var d := String(GameSettings.get_value(profile, "effects_density"))
	effects_density = d if GameSettings.EFFECTS_DENSITIES.has(d) else "high"
	hit_stop = String(GameSettings.get_value(profile, "hit_stop")) != "off"
	var es := String(GameSettings.get_value(profile, "enemy_shadows"))
	enemy_shadows = es if EnemyShadows.MODES.has(es) else "proxy"
	enemy_vat = String(GameSettings.get_value(profile, "enemy_vat")) != "off"
	for a in OS.get_cmdline_user_args():  # The launch flag wins (a logged A/B run)
		if a.begins_with("--enemy-vat="):
			enemy_vat = a.trim_prefix("--enemy-vat=") == "on"
	var m := StringName(String(GameSettings.get_value(profile, "colour_mode")))
	ThemePalette.mode = m if ThemePalette.MODES.has(m) else &"off"


## The dev panel's enemy VAT switch (ActorViews rebuilds those enemies on its next sync).
static func flip_enemy_vat() -> void:
	enemy_vat = not enemy_vat


## How many of `n` sparks a burst throws.
static func sparks(n: int) -> int:
	return maxi(1, (n + 1) / 2) if reduced_motion else n


## Whether a Blade hit holds the views (the option on, reduced motion off).
static func hit_stop_on() -> bool:
	return hit_stop and not reduced_motion
