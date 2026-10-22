class_name Secrets
extends RefCounted
## v0.9.0 RA (owner Q23: "hidden room should not appear or be visible until you open it"; W75 "Secret and Collectible
## Manager"): what the floor's secrets share, so each puzzle stays its own file:
## - the secret rooms not seen yet (hidden_rooms): the timed door's until it first opens (TD), the rune puzzle's until
##   it is solved (RA), the cracked wall's until it breaks (DX);
## - a secret room's reward (place_reward): an epic altar or a chest (priced as the floor's next chest), drawn from the
##   puzzle's own loot sub-stream, on the room's first item spot (else its spawn spot nearest its centre, else its
##   centre), as TD's; is_epic says which rewards are the secrets' epic altars (Offers.roll: epic stat cards);
## - the slabs (barriers added in play) that seal a secret room while it is shut, for the save's wall check (slabs,
##   slabs_up); v0.9.0 DP: with them, the Deep gate's footprint the purple runes add (PurpleRunes.earn).
## Pure.

## The share of the secret rooms' rewards that are epic altars (per mille; the rest chests), as TD's.
const EPIC_PERMILLE := 500


## The setup's spots to keep clear of (rewards, pedestals, the shrine) and the rooms already holding one.
static func taken_rooms(w: World) -> PackedInt32Array:
	var f := w.floor_layout
	var out := PackedInt32Array()
	for i in w.rewards.size():
		out.append(f.room_of(w.rewards.pos(i)))
	for k in w.ev.ids.size():
		out.append(w.ev.room[k])
	if w.gamble_id >= 0:
		out.append(f.room_of(w.gamble_pos))
	return out


static func avoid_spots(w: World) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in w.rewards.size():
		out.append(w.rewards.pos(i))
	for k in w.ev.ids.size():
		out.append(Vector2(w.ev.pos_x[k], w.ev.pos_y[k]))
	if w.gamble_id >= 0:
		out.append(w.gamble_pos)
	return out


## Drops `room`'s enemy spawn spots (a secret room holds none).
static func drop_spawns(w: World, room: int) -> void:
	var spawns := PackedVector2Array()
	for q in w.spawn_points:
		if w.floor_layout.room_of(q) != room:
			spawns.append(q)
	w.spawn_points = spawns


## Places `room`'s reward from sub-stream `stream`. Returns Vector2i(the reward's id, 1 if an epic altar).
static func place_reward(w: World, room: int, stream: String) -> Vector2i:
	var f := w.floor_layout
	var at := f.rooms[room].get_center()
	var found := false
	for k in f.item_spots.size():
		if f.item_rooms[k] == room:
			at = f.item_spots[k]
			found = true
			break
	if not found:
		var best := -1.0
		for q in f.spawn_points[room]:
			var d := Kin.length(q - f.rooms[room].get_center())
			if best < 0.0 or d < best:
				best = d
				at = q
	var rng := RngStream.derive(f.seed_value, stream)
	if rng.chance_permille(EPIC_PERMILLE):
		return Vector2i(w.add_reward(RewardStore.Kind.ALTAR, at, 0), 1)
	var chests := 0
	for i in w.rewards.size():
		if w.rewards.kind[i] == RewardStore.Kind.CHEST:
			chests += 1
	var price := w.reward_table.chest_price(chests, w.floor_index)
	return Vector2i(w.add_reward(RewardStore.Kind.CHEST, at, price), 0)


## Whether reward i is a secret room's epic altar (the timed door's, the rune puzzle's).
static func is_epic(w: World, i: int) -> bool:
	var id := w.rewards.ids[i]
	if w.timed != null and w.timed.reward_epic == 1 and w.timed.reward_id == id:
		return true
	if w.runes != null and w.runes.reward_epic == 1 and w.runes.reward_id == id:
		return true
	var b := w.breakables  # v0.9.0 DX: the cracked wall's room
	return b != null and b.has_crack() and b.crack_reward_epic == 1 and b.crack_reward_id == id


## The secret rooms not seen yet, ascending by kind (the timed door's, the rune puzzle's).
static func hidden_rooms(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	if w.timed != null and w.timed.opened == 0:
		out.append(w.floor_layout.timed_room)
	if w.runes != null and w.runes.solved == 0:
		out.append(w.floor_layout.rune_room)
	if w.breakables != null and w.breakables.has_crack() and w.breakables.crack_broken == 0:
		out.append(w.floor_layout.crack_room)  # v0.9.0 DX
	return out


## Every slab that may stand as a barrier in play (the base world's floor layout), for WorldSnapshot.
static func slabs(w: World) -> Array[Obb]:
	var out: Array[Obb] = []
	var f := w.floor_layout
	if f == null:
		return out
	if f.timed_door_wall != null:
		out.append(f.timed_door_wall)
	if f.rune_door_wall != null:
		out.append(f.rune_door_wall)
	if f.crack_wall != null:  # v0.9.0 DX
		out.append(f.crack_wall)
	if w.purple != null:  # v0.9.0 DP: the Deep gate's footprint, a barrier once the runes are awakened
		out.append(Routes.deep_gate_collider(f))
	return out


## How many slabs stand in `w.walls` now.
static func slabs_up(w: World) -> int:
	var n := 0
	if w.timed != null:
		n += w.timed.wall_up
	if w.runes != null:
		n += w.runes.wall_up
	if w.breakables != null:  # v0.9.0 DX
		n += w.breakables.crack_up
	if w.purple != null:  # v0.9.0 DP
		n += w.purple.wall_up
	return n
