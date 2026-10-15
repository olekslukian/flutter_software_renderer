# Architecture guide

Reference for people and coding agents working on this repository. It answers:
what exists today, who owns what, which rules keep the layers clean, and where
new code should go.

- For working rules (mentor mode, no comments, validation commands), read
  [copilot-instructions.md](../copilot-instructions.md).
- This document is the source of truth for structure, ownership, and
  conventions. If code and this document disagree, fix whichever is wrong in
  the same change.

Throughout, **Implemented** means the code exists and is exercised today, and
**Planned** means it is a direction, not a capability. Do not describe planned
items as existing.

## 1. What this project is

A CPU-only 3D software renderer hosted by Flutter. Dart code rasterizes
triangles into an RGBA byte buffer; Flutter's only jobs are to host the app,
drive the frame clock, and display the finished buffer as an image. The design
follows the shape of game frameworks such as MonoGame and Flame: a reusable
engine owns the lifecycle, and the developer's starting point is a `Game`
subclass.

### Implemented

- Game lifecycle: `initialize` → repeated `update` / `render`.
- Color framebuffer (`SoftwareFramebuffer`) and per-pixel depth buffer
  (`DepthBuffer`) for correct occlusion regardless of triangle order.
- Edge-function triangle rasterization with depth testing.
- Camera hierarchy: abstract `Camera` (view matrix, viewport, `project`) with
  `PerspectiveCamera` as its projection subclass.
- Model transform (`Transform3`), kept separate from cameras.
- `Mesh.normalized()`: centers a mesh and scales its largest extent to 2 units.
- `Renderer.drawMesh`: per-mesh MVP, per-vertex projection (`MeshPipeline`),
  depth-range triangle skipping, then rasterization.
- Wavefront OBJ loading (positions and faces only), flat-colored output.
- Presentation through `RawImage` with nearest-neighbor scaling.
- One demo game, `ModelViewDemo`, which spins an OBJ model.

### Not implemented (do not claim otherwise)

- Textures, materials, `.mtl`, UVs, normals.
- Lighting or shading (output is one flat color per model).
- Near/far plane clipping (triangles with any vertex outside the depth range
  are skipped by `Renderer.drawMesh`, not clipped).
- Camera types beyond perspective (e.g. orthographic). The `Camera` base class
  exists so they can be added; none is implemented yet.
- Back-face culling, perspective-correct attribute interpolation.
- Scene graph, entities, input handling, audio, asset manager.
- Alternative rendering backends (see section 8).
- Anti-aliasing, sub-pixel precision rules such as a top-left fill rule.

## 2. Layers and directory map

```text
lib/
  main.dart                  runApp(App)
  app/                       Flutter bootstrap; picks which Game to run
    app.dart                 MaterialApp -> EngineScreen(game: ModelViewDemo)
    game/
      model_view_demo/       Current game: OBJ model, transform, camera, colors
  engine/                    Reusable engine code (no game content)
    engine_screen.dart       Flutter host widget: Ticker + RawImage
    engine.dart              Engine: lifecycle, frame scheduling, image upload
    game.dart                Game: abstract developer entry point
    math/
      transform3.dart        Position/rotation/scale -> Matrix4
    graphics/
      renderer.dart          Frame-level drawing API handed to the game (drawMesh, drawTriangle)
      mesh_pipeline.dart     Per-mesh MVP and per-vertex projection buffers
      triangle_rasterizer.dart
      mesh.dart              Indexed triangle mesh, normalization, OBJ parsing
      buffers/
        software_framebuffer.dart   RGBA8888 color buffer
        depth_buffer.dart           Per-pixel depth, [0, 1]
      camera/
        camera.dart                 Abstract Camera: view, viewport, project
        perspective_camera.dart     PerspectiveCamera: projection matrix only
test/                        Unit tests per engine type + one widget test
assets/models/               OBJ files (declared in pubspec.yaml)
```

Allowed dependency direction (arrows mean "may import"):

