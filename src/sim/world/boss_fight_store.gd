class_name BossFightStore
extends RefCounted
## The state of the bosses' fight mechanics, one self-contained block per mechanic, each owned by that mechanic's
## code: the Clockwork Judge's time and gears, the Tidecaller's dance, the charge bursts, the Twin Wardens' clocks,
## the Siege Engine's siege and boulders, the Foundry's forge and slabs, and The Fallen's remembered mechanics.
## BossStore keeps the live bosses' own entries and the older signature pieces; these blocks live apart because
## none of them is per boss entry and each is read and written by one mechanic only, so a new boss's mechanic adds its
## block here without growing BossStore.
## Hashed (World.state_hash) right after BossStore, each block only while its mechanic runs.

## The stopped gears' parallel arrays (BossGears), by type.
const GEAR_INT_FIELDS: Array[StringName] = [&"gear_a", &"gear_from", &"gear_until", &"gear_boss"]
const GEAR_FLOAT_FIELDS: Array[StringName] = [&"gear_x", &"gear_y", &"gear_hx", &"gear_hy"]
## The time mechanics' clocks (BossTime, BossRewind).
const TIME_FIELDS: Array[StringName] = [
	&"time_boss",
	&"time_wave_due",
	&"time_field_due",
	&"time_bell_due",
	&"time_bell_from",
	&"time_bell_at",
	&"time_tolls",
	&"time_back",
	&"time_bv_at"
]
## The dance's clocks (BossDance, BossMaelstrom, BossTideBeats).
const DANCE_FIELDS: Array[StringName] = [
	&"dance_boss",
	&"dance_rip_from",
	&"dance_rip_n",
	&"dance_rip_mirror",
	&"dance_rip_hit",
	&"dance_rip_warn",
	&"dance_ht_from",
	&"dance_spin",
	&"dance_grace",
	&"dance_throw",
	&"dance_beat_phase",
	&"dance_beat_k",
	&"dance_beat_at",
	&"dance_beat_run",
	&"dance_beat_end"
]
## The charge bursts pending (BossChargeBurst), by type.
const CB_INT_FIELDS: Array[StringName] = [&"cb_boss", &"cb_attack", &"cb_at"]
const CB_FLOAT_FIELDS: Array[StringName] = [&"cb_x", &"cb_y"]
## The Twin Wardens' clocks (BossWardens, BossWard, BossWardenAmber, BossRift).
const WD_FIELDS: Array[StringName] = [
	&"wd_boss",
	&"wd_mirror_until",
	&"wd_break_at",
	&"wd_push_tick",
	&"wd_mirror_a",
	&"wd_mirror_on",
	&"wd_full",
	&"wd_dash_cd",
	&"wd_dash_t",
	&"wd_dash_side",
	&"wd_rift_stage",
	&"wd_rift_at",
	&"wd_rift_in",
	&"wd_rift_out",
	&"wd_rift_done"
]
const WD_FLOAT_FIELDS: Array[StringName] = [&"wd_dash_vx", &"wd_dash_vy", &"wd_aim_x", &"wd_aim_y"]
## The siege mechanics' clocks (BossSiege, BossDoom).
const SIEGE_FIELDS: Array[StringName] = [
	&"sg_boss",
	&"sg_lock_due",
	&"sg_lock_from",
	&"sg_landed",
	&"sg_held",
	&"sg_doom_phase",
	&"sg_doom_n",
	&"sg_doom_due",
	&"sg_cart",
	&"sg_cart_from",
	&"sg_doom_at",
	&"sg_strip_until",
	&"sg_next"
]
const SIEGE_FLOAT_FIELDS: Array[StringName] = [
	&"sg_lock_x", &"sg_lock_y", &"sg_cart_ax", &"sg_cart_ay", &"sg_cart_bx", &"sg_cart_by"
]
## The boulders' parallel arrays (BossSiege), by type.
const BOULDER_INT_FIELDS: Array[StringName] = [
	&"sg_b_id", &"sg_b_from", &"sg_b_until", &"sg_b_boss"
]
const BOULDER_FLOAT_FIELDS: Array[StringName] = [&"sg_b_x", &"sg_b_y", &"sg_b_h"]
## The forge's clocks (BossForge, BossSlag), with the value each takes when the forge is forgotten.
const FORGE_FIELDS := {
	&"fg_boss": -1,
	&"fg_plate_due": -1,
	&"fg_cast_from": -1,
	&"fg_plate": 0,
	&"fg_exposed_until": 0,
	&"fg_drone_at": -1,
	&"fg_over_due": -1,
	&"fg_over_from": -1,
	&"fg_over_step": -1,
	&"fg_drop_at": -1,
	&"fg_scald": 0,
	&"fg_scald_at": -1,
	&"fg_burning": 0,
	&"fg_slab_next": 0,
}
const SLAB_INT_FIELDS: Array[StringName] = [
	&"slab_id", &"slab_boss", &"slab_from", &"slab_until", &"slab_broke"
]
const SLAB_FLOAT_FIELDS: Array[StringName] = [&"slab_x", &"slab_y", &"slab_r"]
## The Fallen's remembered mechanics (BossRemembered, FallenTime, FallenRiptide, FallenQuake, FallenWard), with the
## value each takes when they are forgotten; the Riptide row they share with the dance is hashed with them too.
const FALLEN_FIELDS := {
	&"fl_boss": -1,
	&"fl_kind": 0,
	&"fl_stage": 0,
	&"fl_from": -1,
	&"fl_end": -1,
	&"fl_open": -1,
	&"fl_next": -1,
	&"fl_gates": 0,
	&"fl_last": 0,
	&"fl_n": 0,
	&"fl_delay": 0,
	&"fl_dash_at": -1,
	&"fl_hit_at": -1,
	&"fl_ward": 0,
	&"fl_stun_until": -1,
	&"fl_sh_stage": 0,
	&"fl_sh_at": -1,
	&"fl_sh_n": 0,
	&"fl_sh_a": 0,
	&"fl_sh_hit": 0,
	&"fl_bu_at": -1,
}
const FALLEN_FLOAT_FIELDS: Array[StringName] = [
	&"fl_r",
	&"fl_hit_x",
	&"fl_hit_y",
	&"fl_sh_x",
	&"fl_sh_y",
	&"fl_sh_ox",
	&"fl_sh_oy",
	&"fl_sh_len",
	&"fl_bu_x",
	&"fl_bu_y"
]
const RIP_FIELDS: Array[StringName] = [
	&"dance_rip_from", &"dance_rip_n", &"dance_rip_mirror", &"dance_rip_hit", &"dance_rip_warn"
]

