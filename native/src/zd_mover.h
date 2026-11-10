#pragma once

#include <cstdint>
#include <vector>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace zd {

// An oriented box as the sim holds it (Obb): centre, axes, half-extents, plus its axis-aligned bounds.
struct Box {
	float cx, cy, ux, uy, vx, vy, hx, hy;
	float x0, y0, x1, y1;
};

// The numeric part of the sim's collision resolve (World's move phase after the steering): each pass pushes the
// bodies out of the walls and the standing solids, then parts overlapping bodies, half to each. A body flagged
// `through` is skipped by both; a heavy body against a light one shoves the light one the whole way, stopped at the
// first wall on the way. Deterministic against itself: fixed iteration order, single-precision floats, no threads.
// Not bit-for-bit the GDScript passes: its own grid, and the pairs are visited in its grid's order.
class ZdMover : public godot::RefCounted {
	GDCLASS(ZdMover, godot::RefCounted)

public:
	// Bodies larger than this radius (m) stay out of the pair grid and are paired with every body instead.
	static constexpr float BIG_R = 1.0f;
	static constexpr float WALL_CELL = 2.0f;
	static constexpr int MAX_SIDE = 256;

	// Walls as 8 floats each (cx, cy, ux, uy, vx, vy, hx, hy); rebuilds the wall grid.
	void set_walls(const godot::PackedFloat32Array &obbs);
	// Standing solid footprints, same layout (few: scanned linearly, as Solids.push does).
	void set_solids(const godot::PackedFloat32Array &obbs);
	int wall_count() const { return int(walls_.size()); }

	// Runs `iters` passes on the given columns. through/heavy are empty (no boss, no hidden lurker) or one
	// entry per body. ghost0: the hero (body 0) takes no pair push (Phase Dash). Returns the pair pushes applied.
	int resolve(const godot::PackedFloat32Array &px, const godot::PackedFloat32Array &py,
			const godot::PackedFloat32Array &rad, const godot::PackedInt32Array &through,
			const godot::PackedInt32Array &heavy, bool ghost0, int iters);
	godot::PackedFloat32Array get_x() const { return out_x_; }
	godot::PackedFloat32Array get_y() const { return out_y_; }

	// Benchmarks and boundary probes (no state of the game is read or written).
	// The pair pass alone, `reps` times on fresh copies of the input; returns ns spent inside (native clock).
	int64_t bench_pairs(const godot::PackedFloat32Array &px, const godot::PackedFloat32Array &py,
			const godot::PackedFloat32Array &rad, int reps);
	// Takes three columns and does nothing with them: the cost of the call and the arguments crossing.
	int touch(const godot::PackedFloat32Array &px, const godot::PackedFloat32Array &py,
			const godot::PackedFloat32Array &rad) const;
	// A fixed scene (walls, solids, 240 bodies with through and heavy ones) run for 60 ticks through resolve; the
	// FNV-1a hash of every result's float bits, as 16 hex digits. A compiler that rounds any float differently
	// gives another hash (the expected one is pinned in tests/unit/app/test_native_move.gd). Replaces the walls.
	godot::String determinism_probe();

protected:
	static void _bind_methods();

private:
	std::vector<Box> walls_;
	std::vector<Box> solids_;
	// The wall grid: every wall listed in each cell its bounds cover.
	float wg_ox_ = 0.0f, wg_oy_ = 0.0f, wg_cell_ = WALL_CELL;
	int wg_w_ = 0, wg_h_ = 0;
	std::vector<int> wg_start_, wg_items_;
	std::vector<uint32_t> wall_stamp_;
	uint32_t wall_query_ = 0;

	// The bodies' working columns.
	std::vector<float> x_, y_, r_;
	std::vector<int32_t> through_, heavy_;
	bool has_flags_ = false;

	// The pair grid: small bodies by the cell of their centre (a counting sort), big ones in a list.
	float ag_ox_ = 0.0f, ag_oy_ = 0.0f, ag_cell_ = 1.0f;
	int ag_w_ = 0, ag_h_ = 0;
	std::vector<int> ag_start_, ag_items_, ag_cell_of_, ag_fill_, big_;

	godot::PackedFloat32Array out_x_, out_y_;

	void load_columns(const godot::PackedFloat32Array &px, const godot::PackedFloat32Array &py,
			const godot::PackedFloat32Array &rad);
	static void read_boxes(const godot::PackedFloat32Array &obbs, std::vector<Box> &out);
	void wall_pass();
	void build_pair_grid();
	int pair_pass(bool ghost0);
	void pair(int a, int b, int &pushes);
	void shove(int i, float dx, float dy);
	template <typename F>
	void walls_in(float x0, float y0, float x1, float y1, F &&f);
};

} // namespace zd
