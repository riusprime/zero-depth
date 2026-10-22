class_name Breakables
extends RefCounted
## v0.9.0 DX (owner W §4 C: "Certain walls, statues, or props contain subtle visual clues indicating that they can be
## destroyed. Breaking them reveals hidden spaces, resources, or collectibles"; §5: destructible containers "Small
## resource or reward chance", explosive objects "Environmental combat interactions"; Q23: "The Skill (Q / pad Y)",
## "hidden room should not appear or be visible until you open it", containers and explosive barrels as proposed): the
## floor's destructibles, in ticks (EI-03). World.breakables holds them (null on a floor with none).
## - The cracked wall (FloorLayout.crack_*, CrackedRooms.mark): a wall section across a dead end's doorway, a barrier
##   from the floor's first tick (World.add_barrier, as the timed door's slab). Only the build's Skill wears it down
##   (on_skill, from PlayerSkill when the Skill lands: Lunge Cleave's fan touching it, or a Scatter Blast pellet ending
##   on it), one hit a use, crack_hits (3) uses; nothing else does (no other attack reaches a wall). Broken, the barrier
##   is gone for good and the hidden room behind (an epic altar or a chest, Secrets.place_reward from
##   `loot:cracked_wall`; no enemy spawns) is open and seen. Nothing tells the player (Q23).
## - Containers (crates, urns, barrels): any of the hero's attacks breaks one in one hit (on_attack, from
##   Attacks.launch: an arc, a burst, a ray; and the hero's projectiles, swept each tick in advance). Each was rolled
##   at setup from the `loot:containers` sub-stream: a drop (container_drop_permille) of a few shards or a heal orb
##   (HealOrbs, Lifesprout's orb), or nothing.
## - Explosive barrels: any hit lights the fuse (fuse_ticks, 1.0 s); then the blast (radius_m, 2.0 m) hurts every enemy
##   and the hero in it (Damage.hit from no actor, effect EFFECT: the readable cause, CAUSE_KEY; a blast that kills the
##   hero sets World.killer_attack to KILL_CAUSE for the recap), breaks the containers in it and lights the barrels.
## - Placement (setup, after the timed door and the rune puzzle; the `map:containers` sub-stream): in each room but the
##   start hall, the boss room, the portal room, the shop's room, the curse room and the secret rooms, 0..containers_max
##   containers and, with barrel_room_permille, 1..barrels_max explosive barrels, on its spawn spots DOOR_GAP_M from its
##   doorways' approaches, AVOID_M from rewards, pedestals, the shrine, the shop and the puzzles' pieces and PROP_GAP_M
##   apart. Not solid: they never block a path.

enum Kind { CRATE, URN, BARREL, EXPLOSIVE }
enum Drop { NONE, SHARDS, HEAL }

const PROP_RADIUS_M := 0.4
const DOOR_GAP_M := 2.0
const AVOID_M := 2.5
const PROP_GAP_M := 1.5
const STREAM := "map:containers"
const DROP_STREAM := "loot:containers"
const REWARD_STREAM := "loot:cracked_wall"
const EFFECT := &"explosive_barrel"
## World.killer_attack when a barrel's blast killed the hero (far below the bosses' attack indices and their marks).
const KILL_CAUSE := -7001
const CAUSE_KEY := &"CAUSE_EXPLOSIVE_BARREL"

## The cracked wall: its hits left and total (0: none), 1 while it stands as a barrier, broken, its last hit and its
## break (-1 not yet), its hidden room's reward (its id, -1 none) and whether that is an epic altar.
var crack_hp := 0
var crack_max := 0
var crack_up := 0
var crack_broken := 0
var crack_hit_tick := -1
var crack_break_tick := -1
var crack_reward_id := -1
var crack_reward_epic := 0
## The props (containers and explosive barrels), one entry each: where, which (Kind), its room, broken, the tick it
## broke (or blew; -1), the tick its fuse was lit (-1), its drop (Drop) and the drop's shards.
var pos := PackedVector2Array()
var kind := PackedInt32Array()
var room := PackedInt32Array()
var broken := PackedByteArray()
var break_tick := PackedInt32Array()
var fuse_tick := PackedInt32Array()
var drop := PackedInt32Array()
var drop_amount := PackedInt32Array()
## The barrels' numbers (SecretRules', copied at setup).
var fuse_ticks := 60
var radius_m := 2.0
var damage := 40
var hero_damage := 15


