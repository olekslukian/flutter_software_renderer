# Roadmap: from spinning model to retro boomer shooter

This is a planning document for people. It explains **what we are missing, why
each piece matters, and in what order to build it**. It deliberately contains
no implementation plan; each phase gets its own design when we start it.

- Current structure and rules: [ARCHITECTURE.md](./ARCHITECTURE.md). That
  document says what exists *today*; this one says where we are going.
- Update the status table (section 3) when a phase finishes, and update
  ARCHITECTURE.md in the same change (its "Not implemented" list shrinks as we
  go).

## 1. Goal and constraints

**Goal:** a low-poly, Quake-style boomer shooter: walk through levels, shoot
enemies, with textured surfaces, basic lighting and shading, rendered entirely
by our own CPU rasterizer hosted in Flutter.

Decisions made so far:

| Topic | Decision |
| --- | --- |
| Look | Authentic retro: low resolution, nearest-neighbor textures, lightmap-style lighting |
| Internal resolution / speed | 320x240 at 60 fps |
| Platforms | macOS, Windows, Android, iOS (no web, so Rust via FFI is fine) |
| Levels (for now) | Our own simple format, authored in Aseprite; no Quake BSP |
| Scope | Rendering **and** gameplay basics: player, enemies, weapons, collision |
| Rust | Move heavy math to Rust; exact timing recommended in Phase 5 |

### What a frame budget means here

60 fps leaves about **16.6 ms per frame** for everything: game logic,
rendering, and handing pixels to Flutter. A 320x240 image has **76,800
pixels**. Walls drawn on top of each other (overdraw) mean we may shade several
times that per frame. A pure-Dart rasterizer is the main risk to this budget,
which is why measurement (Phase 0) comes before features and Rust (Phase 5)
comes before big levels.

## 2. Big picture: what a software 3D renderer does

Every 3D renderer, from Quake to a modern GPU, is the same assembly line. We
already have some of the stations.

```text
 model data ──► vertex stage ──► clipping ──► culling ──► rasterization ──► pixel stage ──► framebuffer
 (mesh, UVs)   (move/rotate,    (cut what    (drop what  (which pixels    (texture, light,  (RGBA bytes
                project to      is outside   cannot be   does a triangle   fog, depth test)  shown by
                screen)         the view)    seen)       cover?)                             Flutter)
```

| Station | Status today |
| --- | --- |
| Vertex stage (model/view/projection) | Done |
| Clipping | **Missing** (triangles crossing the near plane are dropped) |
| Culling (back-face, off-screen, hidden) | **Missing** |
| Rasterization + depth buffer | Done (flat color, slow) |
| Pixel stage (texture, light, fog) | **Missing** |
| Level, player, enemies, input | **Missing** |

Everything in the roadmap fills one of the missing stations, speeds up an
existing one, or builds the game on top.

### Glossary (read once, refer back)

| Term | Meaning |
| --- | --- |
| **Vertex** | A point of a mesh, with a position and optional extra data (UV, normal, color). |
| **Triangle / polygon** | Three vertices. Everything is reduced to triangles because they are always flat and easy to fill. |
| **Model / world / view / clip / screen space** | The successive coordinate systems a vertex passes through, ending in pixel coordinates. |
| **Frustum** | The pyramid-shaped volume the camera can see. |
| **Clipping** | Cutting triangles against the frustum so nothing invalid reaches the rasterizer. |
| **Culling** | Skipping triangles or whole objects that cannot contribute to the image. |
| **Rasterization** | Turning a triangle into the set of pixels it covers. |
| **Fragment** | One candidate pixel produced by rasterization, before it is written. |
| **Depth buffer (z-buffer)** | Per-pixel nearest distance so closer surfaces hide farther ones. |
| **Overdraw** | Shading the same pixel more than once because surfaces overlap. |
| **UV** | 2D texture coordinates attached to a vertex. |
| **Normal** | The direction a surface faces; the input to all lighting. |
| **Lightmap** | A small texture holding precomputed light for a surface. |
| **Billboard / sprite** | A flat image that always faces the camera; how classic enemies are drawn. |
| **AABB** | Axis-aligned bounding box; the simple shape used for collision. |
| **FFI** | Foreign function interface; how Dart calls native (Rust) code. |

