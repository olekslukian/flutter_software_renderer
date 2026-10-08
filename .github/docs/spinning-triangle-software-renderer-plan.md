# Spinning Triangle Software Renderer Plan

## Goal

Render a spinning, filled 3D triangle by writing pixels into a CPU-owned
framebuffer, then display the resulting `ui.Image` in Flutter. This establishes
the rendering path that can later support a software-rendered 3D game.

## Implementation steps

1. **Introduce a CPU framebuffer**
   - Add a renderer-owned, low-resolution RGBA pixel buffer, initially around
     320×240 pixels.
   - Provide operations to clear the buffer and safely write a pixel.
   - Keep rasterization independent of Flutter's `Canvas`.

2. **Create triangle scene data and transforms**
   - Define three vertices in 3D space.
   - Rotate the vertices over time and project them into framebuffer
     coordinates using the existing `vector_math` dependency.
   - Keep the triangle in front of the camera for this first milestone. Add
     general near-plane clipping when the renderer grows to support more
     complex geometry.

3. **Rasterize the filled triangle**
   - Implement a software triangle fill using edge functions or barycentric
     coordinates.
   - Restrict iteration to the triangle's screen-space bounding box.
   - Test pixel centers for coverage and write one flat color to covered
     framebuffer pixels.

4. **Convert the framebuffer into an image**
   - Convert the RGBA bytes into a `dart:ui` `Image`.
   - Make the engine API produce an image from game-rendered pixels instead of
     asking games to draw onto a `Canvas`.

5. **Display the image in `EngineScreen`**
   - Replace the existing `CustomPaint`/`EnginePainter` presentation path with
     a `RawImage` that displays the latest `ui.Image`.
   - Scale the image to fit the available space and use nearest-neighbor
     filtering for a crisp pixel-art appearance.
   - Keep the existing ticker to drive animation updates.

6. **Handle frame and image lifecycles**
   - Account for image conversion completing asynchronously.
   - Prevent an older frame from replacing a newer one.
   - Dispose of replaced images and the final image when the engine is disposed.
   - Define a policy that avoids overlapping image conversions without control.

7. **Test the rendering path**
   - Add focused tests for framebuffer writes and triangle pixel coverage.
   - Add a widget test that verifies `EngineScreen` presents an image.
   - Verify that advancing time changes the triangle's position or orientation.

## Expected files and migration

The main existing files to update are:

- `lib/engine/engine_screen.dart`
- `lib/engine/engine.dart`
- `lib/engine/game.dart`

Add framebuffer and rasterizer code, a triangle demo, and focused tests. The
existing `EnginePainter` and cube demo can remain on the canvas path until this
new pipeline is proven; then migrate the cube to triangles.

## Acceptance criteria

- The triangle is visibly filled and spins as the ticker advances.
- The triangle's pixels are produced by the software rasterizer, not by drawing
  its geometry through `Canvas`.
- `EngineScreen` displays the renderer-produced `ui.Image`.
- Framebuffer and widget tests pass, and images are disposed of correctly.

## Next milestone

Add a depth buffer, then near-plane clipping and back-face culling. These enable
multiple triangles to form a cube with correct visibility.
