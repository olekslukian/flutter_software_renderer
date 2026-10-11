# Flutter Software Renderer

A small CPU-based 3D software renderer hosted by Flutter. The app currently
renders a rotating, filled cube into an engine-owned RGBA framebuffer; Flutter
converts each completed frame to an image and presents it with nearest-neighbor
scaling.

![Animated software-rendered cube demo](img/cube.gif)

## Rendering pipeline

- `CubeDemo` owns the cube geometry, face colors, animation, transform, and
  camera configuration.
- Engine math and camera types apply model transforms and project vertices to
  framebuffer coordinates and normalized depth.
- `Renderer` submits projected triangles to the CPU triangle rasterizer.
- A per-pixel depth buffer ensures nearer fragments occlude farther surfaces.
- `Engine` clears both buffers per frame and handles asynchronous conversion
  and presentation of framebuffer pixels as a Flutter image.

The current renderer rasterizes triangles into color and depth buffers. It does
not yet provide a scene graph, lighting, texture mapping, or near-plane
clipping.

## Run

```sh
flutter run
```

## Test

```sh
flutter test
flutter analyze
```
