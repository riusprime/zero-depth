class_name BossShotFields
extends RefCounted
## Discs a boss lays that slow the hero's shots: BossStore.sf_* {id, boss, speed kept (per mille), laid, ends, centre,
## radius}, oldest first.
## - A hero's projectile whose centre is inside a disc when the projectile phase begins flies that tick at the disc's
##   share of its speed (the slowest of the discs it is in). Its velocity is cut only for the sweep (NativeShots:
##   slow before it, restore after the contacts), so the steering, a bounce and the next tick read its own speed.
## - SLOWS_LIFE: its life (its range left) runs at the same share while inside, so it crawls through and then flies
##   the rest of its range. The share is counted on the world clock (a tick spends life when tick x share crosses a
##   whole thousand), so no state is kept per shot; a crossing may spend one tick of life more or less than the exact
##   share.
## - Hostile shots are never slowed. A Mine disc holding in place is left alone. Attacks that are not projectiles (the
##   Laser's beam, the Lance's charge, the Blade's swing) do not meet the fields at all.
## - A field goes when its time is up, with its boss, with the hero's death and when the hero leaves the sealed arena
##   (BossSlow.fight_over). The cap (ShotFieldTable.max_count, a boss): one more removes that boss's oldest.
## Pure: no stream is drawn.

## True: a slowed shot's life runs at the field's share. False: its life keeps running, so a field also costs range.
const SLOWS_LIFE := true


## What `slow` changed for one sweep, for `restore`: the projectiles' indices, their own velocities, the cut ones, and
## the life each had when it was lent a tick (-1: none lent).
class Crawl:
	extends RefCounted
	var at := PackedInt32Array()
	var own_x := PackedFloat32Array()
	var own_y := PackedFloat32Array()
	var cut_x := PackedFloat32Array()
	var cut_y := PackedFloat32Array()
	var life := PackedInt32Array()


## How many fields boss `boss_id` has down.
static func count_of(w: World, boss_id: int) -> int:
	return w.bosses.sf_boss.count(boss_id)


## Boss `boss_id` lays one field of table t at c. Its id, or -1 without a table.
static func place(w: World, boss_id: int, t: ShotFieldTable, c: Vector2) -> int:
	if t == null:
		return -1
	var bs := w.bosses
	while count_of(w, boss_id) >= maxi(1, t.max_count):
		bs.remove_shot_field(bs.sf_boss.find(boss_id))
	var id := bs.sf_next
	bs.sf_next += 1
	bs.sf_id.append(id)
	bs.sf_boss.append(boss_id)
	bs.sf_speed.append(clampi(t.speed_permille, 1, 1000))
	bs.sf_from.append(w.tick)
	bs.sf_until.append(w.tick + t.life_ticks if t.life_ticks > 0 else 0)
	bs.sf_x.append(c.x)
	bs.sf_y.append(c.y)
	bs.sf_r.append(t.radius_m)
	return id


## Tick phase 6 (BossSignatures.advance, before the projectile sweep): the fight over, all go; else those past their
## time go.
static func advance(w: World) -> void:
	var bs := w.bosses
	if bs.sf_x.is_empty():
		return
	var over := BossSlow.fight_over(w)
	for k in range(bs.sf_x.size() - 1, -1, -1):
		if over or (bs.sf_until[k] > 0 and bs.sf_until[k] <= w.tick):
			bs.remove_shot_field(k)


## The share of its speed a hero's shot at p keeps, per mille: the slowest field it is inside (1000 = none).
static func speed_at(w: World, p: Vector2) -> int:
	var bs := w.bosses
	var keep := 1000
	for k in bs.sf_x.size():
		if bs.sf_speed[k] < keep and Kin.length(Vector2(bs.sf_x[k], bs.sf_y[k]) - p) <= bs.sf_r[k]:
			keep = bs.sf_speed[k]
	return keep


## True when a shot at share `keep` spends a tick of life on this tick (see the class comment).
static func spends_life(w: World, keep: int) -> bool:
	return not SLOWS_LIFE or w.tick * keep / 1000 != (w.tick - 1) * keep / 1000


## NativeShots.sweep, after the steering: every hero's projectile inside a field has its velocity cut for this sweep,
## and one more tick of life on a tick that spends none. `skip` marks the projectiles the sweep leaves alone (empty:
## none). Null when no field is down or no shot is inside one.
static func slow(w: World, skip: PackedByteArray) -> Crawl:
	if w.bosses.sf_x.is_empty():
		return null
	var p := w.projectiles
	var c: Crawl = null
	for i in p.size():
		if p.team[i] != ActorStore.TEAM_PLAYER or (not skip.is_empty() and skip[i] == 1):
			continue
		var keep := speed_at(w, Vector2(p.pos_x[i], p.pos_y[i]))
		if keep >= 1000:
			continue
		if c == null:
			c = Crawl.new()
		c.at.append(i)
		c.own_x.append(p.vel_x[i])
		c.own_y.append(p.vel_y[i])
		p.vel_x[i] = p.vel_x[i] * keep / 1000.0
		p.vel_y[i] = p.vel_y[i] * keep / 1000.0
		c.cut_x.append(p.vel_x[i])
		c.cut_y.append(p.vel_y[i])
		if spends_life(w, keep):
			c.life.append(-1)
		else:
			c.life.append(p.life[i])
			p.life[i] += 1
	return c


## NativeShots.sweep, after the contacts and before the dead projectiles leave (the indices are still the sweep's):
## each slowed shot gets its own velocity back. One a contact turned (a bounce reflects the cut velocity) keeps its
## new heading at its own speed; one a contact gave a new velocity of another size keeps that. A tick of life lent
## that nothing spent is taken back.
static func restore(w: World, c: Crawl) -> void:
	if c == null:
		return
	var p := w.projectiles
	for k in c.at.size():
		var i := c.at[k]
		if c.life[k] >= 0 and p.life[i] == c.life[k] + 1:
			p.life[i] = c.life[k]
		if p.vel_x[i] == c.cut_x[k] and p.vel_y[i] == c.cut_y[k]:
			p.vel_x[i] = c.own_x[k]
			p.vel_y[i] = c.own_y[k]
			continue
		var now := Kin.length(Vector2(p.vel_x[i], p.vel_y[i]))
		var cut := Kin.length(Vector2(c.cut_x[k], c.cut_y[k]))
		if now > 0.0 and absf(now - cut) <= cut * 0.01:
			var own := Kin.length(Vector2(c.own_x[k], c.own_y[k]))
			p.vel_x[i] = p.vel_x[i] * own / now
			p.vel_y[i] = p.vel_y[i] * own / now


## BossSignatures.on_boss_gone: its fields go at once.
static func on_boss_gone(w: World, boss_id: int) -> void:
	var bs := w.bosses
	for k in range(bs.sf_x.size() - 1, -1, -1):
		if bs.sf_boss[k] == boss_id:
			bs.remove_shot_field(k)


## The fields for the view: see WorldReader.boss_shot_fields.
static func rows(w: World) -> Array:
	var out := []
	var bs := w.bosses
	for k in bs.sf_x.size():
		(
			out
			. append(
				{
					"id": bs.sf_id[k],
					"centre": Vector2(bs.sf_x[k], bs.sf_y[k]),
					"radius": bs.sf_r[k],
					"speed": bs.sf_speed[k],
					"age": w.tick - bs.sf_from[k],
					"left": bs.sf_until[k] - w.tick if bs.sf_until[k] > 0 else -1,
				}
			)
		)
	return out
