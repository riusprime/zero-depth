extends SceneTree
## v0.10.5 O16 (owner P15 "we can try sure", P16 "sure"): the three curves (Schreiber: avatar power, game challenge,
## a player-skill proxy) and the run's economy, sampled every 10 s over whole runs. Evidence only: no tuning.
## The run: tests/support/survival_run.gd's flow (each floor built by FloorPlan, as Main builds it, Survivor in the
## start hall for floor_s seconds, the boss fought by test_final_pace's Hero, the portal, the carry), healed to full
## every tick (a damage ledger: every run plays the whole way), on the shipped run table (RunSaver.RUN_ID). The build:
## the survival bot's 3 offence stat cards a floor, plus "shopper": every 30 s of floor time it takes every free altar
## (the offer's first card that needs no swap) and every chest it can afford, cheapest first (the shards really
## spent; arena locks and cursed chests ignored, so T stays 0: the bot never takes a curse). Floor 5's portal ends the
## run (the final arena is left out).
## Per sample (CSV): seed, floor, phase (floor/boss), run second, P (CatchUp.power), the floor's m, the boss m, T,
## the challenge index of the enemies that arrived in the window (mean of max HP / the kind's table HP x damage power,
## per mille: floor scaling x tier x Overrun x m x sqrt(m)), arrivals, kills, enemy HP removed (realized throughput),
## HP lost (the ledger), hit ticks (ticks the hero lost HP), threat dashes (Survivor's dash out of a wind-up), shards
## held, shards earned, shards spent, the unbought chests' price total, heal orbs on the floor, cards taken.
## Writes build/three_curves/seeds_<from>_<to>.csv; paste the aggregate (scripts/checks/three_curves_table.py) by hand.
##   godot --headless --path . -s scripts/checks/three_curves.gd -- from=1 seeds=5 floor_s=240

const Run := preload("res://tests/support/survival_run.gd")
const FP := preload("res://tests/unit/sim/test_final_pace.gd")
const SAMPLE := 600
const SPEND_EVERY := 1800
const BOSS_LIMIT := 18000
const HEADER := (
	"seed,floor,phase,t_s,P,m,m_boss,T,chal,arrivals,kills,hp_removed,hp_lost,hit_ticks,dashes,"
	+ "shards,earned,spent,chest_unbought,orbs,cards"
)

var _out: FileAccess
var _bigs := {}
var _seed := 0
var _floor := 0
var _phase := ""
var _run_t := 0
var _acc := {}
var _hp := {}  # enemy id -> hp last tick
var _cards := 0


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var from := int(args.get("from", "1"))
	var seeds := int(args.get("seeds", "5"))
	var floor_s := int(args.get("floor_s", "240"))
	var repo := ContentRepository.load_all()
	_bigs = Run.dodged(repo)
	DirAccess.make_dir_recursive_absolute("res://build/three_curves")
	var path := "res://build/three_curves/seeds_%d_%d.csv" % [from, from + seeds - 1]
	_out = FileAccess.open(path, FileAccess.WRITE)
	_out.store_line(HEADER)
	var t0 := Time.get_ticks_msec()
	for k in seeds:
		_seed = from + k
		_run_t = 0
		_cards = 0
		var plan := FloorPlan.new_run(RunSaver.RUN_ID, _seed, &"blade", false)
		plan.repo = repo
		plan.build()
		var floors := plan.run.table.floors
		for f in range(1, floors + 1):
			_play_floor(plan.world, f, floor_s)
			if f < floors:
				plan.run.finish_floor(plan.world)  # as Main's _next_floor (MetaHooks.finish_floor)
				var biomes := plan.run_biomes
				plan = FloorPlan.next_floor(plan.run, biomes, {}, false)
				plan.repo = repo
				plan.build()
		print("seed %d done (%d ms)" % [_seed, Time.get_ticks_msec() - t0])
	_out.close()
	print("wrote %s" % path)
	quit()