## The Clockwork Judge's time mechanics (BossTime, BossRewind). time_boss is the Judge that runs them (-1 = none);
## time_wave_due the tick its next Time Wave may be cast (-1 = not set yet) and time_field_due its next slow field's
## (-1 = not in its phase yet). The Bell: time_bell_due the tick its next cast begins (-1 = no Rewind yet),
## time_bell_from the tick the wait for the toll pending began and time_bell_at the tick it tolls (-1 = none
## pending), time_tolls the tolls that follow it. time_back is 1 once the Judge has returned to its own past.
## The Bell's Verdict locked at a toll: time_bv_at the tick it drops (-1 = none), time_bv_x/time_bv_y its centre.
## time_px/time_py: where the hero stood, oldest first, one point every BossTimeTable.step_ticks (the pale copy's
## trail); time_bx/time_by the Judge's own. Hashed only while a Judge runs them or a gear stands.
var time_boss := -1
var time_wave_due := -1
var time_field_due := -1
var time_bell_due := -1
var time_bell_from := -1
var time_bell_at := -1
var time_tolls := 0
var time_back := 0
var time_bv_at := -1
var time_bv_x := 0.0
var time_bv_y := 0.0
var time_px := PackedFloat32Array()
var time_py := PackedFloat32Array()
var time_bx := PackedFloat32Array()
var time_by := PackedFloat32Array()
## The stopped gears, oldest first (BossGears): each a wall while it stands (World.walls, as a barrier): its centre,
## half length and half width (m), its angle (1/4096 turns, along its length), the tick it rose, the tick it goes
## and its boss.
var gear_x := PackedFloat32Array()
var gear_y := PackedFloat32Array()
var gear_hx := PackedFloat32Array()
var gear_hy := PackedFloat32Array()
var gear_a := PackedInt32Array()
var gear_from := PackedInt32Array()
var gear_until := PackedInt32Array()
var gear_boss := PackedInt32Array()
## The Tidecaller's dance (BossDance, BossMaelstrom). dance_boss is the boss that runs it (-1 = none). Riptide:
## dance_rip_from the tick the cast running now began its warning (-1 = no row runs), dance_rip_n that cast's place
## in the row, dance_rip_mirror 1 when the row's safe strips are the mirrored order, dance_rip_hit 1 once this cast's
## wave has hit, dance_rip_warn this cast's warning (ticks). High Tide: dance_ht_from the tick the one running began
## its cast (-1 = none) and dance_ht_x/dance_ht_y its dry circle's centre. The Maelstrom: dance_spin the way it turns
## (1 or -1; 0 = not begun), dance_grace the tick its eye may hurt again and dance_throw the ticks left of a throw out
## of the eye. The rhythm (BossTideBeats): dance_beat_phase the phase its order is for (-1 = none yet),
## dance_beat_k the beats begun in it, dance_beat_at the tick the next may begin (-1 = after the one running),
## dance_beat_run the big mechanic running (BossTideBeats.NONE, PULL, RIPTIDE, HIGH_TIDE) and dance_beat_end the tick
## the last one ended (-1 = none yet). Hashed only while a boss runs it.
var dance_boss := -1
var dance_rip_from := -1
var dance_rip_n := 0
var dance_rip_mirror := 0
var dance_rip_hit := 0
var dance_rip_warn := 0
var dance_ht_from := -1
var dance_spin := 0
var dance_grace := 0
var dance_throw := 0
var dance_beat_phase := -1
var dance_beat_k := 0
var dance_beat_at := -1
var dance_beat_run := 0
var dance_beat_end := -1
var dance_ht_x := 0.0
var dance_ht_y := 0.0
## The bursts a charge leaves where it ends (BossChargeBurst), oldest first: [the boss that charged, its attack (the
## burst's size, damage and recap line), the tick it bursts, its centre]. Hashed only while one is pending.
var cb_boss := PackedInt32Array()
var cb_attack := PackedInt32Array()
var cb_at := PackedInt32Array()
var cb_x := PackedFloat32Array()
var cb_y := PackedFloat32Array()
## The Twin Wardens' own clocks. wd_boss is the amber Warden that runs them (-1 = none). The Mirror Ward:
## wd_mirror_until the tick it ends (-1 = none), wd_mirror_a the way it faces, wd_mirror_on 1 while it stands (its
## end is told once), wd_push_tick the tick it last pushed the hero back. The last phase's ward: wd_full 1 while it
## stands, wd_break_at the tick a charge broke it (-1 = never). The amber Warden's side dash: wd_dash_cd the ticks
## until the next, wd_dash_t the ticks left of the one running, wd_dash_side the side the next one tries first,
## wd_dash_vx/wd_dash_vy its step a tick. Through the Rift: wd_rift_stage (BossRift's stages, 0 = none), wd_rift_at
## the tick the stage began, wd_rift_in and wd_rift_out the rifts it enters and leaves by (-1 = not chosen),
## wd_rift_done 1 once it has been cast, wd_rift_x/wd_rift_y the rifts' centres, wd_aim_x/wd_aim_y where the hero
## stood when the exit was marked. Hashed only while a pair of Wardens runs them.
var wd_boss := -1
var wd_mirror_until := -1
var wd_break_at := -1
var wd_push_tick := -1
var wd_mirror_a := 0
var wd_mirror_on := 0
var wd_full := 0
var wd_dash_cd := 0
var wd_dash_t := 0
var wd_dash_side := 0
var wd_rift_stage := 0
var wd_rift_at := 0
var wd_rift_in := -1
var wd_rift_out := -1
var wd_rift_done := 0
var wd_dash_vx := 0.0
var wd_dash_vy := 0.0
var wd_aim_x := 0.0
var wd_aim_y := 0.0
var wd_rift_x := PackedFloat32Array()
var wd_rift_y := PackedFloat32Array()
## The Siege Engine's siege (BossSiege, BossDoom). sg_boss is the boss that runs it (-1 = none). The Target Lock:
## sg_lock_due the tick the next may begin (-1 = not in its phase yet), sg_lock_from the tick the one running began
## (-1 = none) and sg_lock_x/sg_lock_y its circle's centre now; sg_landed the tick a shell last landed (-1 = none yet).
## sg_held the tick a Shockwave was first held for want of cover (-1 = none held). The Doom Shell: sg_doom_phase the
## phase its carts are counted in (-1 = none yet), sg_doom_n the carts sent in it, sg_doom_due the tick the next may
## roll; sg_cart the cart's actor id (-1 = none, or queued this tick), sg_cart_from the tick it set off (-1 = no cart
## out), sg_cart_ax/ay where it set off and sg_cart_bx/by where it arrives; sg_doom_at the tick the Doom Shell fires
## (-1 = none pending); sg_strip_until the tick the boss's armour comes back (0 = never stripped). sg_next: the next
## boulder id. Hashed only while a boss runs it or a boulder stands.
var sg_boss := -1
var sg_lock_due := -1
var sg_lock_from := -1
var sg_landed := -1
var sg_held := -1
var sg_doom_phase := -1
var sg_doom_n := 0
var sg_doom_due := -1
var sg_cart := -1
var sg_cart_from := -1
var sg_doom_at := -1
var sg_strip_until := 0
var sg_next := 0
var sg_lock_x := 0.0
var sg_lock_y := 0.0
var sg_cart_ax := 0.0
var sg_cart_ay := 0.0
var sg_cart_bx := 0.0
var sg_cart_by := 0.0
## The boulders, oldest first (BossSiege): each a wall while it stands (World.walls, as a barrier): its id, the tick
## it landed, the tick it crumbles and its boss, its centre and half side (m).
var sg_b_id := PackedInt32Array()
var sg_b_from := PackedInt32Array()
var sg_b_until := PackedInt32Array()
var sg_b_boss := PackedInt32Array()
var sg_b_x := PackedFloat32Array()
var sg_b_y := PackedFloat32Array()
var sg_b_h := PackedFloat32Array()
## The Foundry's forge (BossForge, BossSlag). fg_boss is the boss that runs it (-1 = none). The plate: fg_plate_due
## the tick the next forging may begin (-1 = not in its phase yet), fg_cast_from the tick the forging running began
## (-1 = none), fg_plate 1 while worn, fg_exposed_until the tick its exposure after a blow ends, fg_drone_at the tick
## it last launched a drone for the plate (-1 = never). Overpressure: fg_over_due the tick the next may begin (-1 = not
## in its phase yet), fg_over_from the tick the one running began its cast (-1 = none), fg_over_step the tick of its
## burn's next step (-1 = the burn has not begun); fg_drop_at the tick it last dropped a pool so the slabs never run
## out (-1 = never). The scald gauge: fg_scald
## (0..scald_max), fg_scald_at the tick of its next step (-1 = not in its phase yet), fg_burning 1 while full.
## fg_slab_next is the next slab_id.
var fg_boss := -1
var fg_plate_due := -1
var fg_cast_from := -1
var fg_plate := 0
var fg_exposed_until := 0
var fg_drone_at := -1
var fg_over_due := -1
var fg_over_from := -1
var fg_over_step := -1
var fg_drop_at := -1
var fg_scald := 0
var fg_scald_at := -1
var fg_burning := 0
var fg_slab_next := 0
## The slabs the boss's pools cooled into, oldest first: [slab_id, its boss, the tick it cooled, the tick it crumbles,
## the tick a vent blast shattered it (0 = whole), its centre and radius].
var slab_id := PackedInt32Array()
var slab_boss := PackedInt32Array()
var slab_from := PackedInt32Array()
var slab_until := PackedInt32Array()
var slab_broke := PackedInt32Array()
var slab_x := PackedFloat32Array()
var slab_y := PackedFloat32Array()
var slab_r := PackedFloat32Array()
## The Fallen's remembered mechanics (BossRemembered). fl_boss is The Fallen that runs them (-1 = none); fl_r the
## radius of the room it fights in (m, measured as it took them). The rhythm: fl_kind the mechanic cast or running
## (BossRemembered.NONE, TIME, RIPTIDE, QUAKE, WARD), fl_stage 0 none, 1 its cast, 2 it runs, since fl_from; fl_end
## the tick the last one ended (-1 = none yet), fl_open the first tick one may be cast, fl_next the tick the next is
## due by the clock, fl_gates a bit for each HP gate already cast, fl_last the last kind cast, fl_n the mechanics
## begun; fl_delay the ticks the mimic windows have waited for them. The quake: fl_dash_at the tick the next dash at
## the hero is asked for, fl_hit_at the tick a dash reaches the pillar at fl_hit_x/fl_hit_y (-1 = none). The ward:
## fl_ward 1 while it stands, fl_stun_until the tick the stun of its break ends (-1 = none); the shade: fl_sh_stage
## (0 none, 1 winding up, 2 running, 3 waiting) since fl_sh_at, fl_sh_n its charges begun, fl_sh_x/fl_sh_y where it
## stands, fl_sh_ox/fl_sh_oy where its run began, fl_sh_a its aim (1/4096 turns), fl_sh_len its run's length, fl_sh_hit
## 1 once its touch hit this charge; its burst at fl_bu_x/fl_bu_y on tick fl_bu_at (-1 = none armed). fl_beaten: the
## bosses (content ids) killed in the run before this world (RunState.bosses_beaten; setup). Hashed only while a Fallen
## runs them.
var fl_boss := -1
var fl_kind := 0
var fl_stage := 0
var fl_from := -1
var fl_end := -1
var fl_open := -1
var fl_next := -1
var fl_gates := 0
var fl_last := 0
var fl_n := 0
var fl_delay := 0
var fl_dash_at := -1
var fl_hit_at := -1
var fl_ward := 0
var fl_stun_until := -1
var fl_sh_stage := 0
var fl_sh_at := -1
var fl_sh_n := 0
var fl_sh_a := 0
var fl_sh_hit := 0
var fl_bu_at := -1
var fl_r := 0.0
var fl_hit_x := 0.0
var fl_hit_y := 0.0
var fl_sh_x := 0.0
var fl_sh_y := 0.0
var fl_sh_ox := 0.0
var fl_sh_oy := 0.0
var fl_sh_len := 0.0
var fl_bu_x := 0.0
var fl_bu_y := 0.0
var fl_beaten := PackedStringArray()


