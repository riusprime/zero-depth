#include "zd_columns.h"

using namespace godot;

namespace zd {

ColumnNames::ColumnNames() :
		ids("ids"),
		kinds("kinds"),
		teams("teams"),
		pos_x("pos_x"),
		pos_y("pos_y"),
		radius("radius"),
		hp("hp"),
		max_hp("max_hp"),
		invuln("invuln"),
		dead("dead"),
		state("state"),
		state_t("state_t"),
		facing("facing"),
		lock_x("lock_x"),
		lock_y("lock_y"),
		lock_a("lock_a"),
		lock_len("lock_len"),
		cd("cd"),
		fire_cd("fire_cd"),
		jitter_x("jitter_x"),
		jitter_y("jitter_y"),
		slow_t("slow_t"),
		frozen_t("frozen_t"),
		windup("windup"),
		pick("pick"),
		plan_block("plan_block"),
		plan_x("plan_x"),
		plan_y("plan_y"),
		power("power"),
		owner("owner"),
		team("team"),
		vel_x("vel_x"),
		vel_y("vel_y"),
		life("life"),
		damage("damage"),
		tags("tags"),
		bounces("bounces"),
		pierce_left("pierce_left"),
		speed("speed") {}

namespace cols {

void put_f32(Object *store, const StringName &name, const float *src, int64_t n) {
	PackedFloat32Array out;
	out.resize(n);
	if (n > 0) {
		std::memcpy(out.ptrw(), src, size_t(n) * sizeof(float));
	}
	store->set(name, out);
}

void put_i32(Object *store, const StringName &name, const int32_t *src, int64_t n) {
	PackedInt32Array out;
	out.resize(n);
	if (n > 0) {
		std::memcpy(out.ptrw(), src, size_t(n) * sizeof(int32_t));
	}
	store->set(name, out);
}

void put_u8(Object *store, const StringName &name, const uint8_t *src, int64_t n) {
	PackedByteArray out;
	out.resize(n);
	if (n > 0) {
		std::memcpy(out.ptrw(), src, size_t(n));
	}
	store->set(name, out);
}

} // namespace cols
} // namespace zd