```text
main -> app -> engine
app/game/* -> engine/*            (a game uses the engine)
engine_screen -> engine -> game, graphics
game -> graphics/renderer
renderer -> mesh_pipeline, rasterizer, buffers
mesh_pipeline -> camera, transform, mesh
rasterizer -> buffers
camera/*, transform, mesh -> vector_math (mesh also -> rootBundle, see 8)
```

Hard rules:

1. `engine/` never imports from `app/`.
2. Game/demo content (model choice, colors, camera placement, animation) lives
   under `app/game/`, never in `engine/`.
3. `buffers/` and `triangle_rasterizer.dart` know nothing about `Game`,
   `Engine`, or Flutter widgets.
4. Do not add a `games/` directory, broad migrations, or extra folders until a
   split clearly improves navigation. The current layout is an intentional
   small scaffold. The one planned exception is the Phase 0 extraction of the
   engine into a pure Dart package; see [PHASE_0_PLAN.md](./PHASE_0_PLAN.md).
   This document describes the pre-migration layout until that plan lands.

## 3. Components and ownership

| Type | File | Owns / responsibility | Must not |
| --- | --- | --- | --- |
| `App` | [app.dart](../../lib/app/app.dart) | Chooses the `Game` and window size (`160x120` today). | Contain rendering logic. |
| `EngineScreen` | [engine_screen.dart](../../lib/engine/engine_screen.dart) | Flutter host: creates and disposes `Engine`, runs the `Ticker`, converts elapsed time to `deltaTime`, shows `RawImage` or the error text. | Touch pixels, buffers, or game state. |
| `Engine` | [engine.dart](../../lib/engine/engine.dart) | Lifecycle gating, frame scheduling/coalescing, `Renderer` creation, framebuffer → `ui.Image` conversion, `renderError`, disposal. Is a `ChangeNotifier`. | Know about specific games or models. |
| `Game` | [game.dart](../../lib/engine/game.dart) | Abstract contract: `width`, `height`, `clearColor`, `initialize()`, `update(dt)`, `render(Renderer)`. | Allocate its own framebuffer or call Flutter APIs. |
| `Renderer` | [renderer.dart](../../lib/engine/graphics/renderer.dart) | Owns the `SoftwareFramebuffer` and `DepthBuffer` pair; `beginFrame()` clears both; `drawMesh(...)` runs the pipeline and `drawTriangle(...)` delegates to the rasterizer. Camera is passed per call. | Own scene data, cameras, or presentation. |
| `SoftwareFramebuffer` | [software_framebuffer.dart](../../lib/engine/graphics/buffers/software_framebuffer.dart) | `Uint8List` RGBA8888, bounds-checked `setPixel`/`pixelAt`, `clear`, `drawLine`, `snapshot()` copy. | Know about depth. |
| `DepthBuffer` | [depth_buffer.dart](../../lib/engine/graphics/buffers/depth_buffer.dart) | Per-pixel depth, cleared to `infinity`; `testAndSet` keeps the nearer fragment. | Write color. |
| `TriangleRasterizer` | [triangle_rasterizer.dart](../../lib/engine/graphics/triangle_rasterizer.dart) | Bounding box scan, edge functions, depth interpolation, pixel writes. Returns written pixel count. | Hold state (static, stateless). |
| `Camera` | [camera.dart](../../lib/engine/graphics/camera/camera.dart) | Abstract base: position/target/up, near/far planes, view matrix, viewport (`configureViewport`), `project` to pixel + normalized depth. Subclasses supply `setProjectionMatrix`. | Know about meshes or models. |
| `PerspectiveCamera` | [perspective_camera.dart](../../lib/engine/graphics/camera/perspective_camera.dart) | Perspective projection (vertical field of view) on top of `Camera`. | Cull or clip. |
| `MeshPipeline` | [mesh_pipeline.dart](../../lib/engine/graphics/mesh_pipeline.dart) | Computes model-view-projection once per mesh and projects each vertex into reusable screen-position and depth lists. | Rasterize or own the camera. |
| `Transform3` | [transform3.dart](../../lib/engine/math/transform3.dart) | Model matrix (model -> world) from position, Euler rotation, scale; `transformPosition`/`transformPoint`. Separate from cameras because it is per object, while a camera is per view. | Know about cameras. |
| `Mesh` | [mesh.dart](../../lib/engine/graphics/mesh.dart) | Validated vertex positions + triangle indices; `normalized()`; OBJ parsing and asset loading. | Own per-frame working storage. |
| `ModelViewDemo` | [model_view_demo.dart](../../lib/app/game/model_view_demo/model_view_demo.dart) | Game content: picks the model and colors, animates the `Transform3`, places the camera, and calls `drawMesh` each frame. | Be treated as engine API. |

