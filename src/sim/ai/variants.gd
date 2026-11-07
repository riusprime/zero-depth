class_name Variants
extends RefCounted
## v0.11.0 O13a (PLAN M3; docs/roadmap/v0.11.0/ENEMIES.md V1-V5, approved 2026-11-07; owner Q23): the five biome
## variants. Each runs its base's behaviour (EnemyAi.behaviour_of: walk, aim, windup, hit) and adds one twist here;
## its numbers are its EnemyTable's (VariantCompiler, from data/enemies/<id>.tres; starting values). What they leave
## on the floor is World.variants (VariantState). Pure: no stream is drawn.
## - V1 Rubble Warden (Ruins): a crust of extra HP on top of the Warden's; the first tick its HP is at half or under,
##   the crust falls off (crust_fall) as crust_pieces small rocks round it, each a wall while it stands (cover for both
##   sides: collision, shots, sight; World.add_barrier, never the flow field). A spot on the hero, in a wall or out of
##   every room (a doorway) is skipped; at most MAX_RUBBLE pieces on a floor.
## - V2 Dim Needle (Night Rocks): fires the Needle's burst, each shot marked DIM_LOOK; shot_dark says a shot is dark
##   while it is farther than dark_beyond_m from the hero (it lights up within, and is never dark inside it). Its hit
##   is the Needle's.
## - V3 Ember Charger (Red Canyon) / V4 Frost Charger (Frozen Shore): while the charge runs, a patch every
##   trail_step_ticks where it is (on_charge_step), lasting trail_ticks. Fire burns the hero standing in it for
##   burn_damage (its charger's tier, as every hit), at most once every burn_period_ticks however many patches overlap,
##   and only once a patch is trail_arm_ticks old (it shows that long first: the readable rule, the telegraph minimum);
##   its recap line is CAUSE_KEY. On a slick the hero slides (World's walk: slick_at, the easing toward the stick, so it
##   keeps its speed and turns slowly); enemies walk it as ground. At most MAX_TRAILS patches (the oldest goes first).
## - V5 Split Sniper (Starfall): its shot is split_lanes: the Sniper's line to split_at_permille of its reach, then
##   three lines from there (straight on and split_turn either side) to its full reach, each cut short by walls (the
##   first one cut short: no split). The telegraph draws, and the hit resolves, these very lanes (EI-07); one hit at
##   most, however many lanes touch.

const TRAIL_NONE := 0
const TRAIL_FIRE := 1
const TRAIL_SLICK := 2
const MAX_TRAILS := 96
const MAX_RUBBLE := 30
## A piece's spot stands this far past the Warden's body and the piece's own half side (m), and keeps this much room
## from the hero's body.
const PIECE_GAP_M := 0.35
const PIECE_HERO_GAP_M := 0.3
## The look key of a Dim Needle's shot (ProjectileStore.look; FireballViews draws it lit or dark by shot_dark).
const DIM_LOOK := &"dim_needle"
## The dark distance when no Dim Needle table is loaded (m; the data's starting value).
const DARK_BEYOND_M := 4.0
## A fire trail's burn (Damage.hit effect), its World.killer_attack and its recap line.
const FIRE_EFFECT := &"ember_trail"
const KILL_CAUSE := -7003
const CAUSE_KEY := &"CAUSE_EMBER_TRAIL"


static func is_variant(kind: int) -> bool:
	return kind >= ActorStore.Kind.RUBBLE_WARDEN and kind <= ActorStore.Kind.SPLIT_SNIPER


## Phase 3 (EnemyAi.think, before a frozen enemy returns): a Rubble Warden at half HP or under sheds its crust once.
static func on_think(w: World, i: int) -> void:
	var a := w.actors
	if a.kinds[i] != ActorStore.Kind.RUBBLE_WARDEN or a.hp[i] * 2 > a.max_hp[i]:
		return
	if w.variants.crusted.has(a.ids[i]):
		return
	crust_fall(w, i)


## The Rubble Warden i's crust falls: its id is marked, and up to crust_pieces rocks stand round it as walls.
static func crust_fall(w: World, i: int) -> void:
	var a := w.actors
	var v := w.variants
	v.touched = true
	v.crusted.append(a.ids[i])
	var t := w.enemy_table(a.kinds[i])
	if t == null or t.crust_pieces <= 0:
		return
	var h := t.piece_half_m
	var reach := a.radius[i] + h + PIECE_GAP_M
	for k in t.crust_pieces:
		if v.rubble_count() >= MAX_RUBBLE:
			return
		var q := a.pos(i) + Kin.dir((a.facing[i] + 512 + k * 4096 / t.crust_pieces) & 4095) * reach
		if _piece_fits(w, q, h):
			v.add_rubble(q, h)
			w.add_barrier(v.rubble_obb(v.rubble_count() - 1))


