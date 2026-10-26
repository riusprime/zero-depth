class_name BossSignatures
extends RefCounted
## v0.8.0 BS1 (owner O5, "something that actually stands out for each boss"; docs/roadmap/v0.8.0/BOSS_SIGNATURES.md,
## approved 2026-10-14; SIM_CONTRACTS §10f): each boss's signature mechanic, one no other boss has, on top of the
## dodge-first engine (BossDodge, BulletPatterns). Rows S1-S3:
## - S1, the Gatekeeper's Stone Spikes that stay: a `row_lanes` attack with pillar_ticks leaves stone pillars along its
##   struck lanes. Each is a wall while it stands (World.add_barrier: collision, shots, sight; the flow field goes
##   round it through NavField.set_extra), so its Rock Rings break on them. Fair: a pillar never rises on or touching
##   a body, and keeps the hero's width plus PASS_SLACK_M from every wall and other pillar, so it is an island in the
##   free space: it never closes a way and never seals anyone in.
## - S2, the Warlord's recalled javelins: the shots of a `pattern` attack with recall_ticks stick where they stop (a
##   wall, or the end of their range; one that hits a body is spent), then all fly back at once along the lines they
##   came, toward the Warlord, recall_at ticks after the attack's active time began. A javelin whose way back would
##   start on the player crumbles (no shot spawns on top of you). Its shield facing is data (BossDefinition's front
##   arc with a 0 multiplier: Damage blocks the hit).
## - S3, the Brood Mother's eggs: a `marks` attack with egg_ticks lays an egg on each circle as it strikes: an actor
##   of the attack's enemy kind (a Hatchling) in the EGG state, still and with egg_hp, a target. Broken, it is gone
##   (a kill like any). Left egg_ticks, it hatches (its kind's HP, then its spawn-in); from the boss's phase
##   burst_phase on it bursts into the attack's pattern (the acid star) instead and is gone, no kill. An egg whose
##   boss is gone crumbles.
## Pure: no stream is drawn here; everything follows from the locked markers, the shots' own paths and the clock.
## v0.8.0 BS2 (rows S4-S6): the Hive Lens's Gaze (BossGaze), the Siege Engine's ricochet shells (BossRicochet), the
## Foundry's lava and meltdown (BossLava); this class ticks them and keeps the flow field round every piece.

## A pillar never rises touching a body: this much clear round every living body.
const BODY_MARGIN_M := 0.3
## A pillar keeps the hero's width plus this from every wall and other pillar.
const PASS_SLACK_M := 0.15
## Returning javelins and bursting eggs carry LATE_CAUSE plus their attack's index as their cause, so the recap
## names the attack's late part (its late_cause_key).
const LATE_CAUSE := 4096
## An egg's own states (EnemyAi.State and BossAi's STAGGERED and GATE come first): waiting, bursting, gone.
const EGG := 7
const EGG_BURST := 8
const EGG_GONE := 9

# --- S1: the Gatekeeper's pillars ---------------------------------------------------------------------------------


## Tick phase 6, the tick after marker k of boss i's `row_lanes` attack struck: pillars rise along its two lanes, every
## pillar_step_m out from the crossing each way (the crossing itself stays open), as far as the lane ran, each only
## where it fits (fits()). Returns how many rose.
static func raise_pillars(w: World, i: int, atk: BossAttackTable, k: int) -> int:
	if atk.pillar_ticks <= 0 or atk.pillar_m <= 0.0 or atk.pillar_step_m <= 0.0:
		return 0
	var c := BossDodge.mark_of(w, i, k)
	var h := atk.pillar_m * 0.5
	var n := 0
	for way in [0, 2048, 1024, 3072]:
		var run := EnemyAi.clear_run(w, c, way, atk.length_m * 0.5, atk.half_width_m)
		var step := 1
		while step * atk.pillar_step_m + h <= run:
			var p := c + Kin.dir(way) * (step * atk.pillar_step_m)
			step += 1
			if fits(w, p, h):
				_add_pillar(w, w.actors.ids[i], p, h, atk.pillar_ticks)
				n += 1
	if n > 0:
		set_nav_extra(w)
	return n