## Sets up `w`'s destructibles (setup, after the rewards, events, shrine, shop, timed door and rune puzzle).
static func setup(w: World, rules: SecretRules) -> void:
	var f := w.floor_layout
	if f == null:
		return
	var b := Breakables.new()
	b.fuse_ticks = rules.barrel_fuse_ticks
	b.radius_m = rules.barrel_radius_m
	b.damage = rules.barrel_damage
	b.hero_damage = rules.barrel_hero_damage
	w.breakables = b
	if CrackedRooms.mark(f, rules.crack_permille, Secrets.taken_rooms(w)) >= 0:
		b.crack_max = rules.crack_hits
		b.crack_hp = rules.crack_hits
		Secrets.drop_spawns(w, f.crack_room)
		var got := Secrets.place_reward(w, f.crack_room, REWARD_STREAM)
		b.crack_reward_id = got.x
		b.crack_reward_epic = got.y
	_place_props(w, b, rules)
	if b.crack_max == 0 and b.pos.is_empty():
		w.breakables = null


static func _place_props(w: World, b: Breakables, rules: SecretRules) -> void:
	var f := w.floor_layout
	var rng := RngStream.derive(f.seed_value, STREAM)
	var loot := RngStream.derive(f.seed_value, DROP_STREAM)
	var avoid := Secrets.avoid_spots(w)
	avoid.append_array(f.timed_switches)
	avoid.append_array(f.rune_pillars)
	if f.shop_room >= 0:
		avoid.append(f.shop_pos)
	var never := [f.start_room, f.boss_room, f.portal_room, f.shop_room, f.curse_room]
	never.append_array([f.timed_room, f.rune_room, f.crack_room])
	for r in mini(f.room_count(), f.spawn_points.size()):
		if r in never:
			continue
		var n := rng.range_int(0, rules.containers_max)
		var barrels := 0
		if rules.barrels_max > 0 and rng.chance_permille(rules.barrel_room_permille):
			barrels = rng.range_int(1, rules.barrels_max)
		if n + barrels == 0:
			continue
		var spots := _spots(f, r, avoid, b.pos, rng)
		for k in mini(n + barrels, spots.size()):
			var kd := Kind.EXPLOSIVE if k < barrels else rng.range_int(Kind.CRATE, Kind.BARREL)
			var dr := Drop.NONE
			var amount := 0
			if kd != Kind.EXPLOSIVE and loot.chance_permille(rules.container_drop_permille):
				dr = (
					Drop.HEAL
					if loot.chance_permille(rules.container_heal_permille)
					else Drop.SHARDS
				)
				if dr == Drop.SHARDS:
					amount = loot.range_int(rules.container_shards_min, rules.container_shards_max)
			b.add(spots[k], kd, r, dr, amount)


## Room `r`'s free spots for props, drawn from rng (none closer than PROP_GAP_M to each other or to `taken`).
static func _spots(
	f: FloorLayout, r: int, avoid: PackedVector2Array, taken: PackedVector2Array, rng: RngStream
) -> PackedVector2Array:
	var ok := PackedVector2Array()
	var approaches := f.door_approaches(r, 1.0)
	for q in f.spawn_points[r]:
		if _far(q, approaches, DOOR_GAP_M) and _far(q, avoid, AVOID_M):
			if _far(q, f.item_spots, AVOID_M) and _far(q, taken, PROP_GAP_M):
				ok.append(q)
	for k in range(ok.size() - 1, 0, -1):
		var j := rng.range_int(0, k)
		var swap := ok[k]
		ok[k] = ok[j]
		ok[j] = swap
	var out := PackedVector2Array()
	for q in ok:
		if _far(q, out, PROP_GAP_M):
			out.append(q)
	return out


