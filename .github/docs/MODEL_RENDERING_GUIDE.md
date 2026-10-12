# How this project turns a 3D model into an image

This guide follows one frame from app startup to the pixels shown on screen.
The short version is:

```text
Flutter starts the app
  -> EngineScreen creates Engine and starts the game
  -> ModelViewDemo loads and prepares the OBJ mesh
  -> each tick updates the model rotation
  -> the camera projects vertices onto a 2D pixel grid
  -> Renderer fills triangles into color and depth buffers
  -> Engine converts the color buffer into a Flutter image
  -> RawImage displays that image
```

The renderer in this project is a **software renderer**: Dart code calculates
which pixels triangles cover and writes their colors into memory. Flutter hosts
the app and displays the finished image; Flutter is not drawing the model's
triangles itself.

## 1. App startup and ownership

1. [`main.dart`](lib/main.dart) calls Flutter's `runApp` with `App`.
2. [`app.dart`](lib/app/app.dart) creates a `MaterialApp` whose home is
   `EngineScreen(game: ModelViewDemo(...))`.
3. [`EngineScreen`](lib/engine/engine_screen.dart) is the Flutter host. It
   creates an `Engine`, initializes it, and starts a Flutter `Ticker`.
4. [`Engine`](lib/engine/engine.dart) owns the reusable rendering machinery:
   a `Renderer`, its color framebuffer, the depth buffer, and the most recent
   Flutter image.
5. [`Game`](lib/engine/game.dart) is the small contract for content hosted by
   the engine. A game initializes, updates its state, and submits drawing work.
   [`ModelViewDemo`](lib/app/game/model_view_demo/model_view_demo.dart) is the
   current game implementation.

This separation is intentional: Flutter handles the app and screen lifecycle;
the engine coordinates frames and drawing; the demo supplies a model and its
behavior. The current engine does not yet own a scene graph, lighting system,
or a complete multi-stage graphics pipeline.

## 2. Loading the model

During `Engine.initialize()`, the engine awaits `game.initialize()` before
requesting the first frame. This matters because the model is an asynchronous
Flutter asset: drawing before it is loaded would produce an empty frame.

`ModelViewDemo.initialize()` loads
[`real-penger.obj`](assets/models/real-penger.obj) through
[`Mesh.loadFromAsset`](lib/engine/graphics/mesh.dart), using Flutter's
`rootBundle`. The asset directory is registered in [`pubspec.yaml`](pubspec.yaml).

`Mesh.fromObj()` reads the parts of the Wavefront OBJ format this renderer
needs:

- `v x y z` lines become 3D vertex positions.
- `f ...` lines describe faces by referring to vertices.
- OBJ vertex numbers start at 1; negative numbers count backward from the
  vertices already read. The parser converts both forms into zero-based Dart
  list positions.
- A face may have more than three corners. It is split into triangles by
  connecting its first corner to each adjacent pair (a triangle fan).
- OBJ references can also include texture and normal numbers, but this parser
  ignores those parts. Material-library files and material assignments are
  not rendered.

The result is an indexed mesh: `vertices` stores positions once, and `indices`
stores triples saying which three positions make each triangle. For example,
indices `[0, 2, 1]` mean “make a triangle using vertices 0, 2, and 1.” This
avoids repeating a shared corner for every neighboring face.

## 3. Preparing and animating the mesh

The OBJ can use any size and origin. `_prepareMesh()` in
[`ModelViewDemo`](lib/app/game/model_view_demo/model_view_demo.dart):

1. Checks that the index list makes complete triangles, indices point to real
   vertices, and vertex coordinates are finite.
2. Finds the model's minimum and maximum x, y, and z coordinates (its bounds).
3. Moves the bounds' center to `(0, 0, 0)`.
4. Uniformly scales the largest dimension to 2 units.

Centering before rotating makes the model spin around its own center instead
of around some distant origin in the original file. Uniform scale preserves
the model's shape.

`Transform3` holds position, rotation, and scale. `updateMatrix()` combines
them into one model matrix. In this project the order is translation, then
rotation around Z, Y, and X, then scale (the resulting matrix is applied to a
point with scale first, then X/Y/Z rotations, then translation). Rotation values
are radians.

