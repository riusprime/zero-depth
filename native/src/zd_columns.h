#pragma once
// Columns crossing between the GDScript stores (ActorStore, ProjectileStore) and a kernel (NATIVE_CORE.md §2.2).
// In: a column is read by name with Object::get; the packed array comes back sharing the store's buffer (copy on
// write), so the read costs the call, not a copy. Out: a changed column goes back as a new packed array through
// Object::set; a kernel never writes into an array it was given (copy on write would make that a silent copy, and
// the store would keep the old values). GDScript stays the owner of every hashed column.

#include <cstdint>
#include <cstring>
#include <vector>

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string_name.hpp>

namespace zd {

// The store columns by name, made once per ZdWorld (a StringName built per call would cost a lookup each time).
// ActorStore and ProjectileStore field names; a kernel adds a name here only when the store gains a column.
struct ColumnNames {
	// ActorStore
	godot::StringName ids, kinds, teams, pos_x, pos_y, radius, hp, max_hp, invuln, dead;
	godot::StringName state, state_t, facing, lock_x, lock_y, lock_a, lock_len, cd, fire_cd;
	godot::StringName jitter_x, jitter_y, slow_t, frozen_t, windup, pick, plan_block, plan_x, plan_y, power;
	// ProjectileStore (pos_x, pos_y, radius, ids as above)
	godot::StringName owner, team, vel_x, vel_y, life, damage, tags, bounces, pierce_left, speed;

	ColumnNames();
};

namespace cols {

// A column read by name: shares the store's buffer (read it through ptr(), never ptrw()).
inline godot::PackedFloat32Array f32(const godot::Object *store, const godot::StringName &name) {
	return store->get(name);
}
inline godot::PackedInt32Array i32(const godot::Object *store, const godot::StringName &name) {
	return store->get(name);
}
inline godot::PackedByteArray u8(const godot::Object *store, const godot::StringName &name) {
	return store->get(name);
}

// A new array holding `n` values from `src`, set on the store under `name` (the store's old array is dropped).
void put_f32(godot::Object *store, const godot::StringName &name, const float *src, int64_t n);
void put_i32(godot::Object *store, const godot::StringName &name, const int32_t *src, int64_t n);
void put_u8(godot::Object *store, const godot::StringName &name, const uint8_t *src, int64_t n);

inline void put_f32(godot::Object *store, const godot::StringName &name, const std::vector<float> &v) {
	put_f32(store, name, v.data(), int64_t(v.size()));
}
inline void put_i32(godot::Object *store, const godot::StringName &name, const std::vector<int32_t> &v) {
	put_i32(store, name, v.data(), int64_t(v.size()));
}

// A column's values copied into a kernel's working vector (the usual first step of a kernel that changes it).
inline void load(const godot::PackedFloat32Array &col, std::vector<float> &out) {
	out.assign(col.ptr(), col.ptr() + col.size());
}
inline void load(const godot::PackedInt32Array &col, std::vector<int32_t> &out) {
	out.assign(col.ptr(), col.ptr() + col.size());
}

} // namespace cols
} // namespace zd