## 3. Phases at a glance

| # | Phase | Why it exists | Status |
| --- | --- | --- | --- |
| 0 | Foundations and measurement | Know our speed; fix the known slow spots before building on them | Not started |
| 1 | Correct geometry | Walking close to walls must not break the image | Not started |
| 2 | Surface data and correct interpolation | Textures and lighting need per-vertex data that interpolates correctly | Not started |
| 3 | Textures | Walls and enemies need to look like something | Not started |
| 4 | Lighting and shading | Depth and mood; the Quake look | Not started |
| 5 | Rust render core | Hit 320x240 at 60 fps with real levels | Not started |
| 6 | Levels and visibility | Turn a model viewer into a place you can walk through | Not started |
| 7 | Player, input, collision | Move through the level without leaving it | Not started |
| 8 | Entities, sprites, enemies, weapons | The shooter part | Not started |
| 9 | Presentation and polish | HUD, effects, audio, retro finishing touches | Not started |

Dependencies (an arrow means "needs"):

```text
0 ──► 1 ──► 2 ──► 3 ──► 4 ──► 5 ──► 6 ──► 7 ──► 8 ──► 9
                                      ▲
 level format and tools (Phase 6) can be designed in parallel from Phase 3 on
```

Phases are ordered by dependency, but small prototypes may overlap (for
example, a hard-coded textured room is a great test for Phases 2 to 4). Rust
(Phase 5) is placed after the pixel stage stabilizes, because porting an
unfinished, changing algorithm to a second language doubles the work of every
change.

---

## Phase 0: Foundations and measurement

**Why.** Optimizing without numbers is guessing, and later phases (textures,
lighting) multiply per-pixel work. The architecture document already lists the
slow spots: per-pixel object allocation, boxed `List<double>` depth storage,
color decoding on every pixel write, a full-image copy per frame, and a
bounding-box scan that recomputes everything per pixel.

**What we will do.**

- Define a performance budget (section 1) and a repeatable way to measure
  frame time, split into update, render, and presenting the image.
- Fix the cheap, known inefficiencies in the inner loop so later features are
  measured against a sane baseline.
- Decide on timing rules: a fixed simulation step with a variable render rate,
  so gameplay behaves the same at any frame rate.
- Add a small set of reference scenes and "known-good image" tests, so we can
  tell when a change (or the Rust port) alters the picture.

**Outcome.** A number for "ms per frame" on our reference scene on each
platform class (desktop and phone), and a test harness that can compare
images.

**Primer: why the inner loop dominates.** A mesh has hundreds of triangles,
but a screen has tens of thousands of pixels. Work per pixel is repeated
millions of times per second, so a single allocation or a slow byte-write there
costs more than the whole vertex stage.

**Risks.** Over-optimizing in Dart that we will throw away in Phase 5. Keep this
phase to cheap wins and measurement.

---

## Phase 1: Correct geometry (clipping and culling)

**Why.** Today a triangle with any vertex outside the depth range is simply
dropped, so walls vanish as you approach them. In a corridor shooter you are
always close to walls. This is the first thing that makes the renderer unusable
for a game.

**What we will do.**

- **Near-plane clipping:** cut triangles that cross the camera's near plane
  into the visible part (a triangle can become one or two triangles). Other
  planes can often be handled by simply limiting drawing to the screen.
- **Back-face culling:** skip triangles that face away from the camera. For
  closed objects this removes roughly half the triangles for free.
- **A precise pixel-coverage rule** (the "top-left rule") so two triangles
  sharing an edge never both draw, or both miss, the same pixel. This matters
  once we blend or have transparency.
- **Off-screen rejection** of whole objects, the first cheap step of culling.
- Organize the pipeline as clearly separate stages (vertex, clip, raster, pixel)
  because every later phase plugs into one of them.

**Outcome.** You can put the camera inside or against a model and the image
stays correct; winding order is a documented convention.

