class_name AudioStreamBank
extends RefCounted
## Every cue's sound, loaded ahead of play so no fight frame reads the disk: warm() looks for each cue's override
## file and asks a loader thread for the shipped one (or the res:// override), poll() collects what has finished,
## and finish() waits for the rest (a floor's build calls it behind the loading cover). A file named like a cue in
## user://audio_override/ or res://assets/audio/override/ (.wav or .ogg) replaces the shipped one
## (docs/audio/README.md). Ambience comes back looped, and a held sound's looped copy is made once.

const OVERRIDE_DIRS: Array[String] = ["user://audio_override", "res://assets/audio/override"]

## Cue id -> its stream (null when it has no file), once known.
var _streams := {}
## Cue id -> the res:// path a loader thread is fetching for it.
var _pending := {}
## Cue id -> its looped stream for hold().
var _loops := {}
var _cues := {}


## Starts loading the sound of every cue in `cues` (cue id -> AudioCueDefinition): user:// overrides are read now,
## res:// files on a loader thread.
func warm(cues: Dictionary) -> void:
	_cues = cues
	for id: StringName in cues:
		if _streams.has(id) or _pending.has(id):
			continue
		var user := user_override_stream(id)
		if user != null:
			_finish(id, user)
			continue
		var path := res_path(id, cues[id])
		if path == "":
			_streams[id] = null
		elif ResourceLoader.load_threaded_request(path, "AudioStream") == OK:
			_pending[id] = path
		else:
			_finish(id, load(path))


## Collects the loads that have finished (a frame's cheap check while the menu shows).
func poll() -> void:
	if _pending.is_empty():
		return
	for id: StringName in _pending.keys():
		var st := ResourceLoader.load_threaded_get_status(_pending[id])
		if st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_collect(id)


## Waits for every load still running.
func finish() -> void:
	for id: StringName in _pending.keys():
		_collect(id)


## Whether every warmed cue's sound is in hand.
func all_loaded() -> bool:
	return _pending.is_empty()


## The stream for cue `id` (`cue` its definition, or null): from the bank when warmed; a cue that was never warmed
## is looked up now.
func stream(id: StringName, cue: AudioCueDefinition) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	if _pending.has(id):
		_collect(id)
		return _streams[id]
	var s: AudioStream = user_override_stream(id)
	if s == null:
		var path := res_path(id, cue)
		if path != "":
			s = load(path)
	_cues[id] = cue
	_finish(id, s)
	return _streams[id]


## The looped copy of cue `id`'s stream, made once (a held sound turning on and off copies nothing).
func looped_stream(id: StringName, cue: AudioCueDefinition) -> AudioStream:
	if not _loops.has(id):
		var s := stream(id, cue)
		_loops[id] = looped(s) if s != null else null
	return _loops[id]


func _collect(id: StringName) -> void:
	var path: String = _pending[id]
	_pending.erase(id)
	_finish(id, ResourceLoader.load_threaded_get(path) as AudioStream)


func _finish(id: StringName, s: AudioStream) -> void:
	var cue: AudioCueDefinition = _cues.get(id)
	if s != null and cue != null and cue.kind == &"ambience":
		s = looped(s)
	_streams[id] = s


## The res:// file cue `id` plays: the project's override when there is one, else the shipped file; "" when
## neither exists.
static func res_path(id: StringName, cue: AudioCueDefinition) -> String:
	var path := res_override_path(id)
	if path == "" and cue != null and ResourceLoader.exists(cue.default_path()):
		path = cue.default_path()
	return path


## res://assets/audio/override/<id>.wav or .ogg when the project ships one, else "".
static func res_override_path(id: StringName) -> String:
	for ext in ["wav", "ogg"]:
		var path := "%s/%s.%s" % [OVERRIDE_DIRS[1], id, ext]
		if ResourceLoader.exists(path):
			return path
	return ""


## The user's override for `id` read from user://audio_override/<id>.wav or .ogg (any build), or null.
static func user_override_stream(id: StringName) -> AudioStream:
	for ext in ["wav", "ogg"]:
		var path := "%s/%s.%s" % [OVERRIDE_DIRS[0], id, ext]
		if FileAccess.file_exists(path):
			return (
				AudioStreamWAV.load_from_file(path)
				if ext == "wav"
				else AudioStreamOggVorbis.load_from_file(path)
			)
	return null


## The override for `id`, or null: <id>.wav or .ogg in user://audio_override/ (any build), else in
## res://assets/audio/override/ (shipped with the project).
static func override_stream(id: StringName) -> AudioStream:
	var s := user_override_stream(id)
	if s == null and res_override_path(id) != "":
		s = load(res_override_path(id))
	return s


## A stream set to loop over its whole length (an override file may not carry loop points).
static func looped(s: AudioStream) -> AudioStream:
	if s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * w.mix_rate))
		return w
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s
