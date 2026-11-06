extends SceneTree
## v0.9.5 SB: prints each boss model's visible horizontal size (BossModels.get_model's AABB x BossModels.SIZE_SCALE)
## beside the boss tables' radius_m, for docs/roadmap/v0.9.5/evidence/SB.md. Run:
## godot --headless --path . -s scripts/checks/boss_footprints.gd

const PAIRS := {
	&"stone_sentinel": "res://data/bosses/gatekeeper.tres",
	&"crawler_queen": "res://data/bosses/brood_mother.tres",
	&"fortress_turret": "res://data/bosses/siege_engine.tres",
	&"warlord": "res://data/bosses/warlord.tres",
	&"hive_lens": "res://data/bosses/hive_lens.tres",
	&"foundry": "res://data/bosses/foundry.tres",
	&"boss_tidecaller": "res://data/bosses/tidecaller.tres",
	&"boss_twin_warden_amber": "res://data/bosses/twin_wardens.tres",
	&"boss_twin_warden_violet": "res://data/bosses/twin_wardens.tres",
	&"boss_clockwork_judge": "res://data/bosses/clockwork_judge.tres",
	&"boss_lantern_shade": "res://data/bosses/lantern_shade.tres",
	&"final_boss_colossus": "res://data/final_boss/colossus.tres",
	&"final_boss_prism": "res://data/final_boss/prism.tres",
	&"final_boss_nemesis": "res://data/final_boss/nemesis.tres",
}


func _initialize() -> void:
	for id: StringName in PAIRS:
		var m := BossModels.get_model(id)
		var res := load(PAIRS[id])
		var radius: float = res.get("radius_m") if res != null else -1.0
		if m.is_empty():
			print("%s  no model  radius_m=%s" % [id, radius])
			continue
		var bb: AABB = m["aabb"]
		var hx := bb.size.x * 0.5 * BossModels.SIZE_SCALE
		var hz := bb.size.z * 0.5 * BossModels.SIZE_SCALE
		var half := maxf(hx, hz)
		print(
			(
				"%s  half_x=%.3f half_z=%.3f half=%.3f radius_m=%.3f ratio=%.2f target85=%.3f"
				% [id, hx, hz, half, radius, radius / half, half * 0.85]
			)
		)
	quit()
