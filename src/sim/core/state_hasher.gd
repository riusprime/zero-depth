class_name StateHasher
extends RefCounted
## Streams fields in a fixed order into SHA-256 (SIM_CONTRACTS §10): ints as 8-byte little-endian,
## floats as float32 bits (-0.0 == 0.0), strings as length + UTF-8.

var _ctx := HashingContext.new()
var _buf := PackedByteArray()


func _init() -> void:
	_ctx.start(HashingContext.HASH_SHA256)


func add_int(v: int) -> void:
	for i in 8:
		_buf.append((v >> (i * 8)) & 0xFF)
	_flush_if_big()


func add_f32(v: float) -> void:
	CanonicalValue.append_f32(_buf, v)
	_flush_if_big()


func add_ints(values: PackedInt32Array) -> void:
	add_int(values.size())
	for v in values:
		add_int(v)


func add_f32s(values: PackedFloat32Array) -> void:
	add_int(values.size())
	if values.is_empty():
		return
	var normalized := values.duplicate()
	for i in normalized.size():
		if normalized[i] == 0.0:
			normalized[i] = 0.0
	_buf.append_array(normalized.to_byte_array())
	_flush_if_big()


func add_string(s: String) -> void:
	var utf8 := s.to_utf8_buffer()
	add_int(utf8.size())
	_buf.append_array(utf8)
	_flush_if_big()


func finish_hex() -> String:
	if not _buf.is_empty():
		_ctx.update(_buf)
		_buf = PackedByteArray()
	return _ctx.finish().hex_encode()


func _flush_if_big() -> void:
	if _buf.size() >= 4096:
		_ctx.update(_buf)
		_buf = PackedByteArray()
