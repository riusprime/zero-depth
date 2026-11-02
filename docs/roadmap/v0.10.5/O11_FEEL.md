# O11: feel per verb (theory audit P7; the lead's overnight pick, owner reviews)

From [`evidence/O11A_FEEL_TODAY.md`](evidence/O11A_FEEL_TODAY.md) (how each verb behaves today, cited to the code). Swink:
control pleasure lives in the response, the polish and the reaction of the world. The facts that matter most:
- a normal enemy has **no sim reaction** to a hit, only a view flinch and a 3-frame flash;
- **nothing cancels a swing**: a dash mid-swing keeps the swing counting and its hit lands from the new position;
- the Blade finisher is **31 ticks**, 24 of them recovery: the longest locked-feeling window.

Three changes, all starting values in data:

| # | Change | Why (Swink variable) | Numbers |
|---|---|---|---|
| F1 | **Hits push normal enemies back** a little, using the knockback Scatter Blast and Heavy already use (bosses never; elites half) | Response and rules: the world answers your hit | Blade hit 0.15 m, Blade finisher 0.45 m, Gun bolt 0.06 m, a Gun crit 0.12 m |
| F2 | **A dash cancels the Blade swing's recovery** (not its start-up or its active tick): dashing during recovery ends the swing, and the combo step is kept for 12 ticks so you can continue it after the dash | Input and response: commit to the hit, then move freely | Recovery only; the combo window stays 12 ticks |
| F3 | **The finisher's recovery is shorter** | Response: the longest lock eases | 24 → 18 ticks (the combo 74 → 68) |

What stays: the input buffer (6 ticks), hit-stop (S1), damage, i-frames and every cooldown. A golden that swings or hits
enemies may move on purpose.
