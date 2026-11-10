#pragma once
// ZdWorld: the native side of one World (NATIVE_CORE.md §2, §3). It holds only caches derived from the world's
// hashed state and its loadout: the walls and solids with their grid, the direction tables, the per-kind table and
// the tuning, and the nav grid. Between two calls it holds nothing else, so a snapshot never needs it: a restore
// sends the caches again. Each kernel is one batched call a phase, defined in its own zd_<kernel>.cpp, reading the
// store's columns by name and writing back the ones it changed as new arrays (zd_columns.h).
//
// Adding a kernel (say `think`, in zd_ai.h / zd_ai.cpp):
//   1. zd_ai.h: the kernel's scratch struct (working vectors, rebuilt every call) and any helpers.
//   2. zd_ai.cpp: `int ZdWorld::think(...) { ... }`, using the caches below (walls_, trig_, kinds_, nav_,
//      names_) and cols::.
//   3. Here, replace the kernel's own `// slot:` lines: the #include (KERNEL INCLUDES), the method declarations
//      (KERNEL METHODS) and the scratch member (KERNEL SCRATCH, if it keeps working vectors).
//   4. zd_world.cpp: replace its `// slot:` line with the ClassDB::bind_method lines (KERNEL BINDINGS).
// Each kernel has its own slot lines, kept apart by a blank line, so kernels added side by side merge without
// touching each other's lines. SConstruct compiles every native/src/*.cpp, so no build change is needed.

#include <cstdint>
#include <vector>

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include "zd_columns.h"
#include "zd_geom.h"

// ---- KERNEL INCLUDES ----
#include "zd_collide.h"

#include "zd_ai.h"

#include "zd_nav.h"

#include "zd_shots.h"

// slot: strike (#include "zd_strike.h")
// ---- end KERNEL INCLUDES ----

namespace zd {

// The per-kind table (NativeKindTable, §4.2): `ki` ints and `kf` floats per kind, indexed by ActorStore.Kind, and
// the tuning beside it. The field offsets are NativeKindTable's K_* / F_* / T_* constants; the reader that names
// them belongs to the kernel that consumes them. Only the two fields every kernel needs are named here.
struct KindTable {
	static constexpr int K_MODE = 0; // NativeKindTable.K_MODE
	static constexpr int MODE_SCRIPT = 2; // NativeKindTable.MODE_SCRIPT
	static constexpr int T_EGG_STATE = 13; // NativeKindTable.T_EGG_STATE

	std::vector<int32_t> ints;
	std::vector<float> floats;
	std::vector<float> tuning;
	int ki = 0, kf = 0, count = 0;

