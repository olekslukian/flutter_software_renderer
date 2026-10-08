# Flutter software renderer

This project draws a rotating 3D triangle with a CPU software rasterizer.

The game writes RGBA pixels into a low-resolution framebuffer. The engine
converts each completed buffer into a Flutter image, and `EngineScreen` scales
that image to the available space with nearest-neighbor filtering. Flutter's
canvas is not used to draw the triangle itself.

Run the app with `flutter run` and the tests with `flutter test`.