**Primer: why clipping happens before the perspective divide.** After
projection, a point *behind* the camera gets mirrored to a nonsensical position
in front of it. So triangles are cut in "clip space", before dividing by `w`
(the value that creates perspective foreshortening). The standard technique is
**Sutherland-Hodgman clipping**: walk the triangle's edges and keep or
interpolate points against one plane at a time.

**Primer: winding order.** A triangle's vertices go around clockwise or
counter-clockwise on screen. Fix one as "front". A flipped winding means the
triangle faces away.

---

## Phase 2: Surface data and perspective-correct interpolation

**Why.** Textures and lighting both rely on attaching extra values to vertices
(UVs, normals, light levels) and smoothly varying them across a triangle. Our
rasterizer currently only interpolates depth. Interpolating the rest naively
produces visibly warped textures.

**What we will do.**

- Extend the mesh to carry UVs, normals, and optionally vertex colors; extend
  the OBJ loader to read them (and materials).
- Make the rasterizer interpolate *any* per-vertex attribute, not just depth.
- Make that interpolation **perspective-correct**.
- Choose and document the quality model: perfect per-pixel correctness, or the
  cheaper approximations that classic games used (see primer).

**Outcome.** A triangle with a gradient or checkerboard UV displays without
warping at any angle; the same mechanism will carry light values later.

**Primer: affine vs perspective-correct.** A screen-space straight-line blend
of a texture coordinate (**affine**) looks right only when the surface is flat
to the camera. On a floor receding into the distance it swims and bends: the
famous PlayStation 1 wobble. The correct method interpolates `attribute / w`
and `1 / w` linearly in screen space, then divides per pixel. Quake did a
division only every 16 pixels and interpolated linearly in between, which is
visually close and much cheaper. We can pick either; it is a speed/accuracy
choice, and it is the kind of decision that Phase 5 will revisit.

---

## Phase 3: Textures

**Why.** Flat color makes every surface look the same. Textures are what turn
geometry into brick, metal, and monsters, and they are the largest part of the
Quake look.

**What we will do.**

- A **texture** type (pixel data, width, height) and loading from image assets.
- **Nearest-neighbor sampling** (the crisp, blocky retro look we chose),
  with tiling (repeat) for walls and floors.
- **Mip-mapping** (smaller pre-shrunk copies chosen by distance) as an optional
  quality step; it removes shimmering on distant surfaces.
- A **material** concept: which texture, and later how it is lit.
- Alpha testing (a pixel is either drawn or skipped) for fences, grates, and
  sprite edges.
- Decide the **color model** (see section 5, open decisions): plain RGBA, or
  an indexed palette like Quake's.

**Outcome.** A textured, tiling room renders correctly at 320x240; textures
come from standard image files authored in Aseprite.

**Primer: texture sampling.** For each pixel the rasterizer knows a UV. The
pixel stage turns UV into a texel (texture pixel) index and reads its color.
Texture sizes in power-of-two (64x64, 128x128) make wrapping cheap and match
retro assets. Small, memory-friendly textures also keep the CPU cache happy,
which matters more than anything for software rendering speed.

**Primer: palette (indexed) color.** Quake stores each pixel as an index into a
256-color palette. Lighting is then a table lookup: "this color at light level
N". It is fast and gives the signature look, but it is a bigger commitment than
RGBA.

---

## Phase 4: Lighting and shading

**Why.** Light is what makes space feel 3D, and Quake's moody dark corridors
are a defining part of the genre.

**What we will do (in increasing cost, each step usable on its own).**

1. **Flat shading:** one light value per triangle from its normal. The
   simplest possible lighting and a good test of normals.
2. **Gouraud shading:** compute light at vertices and interpolate it across the
   triangle (cheap, smooth, slightly blurry on big triangles).
3. **Lightmaps (the Quake approach):** light for static surfaces is
   **precomputed ("baked") offline** into small textures and multiplied with
   the surface texture at draw time. Costs almost nothing at runtime, and
   it allows shadows and soft pools of light.
4. **Dynamic lights** (muzzle flash, explosions): a cheap per-vertex or
   per-surface contribution added to the baked light.
