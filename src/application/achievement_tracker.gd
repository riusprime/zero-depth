class_name AchievementTracker
extends RefCounted
## v0.7.5 AC (owner N7): unlocks achievements (AchievementBook) as the profile meets them. Main calls `observe` after
## every tick of a floor, like the Codex's recorder; it reads the sim only through WorldReader and its SimEvents
## (EI-07) and writes only the profile (AchievementStore). The Codex's counters are read as CodexStore writes them
## (its `changed` / `unlocked` signals), and this records the run counters the Codex doesn't keep
## (AchievementDefinition.STATS):
## - floors:cleared_N: the portal of floor N taken (outcome 3), or the run won on it (outcome 1);
## - runs:won, runs:won_gun / runs:won_blade: the run won, with the wand's weapon;
## - wand:cards_max: the most cards the wand held (read after a card is taken or bought);
## - kills:child_spell: a kill whose hit came from a hook's attack (HIT.proc_pct under 100: a trigger card's child
##   spell, a split, an echo; SIM_CONTRACTS §7, Attacks.projectile_proc);
## - rooms:sealed_cleared / rooms:no_hit: a sealed room (an arena or the Overrun, Arenas.read) cleared, and cleared
##   without the hero losing HP after it sealed;
## - overruns:cleared: the Overrun room cleared;
## - curses:chest_card: a cursed chest's card taken (a PICKUP of a curse card);
## - cores:stolen: a Core stolen (the steal tick moved);
## - shards:spent: the shards each SHOP_BUY cost.
## - runs:ascended: reported by the Ascension portal (v0.7.5 AP) through `report(&"runs:ascended")`; nothing here
##   records it.
## - v0.8.0 FB1 (FINAL_BOSS.md F8), in the final arena: final:won (the last body fell: the run won), final:won_looped
##   (won on a loop past the first), final:no_hit_phase (a body's whole segment, from its rise to its fall, without the
##   hero losing HP; a fight resumed from a save starts its body clean, the save being its start). The arena's win
##   doesn't count its floor cleared again (End the run already did).
## - v0.9.5 SL: final:won_gun (the final boss beaten with the Gun: "Sword Unbound", which unlocks the Blade; SwordLock).
## - v0.9.5 RS2 (the Runic Stone's lines): bosses:no_hit (a floor boss beaten from its door shutting with no HP lost; a
##   fight resumed from a save doesn't count) and secrets:crack_runs (a cracked wall broken, at most once per run).
## Off (`enabled` false) in a run with the dev panel's balance tweaks (owner: tweaked runs don't count): nothing is
## recorded and nothing unlocks.

## An achievement unlocked (the toast shows it).
signal achieved(a: Dictionary)

## How often (ticks) the wand's size is read without a card taken: a backstop for cards that arrive another way.
const WAND_POLL_TICKS := 30

var book: AchievementBook
var store: AchievementStore
var enabled := true
var _reader: WorldReader
var _last_seq := 0
var _ended := false
var _sealed_room := -1
var _hurt := false
var _cleared_seen := 0
var _lk_cleared_seen := 0  # v0.9.5 DR: the locked rooms (lockdowns, and the old arena rooms) count too
var _overrun_done := false
var _steal_tick := -1
var _wand_due := 0
## v0.8.0 FB1: the final fight's body being watched, and whether the hero lost HP since it rose.
var _final_phase := -1
var _final_hurt := false
## v0.9.5 RS1: the floor's purple runes were awake when last read (RunicStone.PURPLE_STAT).
var _purple_seen := false
## v0.9.5 RS2: a floor boss fight (the door shut) and whether the hero lost HP in it (RunicStone.NO_HIT_STAT); the
## cracked wall seen broken; this run already counted for RunicStone.CRACK_STAT; the run floor last attached (a lower
## one: a new run).
var _boss_fight := false
var _boss_hurt := false
var _boss_done := false
var _crack_seen := false
var _crack_counted := false
var _last_run_floor := 0


func _init(p_book: AchievementBook) -> void:
	book = p_book
	store = p_book.store
	book.codex.changed.connect(_on_codex_changed)
	book.codex.unlocked.connect(_on_codex_unlocked)


