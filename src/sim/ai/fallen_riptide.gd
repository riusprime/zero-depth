class_name FallenRiptide
extends RefCounted
## The Tidecaller's Riptide as The Fallen remembers it (BossRemembered): one row of the table's rip_casts casts on the
## four strips of the square round the fight's room (BossDance.start_row and run_row, the Tidecaller's own row: the
## written safe order or its mirror, each warning never shorter than the hero's walk to its safe strip, the share of
## max HP in a struck strip, the recap's line the carrier fallen_riptide). It ends with the row's last wave. The
## row's state is the dance's (BossFightStore.dance_rip_*), hashed with The Fallen's block.
## Pure: the ai stream only (the row's mirror, through BossDance).


static func begin(w: World, i: int, m: FallenRememberedTable) -> bool:
	BossDance.start_row(w, i, m.dance, BossRemembered.room_of(w))
	return true


static func step(w: World, i: int, m: FallenRememberedTable) -> bool:
	return BossDance.run_row(w, i, m.dance, BossRemembered.room_of(w))


static func finish(w: World) -> void:
	if w.boss_fight.dance_boss < 0:
		w.boss_fight.dance_rip_from = -1


## WorldReader.boss_dance when no Tidecaller dances: {} unless The Fallen runs its Riptide; else BossDance.state's
## shape for its row ("boss", "room", "along_x", "strips", "riptide", no High Tide or Maelstrom, "beats" with the row
## running).
static func dance_state(w: World) -> Dictionary:
	var fs := w.boss_fight
	var m := BossRemembered.table_of(w)
	var i := w.actors.index_of(fs.fl_boss) if fs.fl_boss >= 0 else -1
	if (
		i < 0
		or m == null
		or fs.fl_kind != BossRemembered.RIPTIDE
		or fs.fl_stage != BossRemembered.STAGE_RUN
		or fs.dance_rip_from < 0
	):
		return {}
	var room := BossRemembered.room_of(w)
	return {
		"boss": i,
		"room": room,
		"along_x": SafeArea.runs_along_x(room),
		"strips": SafeArea.strips(room, BossDanceTable.STRIPS),
		"riptide": BossDance.riptide_state(w, m.dance, room),
		"riptide_in": -1,
		"high_tide": {},
		"high_tide_in": -1,
		"maelstrom": {},
		"beats":
		{
			"running": BossTideBeats.RIPTIDE,
			"next": BossTideBeats.NONE,
			"in": -1,
			"held": true,
			"order": PackedInt32Array([BossTideBeats.RIPTIDE]),
		},
	}
