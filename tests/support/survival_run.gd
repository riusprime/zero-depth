extends RefCounted
## v0.9.0 SV (PLAN "Owner decisions" EL, SV: "checked with the bot that a build with no defence card still reaches the
## final boss"): one whole five-floor run played by scripted heroes, floor by floor as Main builds them (RunLab), for
## scripts/balance/survival.gd. Not the retired balance bots (SCORECARD, 2026-10-08): a survival check, read against
## the owner's play.
## Each floor: the run's stat cards for the floor (CARDS_PER_FLOOR, offence only, or one defence card a floor), then
## `floor_s` seconds of Survivor (below) against the floor's spawns from the start hall, then the boss room (entered at
## its door, so it seals) fought by test_final_pace.gd's Hero (BladeRun: dashes out of every boss attack's telegraph,
## attacks in its windows), then the portal; after floor 5's Ascension portal, the final arena (FinalLab.arena on this
## run's state and carry) fought by the same Hero.
## A damage ledger, as test_boss_pace and test_final_pace fight: the hero is healed every tick, so every run plays the
## whole way, and the HP it lost is counted per floor (the floor, the boss) and in the final fight. HpLedger then
## replays the HP pool from it under a rule set (before / after SV) and a share of the bot's damage a player takes.
## The hero keeps no wand or ability cards beyond the start (stat cards only).

const FP := preload("res://tests/unit/sim/test_final_pace.gd")
const CARDS_PER_FLOOR := 3
## The offence cards, in pick order (taken round-robin across the run).
const OFFENCE: Array[int] = [Stats.Stat.DAMAGE, Stats.Stat.ATTACK_SPEED, Stats.Stat.CRIT_CHANCE]
## The defence cards (one a floor in the defence policy, alternating).
const DEFENCE: Array[int] = [Stats.Stat.MAX_HP, Stats.Stat.ARMOUR]
## A floor boss within this (ticks: 5 min); the final boss within test_final_pace's LIMIT (12 min).
const BOSS_LIMIT := 18000
const FINAL_LIMIT := 43200

var lab: RunLab
var defence := false
var floor_s := 90
## Per floor: [floor, max HP after SV, max HP before SV (no growth), HP lost on the floor, HP lost to the boss, the
## boss fight's seconds].
var floors: Array = []
## HP lost in the final fight, and whether the (healed) hero beat it within FINAL_LIMIT.
var final_lost := 0
var final_won := false
var note := ""  # a fight that ran out of time
var _picks := 0
var _defs := 0
var _bigs := {}


func _init(repo: ContentRepository, run_seed: int, build: StringName, p_defence: bool) -> void:
	lab = RunLab.new(repo, run_seed, build)
	defence = p_defence
	_bigs = dodged(repo)


## The attacks the heroes dash out of: every floor and final boss attack (a careful player reads each telegraph).
static func dodged(repo: ContentRepository) -> Dictionary:
	var out := {}
	for cat: StringName in [&"bosses", &"final_bosses"]:
		for def: BossDefinition in repo.all_of(cat):
			for a in def.attacks:
				out[a.id] = true
	return out


func play() -> void:
	for f in range(1, lab.run.table.floors + 1):
		_floor(f)
	var w := FinalLab.arena(lab.run, false)
	CatchUp.start_floor(w)
	FinalArenaScenario.begin(w, lab.run, 3)
	FinalLab.past_rise(w)
	var bot: RefCounted = FP.Hero.new(-1, _bigs)
	for n in FINAL_LIMIT:
		if w.final_fight.won:
			break
		var i := FinalLab.body(w)
		if i >= 0:
			bot.aid = w.actors.ids[i]
		var live := i >= 0 and w.actors.dead[i] == 0
		final_lost += _step(w, bot.frame(w) if live else InputFrame.new())
	final_won = w.final_fight.won
	if not final_won:
		note += " final: out of time"


