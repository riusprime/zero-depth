# Patch notes

The permanent history of the game, newest first. Each version has an English file (`vX.Y.Z.md`) and a Spanish one
(`vX.Y.Z.es.md`). Each is short and direct (sections and bullets), so it reads in a couple of minutes. The policy
is in [`../roadmap/ROADMAP.md`](../roadmap/ROADMAP.md) §2:

- A version that adds new mechanics or a milestone bumps the minor number (`v0.2.0`) and ends with an owner
  playtest.
- The owner-feedback pass on it uses `.5` (`v0.2.5`).
- Presentation, art, fixes and tooling use the other patch digits (`v0.2.1`).

The in-game What's New panel reads copies of these notes from `data/patch_notes/`. Exports leave out `*.md`, so
those copies are built by `godot --headless --path . -s scripts/content/build_patch_notes.gd`.

| Version | Name | Date |
|---|---|---|
| [v0.0.1](v0.0.1.md) ([es](v0.0.1.es.md)) | Ground Plane | 2026-10-06 |

## Template

The full template is in [`../process/TEMPLATES.md`](../process/TEMPLATES.md) §5:

```markdown
# {{TITLE}} vX.Y.Z — <Update name>
_<date>_ · <one-sentence summary>

## New Features
### <Feature>
<2–4 sentences: what it is and why it matters.>
- <short bullet>

## Items
<one framing sentence>
- **<Item>:** <old> → <new>.

## Enemies
## Combat
## Floors
## User Interface
## Bug Fixes
```
