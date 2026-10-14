# How this project turns a 3D model into an image

A newcomer's guide to the rendering pipeline. No graphics background is
assumed. By the end you should be able to explain how a list of 3D points in a
`.obj` file becomes colored pixels on screen, and find the Dart code that does
each step.

> This guide is written for people. It describes the project as it is today.
> For layer rules, ownership, and conventions, see
> [ARCHITECTURE.md](../docs/ARCHITECTURE.md).

## 1. The big idea

A screen is a grid of pixels. A 3D model is a bundle of numbers (points in
space). **Rendering** is everything that happens in between.

Most apps let the GPU do this work. This project is a **software renderer**:
plain Dart code on the CPU decides the color of every pixel and writes it into
a block of memory. Flutter's only jobs are to host the app, tick a clock, and
show the finished picture as an image. Flutter never draws the model's
triangles.

Why build it this way? Because every step is visible, debuggable Dart code
instead of a black box. It is slow compared to a GPU, so the image is small
(160 × 120 pixels in the app) and then scaled up.

## 2. The pipeline in one picture

Almost every 3D renderer, GPU or CPU, follows the same stages. Here they are
with the matching part of this project:

```text
 3D model (triangles)         Mesh                      loaded from an .obj file
        │
        ▼
 1. Place it in the world     Transform3                move / rotate / scale
        │
        ▼
 2. Look at it from a camera  Camera                    "where is the viewer?"
        │
        ▼
 3. Flatten 3D to 2D          PerspectiveCamera         far things look smaller
        │
        ▼
 4. Find covered pixels       TriangleRasterizer        "rasterization"
        │
        ▼
 5. Keep the nearest surface  DepthBuffer               "depth test"
        │
        ▼
 6. Store the color           SoftwareFramebuffer       a grid of RGBA bytes
        │
        ▼
 7. Show it                   Engine + EngineScreen     bytes -> Flutter image
```

Stages 1–3 work on **vertices** (corner points) and are about *geometry*.
Stages 4–6 work on **pixels** and are about *coverage and color*. Stage 7 is
Flutter. Keep this split in mind; it is the shape of the whole project.

### Key terms

| Term | Plain meaning |
|---|---|
| Vertex | A point in 3D space: `(x, y, z)`. |
| Triangle | Three vertices. Every surface is built from triangles because three points always form a flat shape. |
| Mesh | A list of vertices plus a list saying which triples form triangles. |
| Matrix | A grid of numbers that moves, rotates, scales, or projects points when multiplied with them. |
| Rasterization | Deciding which pixels a triangle covers. |
| Framebuffer | The pixel grid being drawn into. Here: 4 bytes per pixel (red, green, blue, alpha). |
| Depth buffer | A second grid storing how far away the nearest thing drawn at each pixel is. |
| Fragment | A candidate pixel produced by a triangle, before the depth test decides whether it is kept. |
| Delta time | Seconds since the previous tick. Used to animate at a speed independent of frame rate. |

## 3. Who does what in the app

```text
main.dart ──► App ──► EngineScreen ──► Engine ──► Renderer
 (Flutter)   (picks     (Flutter       (frame      (draws into
              the game)  widget +       loop,       color + depth
                         clock)         image)      buffers)
                             │
                             └──► Game  ◄── ModelViewDemo (the content)
```

- [`main.dart`](../../lib/main.dart) calls `runApp(App())`.
- [`App`](../../lib/app/app.dart) builds a `MaterialApp` showing
  `EngineScreen(game: ModelViewDemo(width: 160, height: 120))`.
- [`EngineScreen`](../../lib/engine/engine_screen.dart) is the Flutter side:
  it creates the `Engine`, runs a `Ticker` (a callback fired every display
  refresh), and displays the result with a `RawImage`.
- [`Engine`](../../lib/engine/engine.dart) is the reusable core. It owns the
  `Renderer`, runs the frame sequence, and turns pixels into a Flutter image.
- [`Game`](../../lib/engine/game.dart) is a small contract (`initialize`,
  `update`, `render`) that content implements. Think of it as "what to show".
- [`ModelViewDemo`](../../lib/app/game/model_view_demo/model_view_demo.dart) is
  the current game: it loads a model, spins it, and asks the renderer to draw it.

The engine is the *how*, the game is the *what*, and Flutter is the *where*.
That is why the model, color, and camera position live in the demo and not in
`engine/`.

