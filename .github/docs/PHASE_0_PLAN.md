# Phase 0 implementation plan

This is the complete implementation plan for
[Phase 0](./ROADMAP.md#phase-0-foundations-and-measurement). It has two parts
that are done in order, because the second part needs the first:

- **Part A (steps 0 to 6): make it measurable.** Make the engine runnable
  without Flutter, split it into packages, and build the Dart benchmark suite
  and baseline. The same scenes later serve the Dart-vs-Rust comparison in
  Phase 5.
- **Part B (steps 7 to 11): make it fast and trustworthy.** Define the
  performance budget, add known-good image tests, add the fixed simulation
  step, do the cheap inner-loop optimizations against the baseline, and update
  the architecture documents.

It describes the **target** state. [ARCHITECTURE.md](./ARCHITECTURE.md) keeps
describing what exists today until step 11 updates it.

## 1. Goals and non-goals

**Goals**

1. The engine compiles and runs under the plain Dart VM (`dart run`,
   `dart compile exe`) with no `dart:ui` or `package:flutter` import.
2. The Flutter boundary is enforced by the compiler, not by convention: the
   engine is a pure Dart package, and everything Flutter-specific is in a
   separate Flutter host package.
3. A repeatable benchmark suite and deterministic reference scenes, with JSON
   output that a Rust port can later match.
4. The refactor preserves behavior: the same pixels come out before and after.
5. A written performance budget, known-good image tests, a fixed simulation
   step, and the cheap inner-loop fixes, each measured against the baseline.

**Non-goals**

- Any rendering feature (clipping, culling, textures): Phases 1 to 4.
- Deep optimization that Phase 5 (Rust) would throw away.

## 2. Target layout

Three packages with one-way dependencies:
`app` -> `software_engine_flutter` -> `software_engine`, and
`app` -> `software_engine` (a game uses the engine directly).

```text
pubspec.yaml                          Flutter app; path deps on both packages
lib/
  main.dart                           runApp + MaterialApp home: EngineScreen(game)
  game/
    model_view_demo/                  Current game (engine-only imports)
packages/
  software_engine/                    Pure Dart package, no Flutter SDK
    pubspec.yaml                      deps: vector_math, logger; dev: test, lints, image
    analysis_options.yaml
    lib/
      engine.dart                     Engine: lifecycle, update, renderFrame
      game.dart                       Game, AssetLoader
      diagnostics/ errors/ math/
      graphics/
        color32.dart                  extension type Color32
        renderer.dart, mesh.dart, mesh_pipeline.dart, triangle_rasterizer.dart
        buffers/ camera/
      testing/                        Reference scenes, harness, file loader, goldens
    test/                             Engine tests (package:test) and goldens/
    benchmark/                        Thin `dart run` entry points, baselines/
  software_engine_flutter/            Flutter package: the host boundary
    pubspec.yaml                      deps: flutter, software_engine
    lib/
      engine_screen.dart              Ticker + RawImage widget, debug overlay
      engine_presenter.dart           ChangeNotifier: frame requests, ui.Image upload
      flutter_asset_loader.dart       AssetLoader backed by rootBundle
      color32_flutter.dart            Color32 -> ui.Color extension
    test/                             Widget and presenter tests (flutter test)
assets/models/                        Stays at the repo root (app + benchmarks)
test/                                 App smoke test with the real demo
```

Decisions behind this layout:

- **Path dependency, not a pub workspace.** A workspace resolves every member
  together, so `dart pub get` inside the engine package would also resolve the
  root's Flutter SDK dependency and can fail with "Flutter users should run
  `flutter pub get`". A path dependency keeps the engine's resolution
  independent. Confirm in step 0; fall back to a workspace only if the path
  dependency causes problems.
- **No `lib/src/`.** The package mirrors today's `engine/` folders, so step 2 is
  mostly `git mv` plus import rewrites. Add a `src/` split and barrel only if
  the engine is ever published.
- **The Flutter host is its own package** (`software_engine_flutter`), so the
  app contains only the bootstrap and game content, and the pure engine can
  never accidentally depend on it. Another host (for example a headless or
  native one) would be a sibling package.
- **Game content stays in the app**, but imports nothing from Flutter after
  step 1, so it can move later without edits.
- **Reference scenes and harness live in `software_engine/lib/testing/`**, not
  under `benchmark/`. Tests, `dart run` benchmarks and the host package's debug
  overlay on phones can all import them with package imports. Phones cannot run
  plain Dart scripts, so on-device numbers must come from the Flutter host.
- Package names `software_engine` and `software_engine_flutter` are
  placeholders; rename freely before step 2.

## 3. Type and API changes

| Today | Target | Reason |
| --- | --- | --- |
| `ui.Color` everywhere | `extension type Color32` | Flutter-free, zero-cost, one `u32` store per pixel |
| `ui.Offset` in camera, pipeline, rasterizer, renderer | Plain `double` x/y | No allocation per pixel/vertex, matches FFI layout |
| `List<Offset>` / `List<double>` in `MeshPipeline` | `Float64List` for x, y, depth | Flat typed arrays, identical numeric results |
| `List<double>` in `DepthBuffer` | `Float64List` | Same; `Float32List` is a later measured change |
| `Mesh.loadFromAsset` (`rootBundle`) | Removed; `AssetLoader` interface | Engine has no asset-system dependency |
| `Engine extends ChangeNotifier`, `ui.Image` | Pure `Engine`; `EnginePresenter` in `software_engine_flutter` | Presentation is a host concern |
| `Game.clearColor: Color` | `Color32` | Follows `Color32` |

### 3.1 `Color32`

```dart
extension type const Color32._(int _abgr) {
  const Color32.fromARGB(int a, int r, int g, int b);
  const Color32.fromARGB32(int argb);
  int get alpha; int get red; int get green; int get blue;
  int toARGB32();
  int get abgr;
}
```

- **Representation** is the framebuffer-native word: `0xAABBGGRR`, which is the
  byte order R, G, B, A when stored little-endian. A pixel write is one `u32`
  store with no per-pixel decoding, and Rust can use the same `u32`.
- **Readable at the call site:** `Color32.fromARGB32(0xFF20C7D9)` keeps today's
  hex literals; `fromARGB` takes channels. The raw field is private so nobody
  depends on the byte order.
- **Framebuffer** keeps a `Uint8List` and a `Uint32List` view of the same
  buffer. It throws `UnsupportedError` on a big-endian host (none of our
  targets is). `clear()` becomes a single fill instead of a four-store loop.
- Add `color32_flutter.dart` in `software_engine_flutter` with
  `Color toFlutterColor()`, used
  for the `Scaffold` background in `EngineScreen`.

### 3.2 Screen-space coordinates

- `ProjectedVertex(double x, double y, double depth)`.
- `MeshPipeline` exposes `screenX`, `screenY`, `depths` (`Float64List`).
  Behavior stays identical, including the `ProjectionException` path; replacing
  it is a later optimization.
- `TriangleRasterizer.fill` / `fillWithDepth` take
  `ax, ay, bx, by, cx, cy` and `depthA..C`. The sample point becomes two local
  doubles and `_edge` takes scalars, so the per-pixel `Offset` allocation
  disappears as a side effect. The inside test and depth interpolation stay
  as is, so output is bit-identical.
- `Renderer.drawTriangle` uses named `double` parameters
  (`ax`, `ay`, `bx`, ...). It is a game-facing API, so keep it readable
  rather than adding a `Vector2` allocation.

### 3.3 Assets

- New in `game.dart`:
  `abstract interface class AssetLoader { Future<String> loadString(String path); }`.
- `Game.initialize(AssetLoader assets)`; `Engine` receives the loader in its
  constructor and passes it on. `ModelViewDemo` calls
  `Mesh.fromObj(await assets.loadString(modelAssetPath))`.
- Implementations: `FlutterAssetLoader` (host, `rootBundle`) and
  `FileAssetLoader` (`lib/testing/`, `dart:io`, rooted at a directory).
  Textures in Phase 3 will extend this interface.

### 3.4 `Engine` split

Pure `Engine` (package):

- `initialize()`: awaits `game.initialize(assets)`; on failure records
  `renderError` instead of notifying.
- `update(double deltaTime)`: only `game.update`.
- `bool renderFrame()`: clears diagnostics, `renderer.beginFrame()`,
  `game.render(renderer)`; returns `false` and records the error on failure.
- `step(double deltaTime)`: `update` then `renderFrame`, for benchmarks and a
  headless loop.
- `framebuffer`, `renderer`, `warnings`, `renderError`, `clearColor`, `dispose()`.

`EnginePresenter extends ChangeNotifier` (in `software_engine_flutter`) owns
what `Engine` owns now beyond that: the conversion-in-flight/coalescing logic,
`ui.Image` creation and disposal, and `notifyListeners()`. It preserves
today's behavior: a tick calls `engine.update`, then requests a frame; while a
conversion is running the request is coalesced. `EngineScreen` creates the
presenter instead of the engine and moves to the same package. The app's
`lib/` then contains only `main.dart` and the game.

## 4. Steps

Each step ends with a green `flutter analyze` and `flutter test` (and, from
step 2, `dart analyze` and `dart test` in `software_engine`, plus
`flutter analyze` and `flutter test` in `software_engine_flutter`), and is one
commit.

## Part A: make it measurable

### Step 0: Spike and characterization

1. Tooling spike in a throwaway directory: a pure Dart package with
   `vector_math` and `logger`, consumed by the Flutter app through a path
   dependency. Confirm `dart pub get`, `dart run`, `dart compile exe` in the
   package and `flutter analyze` / `flutter test` in the app. Choose path
   dependency vs workspace from the result.
2. Capture **characterization hashes** with the current code (a temporary
   `flutter test`): render `penger.obj` normalized with the demo's camera and
   transform at a few fixed rotation angles, and record an FNV-1a hash of
   `framebuffer.snapshot()` per frame. These numbers become the expected values
   in the new engine test (step 3) and prove the refactor changed no pixels.
   Discard the temporary test.

### Step 1: Remove Flutter types in place (still one package)

Order matters: each substep compiles on its own.

1. **1a `Color32`:** add `graphics/color32.dart` with unit tests; switch
   `SoftwareFramebuffer`, `Game`, `Renderer`, rasterizer, `ModelViewDemo` and
   tests. Add the endianness guard and `Uint32List` view.
2. **1b Coordinates:** `ProjectedVertex`, `MeshPipeline` typed arrays,
   rasterizer and `Renderer.drawTriangle` signatures; `DepthBuffer` to
   `Float64List`.
3. **1c Assets:** `AssetLoader`, `Game.initialize(AssetLoader)`, remove
   `Mesh.loadFromAsset` and its `rootBundle` import; add `FlutterAssetLoader`
   in `lib/app/host/` (temporary home).
4. **1d Engine split:** pure `Engine`, `EnginePresenter`, move
   `engine_screen.dart` to `lib/app/host/` (temporary home), add
   `color32_flutter.dart`.

Exit check: no match for `dart:ui|package:flutter` under `lib/engine/`, and the
step 0 hashes still match.

### Step 2: Extract the packages

1. **2a `software_engine`:** create `packages/software_engine/` with its own
   `pubspec.yaml` (`environment: sdk: ^3.8.1`, `vector_math`, `logger`, dev
   `test`, `lints`). `git mv lib/engine/*` into the package `lib/` and rewrite
   imports from `package:flutter_software_renderer/engine/...` to
   `package:software_engine/...`.
2. **2b `software_engine_flutter`:** create `packages/software_engine_flutter/`
   (`flutter` plus a path dependency on `software_engine`). `git mv`
   `lib/app/host/*` into it. Move the demo from `lib/app/game/` to `lib/game/`
   and fold `app.dart` into `main.dart`, so the app `lib/` holds only the
   bootstrap and the game.
3. App `pubspec.yaml`: add both path dependencies; drop `logger` if the app no
   longer imports it directly; keep `vector_math` for the demo. The
   `assets/models/` declaration stays in the app, since the app bundle serves
   `rootBundle`.
4. Package `analysis_options.yaml` for `software_engine`: base on
   `package:lints/recommended.yaml` and copy the project's strict-mode settings
   and rule list from the root file (the root file includes `flutter_lints`,
   which the pure package cannot resolve, so it cannot be included directly).
   `software_engine_flutter` includes `flutter_lints` like the app.
5. Commit each package's `pubspec.lock` (this is an app-style repo; reproducible
   benchmarks need pinned versions).

