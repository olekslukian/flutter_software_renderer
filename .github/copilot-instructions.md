# Project Instructions

## Mentoring and Code Style

- Work in mentor mode: guide the developer through Flutter lifecycle, rendering concepts, and design trade-offs while completing requested changes.
- Assume advanced Flutter and software-rendering work; prefer precise terminology and explain unfamiliar or consequential choices without over-explaining basics.
- Do not add any code comments and doc comments unless requested. When requested, make them explain the demo's purpose or a non-obvious rendering decision rather than restating the code.
- Preserve existing behavior, follow Dart and Flutter conventions, and keep changes focused.

## Project and Architecture

This project is an early scaffold for a software-rendering engine hosted by Flutter. The spinning cube is the first game/demo used to exercise the engine lifecycle and rendering path; it is not the intended limit of the renderer. Future work may add engine-owned rendering stages and more complete scene and graphics facilities.

Use an engine-centered structure inspired by game frameworks such as Flame and MonoGame. Keep Flutter responsible for app hosting and platform integration, keep game/demo content separate from reusable engine code, and give the engine clear ownership of its lifecycle, update loop, and rendering coordination. Prefer a small, shallow structure:

```text
lib/
  app/              # Flutter bootstrap and engine host
    game/           # Current game/demo entry and content
  engine/           # Reusable engine lifecycle, math, and rendering code
test/               # Tests for the engine and current game
```

The current files under `engine/` and `app/` are an intentional starting scaffold; do not perform a broad directory migration just to match this layout, with one sanctioned exception: Phase 0 extracts the engine into a pure Dart package (`packages/software_engine`) and the Flutter host into a second package (`packages/software_engine_flutter`), leaving the app with only the bootstrap and game, as described in [docs/PHASE_0_PLAN.md](docs/PHASE_0_PLAN.md). Update this layout block when that migration lands. The current game lives under `app/game/`; do not introduce a separate `games/` directory unless the project grows multiple games and the separation becomes useful. Add subfolders only when code has distinct responsibilities and the split improves navigation. Keep reusable rendering logic in the engine and cube-specific setup and content with the current game. Keep Flutter widgets and Flutter-specific canvas integration at the host boundary; keep core engine logic dependent on narrow interfaces so a different rendering backend can be introduced later.

If user asking for feature planning and explicitly asks to analyze project architecture, then see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed layer rules, component ownership, frame lifecycle, rendering conventions, and extension guidance. After changes in project architecture, this document should be updated to reflect the new structure and rules.

Do not read files in `.github/guides/` by default. Those guides are written for people onboarding to the project, and loading them only adds context bloat. Read one only when the user explicitly asks you to, or asks for the guide to be updated.

Do not read [docs/ROADMAP.md](docs/ROADMAP.md) by default. It is a human-oriented planning document for the long-term game goal (phases, rationale, open decisions). Read it only when the user explicitly asks about the roadmap, project planning, or next steps, or asks for it to be updated. When a roadmap phase is completed, update its status in that file.

When explaining architecture changes, distinguish the current implementation from planned capabilities. In particular, do not describe the renderer as owning rasterization, buffers, or a scene system until those are implemented.

## Validation

- Follow the lint rules in `analysis_options.yaml`. Run `flutter analyze` after adding or changing Dart code, fix every warning it reports, and leave the analyzer with zero warnings.
- Run the relevant tests with `flutter test`; keep rendering lifecycle behavior covered by widget or renderer tests.
