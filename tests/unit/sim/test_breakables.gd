extends GutTest
## v0.9.0 DX (owner W §4 C: "Breaking them reveals hidden spaces, resources, or collectibles"; §5: destructible
## containers "Small resource or reward chance", explosive objects "Environmental combat interactions"; Q23: "The
## Skill (Q / pad Y)", the hidden room unseen until it opens, containers and explosive barrels as proposed): the
## destructibles in the sim (Breakables). The cracked wall stands from the first tick; the Blade's Lunge Cleave and the
## Gun's Scatter Blast break it in three uses; the primary attacks never mark it; broken, the hidden room is seen with
## its reward; a container breaks to one hit and gives its drop; an explosive barrel's fuse burns 1 s, then the blast
## hurts the enemies and the hero in it, names its cause and chains; the state saves and resumes exactly.


func _wall_up(w: World) -> bool:
	var o := w.floor_layout.crack_wall
	for x in w.walls:
		if x.center == o.center and x.half == o.half and x.angle == o.angle:
			return true
	return false


func test_the_blades_skill_breaks_the_cracked_wall_in_three() -> void:
	var w := CrackLab.world(&"blade")
	assert_not_null(w, "a floor with a cracked wall")
	if w == null:
		return
	var reader := WorldReader.new(w)
	var f := w.floor_layout
	var b := w.breakables
	w.step(InputFrame.new())
	assert_true(_wall_up(w), "the wall stands from the first tick")
	assert_true(reader.hidden_rooms().has(f.crack_room), "the room behind it unseen")
	var i := w.rewards.index_of(b.crack_reward_id)
	assert_gte(i, 0, "a reward behind it")
	assert_eq(f.room_of(w.rewards.pos(i)), f.crack_room)
	assert_true(reader.reward_hidden(i), "unseen")
	for q in w.spawn_points:
		assert_ne(f.room_of(q), f.crack_room, "no enemy spawns inside")
	for k in 3:
		assert_false(b.crack_broken == 1, "still whole before use %d" % (k + 1))
		CrackLab.skill(w)
		assert_eq(b.crack_hp, 2 - k, "Lunge Cleave use %d took one" % (k + 1))
	assert_eq(b.crack_broken, 1, "three Skill uses: broken")
	assert_false(_wall_up(w), "the wall is gone")
	assert_false(reader.hidden_rooms().has(f.crack_room), "the room is seen")
	assert_false(reader.reward_hidden(i))
	CrackLab.skill(w)
	assert_eq(b.crack_hp, 0, "broken stays broken")


func test_the_guns_skill_breaks_it_too() -> void:
	var w := CrackLab.world(&"gun")
	if w == null:
		return
	w.step(InputFrame.new())
	for k in 3:
		CrackLab.skill(w, 2.5)
	assert_eq(w.breakables.crack_broken, 1, "three Scatter Blasts break it")


func test_no_other_attack_marks_it() -> void:
	for build: StringName in [&"blade", &"gun"]:
		var w := CrackLab.world(build)
		if w == null:
			return
		w.step(InputFrame.new())
		var button := InputFrame.PRIMARY if build == &"blade" else InputFrame.SHOOT
		for k in 30:
			CrackLab.face_wall(w, 1.0)
			CrackLab.press(w, button, 20)
		assert_eq(w.breakables.crack_hp, 3, "%s: 30 primary attacks leave it whole" % build)
		assert_true(_wall_up(w))


func test_a_container_breaks_to_one_hit_and_drops() -> void:
	var w := CrackLab.world(&"blade", false)
	assert_not_null(w, "a floor with props")
	if w == null:
		return
	var b := w.breakables
	var i := _first(b, [Breakables.Kind.CRATE, Breakables.Kind.URN, Breakables.Kind.BARREL])
	assert_gte(i, 0, "a container on the floor")
	if i < 0:
		return
	b.drop[i] = Breakables.Drop.SHARDS
	b.drop_amount[i] = 4
	var shards := w.shards
	_swing_at(w, b.pos[i])
	assert_eq(b.broken[i], 1, "one swing breaks it")
	assert_eq(w.shards, shards + 4, "its few shards")
	var j := _first(b, [Breakables.Kind.CRATE, Breakables.Kind.URN, Breakables.Kind.BARREL], i + 1)
	if j >= 0:
		b.drop[j] = Breakables.Drop.HEAL
		var orbs := w.orbs.size()
		_swing_at(w, b.pos[j])
		assert_eq(b.broken[j], 1)
		assert_eq(w.orbs.size(), orbs + 1, "or a heal orb")
	var drops := 0
	var heals := 0
	var all := 0
	for k in b.pos.size():
		if b.kind[k] != Breakables.Kind.EXPLOSIVE:
			all += 1
			drops += 1 if b.drop[k] != Breakables.Drop.NONE else 0
			heals += 1 if b.drop[k] == Breakables.Drop.HEAL else 0
	gut.p(
		(
			"CONTAINERS| floor_props=%d containers=%d with_drop=%d heals=%d"
			% [b.pos.size(), all, drops, heals]
		)
	)