### Step 3: Move and extend tests

- Move `camera`, `mesh`, `mesh_renderer`, `software_framebuffer`, `transform3`
  tests to `packages/software_engine/test/`; replace `flutter_test` with
  `package:test`.
- Move `test/widget_test.dart`'s host coverage to
  `software_engine_flutter/test/`, driven by a tiny reference-scene `Game`
  from `software_engine/testing` instead of the demo. Keep a minimal app smoke
  test in `test/` that pumps the real `ModelViewDemo`.
- New tests: `Color32` conversions; headless `Engine` lifecycle (initialize
  failure, `renderFrame` failure recorded, `step`); the step 0 characterization
  hashes; `FileAssetLoader`; presenter coalescing in the host package.

### Step 4: Reference scenes, harness, and benchmarks

- `lib/testing/reference_scenes.dart`: deterministic `Game` implementations
  (no wall clock; angle is a pure function of the frame index): the rotating
  cube, `penger.obj`, and an overdraw stress scene of stacked quads.
- `lib/testing/benchmark_runner.dart`: warmup, N timed iterations with a
  `Stopwatch`, and **median, p95, min** (not mean). Result schema:
  `name`, `scene`, `width`, `height`, `iterations`, `medianUs`, `p95Us`,
  `minUs`, `framebufferHash`, `dartVersion`, `os`. The hash lets the Rust
  port prove it produced the same image.
