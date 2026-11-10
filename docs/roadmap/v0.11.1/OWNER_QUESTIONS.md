# v0.11.1: questions for the owner

Written while the owner is away (owner, 2026-11-10: "if there is any open questions just wrtie them and ask them in
the morning"). Each row says what it blocks and what was done meanwhile. Answer in chat or here.

| # | Question | What it blocks | Done meanwhile (and the lead's recommendation) |
|---|---|---|---|
| Q1 | **Where should the performance work stop?** 144 fps everywhere, or for example "never under 60 in a horde, 144 in normal rooms"? | Nothing tonight. It decides how far Wave 8 goes and whether GPU-side work (shadows, transparent layers) is added | Building the native core and the three display changes you approved. Recommendation: "60 in a horde, 144 in normal rooms" |
| Q2 | **The sim-on-a-thread switch (step 48): drop it?** | Nothing | Left parked on its branch `v0111-s48`, unmerged. Recommendation: drop it once the native core is in (a sub-millisecond tick leaves it nothing to save, and it costs a frame of delay) |
| Q3 | **Open the pull request into `main`?** GitHub's workflows run only on the PR; that is the first real test that CI builds the C++ library on Linux and that Linux gives the same results as this PC | The flip's last proof (cross-compiler identity). Not the flip itself on this PC | Not opened: opening a PR is yours to approve. Everything is pushed to `claude/v0110` |
| Q4 | **After the flip the game needs the C++ library on every platform it ships on.** Windows and Linux only for now? | Nothing now (the export is Windows) | Building for Windows and Linux. A web or Mac build would need its own library build later |
| Q5 | **Aim assist on mouse and gamepad, or gamepad only?** (open since the plan) | Nothing | Built for both, on by default, with the Options switch |
| Q6 | **Delete the hub station stand-in panel?** It can no longer be opened in the game; only a test builds it | Nothing | Left in place |