## 4. Frame lifecycle

```text
EngineScreen.initState
  -> Engine(game): builds Renderer(SoftwareFramebuffer(game.width, game.height))
  -> unawaited(engine.initialize())  -> await game.initialize()
                                     -> _initialized = true; _requestFrame()
  -> Ticker.start()

Ticker tick (every vsync)
  -> deltaTime = seconds since previous tick (0.0 on the first tick)
  -> Engine.update(dt): no-op until initialized/after dispose
       game.update(dt)
       _requestFrame()

_requestFrame
  -> if an image conversion is in flight: mark _frameRequested and return
  -> renderer.beginFrame()   // clear color + depth
  -> game.render(renderer)   // synchronous rasterization into the buffers
  -> framebuffer.snapshot()  // copy of the pixels
  -> _convertToImage(pixels) // async

_convertToImage
  -> ImmutableBuffer -> ImageDescriptor.raw(rgba8888) -> Codec -> ui.Image
  -> swap in the new image, dispose the previous one, notifyListeners()
  -> finally: dispose temporaries; if _frameRequested, render again

EngineScreen rebuilds via AnimatedBuilder -> RawImage(
  fit: contain, filterQuality: none)
```

Behavior to preserve:

- **Frame coalescing.** `update` runs every tick, but rendering is gated on the
  async image conversion. If ticks arrive during a conversion, only one
  follow-up frame is rendered. Game time therefore advances smoothly even when
  presentation lags; do not tie `update` to rendered frames.
- **Initialization gate.** No `update` or `render` happens before
  `game.initialize()` completes. Games may do async work (asset loading) there.
- **Error surface.** Exceptions from `game.initialize()`, `game.render()`, or
  image conversion are stored in `Engine.renderError` and shown by
  `EngineScreen`; they are not rethrown. A later successful frame clears the
  error.
- **Disposal.** `_disposed` is checked after every `await`; late results are
  disposed, not published. Every `ui.Image`, `ImmutableBuffer`,
  `ImageDescriptor`, and `Codec` must be disposed exactly once.
- **Fixed internal resolution.** `Game.width`/`height` define the framebuffer;
  Flutter scales it to the window with nearest-neighbor filtering. The
  buffers are created once in `Engine`'s constructor and never resized.
- **`clearColor` capture.** The framebuffer copies `game.clearColor` at
  construction. `EngineScreen` reads it live for the `Scaffold` background, so
  mutating `Game.clearColor` later does not change the cleared framebuffer.

## 5. Rendering pipeline and conventions

Once, at load time: `Mesh.normalized()` centers the vertices and scales the
largest extent to 2 units.

Per frame, the game calls `Renderer.drawMesh(mesh, transform, camera, color)`,
which does the following (the engine owns every step):

```text
Camera.configureViewport(w, h)     view + projection matrices for this viewport
MeshPipeline: MVP = P * V * M      computed once per mesh (M from Transform3)
  per vertex: clip = MVP * v       -> NDC -> pixel + normalized depth
  skip triangle if any depth is non-finite or outside [0, 1]
  Renderer.drawTriangle            per-pixel coverage + depth test
  SoftwareFramebuffer              RGBA bytes
```

Conventions every contributor must keep consistent:

- **Pixel format:** RGBA8888, byte order R, G, B, A, row-major,
  `offset = (y * width + x) * 4`. This must match
  `ui.PixelFormat.rgba8888` in `Engine`.
- **Screen space:** origin at top-left, +x right, +y down. The camera flips
  NDC y (`(1 - y) * height / 2`).