- `benchmark/` entry points (package imports only):
  - Micro: `clear`, `triangle_fill` (small, medium, full-screen), `depth_test`,
    `project_vertices`, `obj_parse`.
  - Macro: `frame_benchmark.dart` runs `Engine.step` on each reference scene
    at 320x240.
  - `run_all.dart` prints a table and writes JSON to
    `benchmark/results/` (git-ignored). Commit one baseline per machine class
    under `benchmark/baselines/`.
- Run benchmarks as AOT: `dart compile exe benchmark/run_all.dart`. JIT
  numbers are for development only. Compiling also acts as a Flutter-import
  guard.
- Package scripts are documented in the repo README (commands only).

### Step 5: Frame timing split

- `Engine` records `lastUpdateMicros` and `lastRenderMicros` (injectable clock
  for tests).
- `EnginePresenter` measures the present step (snapshot, upload, decode) and
  exposes a `FrameTimings` value; show it in a debug-only overlay on
  `EngineScreen`. This is the on-device measurement path for phones.

### Step 6: Record the baseline

Run the AOT suite on the desktop machine, commit the baseline JSON under
`benchmark/baselines/`, and note the machine (CPU, OS, Dart version) in the
file. Every later change is judged against this file. Phone numbers come from
the host overlay (step 5) on a profile build, recorded by hand in the same
format.

