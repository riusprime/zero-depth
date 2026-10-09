class_name AbilityMods
extends RefCounted
## The ability mods (v0.5.0 CP, owner F13: "more objects or upgrades and combos"): items that change an ability
## rather than a weapon, offered only while you own that ability (ItemTable.requires_ability). v0.6.0 MX2: each is a
## modifier card that takes one of the six slots (BuildSlots.is_slot_item). v0.6.0 MX4: all four are modifiers built
## from ops (data/modifiers/), so each carries the rest of the build:
## - Cluster Payload (Bomb Lobber): an ON_END hook on the bomb spec, three bomblets lobbed evenly round the blast at
##   its edge (Attacks._lob), each a share of the bomb's damage in a share of its radius; its hook never rides its
##   own bomblets (lineage), so bomblets never split again.
## - Overclocked Drone (Drone Buddy): the drone spec's heat_rate_permille: + per mille fire rate per heat point held.
## - Razor Orbit (Orbit Blades): a STATUS op on the orbit spec (bleed; the engine's numbers from the item).
## - Afterimage (Blink): an ON_LAUNCH hook on the blink spec that waits (its delay): the blink leaves an echo where it
##   started that bursts that much later (the hook's burst, the area stat applied), drawn as before (World.ab.echo_*).
##   A blink while an echo waits bursts that one first.

const EFFECT_CLUSTER := &"cluster_payload"
const EFFECT_AFTERIMAGE := &"afterimage"


## Overclocked Drone: a drone period of `ticks` under the heat held now (never under 1 tick): the drone spec's rate
## per heat point.
static func drone_period(w: World, ticks: int) -> int:
	var spec := Modifiers.ability(w, Abilities.owned_of_kind(w, AbilityTable.Kind.DRONE_BUDDY))
	var per := spec.heat_rate_permille if spec != null else 0
	var heat := Heat.points(w)
	if per <= 0 or heat <= 0:
		return ticks
	return maxi(1, (ticks * 1000 + (1000 + per * heat) / 2) / (1000 + per * heat))


## The blink spec's waiting hook (Afterimage's echo), or null.
static func echo_hook(w: World) -> AttackHook:
	var spec := Modifiers.blink(w)
	if spec == null:
		return null
	for k in spec.hooks_on(AttackSpec.Trigger.ON_LAUNCH):
		if k.delay_ticks > 0:
			return k
	return null


## Afterimage: a blink just left w.blink_from.
static func on_blink(w: World) -> void:
	var k := echo_hook(w)
	if k == null:
		return
	if w.ab.echo_at >= 0:
		_burst(w)
	w.ab.echo_pos = w.blink_from
	w.ab.echo_at = w.tick + k.delay_ticks


## Tick phase 6 (Abilities.advance): a waiting echo bursts on its tick.
static func advance(w: World) -> void:
	if w.ab.echo_at >= 0 and w.tick >= w.ab.echo_at:
		_burst(w)


static func _burst(w: World) -> void:
	var s := w.ab
	s.echo_at = -1
	var k := echo_hook(w)
	if k == null:
		return
	var r := Stats.area(w, k.child.radius_m)
	s.echo_tick = w.tick
	s.echo_burst_pos = s.echo_pos
	s.echo_r = r
	var tags := Attacks.lingering_tags(k.child)
	var c := AttackContext.make(
		s.echo_pos, 0, k.damage_for(0), w.take_root(), tags, k.child.effect_id
	)
	c.radius_m = r
	Attacks.launch(w, k.child, c)