	bool has(int kind) const { return kind >= 0 && kind < count; }
	const int32_t *row_i(int kind) const { return ints.data() + size_t(kind) * size_t(ki); }
	const float *row_f(int kind) const { return floats.data() + size_t(kind) * size_t(kf); }
	// SCRIPT for a kind past the table (as for a kind without an EnemyTable).
	int mode(int kind) const { return has(kind) ? row_i(kind)[K_MODE] : MODE_SCRIPT; }
};

// The nav grid (NavField): cells of `cell` m from (ox, oy), w x h, blocked cells, the step lists (adjacency, its
// costs), and the last flood's distances. Sent when the field is built or its extra cells change.
struct NavGrid {
	float ox = 0.0f, oy = 0.0f, cell = 0.5f;
	int w = 0, h = 0;
	std::vector<uint8_t> blocked;
	std::vector<int32_t> adj_start, adj;
	std::vector<uint8_t> adj_w;
	std::vector<int32_t> dist;
	std::vector<uint8_t> extra; // NavField.extra: empty, or a byte a cell (1: blocked for a while)
	bool ready = false;
};

class ZdWorld : public godot::RefCounted {
	GDCLASS(ZdWorld, godot::RefCounted)

public:
	// ---- Setup (§3.7): the caches. Each replaces what it sends. ----
	// The direction tables (Kin._cos, Kin._sin, 513 floats each); false if either has another length.
	bool set_trig(const godot::PackedFloat32Array &cos_t, const godot::PackedFloat32Array &sin_t);
	bool has_trig() const { return trig_.ready; }
	// Walls as 8 floats each (cx, cy, ux, uy, vx, vy, hx, hy); rebuilds the wall grid.
	void set_walls(const godot::PackedFloat32Array &obbs);
	// Standing solid footprints, same layout (few: scanned linearly, as Solids.push does).
	void set_solids(const godot::PackedFloat32Array &obbs);
	int wall_count() const { return int(walls_.boxes.size()); }
	// The per-kind table: ki ints and kf floats a kind, and the tuning. Returns the kinds taken, or -1 (nothing
	// changes) when the arrays don't hold a whole number of rows of the same count.
	int set_kinds(const godot::PackedInt32Array &ints, const godot::PackedFloat32Array &floats,
			const godot::PackedFloat32Array &tuning, int ki, int kf);
	int kind_count() const { return kinds_.count; }
	// One kind's row back, ints then floats (as floats), for the tests: what the native side holds.
	godot::PackedFloat32Array kind_row(int kind) const;
	void set_nav_grid(godot::Vector2 origin, godot::Vector2i size, float cell, const godot::PackedByteArray &blocked,
			const godot::PackedInt32Array &adj_start, const godot::PackedInt32Array &adj,
			const godot::PackedByteArray &adj_w);
	void set_nav_dist(const godot::PackedInt32Array &dist);
	bool has_nav() const { return nav_.ready; }
	// The rows (from 1, ascending) GDScript runs itself: a kind in mode SCRIPT, or a row in an egg state.
	godot::PackedInt32Array rows_for_script(const godot::Object *actors) const;

	// ---- Probes: no state of the game is read into a result or written. ----
	// Kin.dir and Kin.angle_of through the native tables, for the geometry tests: dir_of returns (x, y) pairs for
	// each angle; angles_of the angle of each (x, y) pair.
	godot::PackedFloat32Array dir_of(const godot::PackedInt32Array &angles) const;
	godot::PackedInt32Array angles_of(const godot::PackedFloat32Array &xy) const;
	godot::PackedInt32Array turns_toward(const godot::PackedInt32Array &from_to_step) const;
	// The cost of the columns crossing by name: `reps` times, every column in `names` read from `store` with
	// Object::get, then (write) each sent back as a new array of the same values with Object::set. Returns
	// [ns reading, ns writing] by the native clock.
	godot::PackedInt64Array bench_columns(godot::Object *store, const godot::PackedStringArray &names, int reps,
			bool write);

	// ---- KERNEL METHODS: each defined in its kernel's .cpp ----
	// Collision (zd_collide.cpp), the move phase's last step.
	// Runs `iters` passes on the given columns. through/heavy are empty (no boss, no hidden lurker) or one
	// entry per body. ghost0: the hero (body 0) takes no pair push (Phase Dash). Returns the pair pushes applied.
	int resolve(const godot::PackedFloat32Array &px, const godot::PackedFloat32Array &py,
			const godot::PackedFloat32Array &rad, const godot::PackedInt32Array &through,
			const godot::PackedInt32Array &heavy, bool ghost0, int iters);
	// resolve on the store's own columns: pos_x, pos_y and radius read by name, pos_x and pos_y written back.
	int resolve_actors(godot::Object *actors, const godot::PackedInt32Array &through,
			const godot::PackedInt32Array &heavy, bool ghost0, int iters);
	godot::PackedFloat32Array get_x() const { return out_x_; }
	godot::PackedFloat32Array get_y() const { return out_y_; }
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

