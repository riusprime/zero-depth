#pragma once
// The enemy strike kernel (NATIVE_CORE.md §3.4): ZdWorld::strike, tick phase 6's per-enemy loop for every row whose
// kind is NATIVE or HOOKED in the per-kind table (zd_kinds.h). For each such row that is ACTIVE (a critter: walking),
// alive, not frozen, with the hero alive, it tests the kind's hit shape on its tick against the hero (contact, the
// locked disc, the bash lane, the snipe lane, the rune, a lobbed burst's landing), runs the sight test from the
// hit's origin (EnemyAi.sees_player), and counts the Needle's burst and a pattern's waves on their ticks, with
// the shapes, reaches, ticks and fire rates the telegraphs draw (EnemyAi's lane and disc functions, EI-07).
// It reads the store and writes nothing: what lands or fires is handed back as a list, ascending by row and then by
// code, which GDScript applies in that order (NativeStrike, src/sim/world/native_strike.gd): the damage, the
// counters that say a hit or a shot was spent (fire_cd, a critter's cd), the projectiles, the pattern waves and the
// hooked kinds' own rules. It draws nothing (every random draw stays in GDScript) and keeps nothing between calls.
// ZdWorld's methods strike, strike_out_i, strike_out_f and strike_layout are defined in zd_strike.cpp.

#include <cstdint>
#include <vector>

namespace zd {

// The list's codes (NativeStrike.Out), in the order a row's entries are listed. Stride 4: ints (code, row, a, b),
// floats (f0, f1, f2, f3).
enum StrikeOut : int32_t {
	O_HIT = 1, // a shape touched the hero and the origin sees it: a = damage, b = tags, (f0, f1) the origin when
	// f2 is 1 (else the body)
	O_CONTACT = 2, // a contact kind's body touched the hero: fire_cd = 1 (its one hit), then the hit when b (seen) is 1
	O_TOUCH = 3, // a critter's touch: cd = contact_cd_ticks, then the hit when b (seen) is 1; applied after the rest
	O_BOLT = 4, // the Needle's burst shot: a = its angle, b = its index (fire_cd + 1 after it)
	O_WAVE = 5, // a pattern's wave: a = the wave, b = the pattern slot
	O_ACTIVE_HOOK = 6, // a hooked kind's active tick: GDScript runs its rule (mines, the blob, the blink, split lanes)
};

// NativeKindTable.Shape
enum StrikeShape : int32_t {
	SH_NONE = 0,
	SH_CONTACT,
	SH_LOCKED_DISC,
	SH_BASH_LANE,
	SH_SNIPE_LANE,
	SH_RUNE_DISC,
	SH_BURST,
	SH_PATTERN,
	SH_HOOK,
};

struct StrikeScratch {
	std::vector<int32_t> out_i;
	std::vector<float> out_f;

	void emit(int32_t code, int32_t row, int32_t a, int32_t b, float f0 = 0.0f, float f1 = 0.0f, float f2 = 0.0f) {
		out_i.push_back(code);
		out_i.push_back(row);
		out_i.push_back(a);
		out_i.push_back(b);
		out_f.push_back(f0);
		out_f.push_back(f1);
		out_f.push_back(f2);
		out_f.push_back(0.0f);
	}
};

} // namespace zd
