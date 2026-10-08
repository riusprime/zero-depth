class_name RunSaveStore
extends RefCounted
## v0.4.0 SV (ARCHITECTURE §10): the run save file, `user://saves/run.save`. One envelope
## {save_version, game_version, payload}, stored as: the magic "ZDSV", save_version (u32), the uncompressed size (u32),
## the SHA-256 of the compressed body (32 bytes), then the body (zstd of var_to_bytes, no objects). Writes are atomic
## (a .tmp, then rename) and can run on a worker thread (write_async), so a room-entry save never holds a frame.
## Compatibility checks save_version only (EI-09). A save that can't be read (corrupt, another save_version) is
## ignored with a warning and kept on disk under run.bad.<time>.save, never deleted. Headless runs (tests, sims, CI)
## keep the bytes in memory only (path "").

const PLAYER_PATH := "user://saves/run.save"
const SAVE_VERSION := 1
const MAGIC := "ZDSV"
const HEADER := 4 + 4 + 4 + 32

static var _shared: RunSaveStore = null

var path := ""
## Why the last read gave {} ("" when it read a save or there was none).
var last_error := ""
## Bytes of the last write, in memory mode.
var _memory := PackedByteArray()
var _mutex := Mutex.new()
var _task := -1
var _task_ok := true


func _init(p_path: String = "") -> void:
	path = p_path


## The player's save path, or "" (memory only) in a headless run.
static func player_path() -> String:
	return "" if DisplayServer.get_name() == "headless" else PLAYER_PATH


## The process-wide store.
static func shared() -> RunSaveStore:
	if _shared == null:
		_shared = RunSaveStore.new(player_path())
	return _shared


## Replace the shared store (tests, main).
static func use_shared(store: RunSaveStore) -> void:
	_shared = store


static func encode(payload: Dictionary) -> PackedByteArray:
	var envelope := {
		"save_version": SAVE_VERSION, "game_version": GameVersion.string(), "payload": payload
	}
	var raw := var_to_bytes(envelope)
	var body := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var out := MAGIC.to_ascii_buffer()
	out.resize(HEADER)
	out.encode_u32(4, SAVE_VERSION)
	out.encode_u32(8, raw.size())
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(body)
	var digest := ctx.finish()
	for i in 32:
		out[12 + i] = digest[i]
	out.append_array(body)
	return out


## [envelope, error]: the envelope, or {} and why not.
static func decode(bytes: PackedByteArray) -> Array:
	if bytes.size() < HEADER or bytes.slice(0, 4).get_string_from_ascii() != MAGIC:
		return [{}, "not a run save"]
	var version := bytes.decode_u32(4)
	if version != SAVE_VERSION:
		return [{}, "save_version %d, this game reads %d" % [version, SAVE_VERSION]]
	var body := bytes.slice(HEADER)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(body)
	if ctx.finish() != bytes.slice(12, HEADER):
		return [{}, "checksum mismatch (a damaged file)"]
	var raw := body.decompress(bytes.decode_u32(8), FileAccess.COMPRESSION_ZSTD)
	if raw.size() != bytes.decode_u32(8):
		return [{}, "can't decompress"]
	var env: Variant = bytes_to_var(raw)
	if (
		typeof(env) != TYPE_DICTIONARY
		or int((env as Dictionary).get("save_version", -1)) != SAVE_VERSION
		or typeof((env as Dictionary).get("payload")) != TYPE_DICTIONARY
	):
		return [{}, "not a run save envelope"]
	return [env, ""]


## Writes now (atomic). False when the file couldn't be written.
func write(payload: Dictionary) -> bool:
	flush()
	return _write_bytes(encode(payload))


## Encodes and writes on a worker thread; the payload must not change afterwards (a fresh snapshot is). A write
## still running is waited for first, so writes land in order.
func write_async(payload: Dictionary) -> void:
	flush()
	_task = WorkerThreadPool.add_task(_write_task.bind(payload), false, "run save")


## Waits for a write in flight. False when the last async write failed.
func flush() -> bool:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	return _task_ok


func is_writing() -> bool:
	return _task >= 0 and not WorkerThreadPool.is_task_completed(_task)


## The saved payload, or {} (no save, or one that can't be read: see last_error; the file is kept as run.bad.*).
func read() -> Dictionary:
	flush()
	last_error = ""
	var bytes := PackedByteArray()
	if path.is_empty():
		_mutex.lock()
		bytes = _memory
		_mutex.unlock()
	elif FileAccess.file_exists(path):
		bytes = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return {}
	var r := decode(bytes)
	if r[1] != "":
		reject(r[1])
		return {}
	return (r[0] as Dictionary)["payload"]


## A save exists and reads.
func has_save() -> bool:
	return not read().is_empty()


## Sets the save aside (it reads, but doesn't fit this game: say why) as run.bad.<time>.save, kept, never deleted.
func reject(why: String) -> void:
	last_error = why
	if path.is_empty():
		_mutex.lock()
		_memory = PackedByteArray()
		_mutex.unlock()
		push_warning("RunSaveStore: the run save can't be used (%s); ignored." % why)
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var bad := path.get_base_dir().path_join("run.bad.%s.save" % stamp)
	DirAccess.rename_absolute(path, bad)
	push_warning("RunSaveStore: %s can't be used (%s); kept as %s." % [path, why, bad])


## Removes the save (a run that ended in a death or a win).
func delete() -> void:
	flush()
	if path.is_empty():
		_mutex.lock()
		_memory = PackedByteArray()
		_mutex.unlock()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _write_task(payload: Dictionary) -> void:
	_task_ok = _write_bytes(encode(payload))


func _write_bytes(bytes: PackedByteArray) -> bool:
	if path.is_empty():
		_mutex.lock()
		_memory = bytes
		_mutex.unlock()
		return true
	var dir := path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning(
			"RunSaveStore: can't write %s (%s)." % [tmp, error_string(FileAccess.get_open_error())]
		)
		return false
	file.store_buffer(bytes)
	file.close()
	if DirAccess.rename_absolute(tmp, path) != OK:
		push_warning("RunSaveStore: can't move %s over %s." % [tmp, path])
		return false
	return true
