# Flutter Software Renderer

A small CPU-based 3D software renderer hosted by Flutter. The app loads a
Wavefront OBJ mesh and renders it into an engine-owned RGBA framebuffer; Flutter
converts each completed frame to an image and presents it with nearest-neighbor
scaling.

The animation below shows the earlier cube depth-buffer demo; the app now loads
the OBJ model described below.

![Animated software-rendered cube demo](img/cube.gif)

## Rendering pipeline

- `ModelViewDemo` loads indexed triangle geometry from an OBJ asset, normalizes
  it with `Mesh.normalized()`, and animates its transform.
- The `Camera` hierarchy (`PerspectiveCamera` today) and `MeshPipeline` project
  vertices to framebuffer coordinates and normalized depth.
- `Renderer.drawMesh` submits projected triangles to the CPU triangle rasterizer.
- A per-pixel depth buffer ensures nearer fragments occlude farther surfaces.
- `Engine` clears both buffers per frame and handles asynchronous conversion
  and presentation of framebuffer pixels as a Flutter image. It waits for game
  initialization before requesting the first frame.

The current renderer rasterizes triangles into color and depth buffers. It does
not yet display OBJ materials or textures, calculate lighting, or clip
triangles crossing the camera's near plane; faces outside the depth range are
skipped for now.

## Run

```sh
flutter run
```

## Test

```sh
flutter test
flutter analyze
```
