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
## Volume settings (0..100) and the bus each one moves.
const VOLUME_BUSES := {
	"volume_master": "Master",
	"volume_music": "Music",
	"volume_effects": "Effects",
	"volume_ambience": "Ambience",
}
const FRAME_CAPS: Array[String] = ["30", "60", "120", "144", "off"]
const LANGUAGES: Array[String] = ["en", "es"]
const DEFAULTS := {
	"volume_master": 80,
	"volume_music": 70,
	"volume_effects": 80,
	"volume_ambience": 70,
	"captions": "off",
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
		"volume_master", "volume_music", "volume_effects", "volume_ambience":
			var bus := AudioServer.get_bus_index(VOLUME_BUSES[key])
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


## Every bus in BUSES exists, in that order, sending as BUS_SENDS says (a bus sends only to one before it).
static func ensure_buses() -> void:
	for name in BUSES:
		if AudioServer.get_bus_index(name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, BUS_SENDS.get(name, "Master"))
