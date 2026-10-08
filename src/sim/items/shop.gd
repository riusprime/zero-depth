# gdlint: disable=max-public-methods
class_name Shop
extends RefCounted
## The shop and salvage (v0.5.0 PLAN R1, R2; ROADMAP "Shops", "salvage"). One terminal per floor in a side room
## (ShopPlacement). The interact button within reach opens it; while it is open the world waits (like an altar's
## pick: only the shop's actions run, the tick still counts), and every action is an InputFrame.pick value.
## - Stock: ShopTable.offer_size cards drawn on the first open from the loot stream by a chest's rules
##   (Offers.draw: the same pools, ability cards only while they can apply, mods only with their ability). A card
##   costs its rarity's price x the floor step (30 / 55 / 90 x 1, 1.5, 2) and applies exactly as a picked card does
##   (Offers.apply); its slot is then sold out. A card that can no longer apply (a slot filled since, a stat at its
##   cap) can't be bought.
## - Heal: heal_permille of max HP, once per shop, for heal_price x the floor step; refused at full HP.
## - Reroll: a new stock (every slot) for reroll_price, x (1 + step) per use at this shop.
## - Salvage (sell_list): an owned mod or stat card sells for sell_permille of its shop price (a stat card: one
##   stack, the stat values rebuilt from the cards left, so the caps hold); an ability that is not the build's
##   weapon frees its slot for ability_refund_per_level x its level (a later ability card can take the slot). Mods
##   of a salvaged ability stay owned (inert until you own it again) and can be sold.
## - Refusals (unaffordable, nothing to do) change nothing but ShopState.denied_tick, for the view.
## Every purchase emits SHOP_BUY, every sale SHOP_SALVAGE; a bought card also emits PICKUP, the heal HEAL.

## A sell_list entry: [kind, ref, card code, refund]. MOD: ref = the item index; STAT: ref = how many of that card
## are held; ABILITY: ref = the slot.
const SELL_MOD := 0
const SELL_STAT := 1
const SELL_ABILITY := 2
## Spawn points this close to the terminal are dropped, so no enemy appears inside it.
const SPAWN_CLEAR_M := 1.6
const EFFECT_HEAL := &"shop_heal"
const EFFECT_REROLL := &"shop_reroll"
const EFFECT_CLEANSE := &"shop_cleanse"  # v0.5.0 EV


static func present(w: World) -> bool:
	return w.shop.present()


## Places the floor's terminal at the layout's shop spot (setup, after ShopPlacement.pick). Returns its id.
static func place(w: World, layout: FloorLayout) -> int:
	w.shop = ShopState.new()
	if layout.shop_room < 0:
		return -1
	w.shop.pos = layout.shop_pos
	w.shop.room = layout.shop_room
	w.shop.id = w.take_root()
	w.emit_event(SimEvent.Kind.SPAWN, w.shop.id, w.shop.id, w.shop.id, w.shop.pos)
	var kept := PackedVector2Array()
	for q in w.spawn_points:
		if Kin.length(q - w.shop.pos) >= SPAWN_CLEAR_M:
			kept.append(q)
	w.spawn_points = kept
	return w.shop.id


static func in_reach(w: World) -> bool:
	if not present(w) or w.shop_table == null:
		return false
	var reach := Stats.reach(w, w.shop_table.interact_radius_m)
	return Kin.length(w.shop.pos - w.player_pos()) <= reach


## Tick phase 2b, after Rewards.interact and before the gamble shrine: a buffered interact press by the terminal
## opens the shop (drawing the stock on the first open). True if it opened.
static func interact(w: World) -> bool:
	if w.player_dead() or w.buffered(InputFrame.INTERACT) == 0 or not in_reach(w):
		return false
	w.consume_buffered(InputFrame.INTERACT)
	if not w.shop.rolled:
		restock(w)
	w.shop.open = true
	_note(w, ShopState.Action.OPEN, 0)
	return true


