# Ported from riusprime/deathventory@1d697803:src/domain/core/canonical_value.gd.
# Changes: floats are encoded as float32 bits with -0.0 normalized (SIM_CONTRACTS §10); Vector2 and
# PackedFloat32Array added; an unsupported type is a push_error (fails tests) instead of a stripped assert.
class_name CanonicalValue extends RefCounted


static func row_major_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


static func sha256_hex(value: Variant) -> String:
	var bytes := encode(value)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	var digest := ctx.finish()
	return digest.hex_encode()


static func encode(value: Variant) -> PackedByteArray:
	var buffer := PackedByteArray()
	_encode_variant(value, buffer)
	return buffer


static func _encode_variant(value: Variant, buffer: PackedByteArray) -> void:
	if value == null:
		buffer.append(0x00)
		return

	var type_val := typeof(value)
	match type_val:
		TYPE_BOOL:
			buffer.append(0x01)
			buffer.append(1 if value else 0)
		TYPE_INT:
			buffer.append(0x02)
			_append_i64(buffer, int(value))
		TYPE_FLOAT:
			buffer.append(0x03)
			append_f32(buffer, float(value))
		TYPE_STRING:
			buffer.append(0x04)
			_append_string(buffer, String(value))
		TYPE_STRING_NAME:
			buffer.append(0x04)
			_append_string(buffer, String(value))
		TYPE_VECTOR2I:
			buffer.append(0x06)
			var v: Vector2i = value
			_append_i32(buffer, v.x)
			_append_i32(buffer, v.y)
		TYPE_RECT2I:
			buffer.append(0x07)
			var r: Rect2i = value
			_append_i32(buffer, r.position.x)
			_append_i32(buffer, r.position.y)
			_append_i32(buffer, r.size.x)
			_append_i32(buffer, r.size.y)
		TYPE_ARRAY:
			buffer.append(0x08)
			var arr: Array = value
			_append_i32(buffer, arr.size())
			for item in arr:
				_encode_variant(item, buffer)
		TYPE_DICTIONARY:
			buffer.append(0x09)
			var dict: Dictionary = value
			_append_i32(buffer, dict.size())
			var keys: Array = dict.keys()
			keys.sort_custom(_canonical_key_less)
			for k in keys:
				_encode_variant(k, buffer)
				_encode_variant(dict[k], buffer)
		TYPE_PACKED_BYTE_ARRAY:
			buffer.append(0x0A)
			var pba: PackedByteArray = value
			_append_i32(buffer, pba.size())
			buffer.append_array(pba)
		TYPE_PACKED_INT32_ARRAY:
			buffer.append(0x0B)
			var pia: PackedInt32Array = value
			_append_i32(buffer, pia.size())
			for item in pia:
				_append_i32(buffer, item)
		TYPE_PACKED_STRING_ARRAY:
			buffer.append(0x0C)
			var psa: PackedStringArray = value
			_append_i32(buffer, psa.size())
			for item in psa:
				_append_string(buffer, item)
		TYPE_VECTOR2:
			buffer.append(0x0D)
			var v2: Vector2 = value
			append_f32(buffer, v2.x)
			append_f32(buffer, v2.y)
		TYPE_PACKED_FLOAT32_ARRAY:
			buffer.append(0x0E)
			var pfa: PackedFloat32Array = value
			_append_i32(buffer, pfa.size())
			for item in pfa:
				append_f32(buffer, item)
		_:
			push_error("CanonicalValue: unsupported type %s" % type_string(type_val))


static func _canonical_key_less(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if ta != tb:
		return ta < tb
	match ta:
		TYPE_STRING, TYPE_STRING_NAME:
			return String(a) < String(b)
		TYPE_INT:
			return int(a) < int(b)
		TYPE_VECTOR2I:
			return row_major_less(a, b)
		_:
			return str(a) < str(b)


static func _append_i32(buffer: PackedByteArray, val: int) -> void:
	var v: int = val & 0xFFFFFFFF
	buffer.append(v & 0xFF)
	buffer.append((v >> 8) & 0xFF)
	buffer.append((v >> 16) & 0xFF)
	buffer.append((v >> 24) & 0xFF)


static func _append_i64(buffer: PackedByteArray, val: int) -> void:
	for i in range(8):
		buffer.append((val >> (i * 8)) & 0xFF)


## Appends the float32 bit pattern of val, little-endian; -0.0 is written as 0.0.
static func append_f32(buffer: PackedByteArray, val: float) -> void:
	if val == 0.0:
		val = 0.0
	buffer.append_array(PackedFloat32Array([val]).to_byte_array())


static func _append_string(buffer: PackedByteArray, s: String) -> void:
	var utf8 := s.to_utf8_buffer()
	_append_i32(buffer, utf8.size())
	buffer.append_array(utf8)
