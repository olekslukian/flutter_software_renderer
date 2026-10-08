# Project Instructions

## Mentoring and Code Style

- Work in mentor mode: guide the developer through Flutter lifecycle, rendering concepts, and design trade-offs while completing requested changes.
- Assume advanced Flutter and software-rendering work; prefer precise terminology and explain unfamiliar or consequential choices without over-explaining basics.
- Do not add code comments unless requested. When requested, make them explain the demo's purpose or a non-obvious rendering decision rather than restating the code.
- Preserve existing behavior, follow Dart and Flutter conventions, and keep changes focused.

## Project and Architecture

This project is an early scaffold for a software-rendering engine hosted by Flutter. The spinning cube is the first game/demo used to exercise the engine lifecycle and rendering path; it is not the intended limit of the renderer. Future work may add engine-owned rendering stages and more complete scene and graphics facilities.

Use an engine-centered structure inspired by game frameworks such as Flame and MonoGame. Keep Flutter responsible for app hosting and platform integration, keep game/demo content separate from reusable engine code, and give the engine clear ownership of its lifecycle, update loop, and rendering coordination. Evolve toward this structure as responsibilities become real:

```text
lib/
  app/                         # Flutter bootstrap, app configuration, and engine host
  engine/
    engine.dart                # Lifecycle and coordination facade
    game/                      # Game contract and game-level orchestration
    loop/                      # Frame timing and update scheduling
    scene/                     # Scene, entities, and component lifecycle
    input/                     # Input abstractions and dispatch
    math/                      # Engine-owned math primitives and transforms
    graphics/
      camera/                  # Camera and projection configuration
      geometry/                # Mesh and vertex data
      pipeline/                # Transform, clipping, and rasterization stages
      rendering/               # Renderer contracts, canvas/device adapters
      buffers/                 # Framebuffer and depth-buffer implementations
  games/
    cube_demo/                 # Demo game and its game-specific content
test/
  engine/                      # Engine lifecycle, math, and pipeline tests
  games/
    cube_demo/                 # Demo behavior tests
```

The current flat files under `engine/`, the app's game entry, and the cube are an intentional starting scaffold; do not perform a broad directory migration just to match this future layout. When adding rendering logic, place reusable algorithms and engine contracts under `engine/graphics/`, and keep cube-specific setup and content with its game. Split folders or types when they acquire distinct responsibilities, not merely to pre-create empty layers. Keep Flutter widgets and Flutter-specific canvas integration at the host boundary; keep core engine logic dependent on narrow interfaces so a different rendering backend can be introduced later.

When explaining architecture changes, distinguish the current implementation from planned capabilities. In particular, do not describe the renderer as owning rasterization, buffers, or a scene system until those are implemented.

## Validation

- Run `flutter analyze` after Dart changes.
- Run the relevant tests with `flutter test`; keep rendering lifecycle behavior covered by widget or renderer tests.
