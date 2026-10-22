class_name HintStore
extends RefCounted
## v0.7.5 SM (owner N8): the first-run hints the player has seen, in the profile's `hints` section
## (`{"seen": [ids]}`, there since v0.0.1), and whether hints show at all (the Options toggle "Show hints", the
## `hints` setting, on by default). Each hint shows once; "Reset hints" forgets them all. Never part of a run's
## state or any hash.

## Every hint, in the order a first run meets them (OnboardingHints decides when each one shows). v0.8.0 N18: pick,
## trigger, shop and portal removed (they explained; owner O76); an older profile's seen list may still name them.
const IDS: Array[StringName] = [
	&"move",
	&"attack",
	&"dash",
	&"vent",
	&"build",
	&"codex",
]
const SETTING := "hints"

## A hint was marked or the list reset since the profile was last written (Main writes it at a floor's end).
var dirty := false
var _profile: ProfileStore


func _init(profile: ProfileStore) -> void:
	_profile = profile


## Hints show (Options "Show hints").
func enabled() -> bool:
	return String(GameSettings.get_value(_profile, SETTING)) != "off"


func seen(id: StringName) -> bool:
	return _seen_list().has(String(id))


## Hint `id` should show now: hints are on and it hasn't been seen.
func due(id: StringName) -> bool:
	return enabled() and not seen(id)


## Records hint `id` as seen (it never shows again until a reset).
func mark(id: StringName) -> void:
	var list := _seen_list()
	if not list.has(String(id)):
		list.append(String(id))
		dirty = true


## Forgets every seen hint (Options "Reset hints"): a new profile's first run again.
func reset() -> void:
	_profile.section("hints")["seen"] = []
	dirty = true


func seen_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for v: Variant in _seen_list():
		out.append(StringName(String(v)))
	return out


func _seen_list() -> Array:
	var sec := _profile.section("hints")
	if typeof(sec.get("seen")) != TYPE_ARRAY:
		sec["seen"] = []
	return sec["seen"]