## Progress: Part A done, stopped for review

Steps 0 to 6 are implemented in the working tree and **not committed** (as requested). Part B (steps 7 to 11) is not started. [ARCHITECTURE.md](./ARCHITECTURE.md), [copilot-instructions.md](../copilot-instructions.md) and [ROADMAP.md](./ROADMAP.md) are unchanged; their updates belong to step 11.

Validation at the stop point (Flutter 3.32.5, Dart 3.8.1):

- `packages/software_engine`: `dart analyze` clean, `dart test` 48 passing. This includes the step 0 characterization hashes, which were asserted after every substep.
- `packages/software_engine_flutter`: `flutter analyze` clean, `flutter test` 6 passing.
- App: `flutter analyze` clean, `flutter test` 1 passing (smoke test with the real demo).
- `dart compile exe benchmark/run_all.dart` succeeds. `grep -rn "dart:ui\|package:flutter/" packages/software_engine` is empty.

Step notes and deviations:

- **Step 0:** A throwaway spike confirmed `dart pub get`, `dart run`, and `dart compile exe` in a pure package, and `flutter analyze`/`flutter test` in an app that consumes it by path. Path dependencies were chosen; no workspace. Characterization hashes (FNV-1a of `snapshot()`, angle = frame × 0.05 rad): frame 1 `0x8ab934b5`, 2 `0xdb3be0c5`, 3 `0x1d36fda9`, 10 `0x0a7d63a5`, 40 `0x04a18a65`, 90 `0x10300cc5`.
- **Steps 1a to 1d:** As planned. The framebuffer stores RGBA bytes through a `Uint32List` view on little-endian hosts (`Color32` word `0xAABBGGRR`). `Engine` is pure; `EnginePresenter` owns `ui.Image` and frame coalescing.
- **Step 2:** `vector_math` is pinned to 2.1.4 in the new package lock, to match the app lock. 2.3.0 deprecates `translate` and `scale` in `transform3.dart`. Migrating those calls is a follow-up outside Phase 0. `software_engine` uses `lints/recommended` with the project rule list copied and Flutter-only rules removed. `software_engine_flutter` includes the root analysis options by relative path. The `App` widget was folded into `lib/main.dart`.
- **Step 3:** Testing support lives in `lib/testing/` (`FileAssetLoader`, reference scenes, FNV hash, benchmark runner and cases). Engine tests use `package:test`. The host widget test moved to `software_engine_flutter/test/`.
- **Step 4:** Entry points are thin: `benchmark/micro_benchmark.dart`, `benchmark/frame_benchmark.dart`, `benchmark/run_all.dart`. The cases live in `lib/testing/` so entry points use package imports only. A result's hash is the framebuffer after one iteration from a fresh target, so `frame_penger` equals the step 0 frame-1 hash. `run_all` takes `--machine=...` and writes `benchmark/results/run_all.json`, which is git-ignored. The README documents the commands.
- **Step 5:** `Engine(clock:)` and `EnginePresenter(clock:)` are injectable. The overlay shows when `!kReleaseMode`, not only in debug builds, so profile builds can show the phone numbers from step 6. This is a deliberate change from "debug-only".
- **Step 6:** Baseline: `packages/software_engine/benchmark/baselines/macos-arm64-apple-m3-pro.json` (Apple M3 Pro, macOS 26.7.1, Dart 3.8.1 AOT, one run).

