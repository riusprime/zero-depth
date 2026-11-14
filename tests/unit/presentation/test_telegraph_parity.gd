extends GutTest
## PRESENTATION §4 / EI-07: the drawn telegraph is the hit area. For each attack, a player standing just inside
## the drawn shape (grown by the player's radius) is hit, and one just outside is not.

const S := EnemyAi.State
const EPS := 0.03


## Puts actor i into its windup with a fixed lock along angle 0 (as the native think starts it: _windup), the player at
## `at`, and runs the attack out. Returns the damage the player took.
func _attack(kind: int, at: Vector2) -> Array:
	var w := CombatLab.world()
	var id := w.add_enemy(kind, Vector2.ZERO)
	var i := w.actors.index_of(id)
	w.actors.invuln[i] = 0
	w.actors.set_pos(0, at)
	w.enemy_tables[kind].charge_turn = 0  # the drawn lane is the windup's; a steered charge has its own test
	_windup(w, i)
	var tg := EnemyAi.telegraph(w, i)
	w.actors.state_t[i] = 0
	for k in 200:
		w.actors.set_pos(0, at)  # the player stands still
		var j := w.actors.index_of(id)
		if j >= 0 and w.actors.state[j] == S.WINDUP:
			tg = EnemyAi.telegraph(w, j)  # v0.3.5 AI: aimed windups track; the last drawn shape is the hit
		w.step(InputFrame.new())
		if w.actors.index_of(id) < 0 or w.actors.state[w.actors.index_of(id)] == S.RECOVER:
			break
	CombatLab.idle(w, 120)
	return [CombatLab.player_damage(w), tg]


func _inside_lane(tg: Dictionary, p: Vector2, r: float) -> bool:
	var lanes: Array = tg["obbs"] if tg.has("obbs") else [tg["obb"]]
	for o: Obb in lanes:
		if Collide.circle_vs_obb(p, r - 0.0001, o) != Vector2.ZERO:
			return true
	return false


func test_charger_lane() -> void:
	var pr := PlayerTable.starting_values().radius_m
	var cr := CombatLab.world().enemy_table(ActorStore.Kind.CHARGER).radius_m  # by kind: ids sort A-Z
	for d in [cr + pr - EPS, cr + pr + EPS, 0.0, 2.0]:
		var got := _attack(ActorStore.Kind.CHARGER, Vector2(4, d))
		var drawn := _inside_lane(got[1], Vector2(4, d), pr)
		assert_eq(got[0].size() > 0, drawn, "lateral %.2f: hit iff inside the drawn lane" % d)


func test_warden_disc() -> void:
	var pr := PlayerTable.starting_values().radius_m
	var tg: Dictionary = _attack(ActorStore.Kind.WARDEN, Vector2(1, 0))[1]
	var r: float = tg["radius"]
	for d in [r + pr - EPS, r + pr + EPS, 0.6]:
		var got := _attack(ActorStore.Kind.WARDEN, Vector2(d, 0))
		assert_eq(
			got[0].size() > 0, d <= r + pr, "distance %.2f: hit iff inside the drawn disc" % d
		)


func test_needle_line() -> void:
	var pr := PlayerTable.starting_values().radius_m
	for d in [0.0, 0.12 + pr - EPS, 0.12 + pr + EPS, 1.5]:
		var got := _attack(ActorStore.Kind.NEEDLE, Vector2(6, d))
		var drawn := _inside_lane(got[1], Vector2(6, d), pr)
		assert_eq(got[0].size() > 0, drawn, "lateral %.2f: hit iff inside the drawn line" % d)


## An attack's start along angle 0 as the native think makes it for these kinds: WINDUP, locked where the body stands
## (EnemyAi._start_windup's common part), a charge's run cut short by walls, an aimed shot's aim.
func _windup(w: World, i: int) -> void:
	EnemyAi._start_windup(w, i, 0)
	var t := w.enemy_table(w.actors.kinds[i])
	match EnemyAi.behaviour_of(w.actors.kinds[i]):
		ActorStore.Kind.CHARGER:
			w.actors.lock_len[i] = EnemyAi.clear_run(
				w, w.actors.pos(i), 0, t.charge_distance_m, t.radius_m
			)
		ActorStore.Kind.NEEDLE:
			EnemyAi._aim(w, i)