- **Depth:** NDC z remapped to `[0, 1]`, smaller is nearer. The depth buffer is
  cleared to `double.infinity`; a fragment wins only if `depth < stored`
  (strict), so equal depths keep the first-drawn fragment. Values outside
  `[0, 1]` or non-finite throw `ArgumentError`.
- **Depth interpolation:** barycentric in screen space. This is correct for
  NDC z. It is **not** correct for attributes such as UVs or colors; those
  need perspective-correct interpolation (divide by `w`) when added.
- **Sampling:** a pixel is covered when its center (`x + 0.5`, `y + 0.5`) is
  inside or on the triangle edges. Both windings are accepted (no culling).
  Zero-area triangles draw nothing. There is no top-left rule, so shared
  edges are tested twice; the strict depth test makes this harmless for
  opaque flat color but remember it when adding blending.
- **Camera:** `vector_math` right-handed view/projection matrices. Subclasses
  implement `setProjectionMatrix`; `configureViewport` builds the view matrix,
  calls it, and validates orientation and viewport. `project` throws
  `StateError` until a viewport is configured. `Renderer.drawMesh` configures
  the viewport on every call.
- **Mesh:** OBJ `v` and `f` lines only. Polygon faces are triangulated as a
  fan; negative (relative) indices are supported; `f` entries such as
  `1/2/3` use only the position index. Every `Mesh` must have at least one
  vertex, complete triangles, in-range indices, and finite coordinates.
  `normalized()` returns a new mesh and rejects zero-volume input.
- **Validation style:** invalid input throws (`ArgumentError`,
  `FormatException`, `StateError`) with a specific message rather than
  silently clamping.

## 6. Authoring a game

A game is a subclass of `Game`:

```dart
class MyGame extends Game {
  MyGame({super.clearColor, super.width, super.height});

  @override
  Future<void> initialize() async { /* load assets, build state */ }

  @override
  void update(double deltaTime) { /* advance simulation by seconds */ }

  @override
  void render(Renderer renderer) { /* submit triangles */ }
}
```

Contract:

- `initialize` is awaited once; throw to surface a user-visible error.
- `update` receives seconds as a `double`; it is called every tick, not every
  rendered frame. Do no drawing here.
- `render` runs synchronously on the UI isolate after `beginFrame()` has
  cleared both buffers. It should only call `Renderer` APIs. Read the target
  size from `renderer.framebuffer`, not from hard-coded constants.
- Keep per-frame allocations low: reuse vectors and let `drawMesh` own the
  projection buffers instead of allocating per frame.
- Wire a new game in [app.dart](../../lib/app/app.dart); put its files in
  `lib/app/game/<name>/`.

`ModelViewDemo` is the reference implementation. It normalizes its mesh once
in `initialize` with `Mesh.normalized()`, animates a `Transform3`, and submits
the mesh with `Renderer.drawMesh` each frame. Game code holds no working
arrays.

## 7. Extending the engine

Place new code by responsibility, and keep a stage's inputs/outputs narrow.

| Goal | Where it goes | Notes and required tests |
| --- | --- | --- |
| New primitive (lines, points, sprites) | `Renderer` method delegating to a rasterizer in `engine/graphics/` | Test coverage count and depth behavior with a small framebuffer. |
| Near-plane clipping | New stage in `MeshPipeline`/`drawMesh` between projection and `drawTriangle` (clip in clip space before the perspective divide) | Replaces the depth-range skip in `drawMesh`; test partially visible triangles. |
| New camera type (orthographic, etc.) | Subclass `Camera` in `engine/graphics/camera/` and implement `setProjectionMatrix` | Reuses `configureViewport` and `project`; test the projection and viewport mapping. |
| Back-face culling | Option on the stage that sees winding, not in `Game` | Test both windings and that default behavior is unchanged. |
| Shading / lighting | Per-fragment or per-triangle shading hook used by the rasterizer; needs normals in `Mesh` | Must not slow the flat-color path unnecessarily. |
| Textures / materials | New `graphics/` types (texture, material); extend OBJ parsing for `vt`, `vn`, `.mtl` | Requires perspective-correct interpolation first. |
| Scene / entities | New `engine/` area owned by `Engine`, consumed by `Game` | Only when more than one game or object type needs it; update section 1 once real. |
| Input | Captured at the Flutter host boundary, forwarded to `Engine`/`Game` through a plain Dart interface | Keep Flutter event types out of engine logic. |
| Another backend (e.g. GPU, canvas) | A narrow interface the `Renderer` or `Engine` depends on, with Flutter implementations at the host boundary | See section 8 for current coupling. |
| Performance work | Profile first; candidates in section 10 | Keep behavior-preserving changes separate from feature changes. |

