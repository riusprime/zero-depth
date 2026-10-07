class_name Mines
extends RefCounted
## The Mine Layer's mines (v0.4.0 EN). A mine lies idle, its circle drawn, for its life. When the player's body
## touches the circle it arms: its fuse runs for fuse_total ticks (the attack's telegraph, at least
## MIN_TELEGRAPH_TICKS) with the circle filling, then it blows and hits the player if still touching it. Killing the
## Mine Layer clears its mines (as killing a Bomb Drone defuses its bomb). Runs in tick phase 6, after the enemies'
## own hits. The armed mines are their layer's telegraph (EnemyAi.telegraph): the same disc resolves the blast (EI-07).


## Mines of the layer with this id still on the floor.
static func count_of(w: World, owner_id: int) -> int:
	var n := 0
	for k in w.mines.size():
		if w.mines.owner[k] == owner_id:
			n += 1
	return n


## Actor i (a Mine Layer) drops a mine where it stands, if it has fewer than its max on the floor.
static func drop(w: World, i: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	if count_of(w, a.ids[i]) >= t.max_mines:
		return
	w.mines.add(
		w.take_root(),
		a.ids[i],
		a.pos(i),
		t.slam_radius_m,
		t.damage,
		t.mine_life_ticks,
		t.fuse_ticks
	)


## [center, radius] of mine k: the disc that arms it and that its blast hits.
static func disc(w: World, k: int) -> Array:
	return [w.mines.pos(k), w.mines.radius[k]]


static func advance(w: World) -> void:
	var m := w.mines
	if m.size() == 0:
		return
	var gone := PackedInt32Array()
	var p := w.player_pos()
	var pr := w.player.radius_m
	var alive := not w.player_dead()
	for k in m.size():
		var oi := w.actors.index_of(m.owner[k])
		if oi < 0 or w.actors.dead[oi] == 1:
			gone.append(k)  # its layer died: the mine goes with it
			continue
		var c := m.pos(k)  # the same disc as disc(k), without building an Array every tick
		if m.fuse[k] < 0:
			m.life[k] -= 1
			if m.life[k] <= 0:
				gone.append(k)
			elif alive and AttackShapes.disc_touches(c, m.radius[k], p, pr):
				m.fuse[k] = 0
			continue
		m.fuse[k] += 1
		if m.fuse[k] < m.fuse_total[k]:
			continue
		if alive and AttackShapes.disc_touches(c, m.radius[k], p, pr):
			Damage.hit(
				w, 0, m.damage[k], m.owner[k], m.owner[k], w.take_root(), SimEvent.TAG_AREA, c, p
			)
		gone.append(k)
	m.remove_sorted(gone)


## The layer's armed mines as one telegraph ({} when none): their discs, filling with the most advanced fuse.
static func telegraph(w: World, owner_id: int) -> Dictionary:
	var m := w.mines
	var centers := []
	var progress := 0
	var r := 0.0
	for k in m.size():
		if m.owner[k] != owner_id or m.fuse[k] < 0:
			continue
		centers.append(m.pos(k))
		r = m.radius[k]
		progress = maxi(progress, clampi(m.fuse[k] * 1000 / maxi(1, m.fuse_total[k]), 0, 1000))
	if centers.is_empty():
		return {}
	return {
		"shape": &"discs", "centers": centers, "radius": r, "progress": progress, "style": &"mine"
	}