static func restock(w: World) -> void:
	w.shop.offer = PackedInt32Array()  # out of the pool while drawing
	w.shop.offer = Offers.draw(w, true, w.shop_table.offer_size)
	w.shop.rolled = true


## While open: one action per pick value (InputFrame.PICK_*); anything else waits.
static func choose(w: World, frame: InputFrame) -> void:
	var v := frame.pick
	if v == InputFrame.PICK_NONE:
		return
	if v == InputFrame.PICK_CANCEL:
		close(w)
	elif v >= 1 and v <= w.shop.offer.size():
		buy(w, v - 1)
	elif v == InputFrame.PICK_SHOP_HEAL:
		heal(w)
	elif v == InputFrame.PICK_SHOP_REROLL:
		reroll(w)
	elif v == InputFrame.PICK_SHOP_CLEANSE:
		cleanse(w)
	elif v >= InputFrame.PICK_SHOP_SELL:
		sell(w, v - InputFrame.PICK_SHOP_SELL)
	else:
		_deny(w)


## Back to play: nothing pressed while the shop was open fires afterwards.
static func close(w: World) -> void:
	w.shop.open = false
	for s in w.input_buffer.size():
		w.input_buffer[s] = 0
	_note(w, ShopState.Action.CLOSE, 0)


# --- Prices ------------------------------------------------------------------------------------------------------
## The rarity a card is priced by (0 common, 1 rare, 2 epic; Offers.info).
static func rarity(w: World, code: int) -> int:
	return int(Offers.info(w, code)["rarity"])


## v0.5.0 EV: every shop price goes through the prices curse (Curses.price); salvage refunds don't.
static func price(w: World, code: int) -> int:
	return Curses.price(w, w.shop_table.card_price(rarity(w, code), w.floor_index))


static func heal_price(w: World) -> int:
	return Curses.price(w, w.shop_table.heal_cost(w.floor_index))


static func reroll_price(w: World) -> int:
	return Curses.price(w, w.shop_table.reroll_cost(w.shop.rerolls))


## v0.5.0 EV: lifting the latest curse costs the rules' cleanse price x the floor (under the prices curse too).
static func cleanse_price(w: World) -> int:
	return Curses.price(w, w.ev.rules.cleanse_price * maxi(1, w.floor_index))


## HP the heal would restore now.
static func heal_amount(w: World) -> int:
	var a := w.actors
	var add := (a.max_hp[0] * w.shop_table.heal_permille + 500) / 1000
	return maxi(0, mini(add, a.max_hp[0] - a.hp[0]))


## Card `code` would do something if bought now.
static func can_apply(w: World, code: int) -> bool:
	if code < 0:
		return false
	match Offers.type_of(code):
		Offers.ABILITY:
			return Abilities.can_take(w, Offers.ability_of(code))
		Offers.STAT:
			return not Stats.at_cap(w, Offers.stat_of(code))
	return not w.items_owned.has(code) and ItemPool.usable(w, code)


# --- Actions -----------------------------------------------------------------------------------------------------
## Buys stock slot k. True if bought.
static func buy(w: World, k: int) -> bool:
	if k < 0 or k >= w.shop.offer.size():
		return _deny(w)
	var code := w.shop.offer[k]
	if not can_apply(w, code) or w.shards < price(w, code):
		return _deny(w)
	var cost := price(w, code)
	w.shards -= cost
	w.shop.offer[k] = ShopState.SOLD
	_spend(w, cost, Offers.info(w, code)["id"])
	var pid := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.PICKUP, w.shop.id, pid, pid, w.shop.pos)
	e.amount = code
	Offers.apply(w, code)
	_note(w, ShopState.Action.BUY, code)
	return true


static func heal(w: World) -> bool:
	var add := heal_amount(w)
	var cost := heal_price(w)
	if w.shop.heal_used or add <= 0 or w.shards < cost or w.player_dead():
		return _deny(w)
	w.shards -= cost
	w.shop.heal_used = true
	_spend(w, cost, EFFECT_HEAL)
	var a := w.actors
	a.hp[0] += add
	var e := w.emit_event(SimEvent.Kind.HEAL, w.shop.id, a.ids[0], a.ids[0], w.player_pos())
	e.amount = add
	e.amount_applied = add
	e.effect_id = EFFECT_HEAL
	_note(w, ShopState.Action.HEAL, add)
	return true