## Starts reading a floor's world; what already happened is not recorded again. Anything the profile already meets
## (an older Codex, a stat from before) unlocks now.
func attach(reader: WorldReader) -> void:
	_reader = reader
	_last_seq = reader.last_event_seq()
	_ended = reader.outcome() != 0
	var ar := reader.arenas()
	_sealed_room = int(ar.get("sealed", -1))
	_hurt = true  # a room already sealed when the floor resumes doesn't count as clean
	_cleared_seen = (ar.get("cleared", PackedInt32Array()) as PackedInt32Array).size()
	var lk := reader.lockdown()
	if _sealed_room < 0:
		_sealed_room = int(lk.get("sealed", -1))
	_lk_cleared_seen = (lk.get("cleared", PackedInt32Array()) as PackedInt32Array).size()
	_overrun_done = bool(reader.overrun().get("cleared", false))
	_steal_tick = reader.steal_tick()
	_wand_due = 0
	_final_phase = reader.final_phase()  # v0.8.0 FB1: saves are taken at a body's start, so it starts clean
	_final_hurt = false
	_purple_seen = reader.purple_lit()  # v0.9.5 RS1: a floor resumed with the runes awake counted already
	_boss_fight = false  # v0.9.5 RS2: a boss fight resumed from a save is not a clean one
	_boss_hurt = false
	_boss_done = reader.boss_door_sealed()
	_crack_seen = reader.crack_broken()
	var rf := reader.run_floor()
	if rf < _last_run_floor or (rf <= 1 and reader.tick() == 0):
		_crack_counted = false  # a new run
	_last_run_floor = rf
	evaluate_all()


func detach() -> void:
	_reader = null


## The hook for counters other steps report (v0.7.5 AP: `report(&"runs:ascended")` each time the hero Ascends).
## Ignored while recording is off (a tweaked run).
func report(key: StringName, by: int = 1) -> void:
	if not enabled:
		return
	store.add_stat(key, by)
	_check(book.reading_stat(key))


## Reads one tick of `reader` (the floor attached; any other reader is ignored).
func observe(reader: WorldReader) -> void:
	if reader == null or reader != _reader:
		return
	var events := reader.events_since(_last_seq)
	if not events.is_empty():
		_last_seq = events[events.size() - 1].seq
	if not enabled:
		return
	if (
		not _boss_done
		and not _boss_fight
		and reader.boss_door_sealed()
		and not reader.final_arena()
	):
		_boss_fight = true  # v0.9.5 RS2: the door shut behind the hero: the fight begins clean
		_boss_hurt = false
	var took := _events(reader, events)
	_rooms(reader)
	if reader.steal_tick() != _steal_tick:
		_steal_tick = reader.steal_tick()
		if _steal_tick >= 0:
			report(&"cores:stolen")
	_wand_due -= 1
	if took or _wand_due <= 0:
		_wand_due = WAND_POLL_TICKS
		var n := (reader.wand().get("cards", []) as Array).size()
		if n > store.stat(&"wand:cards_max"):
			store.raise_stat(&"wand:cards_max", n)
			_check(book.reading_stat(&"wand:cards_max"))
	_final(reader)
	if not _crack_seen and reader.crack_broken():  # v0.9.5 RS2: a cracked wall broken: once per run
		_crack_seen = true
		if not _crack_counted:
			_crack_counted = true
			report(RunicStone.CRACK_STAT)
	if not _purple_seen and reader.purple_lit():  # v0.9.5 RS1: a purple-rune room activated (the Runic Stone)
		_purple_seen = true
		report(RunicStone.PURPLE_STAT)
	if not _ended and reader.outcome() in [1, 3]:
		_ended = true
		if not reader.final_arena():  # v0.8.0 FB1: End the run counted the floor
			report(StringName("floors:cleared_%d" % reader.floor_index()))
		if reader.outcome() == 1:
			report(&"runs:won")
			report(StringName("runs:won_%s" % reader.wand().get("weapon", &"blade")))


