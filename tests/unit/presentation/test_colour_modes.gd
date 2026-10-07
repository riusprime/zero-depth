extends GutTest
## Colour-blind modes and reduced motion (v0.3.0 O). Each mode's palette keeps the roles that must read apart at
## least MIN_DELTA_E apart (CIE76, in Lab) after simulating that deficiency (Machado, Oliveira and Fernandes 2009,
## severity 1.0, applied in linear RGB). The default palette under normal vision is the reference: its closest
## pair (enemy body vs telegraph) sits at about 19.

const MIN_DELTA_E := 25.0
const SIM := {
	&"protanopia":
	[
		[0.152286, 1.052583, -0.204868],
		[0.114503, 0.786281, 0.099216],
		[-0.003882, -0.048116, 1.051998]
	],
	&"deuteranopia":
	[
		[0.367322, 0.860646, -0.227968],
		[0.280085, 0.672501, 0.047413],
		[-0.011820, 0.042940, 0.968881]
	],
	&"tritanopia":
	[
		[1.255528, -0.076749, -0.178779],
		[-0.078411, 0.930809, 0.147602],
		[0.004733, 0.691367, 0.303900]
	],
}
## Roles that must never be confused.
const PAIRS := [
	[&"player_core", &"enemy_body"],
	[&"player_core", &"telegraph_hostile"],
	[&"player_core", &"proj_hostile"],
	[&"enemy_body", &"telegraph_hostile"],
	[&"telegraph_hostile", &"proj_hostile"],
	[&"enemy_body", &"proj_hostile"],
	[&"hazard", &"telegraph_hostile"],
	[&"player_bar", &"enemy_bar"],
]


func after_each() -> void:
	ThemePalette.mode = &"off"
	ViewPrefs.reduced_motion = false


static func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func _lab(c: Color, m: Array) -> Vector3:
	var l := [_lin(c.r), _lin(c.g), _lin(c.b)]
	var s := []
	for r in 3:
		s.append(clampf(m[r][0] * l[0] + m[r][1] * l[1] + m[r][2] * l[2], 0.0, 1.0))
	var x: float = (0.4124 * s[0] + 0.3576 * s[1] + 0.1805 * s[2]) / 0.95047
	var y: float = 0.2126 * s[0] + 0.7152 * s[1] + 0.0722 * s[2]
	var z: float = (0.0193 * s[0] + 0.1192 * s[1] + 0.9505 * s[2]) / 1.08883
	var f := func(t: float) -> float:
		return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	return Vector3(
		116.0 * f.call(y) - 16.0, 500.0 * (f.call(x) - f.call(y)), 200.0 * (f.call(y) - f.call(z))
	)


func _closest(mode: StringName, m: Array) -> Array:
	ThemePalette.mode = mode
	var best := [1e9, ""]
	for p: Array in PAIRS:
		var d := _lab(ThemePalette.color(p[0]), m).distance_to(_lab(ThemePalette.color(p[1]), m))
		if d < best[0]:
			best = [d, "%s/%s" % p]
	return best


func test_each_mode_keeps_the_roles_apart_under_its_simulation() -> void:
	for mode: StringName in SIM:
		var got := _closest(mode, SIM[mode])
		assert_gte(got[0], MIN_DELTA_E, "%s: closest pair %s at %.1f" % [mode, got[1], got[0]])


func test_the_default_palette_is_what_the_modes_fix() -> void:
	# Without a mode, deuteranopia and tritanopia bring some pairs far closer than the reference: the reason for
	# the modes. If this ever passes the bar, the modes need a second look.
	var deut := _closest(&"off", SIM[&"deuteranopia"])
	var trit := _closest(&"off", SIM[&"tritanopia"])
	assert_lt(deut[0], MIN_DELTA_E, "deuteranopia, default palette: %s %.1f" % [deut[1], deut[0]])
	assert_lt(trit[0], MIN_DELTA_E, "tritanopia, default palette: %s %.1f" % [trit[1], trit[0]])


func test_the_setting_picks_the_mode_and_off_is_the_shipped_palette() -> void:
	var p := ProfileStore.new("")
	ViewPrefs.apply_settings(p)
	assert_eq(ThemePalette.mode, &"off")
	assert_eq(ThemePalette.color(&"enemy_body"), ThemePalette.ROLES[&"enemy_body"])
	p.section("settings")["colour_mode"] = "tritanopia"
	ViewPrefs.apply_settings(p)
	assert_eq(ThemePalette.color(&"enemy_body"), ThemePalette.MODES[&"tritanopia"][&"enemy_body"])
	assert_eq(
		ThemePalette.color(&"player_body"),
		ThemePalette.ROLES[&"player_body"],
		"unlisted roles stay"
	)
	p.section("settings")["colour_mode"] = "nonsense"
	ViewPrefs.apply_settings(p)
	assert_eq(ThemePalette.mode, &"off", "an unknown mode falls back to off")


func test_reduced_motion_stops_the_shake_and_thins_the_sparks() -> void:
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var p := ProfileStore.new("")
	p.section("settings")["reduced_motion"] = "on"
	ViewPrefs.apply_settings(p)
	rig.shake(0.5)
	assert_eq(rig.shake_level(), 0.0, "no shake with reduced motion, even with shake on")
	assert_eq(ViewPrefs.sparks(7), 4)
	p.section("settings")["reduced_motion"] = "off"
	ViewPrefs.apply_settings(p)
	rig.shake(0.5)
	assert_gt(rig.shake_level(), 0.0)
	assert_eq(ViewPrefs.sparks(7), 7)
