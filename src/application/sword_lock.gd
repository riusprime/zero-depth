class_name SwordLock
extends RefCounted
## v0.9.5 SL (G11, owner Q15 a): the sword (Blade) is locked from the start for every profile, the owner's too (like the
## Void was before a Purple Portal). Beating the Hollow Crown with the Gun earns the "Sword Unbound" achievement
## (AchievementTracker: the stat `final:won_gun`), and that achievement IS the unlock: the profile's `achievements`
## section holds it, so it survives save and load with nothing else stored. A profile that earned it before this step
## (none can have) reads as unlocked. A run in progress keeps its build whatever the lock says (RunState.build_id).
## Only the build picker and the default pick read this; the sim and the dev tools (Playground) never do.

const ACHIEVEMENT := &"sword_unbound"
const BLADE := &"blade"
const GUN := &"gun"
## The condition line the build picker shows on the padlocked Blade.
const CONDITION_KEY := &"BUILD_BLADE_LOCKED"


static func is_unlocked(profile: ProfileStore) -> bool:
	return AchievementStore.new(profile).is_unlocked(ACHIEVEMENT)


## Unlocks the Blade without playing for it (the e2e helper, the dev path); true the first time.
static func grant(profile: ProfileStore) -> bool:
	return AchievementStore.new(profile).unlock(ACHIEVEMENT)


## The builds the picker shows padlocked: {build id: condition tr key}; empty once unlocked.
static func locked_builds(profile: ProfileStore) -> Dictionary:
	return {} if is_unlocked(profile) else {BLADE: CONDITION_KEY}


## The build to pick by default: the remembered one, or the Gun while that is the locked Blade.
static func usable(profile: ProfileStore, id: StringName) -> StringName:
	return GUN if id == BLADE and not is_unlocked(profile) else id