## 4. Following one model through the pipeline

### Step 0: Loading the model (once)

`Engine.initialize()` waits for `game.initialize()` before drawing anything,
because asset loading is asynchronous and an early frame would be empty.

`ModelViewDemo.initialize()` calls
[`Mesh.loadFromAsset`](../../lib/engine/graphics/mesh.dart) on
[`penger.obj`](../../assets/models/penger.obj) (the folder is registered in
[`pubspec.yaml`](../../pubspec.yaml)). The parser reads a Wavefront OBJ file:

```text
v 1.0 0.0 0.0       a vertex position
v 0.0 1.0 0.0
v 0.0 0.0 1.0
f 1 2 3             a face: a triangle from vertices 1, 2, 3
```

Details worth knowing:

- OBJ counts vertices from 1; negative numbers count back from the latest
  vertex. Both become ordinary zero-based list positions.
- A face with more than three corners is split into triangles by a *fan*
  (corner 1 plus each neighboring pair).
- Texture and normal references (`1/2/3`) are accepted but only the position
  is used. Materials are ignored.

The result is an **indexed mesh**: positions are stored once in `vertices`,
and `indices` lists triples such as `[0, 2, 1]` meaning "triangle from vertices
0, 2, and 1". Neighboring triangles share corners instead of repeating them.

Bad input (malformed lines, out-of-range references, empty or non-finite data)
throws a specific engine exception instead of rendering garbage.

Next, `Mesh.normalized()` produces a copy that is centered at the origin and
uniformly scaled so its largest dimension is 2 units. Any OBJ file then fits
the same camera, and rotating it spins it around its own center.

### Step 1: Placing it in the world (every frame)

Models are authored in their own coordinate space. A **model matrix** says
where the model sits in the shared "world". [`Transform3`](../../lib/engine/math/transform3.dart)
stores position, rotation (radians), and scale, and builds that matrix.

Every tick, `EngineScreen` computes `deltaTime` and calls `Engine.update`.
Once initialized, the engine calls `ModelViewDemo.update`, which advances the
Y rotation by `1.2 * deltaTime` and derives X and Z from it. Scaling by elapsed
time keeps the spin speed the same on 60 Hz and 120 Hz displays.

### Step 2: The camera

The [`Camera`](../../lib/engine/graphics/camera/camera.dart) holds a position,
a target to look at, and an up direction. From these it builds a **view
matrix**, which re-expresses the world as seen from the camera. The demo's
camera sits at `(0, 0, 4.5)` looking at the origin.

### Step 3: Flattening 3D to 2D

[`PerspectiveCamera`](../../lib/engine/graphics/camera/perspective_camera.dart)
adds a **projection matrix** with a 60° vertical field of view. It squeezes the
visible 3D volume so that distant things end up smaller, like in real vision.

[`MeshPipeline`](../../lib/engine/graphics/mesh_pipeline.dart) multiplies the
three matrices once per mesh: **projection × view × model** (often called
MVP). Then, for each vertex:

1. Multiply the vertex by MVP. The result is a 4-component "clip position"
   `(x, y, z, w)`. The extra `w` is what makes perspective shrinking and
   translation possible with matrices.
2. Divide by `w` (the *perspective divide*). Now x, y, z are in a normalized
   box from -1 to 1.
3. Map x and y to **pixel coordinates**, flipping y because screen y grows
   downward.
4. Map z to a **depth** from 0 (near) to 1 (far).

The output for each vertex is a pixel position and a depth. `MeshPipeline` keeps
these in lists that are reused across frames. A vertex that cannot be projected
(its `w` is zero) gets a depth of `NaN`, so only the triangles using it are
dropped and the frame continues.

### Step 4: Rasterization - which pixels does a triangle cover?

[`Renderer.drawMesh`](../../lib/engine/graphics/renderer.dart) walks the index
list three entries at a time and hands each triangle to
[`TriangleRasterizer`](../../lib/engine/graphics/triangle_rasterizer.dart):

1. Take the triangle's 2D bounding box, clamped to the framebuffer.
2. For each pixel in the box, test its center point against the triangle's
   three edges (an *edge function*: which side of the edge is this point on?).
   A pixel inside all three edges is covered.
3. Both clockwise and counterclockwise triangles work. A zero-area triangle
   covers nothing.

