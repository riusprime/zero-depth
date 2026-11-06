# O2A_INVULNERABLE: how much of a Lantern Shade or Clockwork Judge fight can no hit land?

- **Status:** RUN
- **Build:** before: `3f82f2b4` on `worktree-agent-aa25491135e58da4d` (= `claude/v0100-cleanup`) plus the new, uncommitted
  `scripts/checks/boss_invulnerable.gd`; after: the same tree plus this step's diff (committed as
  `v0.10.5 Step O2a`, whose parent is `3f82f2b4`). Godot `4.7.2.stable.official.ed1daf0bf`; OS Windows 11 Pro
  10.0.26200 (the owner's PC)
- **Date:** 2026-11-01
- **Who ran it:** agent

Owner line (L3, 2026-11-01): "some of them are invulnerable for too long, almost unhittable": the Lantern Shade and
the Clockwork Judge.

## The windows in which no player hit lands (before)

What Damage refuses (`Damage.hit`: `invuln > 0`, `_blocked` = `BossDodge.shielded` or `BossShade.unlit`):

| Boss | Window | Length (ticks) | How often |
|---|---|---|---|
| both | The rise (`World.spawn_boss`, `invuln = boss_intro_ticks`) | 60 | once a fight |
| Lantern Shade | Lights Out shielded (windup 60 + active 180, until the dark falls) | 240 (+4 measured: a pattern's active time is at least its wisps' duration) | every 12 s (`signature_every_seconds`), and as phases 2 and 3 open (their entry attack) |
| Lantern Shade | Unlit in the dark (the Shade's body outside your 3.5 m light and every lit lantern's 3 m) | up to the dark's 540 (9 s) | each Lights Out; 0 when the hero stays within 5 m of it |
| Clockwork Judge | The echo shielded (windup 48 + active 166: 12 points, a strike every 15 ticks) | 214 | every 10 s |

Not counted as blocked: the phase gate (`BossAi.GATE`, 60 ticks at 66 % and 33 %): since v0.9.5 BH1 the hit lands but
the HP floor holds. It is shown in the `gate` column. Neither boss leaps, burrows or vanishes.

## Command
```
godot --headless --path . -s scripts/checks/boss_invulnerable.gd
```
(run with a fresh `APPDATA`; it writes `build/boss_invulnerable.txt`). The heroes and the fight are described in the
script's header: a hero orbiting the boss at 3 m/s and hitting it for 4 every 6 ticks, never dying; `close` 3.0 m,
`ranged` 6.5 m closing to 4.0 m while a Shade's room is dark, `ranged_naive` 6.5 m always (informative, no target).

## Raw output (before)
```
boss_invulnerable: hit 4 every 6 ticks, walk 3.0 m/s, cap 14400 ticks, seeds [1, 2, 3], 60 Hz headless
columns: boss hero seed | ticks | blocked % | rise t/n | shield t/n | unlit t/n | gate t/n | dead
lantern_shade close 1 | 4045 | 37.7 % | 60/1 | 1464/6 | 0/0 | 118/2 | yes
lantern_shade close 2 | 4099 | 37.2 % | 60/1 | 1464/6 | 0/0 | 130/2 | yes
lantern_shade close 3 | 4081 | 37.3 % | 60/1 | 1464/6 | 0/0 | 118/2 | yes
lantern_shade close ALL | 12225 | 37.4 %
lantern_shade ranged 1 | 4717 | 34.0 % | 60/1 | 1544/6 | 0/0 | 118/2 | yes
lantern_shade ranged 2 | 4939 | 37.7 % | 60/1 | 1800/7 | 0/0 | 122/2 | yes
lantern_shade ranged 3 | 4843 | 37.1 % | 60/1 | 1736/7 | 0/0 | 118/2 | yes
lantern_shade ranged ALL | 14499 | 36.3 %
lantern_shade ranged_naive 1 | 11971 | 70.1 % | 60/1 | 4000/16 | 4836/16 | 118/2 | yes
lantern_shade ranged_naive 2 | 12487 | 71.1 % | 60/1 | 4268/17 | 5153/16 | 118/2 | yes
lantern_shade ranged_naive 3 | 13045 | 72.6 % | 60/1 | 4512/18 | 5519/17 | 118/2 | yes
lantern_shade ranged_naive ALL | 37503 | 71.3 %
clockwork_judge close 1 | 4327 | 31.1 % | 60/1 | 1284/6 | 0/0 | 118/2 | yes
clockwork_judge close 2 | 3967 | 28.5 % | 60/1 | 1070/5 | 0/0 | 118/2 | yes
clockwork_judge close 3 | 3949 | 28.6 % | 60/1 | 1070/5 | 0/0 | 118/2 | yes
clockwork_judge close ALL | 12243 | 29.4 %
clockwork_judge ranged 1 | 7201 | 30.9 % | 60/1 | 2164/10 | 0/0 | 126/2 | yes
clockwork_judge ranged 2 | 7207 | 30.8 % | 60/1 | 2160/10 | 0/0 | 126/2 | yes
clockwork_judge ranged 3 | 7219 | 30.8 % | 60/1 | 2164/10 | 0/0 | 118/2 | yes
clockwork_judge ranged ALL | 21627 | 30.8 %
clockwork_judge ranged_naive 1 | 7201 | 30.9 % | 60/1 | 2164/10 | 0/0 | 126/2 | yes
clockwork_judge ranged_naive 2 | 7207 | 30.8 % | 60/1 | 2160/10 | 0/0 | 126/2 | yes
clockwork_judge ranged_naive 3 | 7219 | 30.8 % | 60/1 | 2164/10 | 0/0 | 118/2 | yes
clockwork_judge ranged_naive ALL | 21627 | 30.8 %
determinism: MATCH
```

## The change
- New optional attack field `shield_seconds` (`BossAttackDefinition`, compiled to `BossAttackTable.shield_active_ticks`,
  read by `BossDodge.shielded`): -1 (the default, every other boss) keeps the shield through the whole active time;
  `>= 0` holds it through the windup and only that far into the active time.
- `data/bosses/lantern_shade.tres`: `lights_out` and `lights_out_3` `shield_seconds = 0.0`. The Shade is shielded through
  Lights Out's 1.0 s telegraph, then hittable while its wisps fly and the light drains; the dark still falls 4 s after
  the start and lasts 9 s, and it is still hittable only when lit.
- `data/bosses/clockwork_judge.tres`: `the_echo` `shield_seconds = 0.0`. The Judge is shielded while its path shows
  (0.8 s), then hittable while the ghosts strike along it.
- No telegraph changed (Lights Out 60 ticks, echo 48 ticks, both above `MIN_TELEGRAPH_TICKS`); no shared gate rule and
  no other boss changed. A first try with the Shade at `shield_seconds = 0.25` measured 15.0 % (close, seeds 1 and 3
  at 15.1 %), at the edge of the target, so it went to 0.0.

## Raw output (after)
```
boss_invulnerable: hit 4 every 6 ticks, walk 3.0 m/s, cap 14400 ticks, seeds [1, 2, 3], 60 Hz headless
columns: boss hero seed | ticks | blocked % | rise t/n | shield t/n | unlit t/n | gate t/n | dead
lantern_shade close 1 | 3307 | 12.7 % | 60/1 | 360/6 | 0/0 | 122/2 | yes
lantern_shade close 2 | 3427 | 12.3 % | 60/1 | 360/6 | 0/0 | 122/2 | yes
lantern_shade close 3 | 3295 | 12.7 % | 60/1 | 360/6 | 0/0 | 122/2 | yes
lantern_shade close ALL | 10029 | 12.6 %
lantern_shade ranged 1 | 3703 | 13.0 % | 60/1 | 420/6 | 0/0 | 118/2 | yes
lantern_shade ranged 2 | 3703 | 12.3 % | 60/1 | 396/6 | 0/0 | 122/2 | yes
lantern_shade ranged 3 | 3703 | 11.6 % | 60/1 | 368/6 | 0/0 | 118/2 | yes
lantern_shade ranged ALL | 11109 | 12.3 %
lantern_shade ranged_naive 1 | 7195 | 50.1 % | 60/1 | 720/11 | 3011/10 | 118/2 | yes
lantern_shade ranged_naive 2 | 7291 | 50.7 % | 60/1 | 736/11 | 3078/9 | 122/2 | yes
lantern_shade ranged_naive 3 | 6859 | 47.5 % | 60/1 | 620/10 | 2629/9 | 126/2 | yes
lantern_shade ranged_naive ALL | 21345 | 49.5 %
clockwork_judge close 1 | 3421 | 7.4 % | 60/1 | 192/4 | 0/0 | 118/2 | yes
clockwork_judge close 2 | 3253 | 7.7 % | 60/1 | 192/4 | 0/0 | 138/2 | yes
clockwork_judge close 3 | 3295 | 7.6 % | 60/1 | 192/4 | 0/0 | 122/2 | yes
clockwork_judge close ALL | 9969 | 7.6 %
clockwork_judge ranged 1 | 5461 | 8.6 % | 60/1 | 408/8 | 0/0 | 118/2 | yes
clockwork_judge ranged 2 | 5467 | 8.5 % | 60/1 | 404/8 | 0/0 | 134/2 | yes
clockwork_judge ranged 3 | 5413 | 7.5 % | 60/1 | 348/7 | 0/0 | 134/2 | yes
clockwork_judge ranged ALL | 16341 | 8.2 %
clockwork_judge ranged_naive 1 | 5461 | 8.6 % | 60/1 | 408/8 | 0/0 | 118/2 | yes
clockwork_judge ranged_naive 2 | 5467 | 8.5 % | 60/1 | 404/8 | 0/0 | 134/2 | yes
clockwork_judge ranged_naive 3 | 5413 | 7.5 % | 60/1 | 348/7 | 0/0 | 134/2 | yes
clockwork_judge ranged_naive ALL | 16341 | 8.2 %
determinism: MATCH
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| Blocked share of fight time, close and ranged heroes, 3 seeds | <= ~15 % (starting value) | PLAN v0.10.5 O2a (owner L3) |
| Every telegraph | >= `MIN_TELEGRAPH_TICKS` | EI / `BehaviourSchemas` |

## Result
| Boss | Hero | Before | After | In band? |
|---|---|---|---|---|
| Lantern Shade | close | 37.4 % | 12.6 % | yes |
| Lantern Shade | ranged | 36.3 % | 12.3 % | yes |
| Lantern Shade | ranged_naive (informative) | 71.3 % | 49.5 % | no target |
| Clockwork Judge | close | 29.4 % | 7.6 % | yes |
| Clockwork Judge | ranged | 30.8 % | 8.2 % | yes |

## Interpretation
The shield on each signature was most of the blocked time (the Shade 244 ticks of every 720, the Judge 214 of every
600); it now covers only the telegraph. The fights got shorter as a result (the Shade close 4075 → 3343 ticks on
average, the Judge close 4081 → 3323): more hits land. A hero who stays out of the light in the Shade's dark
(`ranged_naive`) still can't hit it about half the fight: that is the Shade's identity (bring the light to it), left
as it is. The gate's 60 ticks per phase are shared by every boss and were not touched. Whether the two fights now
feel right is OWNER ONLY (the next playtest).