func _play_floor(w: World, f: int, floor_s: int) -> void:
	_floor = f
	for c in Run.CARDS_PER_FLOOR:  # the survival bot's offence cards (Run._cards' order, no defence)
		var r := Stats.Rarity.COMMON
		if f >= 5:
			r = Stats.Rarity.EPIC
		elif f >= 3:
			r = Stats.Rarity.RARE
		Stats.add_card(w, Run.OFFENCE[(Run.CARDS_PER_FLOOR * (f - 1) + c) % Run.OFFENCE.size()], r)
		_cards += 1
	_hp.clear()
	_reset()
	_phase = "floor"
	var bot := Run.Survivor.new(false)
	for k in floor_s * SimTick.TICKS_PER_SECOND:
		if k % SPEND_EVERY == SPEND_EVERY - 1:
			_spend(w)
		var fr := bot.frame(w)
		if fr.pressed & InputFrame.DASH:
			_acc["dashes"] += 1
		_tick(w, fr)
	_spend(w)
	_flush(w)
	var layout := w.floor_layout
	w.actors.set_pos(0, layout.boss_door_inside(1.5))
	_phase = "boss"
	for k in 600:
		if w.boss_flow.state == BossFlow.State.FIGHT and w.actors.index_of(w.boss_id) >= 0:
			break
		_tick(w, InputFrame.new())
	var hero: RefCounted = FP.Hero.new(w.boss_id, _bigs)
	for n in BOSS_LIMIT:
		if hero.boss_dead(w):
			break
		var fr: InputFrame = hero.frame(w)
		if fr.pressed & InputFrame.DASH:
			_acc["dashes"] += 1
		_tick(w, fr)
	if not hero.boss_dead(w):
		print("seed %d floor %d: boss out of time" % [_seed, f])
		var bi := w.actors.index_of(w.boss_id)
		w.actors.invuln[bi] = 0
		Damage.hit(w, bi, 99999999, 0, 0, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
	_flush(w)
	CombatLab.idle(w, 2)
	w.actors.set_pos(0, layout.portal_front_point())
	for k in 600:
		if w.boss_flow.state == BossFlow.State.ENTERING:
			break
		w.step(FinalLab.walk(w, layout.portal_pos))
	CombatLab.idle(w, BossFlow.ENTER_TICKS + 2)
	w.actors.hp[0] = w.actors.max_hp[0]
	print(
		(
			"seed %d floor %d end: shards %d, P %d, m %d, boss m %d, cards %d"
			% [_seed, f, w.shards, CatchUp.power(w), w.catch_up.enemy, w.catch_up.boss, _cards]
		)
	)


## One healed tick, with the window's tallies.
func _tick(w: World, fr: InputFrame) -> void:
	var a := w.actors
	a.hp[0] = a.max_hp[0]
	var before_shards := w.shards
	w.step(fr)
	var lost := maxi(0, a.max_hp[0] - a.hp[0])
	_acc["hp_lost"] += lost
	if lost > 0:
		_acc["hit_ticks"] += 1
	if w.shards > before_shards:
		_acc["earned"] += w.shards - before_shards
	var seen := {}
	for i in range(1, a.size()):
		if a.teams[i] != ActorStore.TEAM_ENEMY:
			continue
		var id := a.ids[i]
		seen[id] = true
		var hp: int = a.hp[i] if a.dead[i] == 0 else 0
		if not _hp.has(id):
			if a.dead[i] == 0 and not BossAi.is_boss_kind(a.kinds[i]):
				var t := w.enemy_table(a.kinds[i])
				if t != null and t.hp > 0:
					_acc["arrivals"] += 1
					_acc["chal_sum"] += a.max_hp[i] * 1000 / t.hp * maxi(1, a.power[i]) / 1000
			_hp[id] = hp
			continue
		var prev: int = _hp[id]
		if hp < prev:
			_acc["hp_removed"] += prev - hp
		if prev > 0 and hp == 0:
			_acc["kills"] += 1
		_hp[id] = hp
	for id in _hp.keys():
		if not seen.has(id):
			if _hp[id] > 0:
				_acc["hp_removed"] += _hp[id]
				_acc["kills"] += 1
			_hp.erase(id)
	_run_t += 1
	if _run_t % SAMPLE == 0:
		_flush(w)


## Shopper: every free altar and every chest it can afford, cheapest first.
func _spend(w: World) -> void:
	var again := true
	while again:
		again = false
		var best := -1
		for i in w.rewards.size():
			if w.rewards.price[i] > w.shards:
				continue
			if best < 0 or w.rewards.price[i] < w.rewards.price[best]:
				best = i
		if best < 0:
			return
		var offer := Offers.roll(w, best)
		var code := -1
		for c in offer:
			if not BuildSlots.needs_swap(w, c):
				code = c
				break
		var price: int = w.rewards.price[best]
		w.solids.remove(w, Solids.Kind.REWARD, w.rewards.ids[best])
		w.rewards.remove_at(best)
		if code < 0:
			again = true
			continue
		w.shards -= price
		_acc["spent"] += price
		Offers.apply(w, code)
		_cards += 1
		again = true


func _reset() -> void:
	_acc = {
		"arrivals": 0,
		"chal_sum": 0,
		"kills": 0,
		"hp_removed": 0,
		"hp_lost": 0,
		"hit_ticks": 0,
		"dashes": 0,
		"earned": 0,
		"spent": 0
	}


func _flush(w: World) -> void:
	var unbought := 0
	for i in w.rewards.size():
		unbought += w.rewards.price[i]
	var chal: int = _acc["chal_sum"] / _acc["arrivals"] if _acc["arrivals"] > 0 else 0
	var row := [
		_seed,
		_floor,
		_phase,
		_run_t / 60,
		CatchUp.power(w),
		w.catch_up.enemy,
		w.catch_up.boss,
		Curses.threat(w),
		chal,
		_acc["arrivals"],
		_acc["kills"],
		_acc["hp_removed"],
		_acc["hp_lost"],
		_acc["hit_ticks"],
		_acc["dashes"],
		w.shards,
		_acc["earned"],
		_acc["spent"],
		unbought,
		w.orbs.size(),
		_cards
	]
	_out.store_line(",".join(row.map(func(v): return str(v))))
	_reset()
