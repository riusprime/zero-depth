class_name WandCasts
extends RefCounted
## v0.6.5 WN5a (docs/design/WAND.md rule 3 and the shared pool; SIM_CONTRACTS §8h): where the wand's small spells were
## cast, for the views. A trigger card's child spell (tagged `cast`, WandCompile) and the shared cards' blasts (a
## hook's BURST: Fire's kill burst, Void's pull, Explosive's blast) and slashes leave a mark here when Attacks.run_hook
## launches them: the tick, the child spec's book key, where from and which way, and whether it is a trigger's cast.
## AttackFormView draws each one once (the trigger's sigil and the small spell). View data only: no outcome ever reads
## it, so it is not hashed (ModifierState.hash_into leaves it out); the snapshot copies it like every state field.
## Deterministic; no randomness.

## At most this many marks; older than KEEP_TICKS go at the next mark.
const MAX := 32
const KEEP_TICKS := 60
## The spec tag WandCompile puts on a trigger's child spell (and so on everything built from it).
const TAG_CAST := "cast"


## Hook `k` launches its child from `at` facing `angle` (1/4096 turns): a mark if the views draw it (a trigger's cast
## of any form; a burst or a slash that no other view draws: not Overcharge's ON_NTH wave, Fissure's line or
## Finisher+'s carried shockwave, which have their own).
static func note(w: World, k: AttackHook, at: Vector2, angle: int) -> void:
	var c := k.child
	var cast := c.has_tag(TAG_CAST) and c.depth > 0
	if not cast:
		if c.form != AttackSpec.Form.BURST and c.form != AttackSpec.Form.ARC:
			return
		if k.trigger == AttackSpec.Trigger.ON_NTH or c.line_m > 0.0 or c.carry > 0:
			return
	var s := w.mx
	while (
		not s.cast_tick.is_empty()
		and (s.cast_tick.size() >= MAX or w.tick - s.cast_tick[0] > KEEP_TICKS)
	):
		_drop_oldest(s)
	s.cast_tick.append(w.tick)
	s.cast_key.append(c.key)
	s.cast_pos.append(at)
	s.cast_angle.append(angle)
	s.cast_flag.append(1 if cast else 0)


static func _drop_oldest(s: ModifierState) -> void:
	s.cast_tick.remove_at(0)
	s.cast_key.remove_at(0)
	s.cast_pos.remove_at(0)
	s.cast_angle.remove_at(0)
	s.cast_flag.remove_at(0)


## The marks, oldest first (WorldReader.wand_casts): tick, key (the child spec's AttackBook key), pos, angle (1/4096
## turns), cast (a trigger's child spell).
static func read(w: World) -> Array[Dictionary]:
	var s := w.mx
	var out: Array[Dictionary] = []
	for j in s.cast_tick.size():
		(
			out
			. append(
				{
					"tick": s.cast_tick[j],
					"key": s.cast_key[j],
					"pos": s.cast_pos[j],
					"angle": s.cast_angle[j],
					"cast": s.cast_flag[j] == 1,
				}
			)
		)
	return out