func hash_into(h: StateHasher) -> void:
	if time_boss >= 0 or not gear_x.is_empty():  # Only while a Judge runs its time mechanics or a gear stands
		h.add_int(-11)
		for f: StringName in TIME_FIELDS:
			h.add_int(get(f))
		for f: StringName in GEAR_INT_FIELDS:
			h.add_ints(get(f))
		for f: StringName in GEAR_FLOAT_FIELDS + [&"time_px", &"time_py", &"time_bx", &"time_by"]:
			h.add_f32s(get(f))
		h.add_f32s(PackedFloat32Array([time_bv_x, time_bv_y]))
	if dance_boss >= 0:  # Only while a boss runs its dance
		h.add_int(-14)
		for f: StringName in DANCE_FIELDS:
			h.add_int(get(f))
		h.add_f32s(PackedFloat32Array([dance_ht_x, dance_ht_y]))
	if wd_boss >= 0 or not cb_boss.is_empty():  # Only while the Wardens fight or a charge's burst is pending
		h.add_int(-15)
		for f: StringName in WD_FIELDS:
			h.add_int(get(f))
		for f: StringName in WD_FLOAT_FIELDS:
			h.add_f32(get(f))
		for f: StringName in CB_INT_FIELDS:
			h.add_ints(get(f))
		for f: StringName in CB_FLOAT_FIELDS + [&"wd_rift_x", &"wd_rift_y"]:
			h.add_f32s(get(f))
	if sg_boss >= 0 or not sg_b_x.is_empty():  # Only while a boss runs its siege or a boulder stands
		h.add_int(-21)
		for f: StringName in SIEGE_FIELDS:
			h.add_int(get(f))
		for f: StringName in SIEGE_FLOAT_FIELDS:
			h.add_f32(get(f))
		for f: StringName in BOULDER_INT_FIELDS:
			h.add_ints(get(f))
		for f: StringName in BOULDER_FLOAT_FIELDS:
			h.add_f32s(get(f))
	if fg_boss >= 0 or not slab_id.is_empty():  # Only while a boss runs its forge or a slab lies
		h.add_int(-22)
		for f: StringName in FORGE_FIELDS:
			h.add_int(get(f))
		for f: StringName in SLAB_INT_FIELDS:
			h.add_ints(get(f))
		for f: StringName in SLAB_FLOAT_FIELDS:
			h.add_f32s(get(f))
	if fl_boss >= 0:  # Only while a Fallen runs its remembered mechanics
		h.add_int(-23)
		for f: StringName in FALLEN_FIELDS:
			h.add_int(get(f))
		for f: StringName in RIP_FIELDS:
			h.add_int(get(f))
		for f: StringName in FALLEN_FLOAT_FIELDS:
			h.add_f32(get(f))
		h.add_int(fl_beaten.size())
		for id in fl_beaten:
			h.add_string(id)


