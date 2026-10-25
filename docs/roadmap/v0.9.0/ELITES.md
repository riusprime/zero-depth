# v0.9.0 Elites (G1)

The owner, 2026-10-22 ([`feedback/2026-10-22_world_elites_progression.md`](feedback/2026-10-22_world_elites_progression.md)
§10): "Elites must become distinct enemy archetypes with unique 3D models, dedicated abilities, and a miniboss-like
presentation … stronger than a normal enemy, but not comparable to a full boss … One distinctive special ability:
Similar in presentation to a simplified boss mechanic … Avoid simply stacking multiple special attacks, extremely high
movement speed, and large damage bonuses … These examples should be evaluated against the enemy roster to avoid
duplicating existing bosses or abilities." Q26: "Your three (Recommended)" (Breaker, Rift Hunter, Conduit). Q24–Q25
(PLAN "Owner decisions"): elites only on floors 4–5 (15 % / 25 % of combat rooms) and in Elite Lockdowns, at most 1
alive, at least 2 rooms apart; the old ×2 HP elite, the Marked curse and the Ambush Cache event go; a kill has a 30 %
chance to drop the elite's core card.

**How to answer:** mark each row **Yes**, **No** or **Change: …**. Only Yes rows get built. Every number is a
starting value (tunable in F10), set against today's data: a Warden has 100 HP and hits for 25, a Charger 45 HP / 20;
bosses start at about 2,000–2,400 HP (`data/bosses/*.tres`). Elites scale with the floor and its danger tier like
every enemy, so their share of a boss stays about the same on floors 4–5, on a Deep floor and on later loops.

**Today** (live code): an elite is any normal enemy with ×2 max HP (`Curses.make_elite`, `src/sim/events/curses.gd:229-235`),
a gold ring under it and the normal small health bar (`actor_views.gd:12, 607`). Bosses' signature mechanics
(v0.8.0 `BOSS_SIGNATURES.md`): Gatekeeper's stone spike pillars, Warlord's shield facing and recalled javelins, Brood
Mother's eggs, Hive Lens's sweeping gaze beam, Siege Engine's ricochet shells, Foundry's lava floor. The Prism's
turning Cross beams, the Colossus's fists and jumps, The Fallen's mimicry.

## The three elites

| Row | Elite | Model (art list §3.1) | Numbers | Its one special ability (telegraph → strike → recovery) | Otherwise | Closest existing, and how it differs | Counterplay | Owner |
|---|---|---|---|---|---|---|---|---|
| **E1** | **The Breaker** | `elite_breaker`, ~2.6 m, bronze and gold, a huge stone fist | HP 600 (6 Wardens, about a quarter of a floor boss); contact 30; move 1.3 m/s | **Ground Slam.** It raises the fist (1.0 s; a ground circle of 3.0 m fills in under it), slams (32 damage in the circle, a dust ring, a vibration only if you're close), then **stays stuck 1.5 s** with its fist in the ground: it takes **+50 %** damage while stuck. Every 6 s | Walks at you slowly; a short punch (25) at 1.5 m | The Warden's slam is small, fast and gives no window; the Colossus's fists come in combos. The Breaker is one big readable slam and a big punish window | Step out of the circle, then hit it while it's stuck | |
| **E2** | **The Rift Hunter** | `elite_rift_hunter`, ~2.1 m, dark violet and gold, blade arms | HP 450; contact 25; move 2.6 m/s (the Charger's is 3.0) | **Rift Step.** It marks a spot near you with a violet rift on the floor (0.9 s; the mark tracks you for the first 0.5 s, then locks), vanishes, reappears on the mark and slashes in a 2.2 m arc (30 damage), then **stands still 1.0 s**. Every 4.5 s | Keeps 4–6 m away between steps, circling | The Charger dashes in a straight line; The Fallen mimics you. The Rift Hunter never runs at you: it reappears where you were | Keep moving after the mark locks, then turn and hit it during its pause | |
| **E3** | **The Conduit** | `elite_conduit`, ~2.3 m, pale teal and gold, floating, a crystal staff | HP 400; no contact damage; move 1.5 m/s, keeps 7–10 m away | **Charged Beam.** It plants its staff and charges (1.4 s; a thin line from the staff toward you, tracking for 0.9 s, then locked and brightening), fires a 0.7 m-wide beam to the room's wall (40 damage, once), then **overloads 2.0 s**: it drops to the floor, no shield, and takes **+50 %** damage. Every 7 s | Between beams it drifts and fires a slow 3-orb fan (12 each) every 2.5 s | The Sniper's line is a quick single shot; the Hive Lens's gaze sweeps continuously; the Prism's Cross turns. The Conduit's beam is one locked line with a long, obvious charge and a big punish window | Sidestep after the line locks, then close in during the overload | |

## What every elite also gets (one row, approve with the three)

| Row | What | Proposal | Owner |
|---|---|---|---|
| **E0** | Presentation and rules | **Arrival:** a 0.7 s burst and a gold ground sigil where it spawns, the `elite_arrive` sound, no pause and no banner (W67). **Bar:** the wider framed bar with its small name above (G2: 3 mockups before building). **One ability only;** no speed or damage stacking (W59). **Fair:** a telegraph never starts on you and always shows at least 0.8 s before the hit; at most 1 elite alive, never two elite rooms within 2 rooms (Q24). **Reward:** 30 % chance of its core card on the kill (Q25), plus 3 × a normal enemy's shards. **Escort:** an elite's room still has its normal pack, but the first pack is one size smaller while the elite lives. **Reduced motion:** the same telegraphs, no screen vibration | |

If you want another elite later, add a row with its name and what it does in play.

## Decisions (owner, date)
| Row | Answer | Built in |
|---|---|---|
| — | | |