## True when a pillar of half side h at p touches no living body (with BODY_MARGIN_M) and keeps the hero's width plus
## PASS_SLACK_M from every wall (the static walls, the door, other pillars): the closest points of two convex boxes
## include a corner of one of them, so the corners of both are tested, and the inscribed circle for an overlap.
static func fits(w: World, p: Vector2, h: float) -> bool:
	var sq := Obb.make(p, Vector2(h, h), 0)
	var a := w.actors
	for j in a.size():
		if (
			a.dead[j] == 0
			and Collide.circle_vs_obb(a.pos(j), a.radius[j] + BODY_MARGIN_M, sq) != Vector2.ZERO
		):
			return false
	var gap := 2.0 * w.player.radius_m + PASS_SLACK_M
	var mine := corners(sq)
	for k in w.walls_near(sq.bounds().grow(gap + 0.01)):
		var wall: Obb = w.walls[k]
		if Collide.circle_vs_obb(p, h, wall) != Vector2.ZERO:
			return false
		for q: Vector2 in mine:
			if Collide.circle_vs_obb(q, gap, wall) != Vector2.ZERO:
				return false
		for q: Vector2 in corners(wall):
			if Collide.circle_vs_obb(q, gap, sq) != Vector2.ZERO:
				return false
	return true


## The four corners of a box.
static func corners(o: Obb) -> PackedVector2Array:
	var u := o.axis_u * o.half.x
	var v := o.axis_v * o.half.y
	return PackedVector2Array(
		[o.center + u + v, o.center + u - v, o.center - u - v, o.center - u + v]
	)


## Pillar k as the wall it is.
static func pillar_obb(bs: BossStore, k: int) -> Obb:
	var h := bs.pillar_h[k]
	return Obb.make(Vector2(bs.pillar_x[k], bs.pillar_y[k]), Vector2(h, h), 0)


## Every standing pillar as a wall.
static func pillar_obbs(w: World) -> Array[Obb]:
	var out: Array[Obb] = []
	for k in w.bosses.pillar_x.size():
		out.append(pillar_obb(w.bosses, k))
	return out


static func _add_pillar(w: World, boss_id: int, p: Vector2, h: float, ticks: int) -> void:
	var bs := w.bosses
	bs.pillar_x.append(p.x)
	bs.pillar_y.append(p.y)
	bs.pillar_h.append(h)
	bs.pillar_from.append(w.tick)
	bs.pillar_until.append(w.tick + ticks)
	bs.pillar_boss.append(boss_id)
	w.add_barrier(pillar_obb(bs, bs.pillar_x.size() - 1))


## Removes the pillars whose time is up (or every pillar of boss `boss_id`, or every one with -2), walls and all.
static func _drop_pillars(w: World, boss_id: int = -1) -> void:
	var bs := w.bosses
	var gone: Array[Obb] = []
	for k in range(bs.pillar_x.size() - 1, -1, -1):
		var due := bs.pillar_until[k] <= w.tick
		if boss_id == -2 or bs.pillar_boss[k] == boss_id or (boss_id == -1 and due):
			gone.append(pillar_obb(bs, k))
			bs.remove_pillar(k)
	if not gone.is_empty():
		w.remove_barriers(gone)
		set_nav_extra(w)


## The flow field goes round the standing pillars, the molten floor and the meltdowns (NavField.set_extra) from this
## tick (v0.8.0 BS2: the lava and melt too); `flood` false leaves the flood to the caller (a snapshot's restore).
static func set_nav_extra(w: World, flood: bool = true) -> void:
	var boxes := pillar_obbs(w)
	boxes.append_array(BossLava.lava_obbs(w))
	w.nav.set_extra(boxes, BossLava.melt_shapes(w))
	if flood and not w.enemy_tables.is_empty():
		w.flood_nav()  # v0.8.0 P1: the world's flood (bounded, stopped past the enemies)