## Removes stopped gear k (the arrays stay oldest first).
func remove_gear(k: int) -> void:
	BossStore.remove_row(self, GEAR_INT_FIELDS, GEAR_FLOAT_FIELDS, k)


## Forgets the time mechanics' clocks and trails (their Judge gone); the gears go through BossGears.
func clear_time() -> void:
	for f: StringName in TIME_FIELDS:
		set(f, -1)
	time_tolls = 0
	time_back = 0
	time_bv_x = 0.0
	time_bv_y = 0.0
	for f: StringName in [&"time_px", &"time_py", &"time_bx", &"time_by"]:
		set(f, PackedFloat32Array())


## Removes pending charge burst k (the arrays stay oldest first).
func remove_burst(k: int) -> void:
	BossStore.remove_row(self, CB_INT_FIELDS, CB_FLOAT_FIELDS, k)


## Forgets the Twin Wardens' clocks (the pair gone).
func clear_wardens() -> void:
	for f: StringName in WD_FIELDS:
		set(f, 0)
	for f: StringName in WD_FLOAT_FIELDS:
		set(f, 0.0)
	for f: StringName in [
		&"wd_boss",
		&"wd_mirror_until",
		&"wd_break_at",
		&"wd_push_tick",
		&"wd_rift_in",
		&"wd_rift_out"
	]:
		set(f, -1)
	wd_rift_x = PackedFloat32Array()
	wd_rift_y = PackedFloat32Array()


