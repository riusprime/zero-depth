# v0.9.0 NB: four new bosses for floors 4 and 5 (G1, waiting for the owner)

The owner (Q24, 2026-10-22): "New bosses for 4–5"; "4: two per floor (Recommended)". PLAN step NB: "one signature
mechanic each, checked against the six; then model prompts; code stand-ins, one step per boss".

**How to answer:** per row, "approve", "change: …" or "drop". Nothing here is built until a row is approved. The lead
drafted this while the owner was away (2026-10-23); see [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md).

Every boss keeps the rules in [`docs/design/BOSS_FIGHTS.md`](../../design/BOSS_FIGHTS.md): markers track then lock and
flash 0.8 s; slow readable fireball patterns with a gap; shielded during its signature pattern; phase gates at 66 % and
33 %; fair (no spawn on you, no shot through walls, no pattern while a marker locks unless it's the named combo).
Numbers are starting values; the feel is OWNER ONLY.

## The mechanics already taken (so the new four avoid them)

| Who | Its mechanic |
|---|---|
| Gatekeeper | stone pillars that stay (cover, walls) |
| Warlord | shield facing; javelins that fly back |
| Brood Mother | eggs to pop before they hatch |
| Hive Lens | a beam sweeping round the room |
| Siege Engine | shots that bounce off walls |
| Foundry | lava that stays; the room melts inward |
| The Fallen (Nemesis) | mimics your moves, melee and ranged |
| The Colossus (final) | fast melee, jumps, floor spikes, thrown rocks |
| Elites (ELITES.md G1) | Breaker's slam and stuck window; Rift Hunter's teleport slash; Conduit's charged beam |

## The four proposals

| # | Boss | Floor pool | Look | Signature mechanic (shielded) | How you play it | Other patterns | Markers that track you | Fair rules | Starting values | Approve? |
|---|---|---|---|---|---|---|---|---|---|---|
| **N1** | **The Tidecaller** | 4 | a hunched shell-backed sea priest, a bell-headed staff; deep teal and brass; fireballs: pale teal bubbles | **The Pull.** It rings its bell and the whole room pulls toward it (your run slows going away, speeds coming in) for 3 s, then pushes out for 2 s; its bubble rings bend with the pull | Fight the current: use the pull to close in and hit, brace (move against it) during the push so you don't drift into its rings | **Tide Rings:** rings of bubbles that bend toward it during the pull | **Undertow:** a tracked circle that drags you 1 m toward its centre when it strikes | the pull never moves you more than 1.5 m/s; never into a wall corner; no ring spawns while the push is on | pull 1.2 m/s for 3 s, push 1.0 m/s for 2 s, every 9 s; phase 3: 1.5 / 1.2 | ☐ |
| **N2** | **The Twin Wardens** | 4 | two half-sized stone knights joined by a glowing chain; one amber, one violet; fireballs: amber and violet embers | **Two bodies, one life.** Two bosses share one HP bar and a chain between them that burns you if you cross it; hitting one makes the other one angry (faster) for 3 s, so you switch targets | Keep both in view, never cross the chain, alternate hits to keep both calm | **Crossfire:** each fires a fan at you from its side, so the gaps line up only between them | **Chain Sweep:** the chain's line tracks you, then locks and lashes along it | the chain is never shorter than 3 m or longer than 9 m; it can't pin you on a wall; at most one is angry at a time | shared HP = one boss; chain 12 burn a tick at 0.5 s; angry +40 % speed | ☐ |
| **N3** | **The Clockwork Judge** | 5 | a tall brass automaton with a clock-face chest and two pendulum arms; gold and black; fireballs: gold gear-sparks | **Your echo.** It records where you walked for the last 3 s; then a ghost trail of strikes replays along that path, so running in circles hits you later | Change direction often; cross your old path quickly, never loop | **Gear Spiral:** two arms of gear-sparks turning, reversing at each phase | **Verdict:** a tracked square (not a circle) that locks and drops a pendulum strike | the echo never strikes where you stand at its start; it shows the whole path 0.8 s before; one echo at a time | echo 3.0 s recorded, 1 strike per 0.25 s of path, 20 each; every 10 s | ☐ |
| **N4** | **The Lantern Shade** | 5 | a tall cloaked figure with a cage of lanterns for a head; violet-black and pale gold; fireballs: dim violet wisps | **Lights out.** It snuffs the room's light: only a small circle around you and four lanterns on the room's edge stay lit. Its wisps glow only inside light. Passing a lantern relights it for 6 s, widening the lit area | Keep lanterns lit between dodges; fight inside the light; the Shade itself is only hittable when lit | **Wisp Bloom:** a slow flower of wisps that brightens as they near you | **Snuff:** a tracked circle that, on strike, puts out the nearest lantern | the dark never hides a marker (markers always draw); wisps always show their outline within 4 m of you; accessibility: Effects density never removes the outline | dark 4 s after the signature starts; your light 3.5 m; lanterns 6 s; every 12 s | ☐ |

## Notes

- The pools: floor 4 draws N1 or N2; floor 5 draws N3 or N4; floors 1–3 keep today's pools (Q24).
- Each boss needs a model (the lead writes the prompts after the rows are approved, in the art list); code stand-ins
  until then, one step per boss.
- Deaths and HUD lines in en and es, as BS1/BS2 did ("The Tidecaller's tide dragged you into its rings.", …).