## v0.8.0 BS2: true while any piece the flow field goes round is down (pillars, lava, a meltdown).
static func has_extra(w: World) -> bool:
	var bs := w.bosses
	return bs.pillar_x.size() + bs.lava_x.size() + bs.melt_boss.size() > 0


# --- S2: the Warlord's javelins -----------------------------------------------------------------------------------


## World._projectile_hits: projectile pi ended at `at` (a wall, its range, or a body when hit_body). A javelin of a
## recall attack (its cause, not a late one) that didn't hit a body sticks there, to fly back on its attack's recall
## tick: the tick its active time began plus recall_at, while the boss is still in it; recall_ticks from now if not.
static func on_shot_end(w: World, pi: int, at: Vector2, hit_body: bool) -> void:
	var p := w.projectiles
	var cause := p.cause_of(pi)
	if cause < 0 or cause >= LATE_CAUSE or hit_body or p.team[pi] != ActorStore.TEAM_ENEMY:
		return
	var bi := w.actors.index_of(p.owner[pi])
	if bi < 0 or not BossAi.is_boss_kind(w.actors.kinds[bi]):
		return
	var t := BossAi.table_of(w, bi)
	if cause >= t.attacks.size() or t.attacks[cause].recall_ticks <= 0:
		return
	var atk := t.attacks[cause]
	var back := w.tick + atk.recall_ticks
	var b := BossAi.entry_of(w, bi)
	if w.bosses.attack[b] == cause and w.actors.state[bi] == EnemyAi.State.ACTIVE:
		back = w.tick - w.actors.state_t[bi] + atk.recall_at
	var bs := w.bosses
	bs.jav_x.append(at.x)
	bs.jav_y.append(at.y)
	bs.jav_a.append(Kin.angle_of(Vector2(p.vel_x[pi], p.vel_y[pi])))
	bs.jav_boss.append(p.owner[pi])
	bs.jav_attack.append(cause)
	bs.jav_from.append(w.tick)
	bs.jav_back.append(maxi(back, w.tick + 1))


## Tick phase 6: the javelins whose recall tick has come fly back along their lines (from where they stuck, the way
## they came) as far as the boss's edge, as its attack's late part; their boss gone, they just go.
static func _recall(w: World) -> void:
	var bs := w.bosses
	for k in range(bs.jav_x.size() - 1, -1, -1):
		if bs.jav_back[k] > w.tick:
			continue
		var bi := w.actors.index_of(bs.jav_boss[k])
		if bi >= 0 and w.actors.dead[bi] == 0:
			_throw_back(w, bi, k)
		bs.remove_javelin(k)


static func _throw_back(w: World, bi: int, k: int) -> void:
	var bs := w.bosses
	var t := BossAi.table_of(w, bi)
	var cause := bs.jav_attack[k]
	if cause < 0 or cause >= t.attacks.size() or t.attacks[cause].pattern == null:
		return
	var atk := t.attacks[cause]
	var pat := atk.pattern
	var at := Vector2(bs.jav_x[k], bs.jav_y[k])
	var safe := pat.safe_radius_m + w.player.radius_m
	if Kin.length(at - w.player_pos()) < safe or w.player_dead():
		return  # it crumbles: no shot spawns on top of you
	var dir := Kin.dir(bs.jav_a[k] + 2048)
	var dist := Kin.length(w.actors.pos(bi) - at) - w.actors.radius[bi]
	var life := int(dist / maxf(pat.speed, 0.0001)) + 1
	if life <= 0:
		return
	w.queue_projectile(
		w.actors.ids[bi],
		ActorStore.TEAM_ENEMY,
		at,
		dir * pat.speed,
		BossAi.orb_damage(w, bi, atk),
		pat.radius_m,
		life,
		SimEvent.TAG_PROJECTILE
	)
	w.set_pending_look(pat.look)
	w.set_pending_cause(LATE_CAUSE + cause)


