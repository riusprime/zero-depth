class_name AbilityMods
extends RefCounted
## The ability mods (v0.5.0 CP, owner F13: "more objects or upgrades and combos"): items that change an ability
## rather than a weapon, offered only while you own that ability (ItemTable.requires_ability). Their numbers live in
## ItemMods (built from the owned items); every hook is a no-op without the item.
## - Cluster Payload (Bomb Lobber): a thrown bomb splits on landing into `bomblets` bomblets, evenly around the
##   blast at its edge, each landing bomblet_delay ticks later for a share of the bomb's damage in a share of its
##   radius. Bomblets never split again. No randomness.
## - Overclocked Drone (Drone Buddy): the drones fire faster with heat: + per mille per heat point held.
## - Razor Orbit (Orbit Blades): a blade's touch adds bleed stacks (Engines.on_hit, the bleed engine's numbers).
## - Afterimage (Blink): a blink leaves an echo where it started that bursts afterimage_delay ticks later for
##   afterimage_damage in afterimage_radius_m (area applies). A blink while an echo waits bursts that one first.

const EFFECT_CLUSTER := &"cluster_payload"
const EFFECT_AFTERIMAGE := &"afterimage"


## Cluster Payload: a bomb of radius `r` and damage `dmg` landed at `at`; queue its bomblets.
static func split(w: World, at: Vector2, r: float, dmg: int, root: int) -> void:
	var m := w.item_mods
	var n := m.bomblets
	if n <= 0:
		return
	var s := w.ab
	var br := r * m.bomblet_radius_permille / 1000.0
	var bd := maxi(1, (dmg * m.bomblet_damage_permille + 500) / 1000)
	for k in n:
		var p := at + Kin.dir((k * SimTick.ANGLE_UNITS / n) & 4095) * r
		s.bomb_pos.append(p)
		s.bomb_from.append(at)
		s.bomb_throw.append(w.tick)
		s.bomb_land.append(w.tick + m.bomblet_delay_ticks)
		s.bomb_root.append(root)
		s.bomb_r.append(br)
		s.bomb_dmg.append(bd)
		s.bomb_split.append(0)


## Overclocked Drone: a drone period of `ticks` under the heat held now (never under 1 tick).
static func drone_period(w: World, ticks: int) -> int:
	var per := w.item_mods.drone_rate_per_heat_permille
	var heat := Heat.points(w)
	if per <= 0 or heat <= 0:
		return ticks
	return maxi(1, (ticks * 1000 + (1000 + per * heat) / 2) / (1000 + per * heat))


## Afterimage: a blink just left w.blink_from.
static func on_blink(w: World) -> void:
	if w.item_mods.afterimage_damage <= 0:
		return
	if w.ab.echo_at >= 0:
		_burst(w)
	w.ab.echo_pos = w.blink_from
	w.ab.echo_at = w.tick + w.item_mods.afterimage_delay_ticks


## Tick phase 6 (Abilities.advance): a waiting echo bursts on its tick.
static func advance(w: World) -> void:
	if w.ab.echo_at >= 0 and w.tick >= w.ab.echo_at:
		_burst(w)


static func _burst(w: World) -> void:
	var s := w.ab
	var r := Stats.area(w, w.item_mods.afterimage_radius_m)
	s.echo_at = -1
	s.echo_tick = w.tick
	s.echo_burst_pos = s.echo_pos
	s.echo_r = r
	Abilities.hit_disc(
		w, s.echo_pos, r, w.item_mods.afterimage_damage, w.take_root(), EFFECT_AFTERIMAGE
	)