Open points for review before Part B:

1. **Phone rows are not measured** (skipped as requested). Add them to the baseline by hand from a profile build of the host overlay, in the same format.
2. **Timer resolution:** `triangle_fill_small` has a 0 µs median, and `project_vertices` is about 6 µs. Micro cases must batch several calls per timed sample before they are useful for Part B comparisons.
3. **Overdraw variance:** min 709 µs, p95 2426 µs in one run. Use more iterations or a quieter machine before applying the 5% rule in step 10.
4. **Docs:** step 11 still needs to update ARCHITECTURE.md, the copilot-instructions layout block and validation list, and ROADMAP.md.
5. **Commits:** nothing is committed. One commit per step, with the Co-authored-by trailer, is still the intended history.

## Part B: make it fast and trustworthy

### Step 7: Performance budget

Turn the roadmap's 16.6 ms frame budget into numbers per stage, using the step
6 baseline instead of guesses. Proposed starting split for 320x240 at 60 fps
(to be adjusted after the baseline, then recorded in
[ROADMAP.md](./ROADMAP.md) section 1):

| Stage | Desktop target | Phone target |
| --- | --- | --- |
| Update (game logic) | <= 1 ms | <= 1.5 ms |
| Render (vertex + raster + pixel stage) | <= 8 ms | <= 9 ms |
| Present (snapshot, upload, decode) | <= 2 ms | <= 3 ms |
| Headroom (GC, input, OS jitter) | >= 5 ms | >= 3 ms |

