# Ported from riusprime/deathventory@1d697803:src/app/game_version.gd.
# Changes: lives in application/ (the profile store needs it, and nothing may import app/).
class_name GameVersion extends RefCounted
## The game's version (roadmap §2). Source of truth: `application/config/version`
## in project.godot, e.g. "0.2.0" or "0.2.0-dev" while a version is in
## development. export_presets.cfg carries the same numbers as "X.Y.Z.0".

const SETTING := "application/config/version"
const FALLBACK := "0.0.0"


## The raw version string ("0.2.0-dev").
static func string() -> String:
	var v := String(ProjectSettings.get_setting(SETTING, FALLBACK))
	return v if not v.is_empty() else FALLBACK


## The numeric part without any suffix ("0.2.0").
static func numeric() -> String:
	return string().split("-", true, 1)[0]


## True while the version carries a suffix such as "-dev".
static func is_prerelease() -> bool:
	return string().contains("-")


## [major, minor, patch] as ints; missing parts read 0.
static func parts(version: String = "") -> Array[int]:
	var v := version if not version.is_empty() else numeric()
	v = v.split("-", true, 1)[0]
	var out: Array[int] = [0, 0, 0]
	var bits := v.split(".")
	for i in mini(3, bits.size()):
		out[i] = int(bits[i])
	return out


## The label shown in menus ("v0.2.0-dev").
static func label() -> String:
	return "v" + string()


## Negative, zero or positive as `a` sorts before, equal to or after `b`
## (numeric parts only).
static func compare(a: String, b: String) -> int:
	var pa := parts(a)
	var pb := parts(b)
	for i in 3:
		if pa[i] != pb[i]:
			return pa[i] - pb[i]
	return 0
