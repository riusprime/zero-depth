# Lead playbook: how a session runs a version

Owner, 2026-10-18: "What we do in the project config so if I start claude code on my pc locally it feels like it has
context and works fine like we are doing in this session without reading the whole convo". This file is that
workflow, written down. `CLAUDE.md` holds the rules; this is how the lead applies them, step by step.

## 1. Pick up

1. Run `bash scripts/dev/session_start.sh` (the SessionStart hook runs it for you). It prints the branch and the
   active `PROGRESS.md` "Where we are" block.
2. Read `CLAUDE.md`, then the active `PLAN.md` owner lines (O##), steps table and decisions (D##), and
   `docs/OWNER_TODO.md` §1–2. Read them by section (`grep -n` then a range); don't load them whole.
3. Work on the session branch the owner named (v0.8.0: `claude/lucid-fermat-9wv2tf`). `git pull` first.

## 2. When the owner asks for something

1. **Record it the same day**, word for word, as the next `O##` row in the PLAN's owner-lines table. Say what it
   changes and which step does it. A question for the owner becomes a `D##` row in `OWNER_TODO.md` §2. A request for
   art becomes a request file under `docs/art/requests/` with prompts, plus a row in `OWNER_TODO.md` §3.
2. **Small and direct** (a doc, a one-file fix, a tuning value): do it yourself.
3. **Anything bigger**: one step per request (`CLAUDE.md` "Keep steps fast"). Give it a short id (`BD`, `PR`, `N19`)
   and a row in the PLAN's steps table (not the owner-lines table), then hand it to an agent (§3).
4. **Owner files** (models, textures, sounds): copy them into `unprocessed_images/<kind>/` with clean names and
   commit them as `Docs: … raw …`. The agent installs them from there.

## 3. Agents

Use the Agent tool with `isolation: "worktree"`, run in the background, started from inside the repo.

**One heavy job at a time.** At most one agent runs Godot tests or shots at once. Others write code, read and lint
until the lead says "go".

The prompt includes:
- the step id;
- the branch to cut (`v0XY-<id>` from the current session branch head, by SHA);
- the owner lines verbatim;
- the files to start from;
- what to build, numbered;
- the tests to run: lint, the touched folders, and the e2e that reach the change;
- the shots wanted: one per biome or per thing the owner will look at;
- the docs to touch: PLAN step row, PROGRESS Done row and History line, OWNER_TODO, an evidence file;
- the files other running agents own (don't touch);
- the line "don't push; report the head SHA".

A follow-up goes to a fresh agent, unless the agent's history is short.

## 4. Merging an agent's branch

Use a clean worktree, never the checkout you edit in:

```bash
git worktree add ../zd-merge claude/lucid-fermat-9wv2tf     # once; afterwards just reuse it
cd ../zd-merge
git clean -fdq -- scripts tests src assets                   # stray .uid/.import files block checkouts
git fetch origin claude/lucid-fermat-9wv2tf
git checkout -B lead-merge origin/claude/lucid-fermat-9wv2tf
git merge --no-ff <agent head SHA> -m "Merge v0.8.0 Step <id>: <outcome>"
```

**Conflicts:**
- **Docs** (`PLAN.md`, `PROGRESS.md`, `OWNER_TODO.md`): keep both sides with
  `python3 scripts/ci/union_merge.py <files>`. Then run `python3 scripts/ci/union_merge.py --dupes <PLAN.md>`: a step
  row that appears twice keeps the newer one (usually "Done"), and you delete the other.
- **Translations** (`locale/*.translation`): `git checkout --theirs`, then
  `godot --headless --path . --editor --import --quit`.
- **Credits** (`data/credits/licences.tres`): rebuild with `godot --headless --path . -s scripts/content/build_credits.gd`.
- **Code and data:** read both sides and merge by hand. If you can't merge them, ask the owner.

## 5. Check, push, report

1. `bash scripts/ci/seams.sh` in the merge worktree, only while no agent is testing. Paste the totals into a PROGRESS
   History line: `- <date> (lead): <id> merged (<merge SHA>), seams on <SHA>: <passing>/<total> (<time> s).`
2. If seams fail, find which step broke it, fix it (yourself or the agent), and run seams again. When a cross-step bug
   gets past seams, add the test that caught it to `seams.sh`.
3. Push: `git push origin HEAD:claude/lucid-fermat-9wv2tf`. Then update the "Where we are" block in PROGRESS.
4. Tell the owner in plain words what changed in the game, what's still open and their questions (D##). Send the
   agent's shots.

## 6. On the owner's PC (i7-10700K, RTX 3060)

- **Shots:** they render on the GPU in a real window, so no `xvfb-run`, and they take minutes, not tens of minutes.
  Agents' shot scripts that wrap Godot in `xvfb-run -a` work without the wrapper; drop it on Windows.
- **Timing** (load freezes, fps): measured here, the numbers are real. Paste them as evidence with the machine named.
- **Windows:** run the bash scripts from Git Bash, and Godot natively, not inside WSL, so it uses the 3060.
  `scripts/verify.ps1` is the PowerShell version of `verify.sh`.