- `benchmark/budget.json` holds the numbers; `run_all.dart` prints each result
  against its budget. It is informational for now, not a CI gate.
- Render must also be reported per reference scene, so Phase 3 to 4 additions
  can be checked against the same table.
- If the baseline shows render far above budget on the simple scenes, apply the
  roadmap's rule: consider pulling Phase 5 forward.

### Step 8: Known-good image tests

Done before the optimizations so they have a safety net.

- **Harness** in `lib/testing/golden.dart` (dev dependency `image` for PNG
  encode/decode): render a reference scene at fixed frame indices, compare with
  `test/goldens/<scene>_<frame>.png`.
- **Comparison options:** `maxChannelDelta` and `maxDifferingPixels`, both `0`
  for Dart. The Rust port will use small non-zero tolerances because it likely
  computes in `f32`.
- **Failure output:** write `<name>_actual.png` and `<name>_diff.png` next to the
  golden so a regression is visible, not just a hash mismatch.
- **Update flow:** `UPDATE_GOLDENS=1 dart test` rewrites goldens; the diff in
  review is the approval.
- **Scene set:** rotating cube, `penger.obj`, overdraw stress (stacked quads).
  Phase 1 adds a near-plane scene; leave a skipped placeholder test with the
  reason.
- Seed the goldens from the step 0 characterization (they must match it), then
  keep the hashes as a quick check inside the benchmark output.

### Step 9: Fixed simulation step

Decide the timing rule and put it in the pure `Engine`, so it is testable with
a fake clock and the same in the host and in headless runs.

- `Engine.advance(double frameDelta)` adds to an accumulator and calls
  `game.update(fixedStep)` zero or more times (default `1 / 60`; configurable
  in the `Engine` constructor), then reports whether state changed.
- **Clamp** the frame delta (default 0.25 s) and cap updates per frame
  (default 5), so a stall cannot cause a spiral of ever-longer catch-up.
- **Game contract:** `Game.update` now always receives the constant fixed step.
  The demo needs no change since it already scales by `deltaTime`. Document
  this in ARCHITECTURE.md section 6.
- **Rendering is variable-rate:** at most one render per host tick, and none if
  no update ran. Interpolating between states using the leftover accumulator is
  deferred to Phase 7, when movement needs it.
- `EnginePresenter` calls `advance` on every tick and requests a frame only
  when it returns `true`. `Engine.step` (benchmarks) is one fixed update plus
  one render.
- Tests: exact update counts for a scripted sequence of deltas, clamping, the
  cap, and that results do not depend on the render rate.

### Step 10: Cheap inner-loop optimizations

Steps 1a and 1b already remove the per-pixel `Offset`, the boxed depth list and
the per-pixel color decoding (three of the five slow spots in ARCHITECTURE.md).
The rest, each its own commit with before/after medians in the message:

| Item | Change | Expected pixel impact |
| --- | --- | --- |
| Redundant checks | Rasterizer-internal unchecked framebuffer and depth writes by index; the loop computes the index incrementally | None |
| Bounding-box scan recomputation | Incremental edge functions: step each edge value by a constant per pixel and per row instead of recomputing from the sample | Possible rounding differences at coverage boundaries |
| Reciprocal of area | Multiply by a precomputed `1 / area` instead of dividing per pixel | Possible last-bit depth differences |
| Per-vertex exceptions | `ProjectionException` replaced by a bool-returning projection into preallocated arrays | None |
| `Float32List` depth | Halve depth memory traffic | Rare depth-tie differences |
| Per-frame image copy | Check whether `ImmutableBuffer.fromUint8List` copies before its first `await`; if so, hand it the live framebuffer view and drop `snapshot()`, otherwise double-buffer | None; measure present time |

