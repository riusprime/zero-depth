#pragma once
// ZdCrowd: the batched enemies' furniture writer (EnemyBatch, src/presentation/world_view/enemy_batch.gd). It is
// presentation code, not a sim kernel: it reads no store and changes no hashed state, so the determinism rules for
// the sim (README "Rules for code here") do not bind its results; it still keeps them, so its numbers are the ones
// the GDScript writer gives (doubles where GDScript reckons in doubles, rounded to float where GDScript stores into a
// PackedFloat32Array).
//
// One call a frame (write_furniture) takes the batch's slot columns (packed arrays the view owns and updates on
// events: a sync, a spawn, a death, a bar's fill) and the frame's interpolation fraction, and gives back the drawn
// places, the bar fills, the body places and one instance buffer per draw set, ready for MultiMesh.buffer. It holds
// nothing between two calls.

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace zd {

class ZdCrowd : public godot::RefCounted {
	GDCLASS(ZdCrowd, godot::RefCounted)

public:
	// The slot columns' order in write_furniture's `slots` (EnemyBatch.NATIVE_COLUMNS).
	enum Slot {
		X0, Y0, Z0, X1, Y1, Z1, // f32: the place at the tick before the latest, and at the latest
		INTERP, BAR_ON, DAZED_ON, BLOB_ON, SHOWN, // u8
		BAR_Y, DAZED_Y, BLOB_S, // f32
		DISC, RING, // i32: the disc's and the ring's set
		FILL, // f64: the bar trail's fill (1 without a trail)
		S0, S1, // f32: the bar fill at the last tick, and written last frame
		SLOT_COLUMNS
	};
	// The draw sets' parts (EnemyBatch.Part).
	enum Part { DISC_PART, RING_PART, DAZED_PART, BAR_PART, BLOB_PART };
	static constexpr int STRIDE = 12;
	static constexpr int START_CAPACITY = 64;

	// Returns [px, py, pz, sx, s0, s1 (PackedFloat32Array), bo (PackedVector3Array, INF: hidden),
	// counts, caps (PackedInt32Array, by set), buffers (Array of PackedFloat32Array, by set)].
	// `set_parts` and `set_caps`: each set's Part and its MultiMesh's instance count now; `heights`: the disc's, the
	// ring's and the blob's offsets over the feet.
	godot::Array write_furniture(const godot::Array &slots, const godot::PackedInt32Array &set_parts,
			const godot::PackedInt32Array &set_caps, double fraction, bool interp_on, bool synced_now, bool ticked,
			const godot::PackedFloat64Array &heights) const;

protected:
	static void _bind_methods();
};

} // namespace zd
