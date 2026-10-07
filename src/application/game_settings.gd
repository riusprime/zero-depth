class_name GameSettings
extends RefCounted
## Options the player sets once and keeps, stored in the profile's "settings" section and applied to the engine.
## Adapted from Deathventory's GameSettings: language through TranslationServer, no key table (InputRemap owns
## bindings). Display changes are skipped when headless, so tests never resize a window.

const BUSES: Array[String] = ["Master", "Music", "Effects"]
const FRAME_CAPS: Array[String] = ["30", "60", "120", "144", "off"]
const LANGUAGES: Array[String] = ["en", "es"]
const DEFAULTS := {
	"volume_master": 80,
	"volume_music": 70,
	"volume_effects": 80,
	"vsync": "on",
	"shake": "on",
	"outline": "ink",
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
		"volume_master", "volume_music", "volume_effects":
			var bus := AudioServer.get_bus_index(
				BUSES[["volume_master", "volume_music", "volume_effects"].find(key)]
			)
			AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(float(v) / 100.0, 0.0001, 1.0)))
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


## Master, Music and Effects exist (Music and Effects send to Master).
static func ensure_buses() -> void:
	for name in BUSES:
		if AudioServer.get_bus_index(name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, "Master")