On every ticker callback, `EngineScreen` calculates elapsed time since the
previous callback and passes it to `Engine.update(deltaTime)`. Once
initialization is complete, the engine calls `game.update(deltaTime)`. The demo
increases its Y rotation by `1.2 * deltaTime`, derives its X and Z rotations,
and rebuilds the transform matrix. Multiplying by elapsed time makes the
rotation depend on time rather than on a particular display refresh rate.

## 4. From each 3D point to a screen pixel

For each frame, `ModelViewDemo.render()` does this for every prepared vertex:

1. **Model transform:** `Transform3.transformPosition()` moves the vertex from
   model-local coordinates into world coordinates. A fourth coordinate,
   `w = 1`, lets the matrix include translation.
2. **Camera setup:** `PerspectiveCamera.configureViewport()` builds a view
   matrix from the camera position, target, and up direction, then builds a
   perspective projection using the framebuffer's width and height.
3. **Projection:** `PerspectiveCamera.project()` maps the world point through
   the view and projection matrices. Perspective makes distant parts look
   smaller.
4. **Viewport mapping:** the projected x/y position is converted from a
   normalized range into framebuffer pixel coordinates. The y direction is
   flipped because screen pixels increase downward.
5. **Depth:** the projected depth is converted to the normalized range `0..1`.
   Smaller depth means closer to the camera; larger depth means farther away.

The demo stores the transformed positions, screen positions, and depths in
lists allocated during mesh preparation. Reusing these lists avoids allocating
new per-vertex working objects every frame.

## 5. Turning triangles into pixels

The demo walks the index list three entries at a time. Each triple picks three
projected vertices and calls `Renderer.drawTriangle()` with their screen
positions, depths, and the demo's single cyan color.

The draw path is:

```text
Renderer.drawTriangle()
  -> TriangleRasterizer.fillWithDepth()
     -> test candidate pixel centers against triangle edges
     -> interpolate depth for covered pixels
     -> ask DepthBuffer whether each fragment is visible
     -> write passing pixels into SoftwareFramebuffer
```

[`TriangleRasterizer`](lib/engine/graphics/triangle_rasterizer.dart) is the
part that answers “which pixels belong to this triangle?” It takes the
triangle's 2D bounding box, limits that box to the framebuffer, and tests each
candidate pixel at its center. Edge tests work for either clockwise or
counterclockwise vertex order. A triangle with zero area covers no pixels.
This is called **rasterization**.

For each covered pixel, the rasterizer interpolates a depth from the three
vertex depths. [`DepthBuffer`](lib/engine/graphics/buffers/depth_buffer.dart)
stores one depth per pixel. It starts at infinity each frame. A fragment is
written only if its depth is smaller than the depth already stored there. So a
near surface can replace a far surface even if the far triangle was submitted
later. This visibility check is the **depth test**.

[`SoftwareFramebuffer`](lib/engine/graphics/buffers/software_framebuffer.dart)
stores the actual image data: four bytes per pixel in red, green, blue, alpha
(RGBA) order. `setPixel()` replaces those bytes with the chosen color. Its
`drawLine()` helper is available but is not part of the model's triangle
rendering path. At the start of each frame, `Renderer.beginFrame()` clears the
color buffer to the game's clear color and clears all depth values.

## 6. Getting the software frame onto the Flutter screen

After the game has submitted the triangles, `Engine` takes a **copy** of the
framebuffer bytes with `snapshot()`. The copy is important: asynchronous image
decoding must not read memory while the next frame is changing it.

The engine passes the copied RGBA pixels to Flutter's image APIs
(`ui.ImmutableBuffer`, `ui.ImageDescriptor`, and `ui.Codec`) to create a
`ui.Image`. When decoding finishes, it publishes the image with
`notifyListeners()`. `EngineScreen` listens through `AnimatedBuilder` and
displays that image with `RawImage`.

The game renders at its configured resolution (currently 320 × 240 pixels).
`BoxFit.contain` scales that image to fit the available screen without
stretching its aspect ratio. `FilterQuality.none` uses nearest-neighbor
sampling, which keeps the software pixels crisp when enlarged.