## The javelins boss i has in the floor now, for the views: [at, angle (1/4096 turns, the way it flew out), the tick
## it stuck, the tick it flies back] each.
static func javelins_of(w: World, i: int) -> Array:
	var out := []
	var bs := w.bosses
	var id := w.actors.ids[i]
	for k in bs.jav_x.size():
		if bs.jav_boss[k] == id:
			out.append(
				[Vector2(bs.jav_x[k], bs.jav_y[k]), bs.jav_a[k], bs.jav_from[k], bs.jav_back[k]]
			)
	return out


# --- S3: the Brood Mother's eggs ----------------------------------------------------------------------------------


## Tick phase 6: marker k of boss i's `marks` attack with eggs has just struck at c: an egg lands there (it arrives
## in phase 9), unless the attack's kind already has max_alive alive or coming (eggs count).
static func lay_egg(w: World, b: int, atk: BossAttackTable, c: Vector2) -> void:
	if atk.egg_ticks <= 0 or w.enemy_table(atk.enemy_kind) == null:
		return
	if BossAi.alive_of(w, atk.enemy_kind) >= atk.max_alive:
		return
	w.queue_egg(atk.enemy_kind, c, [atk.egg_ticks, atk.egg_hp, w.bosses.attack[b]])


## World._apply_spawns: actor i (just added and scaled as any arrival) becomes an egg: still and at once hittable,
## with egg_hp at the kind's base HP scaled as the hatchling's own HP was (EnemyAi fields: windup = its ticks, pick =
## the HP it hatches with, lock_a = the attack that laid it).
static func make_egg(w: World, i: int, egg: Array) -> void:
	var a := w.actors
	var base := maxi(1, w.enemy_table(a.kinds[i]).hp)
	var hatch := a.max_hp[i]
	var hp := maxi(1, (hatch * int(egg[1]) + base / 2) / base)
	a.hp[i] = hp
	a.max_hp[i] = hp
	a.pick[i] = hatch
	a.windup[i] = int(egg[0])
	a.lock_a[i] = int(egg[2])
	a.invuln[i] = 0
	EnemyAi.enter_state(a, i, EGG)


## True while actor i is an egg (waiting or bursting).
static func is_egg(w: World, i: int) -> bool:
	var s := w.actors.state[i]
	return EnemyAi.is_enemy_kind(w.actors.kinds[i]) and (s == EGG or s == EGG_BURST)


## Tick phase 3 (EnemyAi.think, after its clock): an egg's time. Its boss gone, it crumbles; its time up, it hatches
## (its kind's HP, then the spawn-in) or, from its boss's burst phase on, starts bursting; a burst over, it is gone.
static func egg_think(w: World, i: int) -> void:
	var a := w.actors
	var boss := w.actors.index_of(w.boss_id)
	if boss < 0 or a.dead[boss] == 1:
		_gone(w, i)
		return
	if a.state[i] == EGG_BURST:
		var pat := _egg_attack(w, i, boss).pattern
		if pat == null or a.state_t[i] >= pat.duration_ticks() - pat.lob_ticks:
			_gone(w, i)
		return
	if a.state_t[i] < a.windup[i]:
		return
	var atk := _egg_attack(w, i, boss)
	if (
		atk != null
		and atk.pattern != null
		and w.bosses.phase[BossAi.entry_of(w, boss)] >= atk.burst_phase
	):
		EnemyAi.enter_state(a, i, EGG_BURST)
		return
	a.hp[i] = maxi(1, a.pick[i])
	a.max_hp[i] = a.hp[i]
	a.pick[i] = 0
	a.windup[i] = 0
	a.lock_a[i] = 0
	EnemyAi.enter_state(a, i, EnemyAi.State.SPAWN)
	a.invuln[i] = w.tuning.spawn_in_ticks
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[i], a.ids[i], a.ids[i], a.pos(i))
	e.effect_id = &"egg_hatch"