### Step 5: The depth test - what is in front?

If you just painted triangles in file order, a far triangle drawn late would
cover a near one. The
[`DepthBuffer`](../../lib/engine/graphics/buffers/depth_buffer.dart) fixes this:

- It stores one number per pixel, reset to infinity at the start of each frame.
- For every covered pixel the rasterizer blends the three vertex depths into
  that pixel's depth.
- The pixel is written **only if** its depth is smaller than what is stored.

So the nearest surface wins regardless of drawing order.

### Step 6: Writing color

A pixel that passes the depth test is written into the
[`SoftwareFramebuffer`](../../lib/engine/graphics/buffers/software_framebuffer.dart),
a `Uint8List` with 4 bytes per pixel in R, G, B, A order. The whole model uses
one flat color (`modelColor`, a teal). At the start of each frame
`Renderer.beginFrame()` clears the color buffer to the game's clear color and
the depth buffer to infinity.

### Step 7: From bytes to the screen

The software image is only memory until Flutter shows it. After the game has
drawn, `Engine`:

1. Copies the framebuffer bytes (`snapshot()`), so the next frame can't change
   them while they are being converted.
2. Converts the copy into a `ui.Image` with Flutter's `ImmutableBuffer`,
   `ImageDescriptor`, and `Codec`. This step is asynchronous.
3. Swaps in the new image and calls `notifyListeners()`.

`EngineScreen` listens and rebuilds a `RawImage` with `BoxFit.contain`
(keep aspect ratio) and `FilterQuality.none` (nearest-neighbor, so enlarged
pixels stay crisp).

Because conversion is asynchronous, ticks can arrive while one is running.
The engine then just remembers that another frame is wanted and renders the
*latest* game state when the conversion finishes. The simulation keeps advancing
every tick; only presentation is coalesced. Temporary objects and replaced
images are disposed, and a conversion that finishes after the engine is
disposed is discarded.

## 5. One frame as a timeline

```text
Ticker fires (every display refresh)
  EngineScreen: deltaTime = time since last tick
  Engine.update(deltaTime)
    ModelViewDemo.update      rotate the model, rebuild its matrix
    request a frame
      (if an image conversion is running: remember and stop here)
      Renderer.beginFrame     clear color + depth
      ModelViewDemo.render    -> Renderer.drawMesh
        configure camera for the framebuffer size
        MeshPipeline          project every vertex (steps 1-3)
        for each triangle     skip if outside depth range,
                              else rasterize + depth test + write (steps 4-6)
      framebuffer snapshot
      async convert to ui.Image (step 7)
      notifyListeners -> RawImage repaints
      if another frame was requested meanwhile: render again
```

## 6. When things go wrong

- **Errors:** a failure in `initialize`, `render`, or image conversion is caught
  by `Engine`, stored as `Engine.renderError`, and shown on screen as
  `Render failed during <phase>: <message>`.
- **Warnings:** problems that do not stop the frame (unprojectable vertices,
  triangles outside the depth range) go through a `DiagnosticSink`. They are
  logged, and in debug builds a tappable warning banner appears.
