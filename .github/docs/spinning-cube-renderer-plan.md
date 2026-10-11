# Spinning Cube Software Renderer Plan

## Goal

Replace the current spinning-triangle demo with a CPU-rendered, filled 3D cube.
Use the demo to exercise reusable multi-triangle rendering and depth testing
while keeping game-specific geometry and animation separate from engine code.

## Current state

- `TriangleDemo` transforms and projects three vertices, then calls
  `TriangleRasterizer.fill` directly.
- `TriangleRasterizer` fills one flat-colored 2D triangle into a
  `SoftwareFramebuffer`; it has no depth input or visibility test.
- `SoftwareFramebuffer` owns RGBA color bytes only.
- `Engine` owns the framebuffer and frame/image lifecycle. `Game.render` is
  currently given the framebuffer.
- `App` launches `TriangleDemo`; focused tests cover pixel writes, triangle
  coverage, animation, and image presentation.

## Recommended design

1. **Add an engine `Renderer`**
   - Put the reusable implementation in
     `lib/engine/graphics/rendering/renderer.dart`. `Renderer` is an appropriate
     name for the engine-facing rasterization coordinator; keep its API limited
     to drawing projected triangles rather than game lifecycle or Flutter image
     conversion.
   - Have it target the engine-owned `SoftwareFramebuffer`, coordinate
     `TriangleRasterizer` and a depth buffer, and accept multiple triangle
     submissions in a frame.
   - Adapt the render handoff so `Engine` starts a renderer frame and the game
     submits its geometry through `Renderer`. Keep image decoding and image
     disposal in `Engine`.
   - Do not add a general scene graph, material system, or backend abstraction
     for this demo.

2. **Add a depth buffer**
   - Add a reusable depth buffer under `lib/engine/graphics/buffers/`, with the
     same dimensions as the color framebuffer.
   - Store one depth value per pixel; clear it at the beginning of every
     rendered frame to the farthest sentinel.
   - Interpolate the projected depth across each covered triangle and write a
     fragment only when it is nearer than the depth already stored. Use one
     documented depth convention consistently (for example, smaller
     normalized-device depth is nearer).
   - Keep depth storage and depth testing independent of Flutter `Canvas`.

3. **Make triangle filling depth-aware**
   - Reuse the existing edge-function coverage logic and pixel-center sampling;
     do not duplicate the triangle rasterization algorithm in `Renderer`.
   - Add the minimum API needed to provide per-vertex depth and perform a
     depth test while preserving the existing color-only fill behavior and its
     tests.
   - Ensure depth is only written for covered fragments that pass the depth
     test. Preserve winding-independent coverage and framebuffer bounds
     clipping.

4. **Build and animate cube geometry**
   - Add a cube-specific game under `lib/app/game/cube_demo/`. Store the eight
     cube vertices once and describe its six faces as twelve indexed
     triangles; transform each unique vertex once per frame.
   - Apply the existing model/view/projection approach to rotate the cube,
     project vertices, and submit each face triangle with projected depth.
   - Give faces distinguishable flat colors so face orientation and visibility
     are legible. Keep camera setup, cube dimensions, and face colors in the
     demo rather than the reusable renderer.
   - Keep the cube in front of the camera for this milestone. General
     near-plane clipping, lighting, textures, and back-face culling are follow-up
     work unless implementation testing shows one is required for correctness.
   - Keep reusable transform composition under `lib/engine/math/` and
     perspective/view projection under `lib/engine/graphics/camera/`; the cube
     configures these engine types but retains ownership of its pose and camera
     setup.

5. **Wire the demo and frame lifecycle**
   - Update the game render contract and `Engine` together so every frame clears
     both color and depth state before the game submits triangles.
   - Switch `App` to the cube demo. Retain the existing asynchronous
     framebuffer-to-image path, frame coalescing, and disposal behavior.
   - Remove the triangle-demo entry point only if no longer needed; avoid an
     unrelated directory migration.

6. **Document rendering APIs**
   - Add Dart doc comments (`///`) for every new rendering-related class and
     method, including constructors and private helpers, following
     `TriangleRasterizer`'s style.
   - Explain contracts and non-obvious rendering decisions (especially the
     depth convention, frame clearing, and depth comparison), not just restate
     implementation details.