## Tick phase 6 (EnemyAi.resolve): a bursting egg fires its pattern's waves from where it lies, aimed at the player
## (the pattern's aim offset puts the player in a gap), as its boss's attack's late part.
static func egg_burst(w: World, i: int) -> void:
	var boss := w.actors.index_of(w.boss_id)
	if boss < 0 or w.actors.dead[boss] == 1 or w.player_dead():
		return
	var atk := _egg_attack(w, i, boss)
	if atk == null or atk.pattern == null:
		return
	var pat := atk.pattern
	var kw := BulletPatterns.wave_at(pat, w.actors.state_t[i] + pat.lob_ticks)
	if kw < 0:
		return
	var c := w.actors.pos(i)
	BulletPatterns.fire(
		w,
		boss,
		pat,
		kw,
		c,
		Kin.angle_of(w.player_pos() - c),
		w.actors.radius[i] + pat.radius_m + BulletPatterns.MUZZLE_M,
		BossAi.orb_damage(w, boss, atk),
		LATE_CAUSE + w.actors.lock_a[i]
	)


static func _egg_attack(w: World, i: int, boss: int) -> BossAttackTable:
	var t := BossAi.table_of(w, boss)
	var k := w.actors.lock_a[i]
	return t.attacks[k] if k >= 0 and k < t.attacks.size() else null


## The egg leaves without a kill (World._remove_dead skips its kill count and rewards).
static func _gone(w: World, i: int) -> void:
	w.actors.dead[i] = 1
	w.actors.hp[i] = 0
	EnemyAi.enter_state(w.actors, i, EGG_GONE)


## Egg i's time, 0..1000 (a bursting egg: 1000), or -1 when actor i isn't an egg.
static func egg_permille(w: World, i: int) -> int:
	if not is_egg(w, i):
		return -1
	if w.actors.state[i] == EGG_BURST:
		return 1000
	return clampi(w.actors.state_t[i] * 1000 / maxi(1, w.actors.windup[i]), 0, 1000)


# --- the tick and the end of a fight ----------------------------------------------------------------------------


## Tick phase 6 (before the projectile sweep): pillars whose time is up sink, javelins whose recall has come fly;
## v0.8.0 BS2: molten floor cools, steps closer and burns (BossLava).
static func advance(w: World) -> void:
	var bs := w.bosses
	if not bs.pillar_x.is_empty():
		_drop_pillars(w)
	if not bs.jav_x.is_empty():
		_recall(w)
	BossLava.advance(w)
	BossShade.advance(w)  # v0.9.0 NB4: the Lantern Shade's dark and its lanterns
	BossStream.advance(w)  # v0.9.5 BH4: the Tidecaller's ring stream and crossing waves


## World._remove_dead: boss `boss_id` is gone: its pillars sink and its javelins go (its eggs crumble on their own).
static func on_boss_gone(w: World, boss_id: int) -> void:
	var bs := w.bosses
	if not bs.pillar_x.is_empty():
		_drop_pillars(w, boss_id)
	for k in range(bs.jav_x.size() - 1, -1, -1):
		if bs.jav_boss[k] == boss_id:
			bs.remove_javelin(k)
	if BossLava.on_boss_gone(w, boss_id):  # v0.8.0 BS2: its lava and melt cool at once
		set_nav_extra(w)
	BossTide.on_boss_gone(w, boss_id)  # v0.9.0 NB1: its Pull's cadence
	BossTwin.on_boss_gone(w, boss_id)  # v0.9.0 NB2: the Wardens' pair
	BossJudge.on_boss_gone(w, boss_id)  # v0.9.0 NB3: the Clockwork Judge's echo
	BossShade.on_boss_gone(w, boss_id)  # v0.9.0 NB4: the Lantern Shade's room relights
	BossStream.on_boss_gone(w, boss_id)  # v0.9.5 BH4: its streams and waves


## The recap's death line for a cause past LATE_CAUSE (a late part): its attack's late_cause_key (its own cause_key
## when it has none), or &"" for none.
static func late_cause_key(t: BossTable, cause: int) -> StringName:
	var k := cause - LATE_CAUSE
	if k < 0 or k >= t.attacks.size():
		return &""
	var atk := t.attacks[k]
	return atk.late_cause_key if atk.late_cause_key != &"" else atk.cause_key