	// Enemy AI (zd_ai.cpp, NATIVE_CORE.md §3.2-3.3), for the rows of NATIVE and HOOKED kinds. think: phase 3, the
	// walk plan on its staggered ticks and the state machine; held (a byte a row, or empty) is a spell's stun,
	// mine_owners the Mine Layers' mines (MineStore.owner). move: phase 5, the steering before the collision passes;
	// slow (a float a row, or empty: then frozen 0, slowed slow_permille / 1000, else 1) is ItemProcs.slow_factor.
	// flow_native: the flow field is the native nav grid's (else a blocked plan is a FLOW intent, and a relocating
	// Sniper's walk a RELOCATE_STEP). Both return the number of intents (ai_intents_i / _f, stride 4), or -1 when a
	// cache is missing (nothing changes).
	int think(godot::Object *actors, const godot::PackedFloat32Array &hero, int tick,
			const godot::PackedByteArray &held, const godot::PackedInt32Array &mine_owners, bool flow_native);
	int move(godot::Object *actors, const godot::PackedFloat32Array &hero, const godot::PackedFloat32Array &slow,
			float slow_permille, bool flow_native);
	godot::PackedInt32Array ai_intents_i() const;
	godot::PackedFloat32Array ai_intents_f() const;
	// zd_kinds.h's constants in LAYOUT order, and [HERO_SIZE, the intent codes]: what the tests compare with
	// NativeKindTable and NativeAi.
	godot::PackedInt32Array kind_layout() const;
	godot::PackedInt32Array ai_hero_layout() const;

	// The flow field's flood (zd_nav.cpp, NavField.flood whole in one call). The grid comes by set_nav_grid, its extra
	// cells (NavField.extra, empty for none) by set_nav_extra. nav_flood floods from `seeds` (NavField._seeds' flat
	// cell, distance pairs) with NavField's bound and targets into the cache's distances, and returns the work, or
	// -1 - the work when it stopped at its targets with cells still queued. nav_dist hands the distances back. A
	// kernel that steers by the field calls nav::direction (zd_nav.h) on nav_.
	void set_nav_extra(const godot::PackedByteArray &extra);
	int64_t nav_flood(const godot::PackedInt32Array &seeds, int64_t max_steps, const godot::PackedInt32Array &targets);
	godot::PackedInt32Array nav_dist() const;
	// Probe: NavField.direction at each (x, y) pair, on the cache's grid and distances.
	godot::PackedFloat32Array nav_directions(const godot::PackedFloat32Array &xy) const;

	// The projectile sweep (zd_shots.cpp, §3.5). Every projectile's segment this tick against the walls and the
	// bodies; skip (a Mine disc holding) and walls_only (Void and Wave shots) are empty or one byte a projectile.
	// Projectiles that meet nothing are advanced (pos_x, pos_y and life written back as new arrays). Returns the
	// events, in ascending projectile order, at most one each: HOLD (skip), CONTACT (body or wall, t), END (advanced
	// and out of life); -1 when a column is missing or of another length.
	int sweep_shots(godot::Object *projectiles, godot::Object *actors, const godot::PackedByteArray &skip,
			const godot::PackedByteArray &walls_only);
	// The last sweep_shots' events: four ints each (code, projectile, body or -1, wall or -1), and each one's t.
	godot::PackedInt32Array shot_events() const;
	godot::PackedFloat32Array shot_t() const;
	// One projectile's contact again, against the bodies as they stand now (one killed since the sweep is passed):
	// [t (2 when none), body or -1, wall or -1].
	godot::PackedFloat32Array sweep_one(godot::Object *projectiles, godot::Object *actors, int row, bool walls_only);

	// slot: strike (strike; zd_strike.cpp)
	// ---- end KERNEL METHODS ----

protected:
	static void _bind_methods();

private:
	// The caches (shared by every kernel).
	ColumnNames names_;
	WallGrid walls_;
	std::vector<Box> solids_;
	Trig trig_;
	KindTable kinds_;
	NavGrid nav_;

	// ---- KERNEL SCRATCH: one member per kernel that keeps working vectors ----
	CollideScratch collide_;
	godot::PackedFloat32Array out_x_, out_y_;

	AiScratch ai_;

	nav::Scratch nav_scratch_;

	ShotsScratch shots_;

	// slot: strike (StrikeScratch strike_;)
	// ---- end KERNEL SCRATCH ----
};

} // namespace zd