7. **Test and validate**
   - Add depth-buffer tests for clearing, indexing/bounds, and nearer-versus-
     farther fragment acceptance.
   - Add renderer tests showing overlapping triangles resolve to the nearer
     surface regardless of submission order, while existing 2D rasterizer
     behavior remains unchanged.
   - Add cube-demo coverage proving that multiple faces render and advancing
     time changes the resulting pixels.
   - Update widget tests as needed to verify the app still presents the
     rendered image. Run `flutter test` and `flutter analyze`.

## Acceptance criteria

- The app displays a visibly spinning, filled cube produced by software
  rasterization into the CPU framebuffer.
- All twelve cube triangles can be submitted through the engine `Renderer`.
- A per-pixel depth test makes nearer faces occlude farther faces, independent
  of triangle submission order.
- Each frame resets both color and depth state; the existing asynchronous image
  lifecycle remains intact.
- Focused renderer/depth/cube tests pass, and all new rendering-related
  classes and methods have Dart doc comments.

## Task state and change tracking

Treat this document as the living implementation record, not just an initial
plan. When work starts or a phase changes, update the status below. On each
implementation change, record what changed and the exact files touched in the
change log; add rows as needed rather than replacing prior entries. Mark a
phase complete only after its stated behavior is implemented and relevant
validation has passed. Record validation commands and outcomes before marking
the task complete. If scope or design changes, update the plan and note why in
the log.

### Phase status

| Phase | State | Notes |
|---|---|---|
| Renderer and depth-buffer design | Complete | Added a renderer coordinator and normalized depth buffer; moved the existing color framebuffer into `engine/graphics/buffers/`. |
| Depth-aware triangle rasterization | Complete | Added depth interpolation and nearer-fragment testing while retaining the color-only fill path. |
| Cube geometry and animation | Complete | Added an eight-vertex, twelve-triangle rotating cube with distinct face colors. |
| Transform and camera encapsulation | Complete | Added reusable model transforms and perspective projection; the demo now supplies pose and camera configuration without managing matrices. |
| Engine/app integration | Complete | Engine clears both buffers per frame, passes the renderer to games, and the app launches the cube demo. |
| Tests, analysis, and documentation | Complete | Added depth, renderer, cube, and lifecycle coverage; `flutter test` and `flutter analyze` pass. |

Allowed states: `Planned`, `In progress`, `Blocked`, `Complete`.

### Change log

| Date | Phase | Change summary | Changed files | Validation |
|---|---|---|---|---|
| 2026-10-11 | Planning | Added this implementation plan and task-tracking instructions. | `.github/docs/spinning-cube-renderer-plan.md` | Not run; documentation-only change. |
| 2026-10-11 | Implementation | Added depth-tested renderer flow, moved the color framebuffer into the buffers directory, switched the app to the rotating cube, and replaced triangle-demo coverage with depth/renderer/cube tests. | `.github/docs/spinning-cube-renderer-plan.md`, `lib/app/app.dart`, `lib/app/game/cube_demo/cube_demo.dart`, `lib/app/game/triangle_demo/triangle_demo.dart` (removed), `lib/engine/engine.dart`, `lib/engine/game.dart`, `lib/engine/graphics/buffers/depth_buffer.dart`, `lib/engine/graphics/buffers/software_framebuffer.dart` (moved from `lib/engine/software_framebuffer.dart`), `lib/engine/graphics/rendering/renderer.dart`, `lib/engine/triangle_rasterizer.dart`, `test/cube_demo_test.dart` (moved from `test/triangle_demo_test.dart`), `test/software_framebuffer_test.dart`, `test/widget_test.dart` | `flutter test` — passed; `flutter analyze` — passed. |
| 2026-10-11 | Transform and camera encapsulation | Moved model-matrix composition and perspective/view projection out of the cube demo into reusable engine types; retained the demo's cube pose and camera configuration. | `.github/docs/spinning-cube-renderer-plan.md`, `lib/app/game/cube_demo/cube_demo.dart`, `lib/engine/graphics/camera/perspective_camera.dart`, `lib/engine/math/transform3.dart`, `test/camera_transform_test.dart` | Final `flutter test`, `flutter analyze`, and `git diff --check` — passed. |

For each implementation entry, list every added, modified, or removed path.
Keep the planning document itself in the file list whenever it is updated.
