extends GutTest
## v0.9.0 SH, HF (owner Q29b, W36; MI2: the owner's `shrine_blood`, `shrine_chaos`, `shrine_fortune`,
## `healing_fountain`): the shrines' and the fountain's views. The Blood or Chaos shrine and the fountain draw the
## owner's models (code stand-ins when the manifest doesn't list them); Blood paid goes dim, the fountain used goes dry;
## the shared prompt shows the price before the press; the HUD line shows what the press did; the Fortune Shrine is
## the gamble shrine drawn with the owner's Fortune model; the sounds play once each.


func after_each() -> void:
	ShopModels.manifest = ShopModels.MANIFEST
	ShopModels.clear_cache()


## A bare world holding a Blood shrine and a fountain (as Shrines.setup leaves them).
func _world(kind: int = ShrineTable.Kind.BLOOD) -> World:
	var w := World.new(5, PlayerTable.starting_values())
	w.gamble_id = w.take_root()
	w.gamble_pos = Vector2(3.0, -2.0)
	var s := ShrineState.new()
	s.table = ShrineTable.new()
	s.kind = kind
	s.pos = w.gamble_pos
	s.entry = w.interactables.add(Interactables.Kind.SHRINE, s.pos, s.table.reach_m, kind)
	s.fountain_pos = Vector2(-4.0, 3.0)
	s.fountain_entry = w.interactables.add(
		Interactables.Kind.FOUNTAIN, s.fountain_pos, s.table.reach_m, 0
	)
	w.shrine = s
	w.actors.set_pos(0, s.pos + Vector2(1.2, 0))
	return w


func _view(w: World) -> ShrinesView:
	var v := ShrinesView.new()
	add_child_autofree(v)
	v.setup(WorldReader.new(w))
	return v


func test_the_models_stand_at_the_sim_spots() -> void:
	var w := _world()
	var v := _view(w)
	assert_true(v.shrine_model, "the owner's Blood shrine is listed and drawn")
	assert_true(v.fountain_model, "the owner's fountain too")
	assert_eq(v.shrine_root.position, SimPlane.to_3d(w.shrine.pos), "at the shrine's sim spot")
	assert_eq(v.fountain_root.position, SimPlane.to_3d(w.shrine.fountain_pos), "at the fountain's")
	var mi := v.shrine_root.get_node("Model") as MeshInstance3D
	var box := mi.mesh.get_aabb()
	assert_almost_eq(box.position.y, 0.0, 0.001, "on the floor")
	assert_almost_eq(box.end.y, 1.5, 0.01, "Blood drawn 1.5 m tall")
	var fm := v.fountain_root.get_node("Model") as MeshInstance3D
	assert_almost_eq(fm.mesh.get_aabb().end.y, 1.4, 0.01, "the fountain 1.4 m tall")
	var c := _view(_world(ShrineTable.Kind.CHAOS))
	assert_eq(c.shrine_root.name, "Chaos")
	var cm := c.shrine_root.get_node("Model") as MeshInstance3D
	assert_almost_eq(cm.mesh.get_aabb().end.y, 1.8, 0.01, "Chaos drawn 1.8 m tall")


func test_the_stand_ins_without_the_models() -> void:
	ShopModels.manifest = "res://no_such_manifest.json"
	ShopModels.clear_cache()
	var v := _view(_world())
	assert_false(v.shrine_model, "no model listed: the stand-in")
	assert_false(v.fountain_model)
	assert_true(v.shrine_root.has_node("Basin"), "the Blood stand-in's basin")
	assert_not_null(v.water, "the fountain stand-in's water")
	assert_true(v.water.visible)


func test_blood_paid_dims_and_the_fountain_runs_dry() -> void:
	ShopModels.manifest = "res://no_such_manifest.json"
	ShopModels.clear_cache()
	var w := _world()
	var v := _view(w)
	var reader := WorldReader.new(w)
	assert_false(v.spent())
	assert_false(v.dry())
	Shrines.press_shrine(w, w.shrine.entry)
	v.sync(reader)
	assert_true(v.spent(), "Blood paid: dim")
	w.actors.hp[0] = 10
	Shrines.press_fountain(w, w.shrine.fountain_entry)
	v.sync(reader)
	assert_true(v.dry(), "used: dry")
	v._fountain_flash = 0.0
	v._apply()
	assert_false(v.water.visible, "its water gone")
	assert_eq(v.fountain_light.light_energy, 0.0, "its light out")


func test_the_prompt_shows_the_price_and_the_hud_the_result() -> void:
	TranslationServer.set_locale("en")
	var w := _world()
	var reader := WorldReader.new(w)
	var prompt := InteractPromptHud.new()
	add_child_autofree(prompt)
	prompt.sync(reader)
	var cost := Shrines.blood_cost(w)
	assert_gt(cost, 0)
	assert_eq(prompt.prompt_text(), "Pray · −%d HP" % cost, "the price before the press")
	var hud := ShrineHud.new()
	add_child_autofree(hud)
	hud.sync(reader)
	assert_eq(hud.line(), "", "nothing done yet")
	w.tick = 5
	Shrines.press_shrine(w, w.shrine.entry)
	hud.sync(reader)
	assert_eq(hud.line(), "Blood Shrine · −%d HP · an upgrade rises" % cost, "what it took")
	w.actors.set_pos(0, w.shrine.fountain_pos + Vector2(1.2, 0))
	w.actors.hp[0] = 10
	prompt.sync(reader)
	var heal := Shrines.fountain_heal(w)
	assert_eq(prompt.prompt_text(), "Drink · +%d HP" % heal)
	w.tick = 9
	Shrines.press_fountain(w, w.shrine.fountain_entry)
	hud.sync(reader)
	assert_eq(hud.line(), "Healing Fountain · +%d HP · the fountain runs dry" % heal)


func test_the_sounds_play_once() -> void:
	var w := _world()
	var reader := WorldReader.new(w)
	var a := AudioEvents.new()
	a.prime(reader)
	assert_eq(a.collect(reader).size(), 0)
	w.tick = 3
	Shrines.press_shrine(w, w.shrine.entry)
	var ids := []
	for r: Array in a.collect(reader):
		ids.append(r[0])
	assert_true(ids.has(&"shrine_blood"), "Blood's price taken")
	w.actors.hp[0] = 10
	Shrines.press_fountain(w, w.shrine.fountain_entry)
	ids.clear()
	for r: Array in a.collect(reader):
		ids.append(r[0])
	assert_eq(ids, [&"fountain_heal"], "the fountain, once")
	assert_eq(a.collect(reader).size(), 0, "nothing more")


func test_the_fortune_shrine_draws_the_owners_fortune_model() -> void:
	var w := World.new(5, PlayerTable.starting_values())
	w.gamble_id = w.take_root()
	w.gamble_pos = Vector2(3.4, -2.6)
	var view := GambleShrineView.new()
	view.kit_model = true
	add_child_autofree(view)
	view.set_process(false)
	view.setup(w.gamble_pos)
	view.sync(WorldReader.new(w))
	assert_true(view.uses_model())
	assert_same(
		view.model().mesh,
		ShopModels.get_model(GambleShrineView.FORTUNE_ID)["mesh"],
		"the Fortune model"
	)
	var box := view.model().global_transform * view.model().mesh.get_aabb()
	assert_almost_eq(box.end.y, 2.0, 0.01, "2.0 m tall")
	assert_true(view.price_label != null, "the price still floats above it")
