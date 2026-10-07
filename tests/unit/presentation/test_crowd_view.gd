extends GutTest
## The view under a horde (v0.4.0 SC): projectile nodes are pooled and share one mesh and material per look; an
## enemy's HP bar shows only once it is hurt; enemy models far off screen stop animating; occlusion's quick reject
## never changes which walls it picks; the damage-lag rule still holds (no shader change on a reused shot).

const TO_CAM := Vector2(0.70710678, -0.70710678)


func _setup() -> Array:
	var w := CombatLab.world()
	var reader := WorldReader.new(w)
	var views := ActorViews.new()
	add_child_autofree(views)
	views.set_process(false)
	views.sync(reader)
	return [w, reader, views]


func _shoot(w: World, n: int) -> void:
	for k in n:
		var dir := Kin.dir(k * 4096 / maxi(1, n))
		w.queue_projectile(2, ActorStore.TEAM_ENEMY, dir * 2.0, dir * 0.05, 0, 0.1, 4, 0)


func test_projectile_nodes_go_back_to_the_pool_and_come_back() -> void:
	var s := _setup()
	var w: World = s[0]
	var views: ActorViews = s[2]
	_shoot(w, 30)
	w.step(InputFrame.new())
	views.sync(s[1])
	var first := views.projectile_node(w.projectiles.ids[0])
	var mesh := (first.get_child(0) as MeshInstance3D).mesh
	var mat := (first.get_child(0) as MeshInstance3D).material_override
	var children := views.get_child_count()
	for k in 6:
		w.step(InputFrame.new())
	views.sync(s[1])
	assert_eq(w.projectiles.size(), 0, "all expired")
	assert_eq(views.pooled_projectiles(), 30, "their nodes wait, hidden, for reuse")
	assert_false(first.visible)
	assert_eq(views.get_child_count(), children, "nothing freed")
	_shoot(w, 30)
	w.step(InputFrame.new())
	views.sync(s[1])
	assert_eq(views.pooled_projectiles(), 0, "the next 30 shots took them back")
	assert_eq(views.get_child_count(), children, "and built none")
	var again := views.projectile_node(w.projectiles.ids[0])
	assert_true(again.visible)
	assert_same((again.get_child(0) as MeshInstance3D).mesh, mesh, "one mesh per look")
	assert_same(
		(again.get_child(0) as MeshInstance3D).material_override, mat, "one kept material per look"
	)


func test_the_pool_is_bounded() -> void:
	var s := _setup()
	var w: World = s[0]
	var views: ActorViews = s[2]
	_shoot(w, ActorViews.PROJECTILE_POOL_MAX + 50)
	w.step(InputFrame.new())
	views.sync(s[1])
	for k in 6:
		w.step(InputFrame.new())
	views.sync(s[1])
	assert_eq(views.pooled_projectiles(), ActorViews.PROJECTILE_POOL_MAX, "the rest are freed")


func test_an_enemy_bar_shows_once_it_is_hurt() -> void:
	var s := _setup()
	var w: World = s[0]
	var views: ActorViews = s[2]
	var id := w.add_enemy(ActorStore.Kind.CHARGER, Vector2(4, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 2)
	views.sync(s[1])
	var node := views.actor_node(id)
	var bar: Node3D = node.get_meta(&"bar")
	assert_false(bar.visible, "full health: no bar")
	assert_true(
		(views.actor_node(w.actors.ids[0]).get_meta(&"bar") as Node3D).visible, "the hero's shows"
	)
	var i := w.actors.index_of(id)
	w.actors.hp[i] = w.actors.max_hp[i] / 2
	views.sync(s[1])
	assert_true(bar.visible, "hurt: the bar shows")
	assert_almost_eq(bar.scale.x, 0.5, 0.05, "at half")


func test_far_enemies_stop_animating() -> void:
	var s := _setup()
	var w: World = s[0]
	var views: ActorViews = s[2]
	var near := w.add_enemy(ActorStore.Kind.NEEDLE, Vector2(5, 0))
	var far := w.add_enemy(ActorStore.Kind.NEEDLE, Vector2(ActorViews.ANIMATE_RADIUS_M + 5.0, 0))
	views.sync(s[1])
	var near_avatar: Node = views.actor_node(near).get_meta(&"enemy_avatar")
	var far_avatar: Node = views.actor_node(far).get_meta(&"enemy_avatar")
	assert_true(near_avatar.is_processing(), "on screen: animated")
	assert_false(far_avatar.is_processing(), "off screen: still")
	w.actors.set_pos(w.actors.index_of(far), Vector2(6, 2))
	views.sync(s[1])
	assert_true(far_avatar.is_processing(), "back in view: animated again")


## The quick reject in Occlusion.select drops only pairs the exact test would reject.
func test_occlusion_quick_reject_keeps_the_same_walls() -> void:
	var rng := RngStream.derive(4, "occ")
	var walls := []
	for k in 60:
		var c := Vector2(rng.range_int(-2000, 2000), rng.range_int(-2000, 2000)) / 100.0
		var half := Vector2(rng.range_int(20, 300), rng.range_int(10, 60)) / 100.0
		walls.append([c, half, rng.range_int(0, 628) / 100.0, rng.range_int(50, 400) / 100.0])
	var focus: Array[Vector2] = []
	for k in 40:
		focus.append(Vector2(rng.range_int(-2000, 2000), rng.range_int(-2000, 2000)) / 100.0)
	var got := Occlusion.select(TO_CAM, 35.26, focus, walls)
	var want := PackedInt32Array()
	var rise := tan(deg_to_rad(35.26))
	for wi in walls.size():
		var wl: Array = walls[wi]
		var reach: float = maxf(0.0, (wl[3] - SimPlane.CORE_HEIGHT) / maxf(rise, 0.01))
		for p in focus:
			if Occlusion._segment_hits_box(p, p + TO_CAM * reach, wl[0], wl[1], wl[2]):
				want.append(wi)
				break
	assert_gt(want.size(), 0, "some walls hide some points")
	assert_eq(got, want)
