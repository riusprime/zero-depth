class_name SfxMixer
extends RefCounted
## The voice policy, apart from any audio node so it can be tested headless (ARCHITECTURE §Deathventory reuse,
## written fresh here): a cue may not start again within its cooldown, nor sound more than max_voices copies at
## once (counted per voice_group when the cue has one, v0.3.5 F17). Times are the director's own clock in seconds
## (presentation time, never the sim's tick).

## Voice key (cue id or voice group) -> end times of the copies still sounding.
var _voices := {}
## Cue id -> the time it last started.
var _last := {}


## Whether `cue` may start at `now`.
func allows(cue: AudioCueDefinition, now: float) -> bool:
	if _last.has(cue.id) and now - float(_last[cue.id]) < cue.cooldown_s:
		return false
	return active(cue.voice_key(), now) < cue.max_voices


## Records that `cue` started at `now` and sounds for `seconds`.
func note_play(cue: AudioCueDefinition, now: float, seconds: float) -> void:
	_last[cue.id] = now
	var ends: Array = _voices.get(cue.voice_key(), [])
	ends.append(now + seconds)
	_voices[cue.voice_key()] = ends


## Copies of cue `id` (or of a voice group's cues) still sounding at `now` (finished ones are forgotten).
func active(id: StringName, now: float) -> int:
	var ends: Array = _voices.get(id, [])
	var live := ends.filter(func(t: float) -> bool: return t > now)
	_voices[id] = live
	return live.size()


func reset() -> void:
	_voices.clear()
	_last.clear()