5. **Distance fog / depth darkening:** fades distant surfaces to a color; gives
   atmosphere and hides draw distance.
6. A **light baking tool** (offline, can be slow, can be Rust or Dart) that
   fills lightmaps from level geometry and light entities.

**Outcome.** A lit room with shadowed corners, readable depth, and fog; a
visible muzzle flash on nearby walls.

**Primer: the lighting formula.** The basic model is *Lambert diffuse*:
brightness = `max(0, normal · direction-to-light)`. Plus a constant
**ambient** term so shadowed areas are not pitch black. Real-time per-pixel
lighting is affordable on a GPU but expensive on a CPU at every pixel. That is
exactly why 90s games baked light into lightmaps instead.

**Primer: shading models.** *Flat* (per triangle) < *Gouraud* (per vertex) <
*Phong* (per pixel). We do flat and Gouraud for models and lightmaps for
levels; true per-pixel lighting is out of scope unless we change the look
decision.

**Risks.** Lightmap baking requires level geometry with unique, non-overlapping
UVs for light, so this phase is best finished alongside the level format design
(Phase 6).

---

## Phase 5: Rust render core

**Why.** By now the per-pixel work includes depth test, perspective
correction, texture fetch, lightmap multiply, and fog, on a 76,800-pixel
image 60 times a second, with overdraw. This is the kind of tight numeric loop
where Rust is typically many times faster than Dart, and where Rust can use
**multiple CPU cores**. Dart isolates do not share memory cheaply, so
parallelizing the rasterizer in Dart is awkward. Rust also gives us predictable
performance, with no garbage collector in the hot loop.

**What moves to Rust, and what stays in Dart.**

| Rust (hot, numeric, data-parallel) | Dart / Flutter (everything else) |
| --- | --- |
| Vertex transform in bulk | App hosting, ticker, presenting the image |
| Clipping and culling | Game logic, AI, input, state machines |
| Rasterization, depth test | Asset loading and decoding |
| Texture sampling, lighting, fog | Menus and UI |
| Collision queries over the level (later) | Engine lifecycle and diagnostics |
| Optional: lightmap baking | |

**What we will do.**

- Define the narrow interface between the engine and a "render backend" (the
  architecture already anticipates this) and make the existing Dart rasterizer
  one implementation. It stays as a reference and a fallback, and as a
  test oracle for comparing images.
- Choose the build/binding approach for four targets (macOS, Windows, Android,
  iOS). Options to evaluate at that point: Dart's native-assets build hooks,
  `flutter_rust_bridge`, or a hand-written C interface with generated Dart
  bindings.
- Port the render core in slices, verifying each against the Dart reference.
- Share the framebuffer memory with Rust so pixels are written in place with
  no copying across the boundary.
- Add tile-based multi-threading in Rust once single-threaded is correct.

**Outcome.** Reference scenes meet the frame budget on all four platforms, with
headroom for the level and enemies; image tests prove the Rust output matches
the Dart reference.

**Primer: the FFI boundary is the real cost.** Calling Rust is cheap; calling
it a million times is not, and Rust cannot call back into Dart cheaply. So the
rule is: **few, large calls**, for example "here is this frame's batch of
meshes, draw them all", and flat typed arrays of numbers, never per-triangle
or per-pixel calls, never objects.

**Primer: data-oriented layout.** Rust (and the CPU cache) prefer big flat
arrays (positions, indices, UVs) over many small objects. Designing meshes and
textures as flat typed buffers in Phases 0 to 4 is what makes this port
mechanical instead of a rewrite.

**Why here and not earlier or later.**
- *Earlier* means rewriting the port each time clipping, interpolation, or the
  pixel stage changes.
- *Later* risks building a level and enemies that the Dart renderer cannot
  display at speed, then discovering it with no time to fix.
- If Phase 0 measurements show Dart is already far from the budget, bring
  the port forward after Phase 2; it is a checkpoint, not a fixed date.