Every behavior change comes with a test (section 11).

## 8. Boundaries and known seams

The intent: Flutter at the edges, a rendering core that depends on narrow
interfaces so another backend could be introduced later. Current reality:

- `EngineScreen` is the Flutter host and the right place for widgets,
  `Ticker`, and `RawImage`.
- `Engine` extends `ChangeNotifier` and uses `dart:ui` image APIs
  (`ImageDescriptor`, `Codec`). Presentation conversion therefore lives in the
  engine today. If a second presentation path is added, extract it behind an
  interface rather than adding branches in `Engine`.
- Engine graphics types use `dart:ui` value types (`Offset`, `Color`) and
  `Mesh.loadFromAsset` uses `rootBundle`. These are accepted seams, not
  precedent for importing widgets or `BuildContext` into engine code.
- Math uses `package:vector_math/vector_math_64.dart` aliased as `v64`.

Rules: do not import `package:flutter/material.dart` into `graphics/`,
`math/`, or `buffers/`; do not pass `BuildContext` below `EngineScreen`.

## 9. Error handling and diagnostics

Current implementation:

- Typed exceptions in [errors/engine_exception.dart](../../lib/engine/errors/engine_exception.dart),
  all `sealed` under `EngineException`: `MeshFormatException` (OBJ parse
  errors, with line and token), `InvalidMeshException` (carries a `MeshIssue`
  enum value, so callers branch on the enum rather than the message text), and
  `ProjectionException` (a vertex whose clip-space `w` is zero or non-finite).
- Exception role by kind:
  - `ArgumentError`: caller bugs (bad FOV, clipping planes, viewport size,
    `targetExtent`).
  - `StateError`: lifecycle misuse (projecting before `configureViewport`).
  - `EngineException` subclasses: bad data or input files.
  - `assert` with a message: internal invariants on hot paths (rasterizer
    depth and dimensions, `DepthBuffer.testAndSet`). These do not run in
    release builds.
- `MeshPipeline` catches `ProjectionException` per vertex, marks that vertex's
  depth as `NaN`, and the depth filter drops only the affected triangles. The
  frame continues. `Renderer.drawMesh` reports one warning per frame for
  unprojectable vertices and one for triangles skipped by depth range.
- Non-fatal reports flow through the `DiagnosticSink` interface
  ([engine_diagnostic.dart](../../lib/engine/diagnostics/engine_diagnostic.dart)).
  `FrameDiagnostics` collects up to 20 warnings per frame and forwards every
  report to the outer sink. It is cleared at the start of each frame.
- [LoggerDiagnosticSink](../../lib/engine/diagnostics/logger_diagnostic_sink.dart)
  (engine layer, uses `package:logger`) is the default sink of `Engine`. It
  writes warnings and errors with stack traces and rate-limits repeats of the
  same phase and message to once per second. Tests inject a null or recording
  sink instead.
- `Engine` is the only error boundary. A failure in `initialize`, `render`, or
  image conversion becomes an error `EngineDiagnostic` with its phase and
  stack trace. It sets `renderError`, which `EngineScreen` displays as
  `Render failed during <phase>: <message>`.
- `EngineScreen` shows a warnings banner in debug builds only (`kDebugMode`).
  Tap it to expand the list. Release builds show warnings only in the logger.

Rules:

- Throw the most specific type. Do not throw `Exception` or `StateError` for
  data problems; add an `EngineException` subclass instead.
- Catch only where the error can be handled or converted into a diagnostic.
  Do not catch and swallow inside the rasterizer or buffers.
