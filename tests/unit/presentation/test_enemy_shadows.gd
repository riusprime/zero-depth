extends GutTest
## v0.10.5 PA (owner, perf wave 2): a normal or elite enemy's visible parts cast no shadow; one shadow-only mesh shaped
## like it (built once per kind) casts it, or in the blob mode a soft disc with no shadow pass at all. Bosses and the
## hero keep their own. Physics interpolation is kept only on enemies the camera could show.

const KINDS: Array[int] = [
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.NEEDLE,
	ActorStore.Kind.WARDEN,
	ActorStore.Kind.ARC_CASTER,
	ActorStore.Kind.BOMB_DRONE,
	ActorStore.Kind.SWARMER,
	ActorStore.Kind.SPLITTER,
	ActorStore.Kind.SNIPER,
]

var _mode := ""


func before_each() -> void:
	_mode = ViewPrefs.enemy_shadows
	EnemyShadows.clear_cache()


func after_each() -> void:
	ViewPrefs.enemy_shadows = _mode


## Every GeometryInstance3D under `n` with its shadow setting not OFF.
func _casters(n: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for g: Node in n.find_children("*", "GeometryInstance3D", true, false):
		if (g as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			out.append(g)
	return out


func _views_with(mode: String) -> Array:
	ViewPrefs.enemy_shadows = mode
	var w := CombatLab.world()
	var ids: Array[int] = []
	for k in KINDS.size():
		ids.append(w.add_enemy(KINDS[k], Vector2(3.0 * (k + 1), 2.0)))
	ids.append(Elites.spawn(w, ActorStore.Kind.BREAKER, Vector2(6.0, 8.0), Elites.Source.DEV))
	ids.append(w.add_enemy(ActorStore.Kind.CHARGER, Vector2(3.0, 5.0)))  # a second of a kind
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(WorldReader.new(w))
	return [views, ids]


func test_enemy_parts_cast_none_and_one_proxy_casts_its_shadow() -> void:
	var made := _views_with("proxy")
	var views: ActorViews = made[0]
	for id: int in made[1]:
		var node := views.actor_node(id)
		var casters := _casters(node)
		assert_eq(casters.size(), 1, "kind %d: one caster" % id)
		var proxy := casters[0]
		assert_eq(proxy.name, String(EnemyShadows.PROXY_NAME))
		assert_eq(proxy.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
		assert_eq(proxy.get_parent(), node.get_meta(&"enemy_avatar"), "it moves with the avatar")
		var mesh := (proxy as MeshInstance3D).mesh
		assert_eq(mesh.get_surface_count(), 1, "one mesh, one surface")
		assert_gt(mesh.get_aabb().size.y, 0.2, "shaped like the body, not flat")
	var a := _casters(views.actor_node(made[1][0]))[0] as MeshInstance3D
	var b := _casters(views.actor_node(made[1][-1]))[0] as MeshInstance3D
	assert_same(a.mesh, b.mesh, "built once per kind and shared")
	assert_eq(EnemyShadows.cached_kinds(), KINDS.size() + 1, "the kinds and the elite")


func test_blob_mode_draws_a_disc_and_no_shadow_casters() -> void:
	var made := _views_with("blob")
	var views: ActorViews = made[0]
	for id: int in made[1]:
		var node := views.actor_node(id)
		assert_eq(_casters(node).size(), 0, "nothing of it in a shadow pass")
		var blob := node.get_node_or_null(String(EnemyShadows.BLOB_NAME)) as MeshInstance3D
		assert_not_null(blob, "its blob")
		assert_true(blob.visible)
		assert_gt(blob.scale.x, 0.5, "sized to its radius")
	assert_eq(EnemyShadows.cached_kinds(), 0, "no proxy built")


func test_bosses_and_the_hero_keep_their_own_shadows() -> void:
	ViewPrefs.enemy_shadows = "blob"
	var w := BossLab.world()
	var boss := w.spawn_boss(0, Vector2(6, 0))
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.sync(WorldReader.new(w))
	var bnode := views.actor_node(boss)
	assert_gt(_casters(bnode).size(), 0, "the boss's own pieces cast")
	assert_null(bnode.get_node_or_null(String(EnemyShadows.BLOB_NAME)), "no blob")
	var hero := views.actor_node(w.actors.ids[0])
	assert_not_null(hero.get_meta(&"avatar"), "the hero")
	assert_gt(_casters(hero).size(), 1, "the hero's own pieces cast")


func test_far_enemies_drop_interpolation_and_near_ones_keep_it() -> void:
	var rig: IsoRig = add_child_autofree(IsoRig.new())
	rig.snap_to(Vector3.ZERO)
	var cull := ScreenCull.new()
	cull.refresh(rig.camera)
	var w := CombatLab.world()
	var near := w.add_enemy(ActorStore.Kind.NEEDLE, Vector2(2, 1))
	var far := w.add_enemy(ActorStore.Kind.NEEDLE, Vector2(120, 0))
	var reader := WorldReader.new(w)
	var views: ActorViews = add_child_autofree(ActorViews.new())
	views.set_process(false)
	views.cull = cull
	views.sync(reader)
	assert_true(views.actor_node(near).is_physics_interpolated(), "on screen: interpolated")
	assert_false(views.actor_node(far).is_physics_interpolated(), "far off screen: not")
	assert_eq(views.actor_node(far).physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF)
	w.actors.set_pos(w.actors.index_of(far), Vector2(3, -1))
	views.sync(reader)
	assert_true(views.actor_node(far).is_physics_interpolated(), "come near: interpolated again")
	var hero := views.actor_node(w.actors.ids[0])
	assert_true(hero.is_physics_interpolated(), "the hero always")