static func _piece_fits(w: World, q: Vector2, h: float) -> bool:
	if Kin.length(q - w.player_pos()) < w.player.radius_m + h * 1.42 + PIECE_HERO_GAP_M:
		return false
	if w.floor_layout != null and w.floor_layout.room_of(q) < 0:
		return false  # never in a doorway (it would shut it)
	return EnemyAi.clear_of_walls(w, q, h * 1.42)


## Whether Rubble Warden i still wears its crust (the view: its rocks on its back).
static func crust_on(w: World, i: int) -> bool:
	return (
		w.actors.kinds[i] == ActorStore.Kind.RUBBLE_WARDEN
		and not w.variants.crusted.has(w.actors.ids[i])
	)


## Phase 5 (EnemyAi.move, after the charge's step): an Ember or Frost Charger drops its patch every trail_step_ticks.
static func on_charge_step(w: World, i: int, t: EnemyTable) -> void:
	if t.trail == TRAIL_NONE or w.actors.state_t[i] % t.trail_step_ticks != 0:
		return
	var v := w.variants
	if v.trail_count() >= MAX_TRAILS:
		v.remove_trails(PackedInt32Array([0]))
	var fire := t.trail == TRAIL_FIRE
	v.add_trail(
		t.trail,
		w.actors.pos(i),
		t.trail_radius_m,
		w.tick,
		w.tick + t.trail_ticks,
		t.trail_arm_ticks if fire else 0,
		EnemyAi.powered(w, i, t.burn_damage) if fire else t.slick_permille,
		t.burn_period_ticks if fire else 0,
		w.actors.ids[i]
	)


## Phase 6 (after the mines): patches past their time go; an armed fire patch under the hero burns it.
static func advance(w: World) -> void:
	var v := w.variants
	if v.trail_count() == 0:
		return
	var gone := PackedInt32Array()
	var p := w.player_pos()
	var burn := -1
	for k in v.trail_count():
		if w.tick >= v.trail_until[k]:
			gone.append(k)
		elif burn < 0 and burning(w, k) and _covers(v, k, p, w.player.radius_m):
			burn = k
	if burn >= 0 and not w.player_dead() and w.tick >= v.burn_next:
		v.burn_next = w.tick + v.trail_period[burn]
		var c := v.trail_pos(burn)
		Damage.hit(
			w, 0, v.trail_value[burn], 0, 0, w.take_root(), SimEvent.TAG_AREA, c, p, FIRE_EFFECT
		)
		if w.player_dead():
			w.killer_attack = KILL_CAUSE  # the recap names the fire (BossCauses.key)
	v.remove_trails(gone)


## Whether trail k is fire that burns now (dropped at least its arm time ago and not gone).
static func burning(w: World, k: int) -> bool:
	var v := w.variants
	return (
		v.trail_kind[k] == TRAIL_FIRE
		and w.tick - v.trail_born[k] >= v.trail_arm[k]
		and w.tick < v.trail_until[k]
	)


static func _covers(v: VariantState, k: int, p: Vector2, r: float) -> bool:
	return Kin.length(p - v.trail_pos(k)) <= v.trail_r[k] + r * 0.5


## The hero's easing per mille a tick on a slick at `p` (the slowest one under it), or 0 when none is.
static func slick_at(w: World, p: Vector2) -> int:
	var v := w.variants
	var out := 0
	for k in v.trail_count():
		if v.trail_kind[k] == TRAIL_SLICK and w.tick < v.trail_until[k] and _covers(v, k, p, 0.0):
			out = v.trail_value[k] if out == 0 else mini(out, v.trail_value[k])
	return out


## Whether projectile k is a Dim Needle's shot still dark: farther than the Dim Needle's dark_beyond_m from the hero.
static func shot_dark(w: World, k: int) -> bool:
	var pr := w.projectiles
	if pr.look_of(k) != String(DIM_LOOK):
		return false
	var t := w.enemy_table(ActorStore.Kind.DIM_NEEDLE)
	var dark := t.dark_beyond_m if t != null else DARK_BEYOND_M
	return Kin.length(Vector2(pr.pos_x[k], pr.pos_y[k]) - w.player_pos()) > dark


## A Split Sniper's shot (i): the line to the split, then its three branches (none when the first is cut short).
static func split_lanes(w: World, i: int) -> Array[Obb]:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var aim := a.lock_a[i]
	var r := t.lane_half_m
	var start := Vector2(a.lock_x[i], a.lock_y[i]) + Kin.dir(aim) * a.radius[i]
	var first := t.reach_m * t.split_at_permille / 1000.0
	var run := EnemyAi.clear_run(w, start, aim, first, r)
	var out: Array[Obb] = [AttackShapes.lane(start, aim, maxf(run, 0.01), r)]
	if run < first - 0.001:
		return out
	var mid := start + Kin.dir(aim) * first
	var rest := t.reach_m - first
	for turn in [-t.split_turn, 0, t.split_turn]:
		var ang: int = (aim + turn) & 4095
		out.append(
			AttackShapes.lane(mid, ang, maxf(EnemyAi.clear_run(w, mid, ang, rest, r), 0.01), r)
		)
	return out
