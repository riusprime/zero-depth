extends GutTest
## PRESENTATION §4 / EI-07: the drawn telegraph is the hit area. For each attack, a player standing just inside
## the drawn shape (grown by the player's radius) is hit, and one just outside is not.

const S := EnemyAi.State
const EPS := 0.03


## Puts actor i into its windup with a fixed lock (as _start_windup would), the player at `at`, and runs the
## attack out. Returns the damage the player took.
func _attack(kind: int, at: Vector2) -> Array:
	var w := CombatLab.world()
	var id := w.add_enemy(kind, Vector2.ZERO)
	var i := w.actors.index_of(id)
	w.actors.invuln[i] = 0
	w.actors.set_pos(0, at)
	EnemyAi._start_windup(w, i, 0)
	var tg := EnemyAi.telegraph(w, i)
	w.actors.state_t[i] = 0
	for k in 200:
		w.actors.set_pos(0, at)  # the player stands still
		w.step(InputFrame.new())
		if w.actors.index_of(id) < 0 or w.actors.state[w.actors.index_of(id)] == S.RECOVER:
			break
	CombatLab.idle(w, 120)
	return [CombatLab.player_damage(w), tg]


func _inside_lane(tg: Dictionary, p: Vector2, r: float) -> bool:
	return Collide.circle_vs_obb(p, r - 0.0001, tg["obb"]) != Vector2.ZERO


func test_charger_lane() -> void:
	var pr := PlayerTable.starting_values().radius_m
	var cr := CombatLab.tables()[0].radius_m
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
