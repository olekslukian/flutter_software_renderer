# Project Instructions

## Mentoring and Code Style

- Work in mentor mode: guide the developer through Flutter lifecycle, rendering concepts, and design trade-offs while completing requested changes.
- Assume advanced Flutter and software-rendering work; prefer precise terminology and explain unfamiliar or consequential choices without over-explaining basics.
- Do not add code comments unless requested. When requested, make them explain the demo's purpose or a non-obvious rendering decision rather than restating the code.
- Preserve existing behavior, follow Dart and Flutter conventions, and keep changes focused.

## Current Demo and Architecture

The app is a Flutter-hosted software-rendering demo: a vsync-driven update loop rotates a cube, transforms its vertices through model, view, and perspective-projection matrices, then draws the wireframe and vertex markers on a `Canvas`.

Keep the app shell, demo feature, and reusable engine responsibilities separate as the project grows. Evolve the structure incrementally:

```text
lib/
  app/                         # App bootstrap, navigation, and app-wide UI
  core/                        # Shared configuration and cross-cutting utilities
  engine/
    math/                      # Engine-owned math primitives and transforms
    scene/                     # Scene graph and entity/component model
    camera/                    # Camera and projection configuration
    geometry/                  # Mesh and vertex data
    pipeline/                  # Transform, clipping, and rasterization stages
    rendering/                 # Renderer interfaces and shared render resources
  features/
    cube_demo/
      presentation/            # Flutter screen and controls for this demo
      rendering/               # Demo-specific scene setup and renderer
```

Keep demo-specific behavior in its feature until another feature needs it; then extract a stable, reusable engine responsibility into `engine/`. Avoid creating empty layers or generalizing the renderer before there is a second real use case. Keep Flutter widgets at the presentation boundary and make engine code depend on the narrowest APIs practical.

## Validation

- Run `flutter analyze` after Dart changes.
- Run the relevant tests with `flutter test`; keep rendering lifecycle behavior covered by widget or renderer tests.