**Risks.** Cross-compiling for iOS and Android ABIs; debugging across
languages; keeping two implementations in sync until the Dart one is retired
or frozen. Decide at the start of the phase whether the Dart renderer remains
a supported path.

---

## Phase 6: Levels and visibility

**Why.** So far we render one model. A game needs a **world**: walls, floors,
doors, spawn points, lights, and a way to draw only what the player can see.

**What we will do.**

- **Level format (ours):** start with the Aseprite approach: a top-down grid
  where each pixel or tile is a wall, floor, door, or spawn marker, extruded
  into 3D geometry by a loader. Per-cell data (wall texture, floor height,
  light) lives in extra layers or a small data file next to the image.
- **Level builder:** turns the grid into the mesh the renderer already
  understands, with UVs for textures and lightmaps.
- **Visibility, in order of cost:**
  1. Frustum culling: skip what is outside the view.
  2. Sector/room division with **portals** (doorways): only draw rooms
     reachable through visible openings. Natural for a grid/room layout.
  3. Front-to-back drawing so the depth test rejects hidden pixels early.
- **Level lights and entities** declared in the level data (spawns, light
  positions, pickups).
- Keep the format **replaceable**: a later move to an editor like TrenchBroom
  (real Quake `.map`) should only change the loader, not the renderer.

**Outcome.** A multi-room textured, lit level that renders within budget while
you move the camera freely.

**Primer: why visibility matters more than raw speed.** Cost scales with
overdraw. Drawing the whole level and letting the depth buffer sort it out
wastes most of the work. Quake's answer was BSP trees plus precomputed
visibility sets; we use portals and sectors, which suit our simpler levels and
give most of the benefit.

**Primer and trade-off: grid levels.** A grid is the quickest path to a
playable level, and Aseprite can author it directly. Its limits are no sloped
floors, no overlapping rooms, and blocky shapes. That is acceptable now. The
loader-only boundary above keeps the door open.

**Risks.** Level format design is the choice hardest to change once content
exists. Prototype it with a tiny level first.

---

## Phase 7: Player, input, and collision

**Why.** Without these, it is still a viewer. Game feel (movement and aim) is
the core of a boomer shooter.

**What we will do.**

- **Input** captured at the Flutter boundary (keyboard and mouse on desktop,
  touch controls on Android/iOS) and handed to the engine through a plain
  interface that contains no Flutter types.
- **First-person camera:** yaw (turn) and pitch (look up/down) controls; a
  perspective camera driven by the player rather than hard-coded.
- **Fixed-step movement:** acceleration, friction, and strafing; Quake-style
  fast, slippery movement is a design decision to make here.
- **Collision:** the player (and later enemies) as a box or cylinder against
  level geometry, with **sliding** along walls instead of stopping dead, plus
  gravity and steps/stairs if the level format allows heights.
- Basic **scene** concept (a place to hold level and entities) introduced
  only when this phase needs it, as the architecture rules require.

**Outcome.** You can run around the level at a stable 60 fps and cannot walk
through walls.

**Primer: collision.** Never test the player against every triangle. Use a
simple shape for the mover and a spatial lookup for the world; on a grid that
is a few cell checks per frame. "Slide" response means: if the move is blocked,
remove the part of the velocity that points into the wall.

**Primer: why a fixed time step.** Variable-length steps make jumps higher on
fast machines and let fast objects tunnel through walls. A fixed step makes
physics reproducible and testable.

**Risks.** Touch input on phones is a genuine design problem for an FPS
(virtual sticks, aim assist); decide the mobile control scheme before building.

---

## Phase 8: Entities, sprites, enemies, and weapons

**Why.** This is the "shooter".

**What we will do.**

- **Entity model:** a small system for things with a position that update
  and draw (player, enemies, projectiles, pickups, doors).
- **Sprites/billboards** for enemies and items, with **sorting** by distance
  and per-pixel depth testing against walls. (Quake used 3D models for
  enemies; sprites are far cheaper and a valid retro choice. A decision to
  make: see section 5.)
