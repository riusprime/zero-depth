class_name Ascension
extends RefCounted
## v0.7.5 AP (owner N4: "a feature like the blue portal but a new one … that fits the word ascension … end the run
## or you can choose to start over … the infinity loop"). On a run's last floor of a loop the boss room's gate is the
## Ascension portal (BossFlow.ascension, set by RunState.prepare). It opens with the boss's death like any gate;
## walking into its opening opens the choice (BossFlow.ascend_open) and the world waits, as it does for an event's
## panel (World.step). The choice arrives as input (InputFrame.pick):
## - PICK_END (1): End the run. The hero goes in (the portal transit) and the run is won (WorldReader.outcome 1).
## - PICK_ASCEND (2): Ascend. The hero goes in and the floor ends (outcome 3); RunState.finish_floor starts the next
##   loop at its floor 1 with the build carried (RunCarry), harder (RunState.loop_permille, World.loop_threat,
##   World.loop_cap_permille).
## - InputFrame.PICK_CANCEL: Not yet. The choice closes and stays closed until the hero leaves the opening and walks
##   in again (BossFlow.ascend_declined).
## Any other pick is ignored while the choice is open. Pure: no stream is drawn here.

## Appended, never inserted: BossFlow.ascend_choice is hashed and saved.
enum Choice { NONE, END, ASCEND }

const PICK_END := 1
const PICK_ASCEND := 2


## The choice is open: the world waits for it (World.step).
static func waiting(w: World) -> bool:
	return w.boss_flow != null and w.boss_flow.ascend_open


## While the choice is open: the tick's pick answers it.
static func choose(w: World, frame: InputFrame) -> void:
	var bf := w.boss_flow
	match frame.pick:
		PICK_END:
			bf.enter_ascension(w, Choice.END)
		PICK_ASCEND:
			bf.enter_ascension(w, Choice.ASCEND)
		InputFrame.PICK_CANCEL:
			bf.ascend_open = false
			bf.ascend_declined = true


## The floor `w` was left by Ascend (the next floor is the next loop's first).
static func ascended(w: World) -> bool:
	return (
		w.boss_flow != null and w.boss_flow.ascension and w.boss_flow.ascend_choice == Choice.ASCEND
	)


## The floor `w` was left by End the run (the run is won).
static func ended(w: World) -> bool:
	return w.boss_flow != null and w.boss_flow.ascension and w.boss_flow.ascend_choice == Choice.END