Rules:

- Only changes that keep the goldens identical on all reference scenes are
  accepted. A change that alters coverage or depth at boundaries is dropped or
  deferred to Phase 1, which rewrites coverage with the top-left rule anyway.
- Keep a change only if it improves its target benchmark by at least 5% or
  simplifies the code at no cost.
- Time-box this step. Parallelism (isolates), tiling, and fixed-point
  rasterization belong to Phase 5, not here.

### Step 11: Update documentation and close the phase

Done after steps 0 to 10 land, not before.

- [ARCHITECTURE.md](./ARCHITECTURE.md):
  - section 1: add the packages, benchmarks and goldens to "Implemented";
  - section 2: replace the directory map and dependency arrows with the three
    packages; rewrite hard rule 4 (the package split is the sanctioned
    migration) and add the rules "`software_engine` imports no Flutter" and
    "the app contains only the bootstrap and game content";
  - section 3: ownership for `Engine`, `EnginePresenter`, `EngineScreen`,
    `AssetLoader`;
  - section 4: frame lifecycle (fixed-step `advance`, `renderFrame`, present);
  - section 5: `Color32` and screen-space conventions (framebuffer byte order,
    `double` coordinates);
  - section 6: `Game.initialize(AssetLoader)` and the fixed-step contract of
    `Game.update`;
  - section 8: remove the `rootBundle` seam; section 10: update the tech-debt
    list and what step 10 fixed;
  - section 11: three test runners, goldens and update flow, benchmark
    commands, baselines, budget;
  - section 12: checklist additions (run all analyzers and test suites).
- [copilot-instructions.md](../copilot-instructions.md): update the layout
  block, drop the "no broad directory migration" exception sentence, and add
  `dart analyze` / `dart test` (engine) and `flutter analyze` / `flutter test`
  (host package) to Validation.
- [ROADMAP.md](./ROADMAP.md): fill in the measured numbers, record the budget in
  section 1, set Phase 0 to done in the status table.

## 5. Risks and open points

| Risk / question | Mitigation or default |
| --- | --- |
| `dart pub get` in a package consumed by a Flutter app | Step 0 spike; path dependencies by default |
| Three analyzers and test runners | Document commands; single validation checklist |
| Rust parity needs identical pixels, but Dart uses `double` and Rust likely `f32` | Exact goldens for Dart; the same goldens with small tolerances for Rust |
| Silent behavior change in the refactor | Step 0 hashes must match after every substep; goldens from step 8 |
| Optimizations change edge pixels | Step 10 accepts only golden-identical changes |
| `lib/testing/` ships `dart:io` code to the host | Acceptable (no web target); revisit if web is ever added |
| `Renderer.drawTriangle` with six coordinates is verbose | Named parameters; revisit when Phase 1 reorganizes the pipeline stages |
| Budget numbers are guesses before the baseline | Step 7 is after step 6 and revises the proposal |
| `ImmutableBuffer` copy semantics unknown | Verified in step 10 before removing the snapshot copy |

## 6. Definition of done

- `grep -r "dart:ui\|package:flutter" packages/software_engine` is empty, and
  the app `lib/` contains only `main.dart` and the game.
- `dart analyze` and `dart test` pass in `software_engine`; `flutter analyze`
  and `flutter test` pass in `software_engine_flutter` and the app, all with
  zero warnings.
- The AOT benchmark build produces JSON; a baseline is committed; budget
  numbers are in the roadmap.
- Goldens exist for every reference scene and pass.
- The fixed step is covered by tests, and the optimizations kept in step 10
  show measured gains over the baseline.
- The app renders the same image as before (step 0 hashes match; visual check).
- ARCHITECTURE.md and copilot-instructions.md describe the new structure.