- **Animated models** (frame-by-frame mesh swapping like Quake's MDL) if we
  choose 3D enemies.
- **Weapons:** a first-person "viewmodel" drawn last in its own depth range so
  it never clips into walls; muzzle flash light from Phase 4.
- **Shooting:** hitscan (instant ray) first, projectiles after. Needs ray
  casts against the level and enemy boxes.
- **Enemy AI:** a simple state machine (idle, chase, attack, hurt, die), with
  line-of-sight checks and movement using Phase 7 collision.
- **Health, damage, pickups, doors, level end.**
- **Transparency** where needed (particles, effects): dithered ("screen-door")
  transparency is retro-appropriate and avoids blending order problems.

**Outcome.** A short playable arena: enemies chase and can be killed, the
player can be hurt, weapons feel responsive.

**Primer: why billboards need depth care.** A sprite is a flat quad that
faces the camera but still sits at a position in 3D. It must be depth-tested
against the world so it can hide behind a corner, and drawn after opaque
geometry.

**Primer: hitscan.** The shot is a ray from the camera; find the nearest thing
it hits (wall or enemy box). No projectile simulation needed, so it is the right
first weapon.

---

## Phase 9: Presentation and polish

**Why.** Turns a tech demo into something that feels like a game.

**What we will do.**

- **2D drawing:** HUD (health, ammo), bitmap fonts, crosshair, menus. Drawn
  as a final layer on the framebuffer.
- **Audio** (outside the renderer; Flutter/plugin-level integration behind an
  engine interface): shots, footsteps, ambient, music.
- **Retro finishing:** optional palette reduction, ordered dithering, and
  integer scaling of the 320x240 image to the window.
- **Effects:** particles, screen flashes on damage, simple explosions.
- **Game flow:** title screen, level loading, death and restart, settings.
- **Quality of life:** debug overlay (frame time, triangle and overdraw
  counts), configurable resolution and controls.
- Final performance pass across all four platforms.

**Outcome.** A start-to-finish playable slice of the game.

---

## 4. Cross-cutting concerns (apply to every phase)

- **Tests:** every behavior change comes with a test; reference-image tests
  from Phase 0 guard the renderer, and the Dart-vs-Rust comparison guards the
  port.
- **Architecture discipline:** engine content stays reusable and game content
  stays under `app/game/`; keep Flutter-specific code at the host boundary.
  Update [ARCHITECTURE.md](./ARCHITECTURE.md) when a phase changes the
  structure.
- **Performance:** re-measure at the end of each phase; a regression is a bug.
- **Assets:** a simple, documented pipeline (Aseprite → image/JSON → loader)
  so content authoring is repeatable.
- **Diagnostics:** keep using the typed errors and diagnostics already in the
  engine; new data (textures, levels) fails with specific exceptions.

## 5. Open decisions

These do not block Phase 0 but must be answered by the phase named.

| Decision | Options | Needed by |
| --- | --- | --- |
| Color model | Plain RGBA with an optional retro palette filter at the end, **or** an indexed 256-color palette like Quake (cheaper lighting, stronger commitment). Leaning RGBA first, because it keeps content authoring simple. | Phase 3 |
| Interpolation quality | Exact per-pixel perspective correction, or Quake-style correction every N pixels. | Phase 2 (revisit in 5) |
| Enemy representation | Billboard sprites (cheapest, Doom-style) or low-poly animated 3D models (Quake-style). | Phase 8, but affects asset work from Phase 3 |
| Rust binding approach | Native-assets hooks, `flutter_rust_bridge`, or hand-written C interface. | Start of Phase 5 |
| Dart renderer's future | Keep as a supported fallback, or freeze as a test reference only. | Start of Phase 5 |
| Level baking tool | Dart, Rust, or an external tool. | Phase 4 |
| Mobile control scheme | Virtual sticks, gyro aim, aim assist. | Before Phase 7 |
| Movement feel | Quake-style (air control, fast) or grounded and simple. | Phase 7 |

## 6. Suggested first milestone

Phases 0 to 2 together produce the first visible win: **a clipped, back-face
culled, perspective-correct textured surface you can walk the camera up to**.
That is the smallest result that proves the pipeline is shaped correctly for
everything after it.
