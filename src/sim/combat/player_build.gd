class_name PlayerBuild
extends RefCounted
## The run's starting build in the sim (v0.3.0 PLAN L15, L16, L29): which weapon answers its button, that weapon's
## damage factor, and the way melee swings go.
## - Blade runs swing (PRIMARY) and never shoot; Gun runs shoot (SHOOT held) and never swing. A press of the
##   missing weapon's button is dropped (it does nothing, now or later).
## - Damage: base x per mille / 1000 with the remainder carried to the next hit of that weapon, so the average is
##   exact (Gun 4 x 850 = 3.4: 3, 3, 4, 3, 4 ...). Full damage (1000) leaves numbers untouched.
## - Melee goes along the character's facing (the last move direction; the aim before the first move); shots go
##   along the aim (L29: "Sword should be used towards where the character is looking, shooting towards the aimed
##   with the other joystick").


static func has_blade(w: World) -> bool:
	return (w.player.weapons & PlayerTable.WEAPON_BLADE) != 0


static func has_gun(w: World) -> bool:
	return (w.player.weapons & PlayerTable.WEAPON_GUN) != 0


## Tick phase 2: moving turns the character (the facing keeps the last move direction when you stop).
static func note_facing(w: World) -> void:
	if w.move_intent != Vector2i.ZERO and not w.player_dead():
		w.build_state.facing_angle = Kin.angle_of(Vector2(w.move_intent.x, w.move_intent.y))


## The angle a swing starting now takes: the facing, or the aim before the first move. The hit (PlayerKit) and the
## blade view (WorldReader.swing_angle, locked at the start) read the same number (EI-07).
static func melee_angle(w: World) -> int:
	return w.build_state.facing_angle if w.build_state.facing_angle >= 0 else w.aim_angle


## A swing's damage under the build (the melee remainder carries over).
static func melee_damage(w: World, base: int) -> int:
	var pm := w.player.melee_damage_permille * Abilities.weapon_permille(w) / 1000  # v0.4.0: Combo Sword level
	if pm == 1000:
		return base
	var total := base * pm + w.build_state.melee_residue
	w.build_state.melee_residue = total % 1000
	return total / 1000


## A shot's damage per bolt under the build (the bolt remainder carries over, once per shot).
static func bolt_damage(w: World, base: int) -> int:
	var pm := w.player.bolt_damage_permille * Abilities.weapon_permille(w) / 1000  # v0.4.0: Pulse Gun level
	if pm == 1000:
		return base
	var total := base * pm + w.build_state.bolt_residue
	w.build_state.bolt_residue = total % 1000
	return total / 1000


## Whether the build and regen state is in the hash: once a build is chosen, the world has a loadout (enemies or
## items), or any of it left its default. Worlds without any of it (the kernel goldens) keep their hash.
static func touched(w: World) -> bool:
	return (
		w.player.weapons != PlayerTable.WEAPONS_ALL
		or not w.enemy_tables.is_empty()
		or not w.item_tables.is_empty()
		or w.regen_bonus_permille != 0
		or w.build_state.touched()
	)


## state_hash: the build and regen state, once touched.
static func hash_into(w: World, h: StateHasher) -> void:
	if not touched(w):
		return
	var t := w.player
	var s := w.build_state
	for v in [t.weapons, t.melee_damage_permille, t.bolt_damage_permille, s.facing_angle]:
		h.add_int(v)
	for v in [s.melee_residue, s.bolt_residue, s.combat_tick, s.regen_acc, s.regen_tick]:
		h.add_int(v)
	h.add_int(w.regen_bonus_permille)


## The reads the views need (WorldReader.player_build): has_blade, has_gun, facing (the melee angle now),
## regenerating (PlayerRegen.active), regen_tick (the last tick regen healed, -1 = never).
static func read(w: World) -> Dictionary:
	return {
		"has_blade": has_blade(w),
		"has_gun": has_gun(w),
		"facing": melee_angle(w),
		"regenerating": PlayerRegen.active(w),
		"regen_tick": w.build_state.regen_tick,
	}
