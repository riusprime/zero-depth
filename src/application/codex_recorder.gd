class_name CodexRecorder
extends RefCounted
## v0.7.5 CX (owner N6): turns what the sim reports into Codex unlocks and counters (CodexStore, in the profile).
## Main calls `observe` after every tick of a floor (SimDriver.ticked) and `enter_biome` when a floor starts. It reads
## the sim only through WorldReader and its SimEvents (EI-07) and writes only the profile; nothing here reaches a run,
## a save or a hash. Recording is off in a run with the dev panel's balance tweaks (`enabled`, owner: tweaked runs
## don't count, docs/tools/DEV_PANEL.md Step 5).
## What counts:
## - a card: offered when a pick (altar, chest, the boss's tier), the shop's stock or an event's choice shows it;
##   taken on its PICKUP (a pick, a purchase, an event's card); its level is the highest the wand or the ability slots
##   held it at. Curse cards and the starting weapons are not Codex cards.
## - an enemy: met when a living one stands within SEEN_M of you; a kill on its KILL; a death when it killed you.
## - a boss: met (fights + 1, once per boss on the floor) when it has risen; a kill on BOSS_DEFEATED; a death when it
##   killed you.
## - a biome: a visit each time a floor of it starts (not when Continue resumes one).

## How close (m) a living enemy or boss must be to count as met: about the iso camera's view.
const SEEN_M := 18.0

var store: CodexStore
var catalog: CodexCatalog
var enabled := true
var _reader: WorldReader
var _last_seq := 0
## Actor id -> kind (a killed actor's kind outlives its slot).
var _kinds := {}
## Boss actor ids already counted as a fight on this floor.
var _fought := {}
var _offer := PackedInt32Array()
var _shop := PackedInt32Array()
var _event := PackedInt32Array()
var _ended := false


func _init(p_store: CodexStore, p_catalog: CodexCatalog) -> void:
	store = p_store
	catalog = p_catalog


## Starts reading a floor's world; what already happened before this is not recorded again.
func attach(reader: WorldReader) -> void:
	_reader = reader
	_last_seq = reader.last_event_seq()
	_kinds.clear()
	_fought.clear()
	_offer = PackedInt32Array()
	_shop = PackedInt32Array()
	_event = PackedInt32Array()
	_ended = false


func detach() -> void:
	_reader = null


## A floor of `biome` starts (a new floor, not a resumed one).
func enter_biome(biome: StringName) -> void:
	if enabled and catalog.has(&"biomes", biome):
		store.add(&"biomes", biome, &"visits")


## Reads one tick of `reader` (the floor attached; any other reader is ignored).
func observe(reader: WorldReader) -> void:
	if reader == null or reader != _reader:
		return
	_scan_actors(reader)
	var leveled := _events(reader)
	if not enabled:
		return
	_offers(reader)
	if leveled:
		_levels(reader)
	if not _ended and reader.outcome() == 2:
		_ended = true
		_death(reader.killer_kind())


func _scan_actors(reader: WorldReader) -> void:
	var me := reader.player_pos()
	for i in range(1, reader.actor_count()):
		var kind := reader.actor_kind(i)
		_kinds[reader.actor_id(i)] = kind
		if not enabled or reader.actor_dead(i) or reader.actor_spawning(i):
			continue
		if reader.actor_team(i) == reader.actor_team(0):
			continue
		if reader.actor_pos(i).distance_to(me) > SEEN_M:
			continue
		if WorldReader.is_boss_kind(kind):
			var id := reader.actor_id(i)
			var boss := catalog.boss_of_kind(kind)
			if not _fought.has(id) and boss != &"" and reader.boss_intro_permille(i) >= 1000:
				_fought[id] = true
				store.add(&"bosses", boss, &"fights")
		else:
			var enemy := catalog.enemy_of_kind(kind)
			if enemy != &"" and not store.is_unlocked(&"enemies", enemy):
				store.unlock(&"enemies", enemy)


## The tick's events; true when a card was taken (its level may have changed).
func _events(reader: WorldReader) -> bool:
	var player_id := reader.actor_id(0)
	var taken := false
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if not enabled:
			continue
		match e.kind:
			SimEvent.Kind.KILL:
				var kind: int = _kinds.get(e.target_id, -1)
				if e.target_id != player_id and not WorldReader.is_boss_kind(kind):
					var enemy := catalog.enemy_of_kind(kind)
					if enemy != &"":
						store.add(&"enemies", enemy, &"kills")
			SimEvent.Kind.BOSS_DEFEATED:
				var boss := catalog.boss_of_kind(_kinds.get(e.target_id, -1))
				if boss != &"":
					store.add(&"bosses", boss, &"kills")
			SimEvent.Kind.PICKUP:
				var id := _card_id(reader, e.amount)
				if id != &"":
					store.add(&"cards", id, &"taken")
					taken = true
	return taken


## The Codex card id of card code `code` (&"" for a curse card or a card the Codex doesn't list).
func _card_id(reader: WorldReader, code: int) -> StringName:
	if code < 0:
		return &""
	var info := reader.card_info(code)
	if int(info.get("type", -1)) == WorldReader.CARD_CURSE:
		return &""
	var id: StringName = info.get("id", &"")
	return id if catalog.has(&"cards", id) else &""


## Cards shown: the open pick's three, the shop's stock and an open event's card choices (each once per showing).
func _offers(reader: WorldReader) -> void:
	var offer := reader.choice_items() if reader.choosing() else PackedInt32Array()
	if offer != _offer:
		_offer = offer
		_offered(reader, offer)
	var stock := PackedInt32Array()
	if reader.shop_open():
		for s: Dictionary in reader.shop()["stock"]:
			stock.append(int(s["code"]))
	if stock != _shop:
		var shown := PackedInt32Array()
		for c in stock:
			if not _shop.has(c):
				shown.append(c)
		_shop = stock
		_offered(reader, shown)
	var cards := PackedInt32Array()
	if reader.event_open():
		var k := reader.event_open_index()
		for c in reader.event_choice_count(k):
			var code := reader.event_choice_card(k, c)
			if code >= 0:
				cards.append(code)
	if cards != _event:
		_event = cards
		_offered(reader, cards)


func _offered(reader: WorldReader, codes: PackedInt32Array) -> void:
	for code in codes:
		var id := _card_id(reader, code)
		if id != &"":
			store.add(&"cards", id, &"offered")


## The highest level each held card reached: the wand's cards and the ability slots.
func _levels(reader: WorldReader) -> void:
	for c: Dictionary in reader.wand().get("cards", []):
		var id: StringName = c.get("id", &"")
		if catalog.has(&"cards", id) and bool(catalog.entry(&"cards", id).get("leveled", false)):
			store.raise_to(&"cards", id, &"level", maxi(1, int(c.get("level", 1))))
	for a: Dictionary in reader.abilities():
		var id: StringName = a.get("id", &"")
		if catalog.has(&"cards", id):
			store.raise_to(&"cards", id, &"level", maxi(1, int(a.get("level", 1))))


func _death(killer_kind: int) -> void:
	if killer_kind < 0:
		return
	if WorldReader.is_boss_kind(killer_kind):
		var boss := catalog.boss_of_kind(killer_kind)
		if boss != &"":
			store.add(&"bosses", boss, &"deaths")
		return
	var enemy := catalog.enemy_of_kind(killer_kind)
	if enemy != &"":
		store.add(&"enemies", enemy, &"deaths")