func add(at: Vector2, p_kind: int, p_room: int, p_drop: int, amount: int) -> void:
	pos.append(at)
	kind.append(p_kind)
	room.append(p_room)
	broken.append(0)
	break_tick.append(-1)
	fuse_tick.append(-1)
	drop.append(p_drop)
	drop_amount.append(amount)


func has_crack() -> bool:
	return crack_max > 0


## Attacks.launch (after the form ran): the hero's arc, burst or rays reaching a prop hit it.
static func on_attack(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	var b := w.breakables
	if b == null or b.pos.is_empty():
		return
	match spec.form:
		AttackSpec.Form.ARC:
			for i in b.pos.size():
				if (
					b.live(i)
					and Attacks.arc_touches(w, spec, ctx.origin, ctx.angle, b.pos[i], PROP_RADIUS_M)
				):
					hit(w, i)
		AttackSpec.Form.BURST:
			if spec.line_m > 0.0:
				return
			var r := ctx.radius_m if ctx.radius_m > 0.0 else spec.radius_m
			for i in b.pos.size():
				if b.live(i) and AttackShapes.disc_touches(ctx.origin, r, b.pos[i], PROP_RADIUS_M):
					hit(w, i)
		AttackSpec.Form.BEAM:
			if not spec.seek:
				_rays(w, b, spec, ctx)


static func _rays(w: World, b: Breakables, spec: AttackSpec, ctx: AttackContext) -> void:
	for ang in AttackShapes.pellet_angles(ctx.angle, spec.spread / 2, spec.count):
		var dir := Kin.dir(ang)
		var from := ctx.origin + dir * w.player.radius_m
		var to := from + dir * spec.reach_m
		var best := 2.0
		for k in w.walls_along(from, to, spec.radius_m):
			var s := Collide.sweep_vs_obb(from, to, spec.radius_m, w.walls[k])
			if s >= 0.0 and s < best:
				best = s
		for i in b.pos.size():
			if not b.live(i):
				continue
			var s := Collide.sweep_vs_circle(from, to, spec.radius_m, b.pos[i], PROP_RADIUS_M)
			if s >= 0.0 and s < best:
				hit(w, i)


## Prop i can still be hit (whole; an explosive barrel whose fuse is not lit yet).
func live(i: int) -> bool:
	return broken[i] == 0 and (kind[i] != Kind.EXPLOSIVE or fuse_tick[i] < 0)


## A hit on prop i: a container breaks (its drop falls), an explosive barrel's fuse is lit.
static func hit(w: World, i: int) -> void:
	var b := w.breakables
	if not b.live(i):
		return
	if b.kind[i] == Kind.EXPLOSIVE:
		b.fuse_tick[i] = w.tick
		return
	b.broken[i] = 1
	b.break_tick[i] = w.tick
	var me := w.actors.ids[0]
	match b.drop[i]:
		Drop.SHARDS:
			w.shards += b.drop_amount[i]
			var e := w.emit_event(SimEvent.Kind.SHARDS, 0, me, me, b.pos[i])
			e.amount = b.drop_amount[i]
		Drop.HEAL:
			if w.orbs.size() >= w.tuning.heal_orbs_max:
				w.orbs.remove_at(0)
			var id := w.take_id()
			w.orbs.add(id, b.pos[i])
			w.emit_event(SimEvent.Kind.SPAWN, id, id, id, b.pos[i])


## PlayerSkill, when a Skill use lands (`cleave`: Lunge Cleave's fan from `center` facing `angle`; else Scatter
## Blast, its pellets' ends in KitState.pellet_ends): one hit on the cracked wall if the use reached it.
static func on_skill(w: World, center: Vector2, angle: int, cleave: bool) -> void:
	var b := w.breakables
	if b == null or not b.has_crack() or b.crack_broken == 1:
		return
	var wall := w.floor_layout.crack_wall
	var spec := Modifiers.skill(w)
	var touched := false
	if cleave:
		touched = Attacks.arc_touches(w, spec, center, angle, closest(wall, center), 0.05)
	else:
		for e in w.kit.pellet_ends:
			if Collide.circle_vs_obb(e, spec.radius_m + 0.1, wall) != Vector2.ZERO:
				touched = true
				break
	if not touched:
		return
	b.crack_hp -= 1
	b.crack_hit_tick = w.tick
	if b.crack_hp > 0:
		return
	b.crack_broken = 1
	b.crack_break_tick = w.tick
	if b.crack_up == 1:
		var slab: Array[Obb] = [wall]
		w.remove_barriers(slab)
		b.crack_up = 0


## The point of box `o` nearest `p`.
static func closest(o: Obb, p: Vector2) -> Vector2:
	var d := p - o.center
	var u := clampf(d.dot(o.axis_u), -o.half.x, o.half.x)
	var v := clampf(d.dot(o.axis_v), -o.half.y, o.half.y)
	return o.center + o.axis_u * u + o.axis_v * v


## Tick phase 9 (before the dead leave): the cracked wall stands until broken; the hero's projectiles break what they
## pass; a lit fuse that has burnt down blows its barrel.
static func advance(w: World) -> void:
	var b := w.breakables
	if b == null:
		return
	if b.has_crack() and b.crack_broken == 0 and b.crack_up == 0:
		w.add_barrier(w.floor_layout.crack_wall)
		b.crack_up = 1
	if b.pos.is_empty():
		return
	var p := w.projectiles
	for k in p.size():
		if p.team[k] != ActorStore.TEAM_PLAYER:
			continue
		var at := Vector2(p.pos_x[k], p.pos_y[k])
		var from := at - Vector2(p.vel_x[k], p.vel_y[k])
		for i in b.pos.size():
			if b.live(i) and (b.pos[i] - at).length_squared() < 4.0:
				if Collide.sweep_vs_circle(from, at, p.radius[k], b.pos[i], PROP_RADIUS_M) >= 0.0:
					hit(w, i)
	for i in b.pos.size():
		if b.kind[i] == Kind.EXPLOSIVE and b.broken[i] == 0 and b.fuse_tick[i] >= 0:
			if w.tick - b.fuse_tick[i] >= b.fuse_ticks:
				_blast(w, b, i)


static func _blast(w: World, b: Breakables, i: int) -> void:
	b.broken[i] = 1
	b.break_tick[i] = w.tick
	var at := b.pos[i]
	var a := w.actors
	var root := w.take_root()
	for j in a.size():
		if a.dead[j] == 1 or (j > 0 and a.teams[j] == ActorStore.TEAM_PLAYER):
			continue
		if not AttackShapes.disc_touches(at, b.radius_m, a.pos(j), a.radius[j]):
			continue
		Damage.hit(w, j, b.hero_damage if j == 0 else b.damage, 0, 0, root, 0, at, a.pos(j), EFFECT)
		if j == 0 and a.dead[0] == 1:
			w.killer_attack = KILL_CAUSE  # the recap names the barrel (BossCauses.key)
	for k in b.pos.size():
		if (
			k != i
			and b.live(k)
			and AttackShapes.disc_touches(at, b.radius_m, b.pos[k], PROP_RADIUS_M)
		):
			hit(w, k)


static func _far(q: Vector2, points: PackedVector2Array, gap: float) -> bool:
	for p in points:
		if Kin.length(p - q) < gap:
			return false
	return true


## The fuse of barrel i is burning (lit, not blown yet).
func fusing(i: int) -> bool:
	return kind[i] == Kind.EXPLOSIVE and broken[i] == 0 and fuse_tick[i] >= 0


func hash_into(h: StateHasher) -> void:
	for v in [
		crack_hp,
		crack_max,
		crack_up,
		crack_broken,
		crack_hit_tick,
		crack_break_tick,
		crack_reward_id,
		crack_reward_epic,
		fuse_ticks,
		damage,
		hero_damage
	]:
		h.add_int(v)
	h.add_f32(radius_m)
	for k in pos.size():
		h.add_f32(pos[k].x)
		h.add_f32(pos[k].y)
		h.add_int(broken[k])
	h.add_ints(kind)
	h.add_ints(room)
	h.add_ints(break_tick)
	h.add_ints(fuse_tick)
	h.add_ints(drop)
	h.add_ints(drop_amount)
