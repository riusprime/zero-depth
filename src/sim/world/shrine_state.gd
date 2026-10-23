class_name ShrineState
extends RefCounted
## v0.9.0 SH, HF (owner Q29b, W36; Shrines): the floor's Blood or Chaos shrine and its healing fountain in play
## (World.shrine; null on a floor with neither: a Fortune shrine alone is the gamble shrine's own state). Hashed
## whenever it exists.

## The numbers (content, kept by the snapshot as loadout).
var table: ShrineTable
## The floor's shrine kind (ShrineTable.Kind: FORTUNE when the shrine is the gamble shrine, or there is none), where
## it stands (the gamble shrine's site, World.gamble_pos) and its interactable entry (-1 = none).
var kind: int = ShrineTable.Kind.FORTUNE
var pos := Vector2.ZERO
var entry := -1
## The shrine's use: the tick it was used (-1 = not yet), the tick a press was refused (Blood: too weak), and the HP
## Blood took.
var used_tick := -1
var denied_tick := -1
var paid := 0
## Chaos: 0 not begun, 1 being fought, 2 cleared; its enemies (actor ids) and the tick it was cleared.
var chaos_phase := 0
var members := PackedInt32Array()
var clear_tick := -1
## The rewards it raised (free altars' ids).
var reward_ids := PackedInt32Array()
## The healing fountain: its interactable entry (-1 = none on this floor), where it stands, the tick it healed (-1 =
## not yet; then it is dry), how much, and the tick a press was refused (full HP).
var fountain_entry := -1
var fountain_pos := Vector2.ZERO
var fountain_tick := -1
var fountain_healed := 0
var fountain_denied_tick := -1


func has_shrine() -> bool:
	return entry >= 0


func has_fountain() -> bool:
	return fountain_entry >= 0


func hash_into(h: StateHasher) -> void:
	for v in [kind, entry, used_tick, denied_tick, paid, chaos_phase, clear_tick]:
		h.add_int(v)
	for v in [fountain_entry, fountain_tick, fountain_healed, fountain_denied_tick]:
		h.add_int(v)
	h.add_ints(members)
	h.add_ints(reward_ids)
	for q in [pos, fountain_pos]:
		h.add_f32(q.x)
		h.add_f32(q.y)
