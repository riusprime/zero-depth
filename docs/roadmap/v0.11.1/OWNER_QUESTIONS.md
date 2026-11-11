# v0.11.1: questions for the owner

Written while the owner is away (owner, 2026-11-10: "if there is any open questions just wrtie them and ask them in
the morning"). Each row says what it blocks and what was done meanwhile. Answer in chat or here.

| # | Question | What it blocks | Done meanwhile (and the lead's recommendation) |
|---|---|---|---|
| Q1 | **Where should the performance work stop?** 144 fps everywhere, or for example "never under 60 in a horde, 144 in normal rooms"? | Nothing tonight. It decides how far Wave 8 goes and whether GPU-side work (shadows, transparent layers) is added | Building the native core and the three display changes you approved. Recommendation: "60 in a horde, 144 in normal rooms" |
|  | *Owner, 2026-11-11, after playing:* "feels really smooth, barely falls under 60 fps and I like that". Still open: whether that is where it stops, or whether the attack forms' light effects (Ring) come first | | |
| Q2 | **The sim-on-a-thread switch (step 48): drop it?** | Nothing | Left parked on its branch `v0111-s48`, unmerged. Recommendation: drop it once the native core is in (a sub-millisecond tick leaves it nothing to save, and it costs a frame of delay) |
| Q3 | **Open the pull request into `main`?** GitHub's workflows run only on the PR; that is the first real test that CI builds the C++ library on Linux and that Linux gives the same results as this PC | The flip's last proof (cross-compiler identity). Not the flip itself on this PC | Not opened: opening a PR is yours to approve. Everything is pushed to `claude/v0110` |
| Q4 | **After the flip the game needs the C++ library on every platform it ships on.** Windows and Linux only for now? | Nothing now (the export is Windows) | Building for Windows and Linux. A web or Mac build would need its own library build later |
| Q5 | **Aim assist on mouse and gamepad, or gamepad only?** (open since the plan) | Nothing | Built for both, on by default, with the Options switch |
| Q6 | **Delete the hub station stand-in panel?** It can no longer be opened in the game; only a test builds it | Nothing | Left in place |
| Q7 | **After you have played it: delete the script versions of the ported loops?** That is the real flip (step 54b): the C++ core becomes the only one and the goldens are re-recorded | The deletion and the golden re-record | The C++ core is ON by default in your folder (step 54a) and every script path is still there, so one switch in the dev panel (F10) goes back to the script sim for comparison. I did not delete anything: how fights feel is yours to judge, and CI has not yet shown that Linux gives the same results as this PC (Q3). Recommendation: delete after your playtest and the PR's first green run |
| Q8 | **Lightning bolts: bright core on top of the glow, always?** A bolt is a core line and a wider glow shell. Which drew on top used to vary from bolt to bolt by accident; step 57 made it the same for every bolt | Nothing | Core on top (the agent's choice; every pixel matches one of the two old looks). The other option is glow on top; say if you prefer it when you see lightning in play |

## Answers (owner, 2026-11-11, in chat)

| # | The owner's words | What the lead does |
|---|---|---|
| Q1 | "If we get never below 60 fps and cealing is 144fps, as much as we can get during not busy but the target is not doing 144fps all the time as a final objective, I think we optimized the game a lot already" | The frame target becomes: never under 60 fps; up to 144 when the scene allows; 144 on every frame is no longer the objective. The performance work stops after the Ring measurement and the last quiet run |
| Q2 | "drop it once the native core is in" | The sim-on-a-thread trial is dropped: its worktree and branch removed, its commit kept under the tag `archive/sim-thread-2026-11` |
| Q3 | "When done open PR for github main" | The PR into `main` is opened once the flip (Q7) and the last seams run are in |
| Q4 | "windows and linux for now yes" | The library is built for Windows and Linux only |
| Q5 | "both is fine" | Aim assist stays on mouse and gamepad |
| Q6 | "Sure" | The hub station stand-in panel is deleted (step 61) |
| Q7 | "C++ becomes the only one if performance is better" | It is (tick at 120 enemies 3.3 → 0.56 ms, PERF_NATIVE): step 54b goes ahead: the script versions of the ported loops are deleted and the goldens re-recorded |
| Q8 | "Core on top yeah" | Lightning bolts stay as step 57 left them |