Image conversion is asynchronous. If more ticker updates ask for a frame while
conversion is in progress, the engine remembers that another frame is needed
and renders the latest game state when the conversion completes. It does not
start an unlimited queue of conversions for old intermediate frames. Temporary
decoder objects and replaced images are disposed; the engine also prevents an
in-flight conversion from publishing after disposal.

## 7. What happens when something goes wrong

- Invalid OBJ syntax, faces with invalid vertex references, or unusable mesh
  data fail initialization or mesh preparation.
- Errors from initialization, rendering, or image conversion are exposed as
  `Engine.renderError`; the screen displays `Render failed: ...`.
- The demo currently skips a whole triangle if any of its projected vertex
  depths is outside `0..1`.

That last behavior is deliberately simpler than full clipping. The camera
projects vertices, but does not cut triangles at the near plane or far plane.
A triangle crossing those planes may disappear rather than being correctly
trimmed. Screen-space raster bounds are clamped to the framebuffer.

## 8. Current scope and the role of each file

The current pipeline draws solid-color triangles and resolves their visibility.
It does **not** yet use OBJ materials, textures, vertex normals, lighting, or
back-face culling. The project has a perspective camera and software color and
depth buffers, but it is not yet a general-purpose scene or graphics engine.

| File | Responsibility |
|---|---|
| [`lib/main.dart`](lib/main.dart) | Flutter application entry point. |
| [`lib/app/app.dart`](lib/app/app.dart) | Builds the app and chooses the demo game. |
| [`lib/engine/engine_screen.dart`](lib/engine/engine_screen.dart) | Flutter widget host, ticker, error display, and image display. |
| [`lib/engine/game.dart`](lib/engine/game.dart) | Lifecycle contract that game content implements. |
| [`lib/engine/engine.dart`](lib/engine/engine.dart) | Initialization, frame scheduling, rendering coordination, async image conversion, and cleanup. |
| [`lib/app/game/model_view_demo/model_view_demo.dart`](lib/app/game/model_view_demo/model_view_demo.dart) | Loads and normalizes the model, animates it, projects vertices, and submits triangles. |
| [`lib/engine/graphics/mesh.dart`](lib/engine/graphics/mesh.dart) | OBJ asset loading and indexed triangle mesh data. |
| [`lib/engine/math/transform3.dart`](lib/engine/math/transform3.dart) | Position, rotation, scale, and model-matrix transform. |
| [`lib/engine/graphics/camera/perspective_camera.dart`](lib/engine/graphics/camera/perspective_camera.dart) | Camera matrices and world-to-screen projection. |
| [`lib/engine/graphics/renderer.dart`](lib/engine/graphics/renderer.dart) | Frame clearing and triangle-rasterizer entry point. |
| [`lib/engine/graphics/triangle_rasterizer.dart`](lib/engine/graphics/triangle_rasterizer.dart) | Triangle coverage, depth interpolation, and pixel writes. |
| [`lib/engine/graphics/buffers/software_framebuffer.dart`](lib/engine/graphics/buffers/software_framebuffer.dart) | CPU-side RGBA pixel storage. |
| [`lib/engine/graphics/buffers/depth_buffer.dart`](lib/engine/graphics/buffers/depth_buffer.dart) | Per-pixel nearest-surface depth values. |
| [`assets/models/real-penger.obj`](assets/models/real-penger.obj) | The OBJ model loaded by the demo. |
| [`pubspec.yaml`](pubspec.yaml) | Flutter dependencies and asset registration. |

## 9. Tests as a map of the concepts

The tests exercise the pipeline in layers:

- [`mesh_test.dart`](test/mesh_test.dart): OBJ vertices, triangulation, and
  positive/negative OBJ indices.
- [`camera_transform_test.dart`](test/camera_transform_test.dart): model
  transforms and camera projection.
- [`software_framebuffer_test.dart`](test/software_framebuffer_test.dart):
  pixel storage, depth testing, triangle filling, and frame clearing.
- [`model_view_test.dart`](test/model_view_test.dart): actual mesh loading,
  rendering, and animation.
- [`widget_test.dart`](test/widget_test.dart): image presentation by the
  Flutter host widget.

To check the project, run `flutter test` and `flutter analyze`.