- Use `(error, stackTrace)` in catch clauses at boundaries so the trace is kept.
- Do not parse messages to classify errors; branch on the type or enum.
- Do not add an `assert` where a real caller-facing check is needed, and do not
  rely on an `assert` in code paths that must reject bad input in release.

## 10. Known limitations and tech debt

- One full-framebuffer `snapshot()` copy per frame, plus the copy made by
  `ImmutableBuffer`; frame budget is spent mostly in pure-Dart rasterization.
- Rasterizer visits the whole clamped bounding box per triangle and
  recomputes edge functions per pixel; no incremental edges or tiling.
- Per-pixel `Offset` allocation in the rasterizer inner loop; `DepthBuffer`
  uses `List<double>` (not `Float32List`/`Float64List`).
- `SoftwareFramebuffer.setPixel` decodes the color on each call.
- Everything runs on the UI isolate; no isolate or worker rendering.
- `MeshPipeline` reallocates its projection lists only when the vertex count
  changes; a mesh swap with the same count reuses them.
- `Camera.configureViewport` runs on every `drawMesh` call. It is per mesh, not
  per pixel, so the cost is small, but it could move to a viewport-change
  notification.
- Triangles crossing the near plane are dropped by `drawMesh`, so models close
  to the camera can pop out.
- `Engine` owns image conversion and scheduling together (see section 8).

## 11. Testing and validation

Run after any Dart change:

```sh
flutter analyze   # must report zero warnings
flutter test
```

| Test file | Protects |
| --- | --- |
| [software_framebuffer_test.dart](../../test/software_framebuffer_test.dart) | Framebuffer pixel writes, bounds, clear; depth buffer; rasterizer winding/degenerate cases; `Renderer` order independence and per-frame clearing. |
| [camera_test.dart](../../test/camera_test.dart) | `PerspectiveCamera` projection, viewport requirement, field-of-view and clipping-plane validation, a `Camera` subclass driven through the shared path. |
| [transform3_test.dart](../../test/transform3_test.dart) | `Transform3` rotation/translation and `transformPoint`. |
| [mesh_test.dart](../../test/mesh_test.dart) | OBJ triangulation, relative indices, out-of-range face rejection as `MeshFormatException`, `normalized()` centering and scale, rejection of empty, partial, non-finite, and zero-volume meshes as `InvalidMeshException` with the matching `MeshIssue`, and `ArgumentError` for invalid `targetExtent`. |
| [mesh_renderer_test.dart](../../test/mesh_renderer_test.dart) | `MeshPipeline` projection, viewport requirement, and per-vertex `ProjectionException` handling; `Renderer.drawMesh` pixel output, depth-range skipping, and the render-phase warning for unprojectable vertices. |
| [widget_test.dart](../../test/widget_test.dart) | `EngineScreen` hosting `ModelViewDemo` with an injected `Mesh` and presenting a `RawImage` as time advances. |

Keep rendering lifecycle behavior (init gate, coalescing, disposal, error
surface) covered by widget or renderer tests. Today only the happy path is
covered by `widget_test.dart`; the other lifecycle behaviors have no dedicated
tests yet. Prefer tiny framebuffers (a few
pixels wide) in unit tests so expected pixels can be asserted exactly.

Style rules enforced by [analysis_options.yaml](../../analysis_options.yaml):
80-column formatting, `always_use_package_imports`, `unawaited_futures` as an
error, strict casts/inference. Do not add code comments or doc comments unless
asked; when asked, explain a demo's purpose or a non-obvious rendering
decision, not what the code literally does.

## 12. Checklist for changes

- [ ] Code is in the right layer and imports only in the allowed direction
      (section 2).
- [ ] Game-specific content stays under `app/game/`.
- [ ] Pixel format, screen space, and depth conventions are unchanged or this
      document is updated (section 5).
- [ ] New async work checks `_disposed` and disposes native-backed objects.
- [ ] Invalid inputs fail with specific typed exceptions (section 9).
- [ ] Tests added or updated; `flutter analyze` has zero warnings and
      `flutter test` passes.
- [ ] Docs distinguish implemented behavior from planned behavior.