- **Skipped triangles:** the renderer skips any triangle with a vertex whose
  depth is outside 0..1 or not finite. This is a stand-in for real *clipping*
  (cutting triangles at the camera's near and far planes). A triangle
  crossing those planes can vanish instead of being trimmed, so bringing the
  model very close to the camera makes parts disappear.

## 7. What this renderer does not do yet

Real graphics pipelines have more stages than this project implements. Today
there is **no**:

- Clipping against the near and far planes (see above).
- Back-face culling (skipping triangles that face away from the camera).
- Lighting or shading: the model is one flat color, so it looks like a
  silhouette with no sense of form.
- Textures, UV coordinates, materials, or vertex normals.
- Orthographic cameras (the `Camera` base class is ready for them).
- Scene graph, input handling, or alternative rendering backends.

These are natural next steps; the order above roughly follows how much each
changes the pipeline. When you add one, update this guide and
[ARCHITECTURE.md](../docs/ARCHITECTURE.md).

## 8. Try it yourself

Small edits that make each stage visible. Run with `flutter run`.

| Change | File | What you learn |
|---|---|---|
| Change `modelColor` | [model_view_demo.dart](../../lib/app/game/model_view_demo/model_view_demo.dart) | Color is flat; the framebuffer stores exactly what you give it. |
| Change `width` and `height` | [app.dart](../../lib/app/app.dart) | Resolution is the framebuffer size; Flutter just scales it. |
| Change the rotation speed `1.2` | [model_view_demo.dart](../../lib/app/game/model_view_demo/model_view_demo.dart) | `deltaTime` makes speed independent of frame rate. |
| Move the camera closer (e.g. `z = 1.5`) | [model_view_demo.dart](../../lib/app/game/model_view_demo/model_view_demo.dart) | Perspective grows near objects; you will also see triangles vanish from the missing clipping. |
| Change `verticalFieldOfView` | [perspective_camera.dart](../../lib/engine/graphics/camera/perspective_camera.dart) | A wider field of view makes the model smaller and more distorted. |
| Try `real-penger.obj` as `modelAssetPath` | [assets/models/](../../assets/models/) | Normalization lets different models share one camera. |

## 9. Where to look in the code

| File | Responsibility |
|---|---|
| [`lib/main.dart`](../../lib/main.dart) | Flutter entry point. |
| [`lib/app/app.dart`](../../lib/app/app.dart) | Builds the app and picks the game. |
| [`lib/app/game/model_view_demo/model_view_demo.dart`](../../lib/app/game/model_view_demo/model_view_demo.dart) | Current game: loads, normalizes, spins, and draws the model. |
| [`lib/engine/engine_screen.dart`](../../lib/engine/engine_screen.dart) | Flutter host: ticker, image display, error and warning UI. |
| [`lib/engine/engine.dart`](../../lib/engine/engine.dart) | Lifecycle, frame scheduling, image conversion, cleanup. |
| [`lib/engine/game.dart`](../../lib/engine/game.dart) | The contract games implement. |
| [`lib/engine/graphics/renderer.dart`](../../lib/engine/graphics/renderer.dart) | Owns the buffers; `beginFrame`, `drawMesh`, `drawTriangle`. |
| [`lib/engine/graphics/mesh_pipeline.dart`](../../lib/engine/graphics/mesh_pipeline.dart) | MVP and per-vertex projection. |
| [`lib/engine/graphics/mesh.dart`](../../lib/engine/graphics/mesh.dart) | OBJ parsing, validation, normalization. |
| [`lib/engine/math/transform3.dart`](../../lib/engine/math/transform3.dart) | Position, rotation, scale to model matrix. |
| [`lib/engine/graphics/camera/camera.dart`](../../lib/engine/graphics/camera/camera.dart) | View matrix, viewport, world-to-pixel projection. |
| [`lib/engine/graphics/camera/perspective_camera.dart`](../../lib/engine/graphics/camera/perspective_camera.dart) | Perspective projection matrix. |
| [`lib/engine/graphics/triangle_rasterizer.dart`](../../lib/engine/graphics/triangle_rasterizer.dart) | Pixel coverage, depth interpolation, pixel writes. |
| [`lib/engine/graphics/buffers/software_framebuffer.dart`](../../lib/engine/graphics/buffers/software_framebuffer.dart) | RGBA pixel storage. |
| [`lib/engine/graphics/buffers/depth_buffer.dart`](../../lib/engine/graphics/buffers/depth_buffer.dart) | Per-pixel nearest depth. |
| [`lib/engine/diagnostics/`](../../lib/engine/diagnostics) | Warning and error reporting. |
| [`lib/engine/errors/engine_exception.dart`](../../lib/engine/errors/engine_exception.dart) | Typed exceptions for bad meshes and projection failures. |

### Tests as a map of the concepts

| Test | Covers |
|---|---|
| [`mesh_test.dart`](../../test/mesh_test.dart) | OBJ parsing, triangulation, normalization, validation. |
| [`transform3_test.dart`](../../test/transform3_test.dart) | Model transforms. |
| [`camera_test.dart`](../../test/camera_test.dart) | Projection and viewport rules. |
| [`mesh_renderer_test.dart`](../../test/mesh_renderer_test.dart) | `MeshPipeline` and `Renderer.drawMesh` output. |
| [`software_framebuffer_test.dart`](../../test/software_framebuffer_test.dart) | Buffers, rasterizer, depth ordering, per-frame clearing. |
| [`widget_test.dart`](../../test/widget_test.dart) | `EngineScreen` presenting frames. |

Run `flutter test` and `flutter analyze` to check the project.