func _floor(f: int) -> void:
	var w := lab.floor_world()
	_cards(w, CARDS_PER_FLOOR)
	var keep := w.floor_hp_bonus
	w.floor_hp_bonus = 0
	var before_max := Stats.max_hp(w)
	w.floor_hp_bonus = keep
	var row := [f, w.actors.max_hp[0], before_max, 0, 0, 0]
	floors.append(row)
	var bot := Survivor.new(PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w))
	for k in floor_s * SimTick.TICKS_PER_SECOND:
		row[3] += _step(w, bot.frame(w))
	var layout := w.floor_layout
	w.actors.set_pos(0, layout.boss_door_inside(1.5))
	for k in 600:  # the door seals and the boss rises
		if w.boss_flow.state == BossFlow.State.FIGHT and w.actors.index_of(w.boss_id) >= 0:
			break
		row[4] += _step(w, InputFrame.new())
	if w.actors.index_of(w.boss_id) < 0:
		note += " boss %d: never rose (state %d)" % [f, w.boss_flow.state]
	var hero: RefCounted = FP.Hero.new(w.boss_id, _bigs)
	for n in BOSS_LIMIT:
		if hero.boss_dead(w):
			break
		row[4] += _step(w, hero.frame(w))
		row[5] = n / 60
	if not hero.boss_dead(w):  # (killed by script so the run goes on; noted)
		note += " boss %d: out of time" % f
		var bi := w.actors.index_of(w.boss_id)
		w.actors.invuln[bi] = 0
		Damage.hit(w, bi, 99999999, 0, 0, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
	CombatLab.idle(w, 2)
	w.actors.set_pos(0, layout.portal_front_point())
	for k in 600:
		if w.boss_flow.state == BossFlow.State.ENTERING:
			break
		w.step(FinalLab.walk(w, layout.portal_pos))
	CombatLab.idle(w, BossFlow.ENTER_TICKS + 2)
	w.actors.hp[0] = w.actors.max_hp[0]  # (the carry's HP is the pool's business, HpLedger)
	lab.next_floor(w)


## One healed tick: the HP the hero lost in it.
static func _step(w: World, f: InputFrame) -> int:
	w.actors.hp[0] = w.actors.max_hp[0]
	w.step(f)
	return maxi(0, w.actors.max_hp[0] - w.actors.hp[0])


## Takes `count` stat cards: offence round-robin; in the defence policy the first of each floor is a defence card.
## Rarity by floor: common on floors 1-2, rare on 3-4, epic on 5.
func _cards(w: World, count: int) -> void:
	var r := Stats.Rarity.COMMON
	if w.floor_index >= 5:
		r = Stats.Rarity.EPIC
	elif w.floor_index >= 3:
		r = Stats.Rarity.RARE
	for k in count:
		if defence and k == 0:
			Stats.add_card(w, DEFENCE[_defs % DEFENCE.size()], r)
			_defs += 1
		else:
			Stats.add_card(w, OFFENCE[_picks % OFFENCE.size()], r)
			_picks += 1


## The HP pool over a ledger's run under a rule set: `heal_permille` between floors (of the max HP left), the max HP
## each floor (after or before SV), floor 1's boss room heal (the run table's), and `share_permille` of the bot's
## damage taken. Returns [the floor the hero died on (0: reached the final boss), [HP on arrival, at the boss door,
## after the boss] per floor reached, HP on arriving in the final arena, beat the final boss].
static func pool(
	r: RefCounted,
	before: bool,
	heal_permille: int,
	room_heal: PackedInt32Array,
	share_permille: int
) -> Array:
	var per := []
	var hp := 0
	var prev_max := 0
	for row: Array in r.floors:
		var mx: int = row[2] if before else row[1]
		if prev_max == 0:
			hp = mx
		else:
			hp = mini(prev_max, hp + prev_max * heal_permille / 1000) + maxi(0, mx - prev_max)
			hp = mini(hp, mx)
		var arrive := hp
		hp -= int(row[3]) * share_permille / 1000
		if hp <= 0:
			per.append([arrive, 0, 0])
			return [row[0], per, 0, false]
		var door := hp
		var f: int = row[0]
		var heal := room_heal[f - 1] if f - 1 < room_heal.size() else 0
		hp = mini(mx, hp + mx * heal / 1000)
		hp -= int(row[4]) * share_permille / 1000
		if hp <= 0:
			per.append([arrive, door, 0])
			return [row[0], per, 0, false]
		per.append([arrive, door, hp])
		prev_max = mx
	var at := mini(prev_max, hp + prev_max * heal_permille / 1000)
	var won: bool = r.final_won and at - int(r.final_lost) * share_permille / 1000 > 0
	return [0, per, at, won]


## The floor's hero: FightBot's aim, with a player's care. It dashes out of an enemy's wind-up near it, backs off
## from a crowd (the Blade) or keeps its range (the Gun: 4.5-8 m, always shooting), and otherwise closes in and
## swings. It stands in the start hall's area; the spawns come to it.
class Survivor:
	extends RefCounted
	const SWING := 2.4
	const THREAT_M := 3.5
	var gun := false
	var _strafe := 1
	var _flee := Vector2.ZERO
	var _flee_t := 0

	func _init(p_gun: bool) -> void:
		gun = p_gun

	func frame(w: World) -> InputFrame:
		if w.tick % 120 == 0:
			_strafe = -_strafe
		var p := w.player_pos()
		var near := -1
		var near_d := 0.0
		var crowd := Vector2.ZERO
		var crowd_n := 0
		var threat := Vector2.ZERO
		for i in range(1, w.actors.size()):
			if w.actors.dead[i] == 1 or w.actors.teams[i] != ActorStore.TEAM_ENEMY:
				continue
			var d := Kin.length(w.actors.pos(i) - p)
			if near < 0 or d < near_d:
				near = i
				near_d = d
			if d < 3.0:
				crowd += w.actors.pos(i)
				crowd_n += 1
			if d < THREAT_M + w.actors.radius[i] and w.actors.state[i] == EnemyAi.State.WINDUP:
				threat = w.actors.pos(i)
		if near < 0:
			return InputFrame.new()
		var to := w.actors.pos(near) - p
		var dir := to / near_d if near_d > 0.0 else Vector2.RIGHT
		var side := Vector2(-dir.y, dir.x) * _strafe
		var pressed := 0
		var held := 0
		if _flee_t > 0:
			_flee_t -= 1
			return _frame(_flee, to, near_d, InputFrame.SHOOT if gun else 0, 0)
		if threat != Vector2.ZERO and w.dash_cooldown_left == 0:
			var away := (p - threat).normalized()
			_flee = (away + Vector2(-away.y, away.x) * _strafe).normalized()
			_flee_t = 14
			return _frame(_flee, to, near_d, 0, InputFrame.DASH)
		var move := dir
		if gun:
			held = InputFrame.SHOOT
			if near_d < 4.5:
				move = (-dir + side).normalized()
			elif near_d < 8.0:
				move = side
		else:
			var hurt := w.actors.hp[0] * 100 < w.actors.max_hp[0] * 40
			if crowd_n >= 3 or (hurt and crowd_n >= 2):
				move = ((p - crowd / crowd_n).normalized() + side * 0.5).normalized()
			elif near_d < SWING * 0.6:
				move = side
			if near_d <= SWING and w.tick % 6 == 0:
				pressed |= InputFrame.PRIMARY
			elif near_d > SWING:
				held |= InputFrame.SHOOT
		return _frame(move, to, near_d, held, pressed)

	static func _frame(
		move: Vector2, aim: Vector2, dist: float, held: int, pressed: int
	) -> InputFrame:
		var mv := Vector2i(int(move.x * 127.0), int(move.y * 127.0))
		return InputFrame.make(mv, Kin.angle_of(aim), int(dist * 100.0), held, pressed)