static func reroll(w: World) -> bool:
	var cost := reroll_price(w)
	if w.shards < cost:
		return _deny(w)
	w.shards -= cost
	w.shop.rerolls += 1
	_spend(w, cost, EFFECT_REROLL)
	restock(w)
	_note(w, ShopState.Action.REROLL, cost)
	return true


## v0.5.0 EV: pays cleanse_price to lift the latest curse (Curses.cleanse). Refused without a curse or the shards.
static func cleanse(w: World) -> bool:
	var cost := cleanse_price(w)
	if w.curses_owned.is_empty() or w.shards < cost:
		return _deny(w)
	w.shards -= cost
	_spend(w, cost, EFFECT_CLEANSE)
	var c := w.curses_owned[w.curses_owned.size() - 1]
	Curses.cleanse(w)
	_note(w, ShopState.Action.CLEANSE, c)
	return true


## What can be sold now, in a fixed order: mods (pickup order), stat cards (one entry per card, first-taken
## order), then abilities but the weapon (slot order). Each entry is [kind, ref, code, refund].
static func sell_list(w: World) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	var t := w.shop_table
	for idx in w.items_owned:
		out.append(
			PackedInt32Array([SELL_MOD, idx, idx, t.sell_price(rarity(w, idx), w.floor_index)])
		)
	var seen := PackedInt32Array()
	for code in w.stat_cards:
		if seen.has(code):
			continue
		seen.append(code)
		var n := w.stat_cards.count(code)
		var refund := t.sell_price(Offers.rarity_of(code), w.floor_index)
		out.append(PackedInt32Array([SELL_STAT, n, code, refund]))
	for s in w.ability_owned.size():
		var at := w.ability_tables[w.ability_owned[s]]
		if at.start_weapon != 0:
			continue
		var refund := t.ability_refund_per_level * w.ability_levels[s]
		out.append(
			PackedInt32Array([SELL_ABILITY, s, Offers.ability_code(w.ability_owned[s]), refund])
		)
	return out


## Sells sell_list entry n. True if sold.
static func sell(w: World, n: int) -> bool:
	var list := sell_list(w)
	if n < 0 or n >= list.size():
		return _deny(w)
	var entry := list[n]
	var code := entry[2]
	var id: StringName = Offers.info(w, code)["id"]
	match entry[0]:
		SELL_MOD:
			remove_item(w, entry[1])
		SELL_STAT:
			remove_stat_card(w, code)
		SELL_ABILITY:
			salvage_ability(w, entry[1])
	w.shards += entry[3]
	var pid := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.SHOP_SALVAGE, w.shop.id, pid, code, w.shop.pos)
	e.amount = entry[3]
	e.effect_id = id
	var action := (
		ShopState.Action.SALVAGE_ABILITY if entry[0] == SELL_ABILITY else ShopState.Action.SELL
	)
	_note(w, action, code)
	return true


## Drops owned item `idx`: its modifiers go, and so does every combo it completed.
static func remove_item(w: World, idx: int) -> void:
	var owned := w.items_owned.duplicate()
	owned.remove_at(owned.find(idx))
	var still := Engines.combos_for(w.combo_tables, owned)
	var keep := PackedInt32Array()
	for c in w.combos_owned:
		if still.has(c):
			keep.append(c)
	w.combos_owned = keep
	w.set_items_owned(owned)


## Drops the last-taken card `code` and rebuilds the stat values from the cards left (in the order taken), then the
## gamble shrine's wins that pay into stats. Max HP follows; HP stays, at most the new max.
static func remove_stat_card(w: World, code: int) -> void:
	var cards := w.stat_cards.duplicate()
	for k in range(cards.size() - 1, -1, -1):
		if cards[k] == code:
			cards.remove_at(k)
			break
	rebuild_stats(w, cards)