## The tick's events; true when a card was taken (the wand may have grown).
func _events(reader: WorldReader, events: Array[SimEvent]) -> bool:
	var me := reader.actor_id(0)
	var hits := {}
	var damages := {}
	var took := false
	for e in events:
		match e.kind:
			SimEvent.Kind.HIT:
				if e.owner_id == me:
					hits[e.seq] = e.proc_pct
			SimEvent.Kind.DAMAGE:
				damages[e.seq] = e.parent_seq
				if e.target_id == me and e.amount_applied > 0 and _sealed_room >= 0:
					_hurt = true
				if e.target_id == me and e.amount_applied > 0:
					_final_hurt = true  # v0.8.0 FB1
				if e.target_id == me and e.amount_applied > 0 and _boss_fight:
					_boss_hurt = true  # v0.9.5 RS2
			SimEvent.Kind.BOSS_DEFEATED:
				if _boss_fight and not reader.boss_alive():  # v0.9.5 RS2: the last boss of the room fell
					_boss_fight = false
					_boss_done = true
					if not _boss_hurt:
						report(RunicStone.NO_HIT_STAT)
			SimEvent.Kind.KILL:
				if e.owner_id == me and e.target_id != me:
					var pct: int = hits.get(damages.get(e.parent_seq, -2), 100)
					if pct > 0 and pct < 100:
						report(&"kills:child_spell")
			SimEvent.Kind.PICKUP:
				took = true
				if e.amount >= 0:
					var info := reader.card_info(e.amount)
					if int(info.get("type", -1)) == WorldReader.CARD_CURSE:
						report(&"curses:chest_card")
			SimEvent.Kind.SHOP_BUY:
				took = true
				if e.amount > 0:
					report(&"shards:spent", e.amount)
	return took


## v0.8.0 FB1: the final fight's achievements: a body beaten clean when the next rises (or the last falls), and the
## win (a loop past the first too).
func _final(reader: WorldReader) -> void:
	if not reader.final_arena():
		return
	var ph := reader.final_phase()
	var won := reader.final_won()
	if ph > _final_phase or (won and _final_phase >= 0):
		if not _final_hurt and _final_phase >= 0:
			report(&"final:no_hit_phase")
		_final_phase = -1 if won else ph
		_final_hurt = false
	if won and not _ended:
		report(&"final:won")
		if reader.wand().get("weapon", &"blade") == &"gun":  # v0.9.5 SL: Sword Unbound unlocks the Blade
			report(&"final:won_gun")
		if reader.loop() > 1:
			report(&"final:won_looped")


## Sealed rooms: one sealing starts clean; a hit that costs HP spoils it; its clear counts (and counts clean).
## v0.9.5 DR: the locked rooms (lockdowns; on floor rules 20 the arena rooms too) count like the arenas.
## the locked rooms (lockdowns; on floor rules 20 the arena rooms too) count like the arenas.
func _rooms(reader: WorldReader) -> void:
	_cleared_seen = _sealed_source(reader.arenas(), _cleared_seen)
	_lk_cleared_seen = _sealed_source(reader.lockdown(), _lk_cleared_seen)
	var ov := reader.overrun()
	if not _overrun_done and bool(ov.get("cleared", false)):
		_overrun_done = true
		report(&"overruns:cleared")


## One source of sealed rooms (WorldReader.arenas() or lockdown(): {active, sealed, cleared}); returns the clears
## it has seen.
func _sealed_source(d: Dictionary, seen: int) -> int:
	if not bool(d.get("active", false)):
		return seen
	var sealed := int(d.get("sealed", -1))
	if sealed >= 0 and sealed != _sealed_room:
		_sealed_room = sealed
		_hurt = false
	var cleared: PackedInt32Array = d.get("cleared", PackedInt32Array())
	if cleared.size() <= seen:
		return seen
	var clean := not _hurt and _sealed_room >= 0 and cleared.has(_sealed_room)
	_sealed_room = -1
	report(&"rooms:sealed_cleared")
	if clean:
		report(&"rooms:no_hit")
	return cleared.size()


## Unlocks every achievement the profile meets now (a floor starts; Codex counts from before AC count).
func evaluate_all() -> void:
	if enabled:
		_check(book.all())


func _on_codex_changed(page: StringName, _id: StringName, _counter: StringName, _v: int) -> void:
	if enabled:
		_check(book.reading_page(page))


func _on_codex_unlocked(page: StringName, _id: StringName) -> void:
	if enabled:
		_check(book.reading_page(page))


func _check(list: Array[Dictionary]) -> void:
	for a in list:
		if not store.is_unlocked(a["id"]) and book.met(a) and store.unlock(a["id"]):
			achieved.emit(a)
