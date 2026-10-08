class_name GameSettings
extends RefCounted
## Options the player sets once and keeps, stored in the profile's "settings" section and applied to the engine.
## Adapted from Deathventory's GameSettings: language through TranslationServer, no key table (InputRemap owns
## bindings). Display changes are skipped when headless, so tests never resize a window.

const BUSES: Array[String] = ["Master", "Music", "Effects", "Ambience", "SFX", "UI"]
## Where each bus sends (v0.3.0 AU): world sounds (SFX, ducked under boss telegraphs) and menus/alerts (UI) both
## sit under Effects, so the Effects volume covers them; the biome loops have their own Ambience volume.
const BUS_SENDS := {
	"Music": "Master", "Effects": "Master", "Ambience": "Master", "SFX": "Effects", "UI": "Effects"
}
const FRAME_CAPS: Array[String] = ["30", "60", "120", "144", "off"]
const LANGUAGES: Array[String] = ["en", "es"]
## v0.3.0 O + AU: the three volumes the Options screen shows (0-100), applied to these buses when they exist. Sound
## effects move Effects, which carries both the world sounds (SFX) and the menu/alert sounds (UI).
const VOLUME_BUSES := {
	"audio/master": "Master", "audio/sfx": "Effects", "audio/ambience": "Ambience"
}
const WINDOW_MODES: Array[String] = ["windowed", "fullscreen"]
const RENDER_SCALES: Array[String] = ["50", "67", "75", "85", "100"]
const COLOUR_MODES: Array[String] = ["off", "protanopia", "deuteranopia", "tritanopia"]
## Starting values (v0.3.0 O); the shipped look stays the default.
const DEFAULTS := {
	"audio/master": 80,
	"audio/sfx": 80,
	"audio/ambience": 60,
	"window_mode": "windowed",
	"render_scale": "100",
	"reduced_motion": "off",
	"colour_mode": "off",
	"captions": "off",
	"vsync": "on",
	"shake": "on",
	"outline": "ink",
	"lighting": "high",
	"frame_cap": "off",
	"language": "en",
}


static func get_value(profile: ProfileStore, key: String) -> Variant:
	return profile.section("settings").get(key, DEFAULTS.get(key))


static func set_value(profile: ProfileStore, key: String, value: Variant) -> void:
	profile.section("settings")[key] = value
	apply_one(profile, key)


static func apply_all(profile: ProfileStore) -> void:
	ensure_buses()
	for key: String in DEFAULTS:
		apply_one(profile, key)


static func apply_one(profile: ProfileStore, key: String) -> void:
	var v: Variant = get_value(profile, key)
	match key:
		"audio/master", "audio/sfx", "audio/ambience":
			var bus := AudioServer.get_bus_index(VOLUME_BUSES[key])
			if bus >= 0:
				AudioServer.set_bus_volume_db(
					bus, linear_to_db(clampf(float(v) / 100.0, 0.0001, 1.0))
				)
		"render_scale":
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null:
				tree.root.scaling_3d_scale = clampf(float(v) / 100.0, 0.25, 1.0)
		"window_mode":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(
					(
						DisplayServer.WINDOW_MODE_FULLSCREEN
						if String(v) == "fullscreen"
						else DisplayServer.WINDOW_MODE_WINDOWED
					)
				)
		"language":
			TranslationServer.set_locale(String(v))
		"frame_cap":
			Engine.max_fps = 0 if String(v) == "off" else int(v)
		"vsync":
			if DisplayServer.get_name() != "headless":
				var mode := (
					DisplayServer.VSYNC_ENABLED
					if String(v) == "on"
					else DisplayServer.VSYNC_DISABLED
				)
				DisplayServer.window_set_vsync_mode(mode)


## Every bus in BUSES exists, in that order, sending as BUS_SENDS says (a bus sends only to one before it).
static func ensure_buses() -> void:
	for name in BUSES:
		if AudioServer.get_bus_index(name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, BUS_SENDS.get(name, "Master"))
