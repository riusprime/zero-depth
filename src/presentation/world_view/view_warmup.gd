class_name ViewWarmup
extends RefCounted
## v0.8.0 N12 (owner O70; docs/roadmap/v0.8.0/evidence/LOADS_NO_FREEZE.md): reads the owner's models a floor will draw
## into their caches before its view is built, as a worker job of the view's ViewBuildQueue (WorldViewRoot.queue_setup),
## so the main thread never waits on a model file: the boss models (BossModels.preload_all, as the stage build always
## did), the kit's pieces, their decoration detail and the chest's two halves, the wall textures, and the shop
## stall's models, and (v0.8.0 BD) the biome's boss door. Measured
## before N12, reading them cold held one frame of a run's first floor for 5-8 s (the boss models), 2-3 s (the shop
## stall) and 0.5 s (the kit's walls). Each cache is filled once per run of the game; later floors find them filled.
## Thread rule: the worker reads and fills these caches while the main thread builds nothing and draws only the
## loading cover (the queue runs no other job until it is done, the old floor's view is gone and the new one is not
## processing), so no frame reads a cache while it is filled.

## v0.8.0 MI (the load-frame fix): the textures warm() read (the biome's wall textures, Starfall's crack textures),
## kept until the next warm(): a read that nothing holds is let go at once and read again, from its file, on the main
## thread by the job that uses it.

static var _kept: Array = []


## `final`: the final boss's three models too (the final arena, the Playground). `kit`: the floor is dressed from
## the kit (a biome mood; v0.8.0 N10: with the biome's wall textures). `biome`: the floor's (StageView.prop_style).
## `shop`: the floor has the biome's shop stall.
static func warm(final: bool, kit: bool, biome: StringName, shop: bool) -> void:
	BossModels.preload_all(final)
	# v0.8.0 MI: the owner's enemy models (read here, so a Mender's first spawn never reads a file mid-fight) and the
	# two devices' models (the Loop device's pad, the Ascension portal).
	for id: StringName in EnemyModels.SPECS:
		EnemyModels.get_model(id)
	LoopDevice.warm_model()
	AscensionPortal.warm_model()
	BossDoorModels.get_model(biome)  # v0.8.0 BD (O82): the biome's boss door
	if kit:
		for id: StringName in KitModels.SPECS:
			var piece := KitModels.get_piece(id)
			if not piece.is_empty() and KitModels.SPECS[id]["role"] == &"decor":
				KitModels.decor_mesh(piece["mesh"])
		KitModels.split(&"chest", KitModels.CHEST_LID_CUT)
		var keep: Array = StageView.wall_textures(biome).values()
		for path: String in [StarglowViews.STARS_TEX, StarglowViews.CRACKS_TEX]:
			if biome == &"starfall" and ResourceLoader.exists(path):
				keep.append(load(path))
		_kept = keep
		VfxCore.warm()  # the effects layer's sheets and floor marks (a floor with a mood has the layer)
	if shop:
		for id: StringName in [&"shop_tent", &"shop_wares", ShopModels.vendor_id(biome)]:
			ShopModels.get_model(id)