func test_the_barrel_fuse_then_the_blast_hurts_both_and_names_its_cause() -> void:
	var w := CrackLab.world(&"blade", false)
	if w == null:
		return
	var b := w.breakables
	var i := _first(b, [Breakables.Kind.EXPLOSIVE])
	if i < 0:
		b.add(w.player_pos() + Vector2(3.0, 0.0), Breakables.Kind.EXPLOSIVE, 0, 0, 0)
		i = b.pos.size() - 1
	var at := b.pos[i]
	w.actors.invuln[0] = 0
	var check := ReadableCause.new(w)
	var id := w.add_enemy(ActorStore.Kind.CHARGER, at + Vector2(1.2, 0.0))
	var reader := WorldReader.new(w)
	_swing_at(w, at)
	assert_eq(b.broken[i], 0, "a hit lights it, it doesn't blow yet")
	assert_gte(b.fuse_tick[i], 0, "the fuse is lit")
	assert_true(reader.breakable_fusing(i))
	var lit := b.fuse_tick[i]
	w.actors.set_pos(0, at + Vector2(-1.0, 0.0))
	var hp := w.actors.hp[0]
	var e := w.actors.index_of(id)
	var ehp := w.actors.hp[e]
	while b.broken[i] == 0 and w.tick - lit < 200:
		w.actors.set_pos(0, at + Vector2(-1.0, 0.0))
		w.vel = Vector2.ZERO
		w.step(InputFrame.new())
		check.observe(w)
	assert_eq(b.break_tick[i] - lit, 60, "it blows after a 1.0 s fuse")
	assert_lt(w.actors.hp[0], hp, "the blast hurt the hero")
	# the hero's share, through the hero's own damage taken (the Blade takes 25 % less: 15 -> 11)
	assert_between(hp - w.actors.hp[0], 1, b.hero_damage, "by the hero's share, after armour")
	e = w.actors.index_of(id)
	assert_true(e < 0 or w.actors.hp[e] < ehp, "and the enemy beside it")
	assert_true(check.by_cause.has("CAUSE_EXPLOSIVE_BARREL"), "the hit names the barrel")
	assert_eq(check.violations.size(), 0, "a readable cause: %s" % str(check.violations))


func test_a_blast_that_kills_the_hero_is_in_the_recap() -> void:
	var w := CrackLab.world(&"blade", false)
	if w == null:
		return
	var b := w.breakables
	b.add(w.player_pos() + Vector2(1.0, 0.0), Breakables.Kind.EXPLOSIVE, 0, 0, 0)
	var i := b.pos.size() - 1
	w.actors.invuln[0] = 0
	w.actors.hp[0] = 1
	Breakables.hit(w, i)
	for k in 70:
		w.step(InputFrame.new())
	assert_true(w.player_dead(), "the blast killed the hero")
	assert_eq(
		WorldReader.new(w).killer_cause_key(),
		Breakables.CAUSE_KEY,
		"the recap says an explosive barrel"
	)


func test_a_blast_chains_to_props_in_reach() -> void:
	var w := CrackLab.world(&"blade", false)
	if w == null:
		return
	var b := w.breakables
	var at := w.floor_layout.start_pos + Vector2(0.0, 3.0)
	b.add(at, Breakables.Kind.EXPLOSIVE, 0, 0, 0)
	b.add(at + Vector2(1.5, 0.0), Breakables.Kind.CRATE, 0, 0, 0)
	b.add(at + Vector2(-1.5, 0.0), Breakables.Kind.EXPLOSIVE, 0, 0, 0)
	var n := b.pos.size()
	Breakables.hit(w, n - 3)
	for k in 61:
		w.step(InputFrame.new())
	assert_eq(b.broken[n - 3], 1, "the first blew")
	assert_eq(b.broken[n - 2], 1, "the crate beside it broke")
	assert_gte(b.fuse_tick[n - 1], 0, "and the next barrel's fuse is lit")


func test_saves_mid_way_and_after_resume_exactly() -> void:
	var w := CrackLab.world(&"blade")
	if w == null:
		return
	w.step(InputFrame.new())
	CrackLab.skill(w)
	var b := w.breakables
	var i := _first(b, [Breakables.Kind.EXPLOSIVE])
	if i >= 0:
		Breakables.hit(w, i)
	var snap := WorldSnapshot.take(w)
	var base := CrackLab.world(&"blade")
	assert_eq(WorldSnapshot.apply(base, snap), "", "a save with the wall up and a fuse lit fits")
	assert_eq(base.state_hash(), w.state_hash(), "same state")
	for k in 2:
		CrackLab.skill(w)
		CrackLab.skill(base)
	assert_eq(base.state_hash(), w.state_hash(), "and breaks the same")
	assert_eq(base.breakables.crack_broken, 1)
	var after := WorldSnapshot.take(w)
	var base2 := CrackLab.world(&"blade")
	assert_eq(WorldSnapshot.apply(base2, after), "", "a save after it broke fits")
	assert_eq(base2.state_hash(), w.state_hash())


## Swings the Blade at `at` from 1 m away (a fresh swing, the last one waited out).
func _swing_at(w: World, at: Vector2) -> void:
	var from := at + Vector2(-1.0, 0.0)
	w.actors.set_pos(0, from)
	w.vel = Vector2.ZERO
	w.build_state.facing_angle = Kin.angle_of(at - from)
	var a := Kin.angle_of(at - from)
	w.step(InputFrame.make(Vector2i.ZERO, a, 100, InputFrame.PRIMARY, InputFrame.PRIMARY))
	for k in 30:
		w.step(InputFrame.make(Vector2i.ZERO, a, 100, 0, 0))


func _first(b: Breakables, kinds: Array, from: int = 0) -> int:
	for k in range(from, b.pos.size()):
		if b.kind[k] in kinds and b.broken[k] == 0:
			return k
	return -1