static func rebuild_stats(w: World, cards: PackedInt32Array) -> void:
	var hp := w.actors.hp[0]
	w.stat_values = PackedInt32Array()
	w.stat_cards = PackedInt32Array()
	for c in cards:
		Stats.add_card(w, Offers.stat_of(c), Offers.rarity_of(c))
	for s in w.gamble_stacks.size():
		var stat := Stats.from_gamble(w, s)
		if stat < 0:
			continue
		for k in w.gamble_stacks[s]:
			Stats.add_amount(w, stat, Gamble.gamble_permille(w, s))
	w.actors.max_hp[0] = maxi(1, Stats.max_hp(w))
	w.actors.hp[0] = clampi(hp, 1, w.actors.max_hp[0])


## Frees ability slot `s` (never the weapon): its level, cooldown and its own floor state go.
static func salvage_ability(w: World, s: int) -> void:
	var t := w.ability_tables[w.ability_owned[s]]
	w.ability_owned.remove_at(s)
	w.ability_levels.remove_at(s)
	if s < w.ab.cd.size():
		w.ab.cd.remove_at(s)
	match t.kind:
		AbilityTable.Kind.DRONE_BUDDY:
			w.ab.drone_pos = PackedVector2Array()
			w.ab.drone_cd = PackedInt32Array()
			w.ab.drone_fire = PackedInt32Array()
		AbilityTable.Kind.BLINK:
			w.ab.blink_charges = 0
			w.blink_cd = 0
		AbilityTable.Kind.ORBIT_BLADES:
			w.ab.orbit_ids = PackedInt32Array()
			w.ab.orbit_next = PackedInt32Array()


# --- Read (WorldReader.shop) ------------------------------------------------------------------------------------
## Plain data for the views: the terminal, the stock with prices, the heal and reroll, the sell list.
static func read(w: World) -> Dictionary:
	var stock: Array[Dictionary] = []
	for code in w.shop.offer:
		var c := {
			"code": code, "sold": code < 0, "price": 0, "can_apply": false, "affordable": false
		}
		if code >= 0:
			c["price"] = price(w, code)
			c["can_apply"] = can_apply(w, code)
			c["affordable"] = w.shards >= c["price"]
		stock.append(c)
	var sells: Array[Dictionary] = []
	for e in sell_list(w):
		sells.append({"kind": e[0], "ref": e[1], "code": e[2], "refund": e[3]})
	return {
		"open": w.shop.open,
		"stock": stock,
		"heal_price": heal_price(w),
		"heal_amount": heal_amount(w),
		"heal_used": w.shop.heal_used,
		"reroll_price": reroll_price(w),
		"cleanse_price": cleanse_price(w),  # v0.5.0 EV
		"cleanse_curse": _latest_curse(w),
		"cleanse_name_key":
		w.ev.curses[_latest_curse(w)].name_key if _latest_curse(w) >= 0 else &"",
		"rerolls": w.shop.rerolls,
		"sell": sells,
		"last_action": w.shop.last_action,
		"last_tick": w.shop.last_tick,
		"last_value": w.shop.last_value,
		"denied_tick": w.shop.denied_tick,
	}


## The curse a cleanse would lift (the latest held, with a table), or -1.
static func _latest_curse(w: World) -> int:
	var n := w.curses_owned.size()
	return w.curses_owned[n - 1] if n > 0 and w.curses_owned[n - 1] < w.ev.curses.size() else -1


static func _spend(w: World, cost: int, what: StringName) -> void:
	var pid := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.SHOP_BUY, w.shop.id, pid, pid, w.shop.pos)
	e.amount = cost
	e.effect_id = what


static func _note(w: World, action: int, value: int) -> void:
	w.shop.last_action = action
	w.shop.last_tick = w.tick
	w.shop.last_value = value


static func _deny(w: World) -> bool:
	w.shop.denied_tick = w.tick
	return false