## Forgets the dance's clocks (its boss gone).
func clear_dance() -> void:
	for f: StringName in DANCE_FIELDS:
		set(f, 0)
	for f: StringName in [
		&"dance_boss",
		&"dance_rip_from",
		&"dance_ht_from",
		&"dance_beat_phase",
		&"dance_beat_at",
		&"dance_beat_end"
	]:
		set(f, -1)
	dance_ht_x = 0.0
	dance_ht_y = 0.0


## Removes boulder k (the arrays stay oldest first).
func remove_boulder(k: int) -> void:
	BossStore.remove_row(self, BOULDER_INT_FIELDS, BOULDER_FLOAT_FIELDS, k)


## Forgets the siege's clocks (its boss gone); the boulders and the cart go through BossSiege and BossDoom.
func clear_siege() -> void:
	for f: StringName in SIEGE_FIELDS:
		set(f, -1)
	sg_doom_n = 0
	sg_strip_until = 0
	sg_next = 0
	for f: StringName in SIEGE_FLOAT_FIELDS:
		set(f, 0.0)


## Removes slab k (the arrays stay oldest first).
func remove_slab(k: int) -> void:
	BossStore.remove_row(self, SLAB_INT_FIELDS, SLAB_FLOAT_FIELDS, k)


## Forgets the forge's clocks and its slabs (its boss gone).
func clear_forge() -> void:
	for f: StringName in FORGE_FIELDS:
		set(f, FORGE_FIELDS[f])
	for f: StringName in SLAB_INT_FIELDS:
		set(f, PackedInt32Array())
	for f: StringName in SLAB_FLOAT_FIELDS:
		set(f, PackedFloat32Array())


## Forgets The Fallen's remembered mechanics (its body gone); the bosses beaten stay (the run's).
func clear_fallen() -> void:
	for f: StringName in FALLEN_FIELDS:
		set(f, FALLEN_FIELDS[f])
	for f: StringName in FALLEN_FLOAT_FIELDS:
		set(f, 0.0)
