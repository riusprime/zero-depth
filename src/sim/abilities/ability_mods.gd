class_name AbilityMods
extends RefCounted
## The ability mods (v0.5.0 CP, owner F13: "more objects or upgrades and combos"): items that change an ability
## rather than a weapon, offered only while you own that ability (ItemTable.requires_ability). each is a
## modifier card that takes one of the six slots (BuildSlots.is_slot_item). all four are modifiers built
## from ops (data/modifiers/), so each carries the rest of the build:
## - A blink spec's waiting ON_LAUNCH hook (its delay; Afterimage's, v0.5.0 CP): the blink leaves an echo where it
##   started that bursts that much later (the hook's burst, the area stat applied), drawn as before (World.ab.echo_*).
##   A blink while an echo waits bursts that one first.
## - A bomb's ON_END bomblets carry EFFECT_CLUSTER (Abilities._land_bombs).
## The four ability mods' cards (Cluster Payload, Overclocked Drone, Razor Orbit,
## Afterimage) are gone with the abilities they changed; the hooks above are the generic ones that stay.

const EFFECT_CLUSTER := &"cluster_payload"
const EFFECT_AFTERIMAGE := &"afterimage"


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
