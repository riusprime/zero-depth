class_name ShopState
extends RefCounted
## The floor's shop (v0.5.0 SH; World.shop): where the terminal stands, whether its panel is open (the world waits
## while it is), the stock (card codes, Offers; SOLD for a bought slot), the heal and reroll counters, and the last
## action and refusal for the views. A new floor starts it fresh. Hashed once the floor has a shop.

enum Action { NONE, BUY, HEAL, REROLL, SELL, SALVAGE_ABILITY, OPEN, CLOSE, CLEANSE }
## v0.5.5 EC: why the last refusal happened (the view's message): anything else, or the floor's buy limit.
enum Deny { OTHER, LIMIT }

const SOLD := -1

## The terminal's id (-1 = no shop on this floor), position and room.
var id := -1
var pos := Vector2.ZERO
var room := -1
var open := false
## True once the stock was drawn (on the first open, from the loot stream).
var rolled := false
var offer := PackedInt32Array()
var heal_used := false
var rerolls := 0
## v0.5.5 EC (owner S3): cards bought at this floor's shop (ShopTable.max_buys caps it).
var bought := 0
## The last action (Action), its tick and its subject (a card code, the HP healed, the refund).
var last_action := 0
var last_tick := -1
var last_value := 0
## The last refused action (unaffordable, or nothing to do): its tick and why (Deny).
var denied_tick := -1
var denied_reason := 0


func present() -> bool:
	return id >= 0


func hash_into(h: StateHasher) -> void:
	for v in [id, room, 1 if open else 0, 1 if rolled else 0, 1 if heal_used else 0, rerolls]:
		h.add_int(v)
	for v in [last_action, last_tick, last_value, denied_tick, bought, denied_reason]:
		h.add_int(v)
	h.add_ints(offer)
	h.add_f32(pos.x)
	h.add_f32(pos.y)
