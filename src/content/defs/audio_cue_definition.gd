class_name AudioCueDefinition
extends ContentDef
## One sound the game can play (docs/audio/SFX_NEEDS.md, PLAN v0.3.0 L27): its file is
## res://assets/audio/<kind>/<id>.wav, written by scripts/audio/generate_sfx.py. A file with the same name in
## user://audio_override/ or res://assets/audio/override/ replaces it (AudioDirector). Tuning numbers here are
## starting values; the owner judges the sound.

const KINDS: Array[StringName] = [&"sfx", &"ambience"]
## sfx: world sounds, ducked under boss telegraphs. ui: menus and alerts, never ducked. ambience: biome loops.
const BUSES: Array[StringName] = [&"sfx", &"ui", &"ambience"]

@export var kind: StringName = &"sfx"
@export var bus: StringName = &"sfx"
@export var volume_db := 0.0
## Each play is pitched by a random factor in [1 - jitter, 1 + jitter] (presentation's own RNG, never the sim's).
@export var pitch_jitter := 0.04
## How many copies may sound at once; a play beyond that is dropped.
@export var max_voices := 3
## The shortest gap between two plays of this cue, in seconds (quick repeats are dropped).
@export var cooldown_s := 0.03
## While this cue plays, the sfx bus is ducked (boss telegraphs) so the warning reads.
@export var duck := false
## Shown on the caption line when captions are on; empty = no caption.
@export var caption_key: StringName = &""


func category() -> StringName:
	return &"audio_cues"


## The shipped file for this cue.
func default_path() -> String:
	return "res://assets/audio/%s/%s.wav" % [kind, id]


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if not kind in KINDS:
		issues.append(ValidationIssue.new(&"bad_kind", resource_path, "kind %s unknown" % kind))
	if not bus in BUSES:
		issues.append(ValidationIssue.new(&"bad_bus", resource_path, "bus %s unknown" % bus))
	if kind == &"ambience" and bus != &"ambience":
		issues.append(
			ValidationIssue.new(&"bad_bus", resource_path, "ambience plays on the ambience bus")
		)
	if max_voices < 1:
		issues.append(
			ValidationIssue.new(&"not_positive", resource_path, "max_voices must be >= 1")
		)
	if pitch_jitter < 0.0 or pitch_jitter > 0.5:
		issues.append(
			ValidationIssue.new(&"out_of_range", resource_path, "pitch_jitter must be in 0..0.5")
		)
	if cooldown_s < 0.0:
		issues.append(ValidationIssue.new(&"duration_negative", resource_path, "cooldown_s < 0"))
	if KINDS.has(kind) and not ResourceLoader.exists(default_path()):
		issues.append(
			ValidationIssue.new(&"missing_file", resource_path, "%s is missing" % default_path())
		)
	return issues
