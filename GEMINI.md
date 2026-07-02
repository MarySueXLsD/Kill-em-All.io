# EdenSpark Framework

## Required MCP Tools

Before writing any code or making any changes, verify that both MCP tools are available:

- **EdenSpark MCP** — provides live interaction with the scene editor (create nodes, run cheats, take screenshots, inspect the scene). Check with `/mcp` in the Gemini CLI console.
- **Context7 MCP** — provides up-to-date EdenSpark and Daslang documentation. Always use it to look up APIs, components, and syntax instead of relying on training data.

**If either tool is missing, stop and ask the user to fix the setup before proceeding:**

> "EdenSpark MCP is not connected. Please make sure the Eden editor is running and open this project from the launcher. Run `/mcp` to check connected tools."

> "Context7 MCP is not connected. Please make sure `.gemini/settings.json` in this project includes the `context7` entry under `mcpServers`, then restart Gemini CLI."

Do not attempt to generate or edit game code until both tools are confirmed available.

### How to use Context7

Always fetch documentation before using any EdenSpark API or Daslang feature you are not certain about:
1. Call `resolve-library-id` with `"EdenSpark"` or `"Daslang"` to get the library ID
2. Call `query-docs` with a specific question (e.g. `"how to create a RigidBody component"`)

Never rely on training data for EdenSpark or Daslang APIs — always verify with Context7.

### How to use EdenSpark MCP

EdenSpark MCP gives you live access to the running editor and game. Use it to observe, control, and verify — not just to write code blindly.

#### Recommended workflow

Follow this sequence when working on a game:

1. **Check status** — call `get_game_status`. If there are compilation errors, fix them before doing anything else.
2. **Inspect the scene** — use `scene_children` (depth 2-3) to understand what nodes exist before writing code that references them.
3. **Look up APIs** — use Context7 `query-docs` for any EdenSpark component or Daslang feature you are about to use.
4. **Write and save** — edit `.das` files. The editor hot-reloads on save. After saving, call `get_game_status` to confirm compilation succeeded.
5. **Verify visually** — call `get_screenshot` to confirm the game looks correct.
6. **Test interactions** — use `list_cheat_commands` to discover game-specific test hooks, then `exec_cheat` to trigger them. Use input tools to simulate player input.
7. **Step through logic** — pause with `game_pause`, then use `game_next_frame` to advance frame-by-frame when debugging timing issues.


## Documentation

Use documentation for EdenSpark and Daslang from Context7 in the first place.
If Context7 is not available use local documentation bundled with EdenSpark:

- **API reference (RST):** `C:/Users/syanavi/AppData/Local/EdenSpark/docs`

In case you couldn't find required functionality in documentation look into usages in samples bundled with EdenSpark:

- **Sample projects:** `C:/Users/syanavi/AppData/Local/EdenSpark/samples`

## Project Architecture

When building or extending an EdenSpark game, follow this layered module structure. It scales from small prototypes to multi-thousand-line projects and avoids the tangle that comes from putting everything in `main.das`. Read this section before adding code — putting things in the wrong file is the single most common source of refactor pain.

### Recommended Module Layout

Split the codebase into the following kinds of files. Smaller projects can collapse some, but the layering rules still apply.

| Kind | Suggested filename | Holds | Never holds |
|------|--------------------|-------|-------------|
| Engine entry | `main.das` | `[export]` hooks (`on_initialize`, `on_update`, `on_resolution_changed`, etc.), `[cheat]` debug commands, scene-infrastructure construction (camera, lights, render settings, UI canvas, render targets) | Domain logic, per-entity per-frame work |
| Constants | `constants.das` | `let public UPPER_SNAKE` tunables only | `var`, mutable state, classes, helper functions |
| Mutable state | `game_state.das` (or `state.das`) | `var public camelCase` cross-module mutable state, scene-infrastructure NodeIds, world geometry constants shared across systems | Tunables, helpers, classes |
| Per-X data | e.g. `level_data.das`, `room_data.das` | A struct describing one slot of repeated state (one level, one room, one wave) plus a deep-move helper for slot rotation | Spawning logic, per-frame logic |
| Shared components | e.g. `components.das` | Small reusable Components used across multiple domain modules | Domain-specific Components |
| Math / utility | e.g. `ik.das`, `math.das` | Pure helpers, no scene side-effects | State, resource handles |
| Domain modules | one per system: `player.das`, `enemies.das`, `ai.das`, `pickups.das`, `world.das`, `collision.das`, `particles.das`, `sounds.das`, etc. | Controller Components, `spawn_*` factories, `load_*` resource requests, queries, system-local helpers | `[export]` engine hooks |

Modules form a one-way dependency graph: domain modules require shared utilities and state; `main.das` requires everything; nothing requires `main.das`. Avoid cycles — if you find one, the shared piece belongs in a lower layer (constants, state, or a helper module).

### Core Patterns

**1. Per-frame work belongs in a Component, not a global update loop.**

Every animated, AI-driven, or timer-based entity owns a Component with `def override on_update`. `main.das on_update` is reserved for cross-cutting passes that span entities (e.g. proximity collision checks, global state machines). New animated entity → new Component.

```das
class Thing : Component {
    timer : float = 0.0
    speed : float = 1.0

    def override on_update {
        let dt = get_delta_time()
        timer += dt
        // per-entity logic here
    }
}
```

**2. Resource loading is centralized at startup.**

Every prefab, material, texture, and sound has the same shape:

```das
// in the owning domain module
var public thingPrefab : PrefabId

def public load_thing_prefab() {
    thingPrefab = request_prefab("assets/thing.prefab")
}
```

Then call `load_thing_prefab()` once from `main.das on_initialize`. Never request resources lazily inside `on_update` or spawn paths.

**3. State separation is strict.**

| Kind of value | Where it lives | Convention |
|---------------|----------------|------------|
| Static tunable (radius, speed, duration, color) | constants module | `let public UPPER_SNAKE = ...` |
| Mutable runtime variable read by ≥2 modules | state module | `var public camelCase = ...` |
| Repeated slot of state (one level, one wave, one room) | per-X-data struct, instances stored in state module | array fields per entity category |
| Per-entity state | fields on the controller Component | |
| Module-private state | `var private` at module top | only visible inside that module |

Multiple values of the same kind should be placed inside multiline value declaration:
```
let public {
    UPPER_SNAKE = ...
    FOO = ...
}
```
A new tunable always goes in the constants module; never inline it in the module that happens to use it first. A new shared runtime variable always goes in the state module; never at module scope of a domain module.

**4. Cross-module communication is via shared state, not back-references.**

Modules read and write the state module's globals. They do not import each other to call update methods, and they do not pass NodeIds "up" to `main`. The global update function does not iterate per-entity arrays — entities tick themselves through their Components.

**5. Engine entry points live only in `main.das`.**

- `[export] def on_initialize()` — call every `load_*()`, build scene infrastructure (camera, lights, render settings, render targets, UI canvas), spawn the player, spawn the initial slot of per-X state.
- `[export] def on_update()` — global state machine (menu / fade / play), then cross-cutting passes. Per-entity work happens in Components.
- `[export] def on_resolution_changed(res : int2)` — recreate render targets at the new dimensions, rescale camera-attached quads (store the original aspect at init and scale by `newAspect / initialAspect`), resize UI canvas frames. Anything sized to `get_resolution()` at init must be wired up here.
- `[cheat] def name()` — debug shortcuts callable from the editor console.

Domain modules never declare `[export]` functions.

**6. Spawn factories follow a consistent shape.**

```das
def public spawn_thing_into(var slot : XData; count : int) {
    for (i in range(count)) {
        let node = create_node(NodeData(position = ..., scale = ...))
        // or: instantiate_prefab(thingPrefab, NodeData(...))
        add_component(node, new Mesh(meshId = ..., color = ..., visibility = VIS_MAIN))
        add_component(node, new Thing(...))   // per-frame logic
        push(slot.thingNodes, node)
    }
}
```

The factory takes the slot it spawns into, builds node + components, and pushes into the appropriate slot array. Visibility is set explicitly. The controller Component owns per-entity state — no parallel module-level array of "current things" alongside the slot's array.

### Decision Tree — "Where do I put this?"

- **A tuning number** (radius, speed, duration, color, threshold) → constants module as `let public`.
- **A runtime variable read by ≥2 modules** → state module as `var public`.
- **A new prefab / sound / material asset** → `var public` in the owning domain module + `load_*()` function + call from `on_initialize`.
- **Something that spawns once per slot** (level, room, wave) → add field to the per-X-data struct, write `spawn_x_into(var slot : XData; ...)` factory, call from the slot's spawn function, free in the slot's clear function.
- **Per-frame animation / AI / timer on a specific entity** → new Component class with `on_update`, attached at spawn. Don't add a global loop in main.
- **A cross-cutting per-frame pass** (touching many entities at once) → function in a domain module, called once from `main.das on_update`. Prefer Components when possible.
- **A debug shortcut** → `[cheat] def name()` in `main.das`.
- **An engine callback** (`on_initialize`, `on_update`, `on_resolution_changed`, `on_destroy`, etc.) → only in `main.das`. Never in a domain module.
- **Code that reacts to viewport resize** (render targets, cam-attached quads, UI canvases) → wire it into `on_resolution_changed`.

### Common Mistakes

- **Putting logic in `main.das on_update` instead of a Component** — bloats the global loop, defeats the "entities tick themselves" pattern, makes it hard to add or remove entity types.
- **Defining tunables inside a domain module** — they belong in the constants module so every module can share them and tune in one place.
- **Aliasing scalar fields during slot deep-move** — copy then explicitly zero `NodeId` and primitive fields on the source, or both slots will reference the same node and a later sweep on one will mutate the other.
- **Loading prefabs / materials / sounds lazily inside `on_update` or a spawn function** — always centralize in a `load_*()` called from `on_initialize`. Lazy loads cause first-use hitches and make resource lifetime hard to reason about.
- **Adding `[export]` functions outside `main.das`** — engine entry points are exclusively main's job. The export annotation outside main makes the entry point hard to find and confuses the layering.
- **Building UI / scene meshes that depend on viewport size without wiring `on_resolution_changed`** — anything sized to `get_resolution()` at init must be rebuilt or rescaled on resize.
- **Modules requiring each other to call update methods or pass NodeIds back to main** — communicate exclusively through the state module. If module A needs something from module B that the state module doesn't already expose, expose it on the state module rather than introducing a back-reference.
- **Leaving textures on the wrong filter/addressing** — causes noticeable artifacts (edge bleed, shimmer). Pixel/2D → `Point`+`Clamp`, 3D material textures → `Bilinear`+`Wrap`, set in each `<texture>.png.meta`. See **Textures — Filtering & Addressing**.

## Language: Gen2 daScript

Eden user scripts use Gen2 daScript — a statically typed scripting language with C-like braces syntax. This is the "Gen2" variant which uses braces `{}` and parentheses `()` instead of the original Python-like indentation-based syntax.

## Core Syntax Rules

### Braces and Parentheses — Always Required
- Functions ALWAYS use braces: `def foo() { ... }`
- Conditions ALWAYS use parentheses AND braces: `if (x > 0) { ... } elif (x == 0) { ... } else { ... }`
- Loops ALWAYS use parentheses AND braces: `for (i in range(10)) { ... }`, `while (condition) { ... }`

### Variables
- `let` for immutable, `var` for mutable
- Module-level constants: `UPPER_SNAKE_CASE`
- Prefer `let` over `var` when value won't change

### Type Annotations
Type annotations use `:` after the name. Optional when type can be inferred: `let x : int = 5`, `var nodes : array<NodeId>`, `var arr : NodeId[15]` (fixed-size)

### Functions
- `def name(params) : ReturnType { ... }` — return type optional when inferrable
- Default values: `def setup(speed : float = 1.0) { ... }`
- Generic/untyped parameter: `def set_status(str) { ... }` (type inferred)

### String Interpolation
Use `{}` inside string literals: `print("position: {position}")`, `text.text = "{get_current_score()}"`

### Modules and Imports
- `require engine.core` — import engine modules
- `require MyModule` — import local modules (same project)
- `module mod` — declare a module (comes after `require` statements)
- `module trackSegmentGen public` — `public` re-exports imports

### Export Annotation
Functions called by the engine must have `[export]`: `[export] def on_initialize() { ... }`

## Type System

### Primitive Types
`int`, `uint`, `float`, `double`, `bool`, `string`

### Vector/Math Types
`float2`, `float3`, `float4`, `int2`, `int3`, `uint3`, `quat4`

### Constructors
- `float3(0)` — shorthand for `float3(0, 0, 0)`
- `quat4(0, PI * 0.3f, 0)` — euler angles in radians
- Both `1.0` and `1f` are float literals; `2.1lf` is double

### Arrays
- Dynamic: `var cubes : array<NodeId>`, use `resize()`, `push()`
- Fixed-size: `var arr : NodeId[15]`
- Literal with move: `var arr <- [a, b, c]`
- `fixed_array(...)` for typed fixed arrays

### Tables (Hash Maps)
`var map <- { "key" => value }`, access with `map.get_value(key)`

### Structs
`struct Name { field : type = default }`, construct with `Name()` or `Name(field = val)`

### Enums
`enum Name { Value1 = 0, Value2 = 1 }`, access with `Name.Value1`

### Move Semantics
Use `<-` for move assignment (transfers ownership): `return <- mesh`, `var bitmap <- Bitmap(w, h)`

## Classes and Components

### Component Classes
Components inherit from `Component`, attach to scene nodes. Override `on_initialize`, `on_update`, `on_destroy`. Fields are public/serialized by default.

### Visibility Modifiers
- `private` — private field or method
- `@no_export` — field not serialized to prefab
- Methods can be `public`, `private`, `abstract`

### Collision Listeners
Inherit from `CollisionListener`, override `on_collision(c : Collision)`, `on_collision_stay(c : Collision)`, `on_collision_exit(node : NodeId)`

### Method Syntax
Methods can omit `()` when no parameters: `def override on_update { ... }`

## Control Flow

- `if / elif / else` — note: `elif` not `else if`
- `for (i in range(10)) { }`, `for (i in 0 .. n) { }` (half-open range)
- Multiple iterators (zip): `for (node, i in nodes, count()) { }`
- Ternary: `let val = (cond ? a : b)`
- Variant matching: `if (cmd is Type) { let x = cmd as Type; ... }`

## Blocks and Lambdas

- **Blocks** (capture by reference): `$(args) { body }` — used as last argument after `)`
- **Lambdas** (function pointers, no capture): `@@(args) { body }`
- **Closures** (capture outer vars): `@(args) { body }`
- No-arg lambda: `@() { ... }`
- Block as last argument goes after closing `)`: `get_component(nodeId) $(var mesh : Mesh?) { ... }`

## Scene API Patterns

### Creating Nodes
`create_node()` or `create_node(NodeData(name = "cube", position = ..., rotation = ..., parent = ..., scale = ...))`

### Adding Components
`add_component(node, new Mesh(meshId = CUBE_MESH_ID))` — returns component pointer. Method syntax: `node.add_component(...)`

### Getting Components
- Block-based (safe): `get_component(nodeId) $(var text : UIText?) { ... }`
- Type-based: `var cam = get_component(node, type<Camera>)`
- Safe navigation: `var cam = node?.Camera`
- Require (creates if missing): `require_component(node, type<Camera>)`
- Find globally: `find_component(type<UICanvas>)`, `find_components(type<CameraFocus>)`, `find_components(array)`

### Node Properties
- Position/rotation/scale: `nodeId.localPosition`, `nodeId.worldPosition`, `nodeId.localRotation`, `nodeId.localScale`
- `nodeId.name`, `nodeId.isActive`, `nodeId.isAlive`, `nodeId.parent`
- `set_position(node, pos)`, `set_scale(node, scale)`
- Parenting: `nodeId.set_parent(parent, AddChildStrategy.KeepLocalTransform)`
- Children: `nodeId.get_children()`, `get_child(node, index)`
- `remove_node(nodeId)`, `duplicate_node(original, NodeData(...))`

### Prefabs
`request_prefab("path.prefab")` then `instantiate_prefab(prefab, NodeData(...))`

## Project Settings (manifest.blk)

Project-wide settings live in `manifest.blk` at the project root (DataBlock format). The editor normally writes them via **Preferences → Project** tab, but they can also be edited by hand.

### Default prefab (startup scene)
Which prefab opens when the project is entered.

```
defaultPrefab:t="<prefab-guid>"
```

- The value is the prefab's **GUID**, not its file path. Every prefab has a sidecar `<name>.prefab.meta` file whose first entry is the GUID — copy it from there.
- Set via UI: **Preferences → Project → Default scene**.
- **No editor restart needed** — takes effect the next time the project is opened.

### HD rendering
High-definition rendering for the project.

```
hdRendering:b=yes
```

- Defaults to `no` (omit the key to disable).
- Set via UI: **Preferences → Project → HD rendering**.
- **Restart the editor to apply changes** — the rendering scene is chosen once at startup, so toggling this mid-session does nothing until you restart. The UI shows a "Restart required" popup for the same reason.

## Annotations
- `[export]` — expose to engine
- `[cheat]` — register as cheat command
- `[hot_reload_class]` — class survives hot-reload

## Code Style Conventions

### Naming
- Variables/parameters: `camelCase`
- Functions: `snake_case` for utilities, `camelCase` for methods/callbacks
- Constants (module-level `let`): `UPPER_SNAKE_CASE`
- Classes/Structs/Enums: `PascalCase`
- Enum values: `PascalCase`

### Formatting
- 4 spaces indentation
- Opening brace on same line
- 2 blank lines between top-level functions; 1 between methods in a class
- `//` comments, `////` lines for section dividers

### Patterns
- UFCS: both `f(x)` and `x.f()` valid; pipe: `grid |> resize(n)`
- `inscope` for scoped lifetime: `var inscope children = nodeId.get_children()`
- String interpolation preferred over concatenation
- `pass` for empty bodies

## Known Gen2 Syntax Pitfalls

### No Semicolons Between Statements
Each statement must be on its own line. Semicolons between statements cause silent compilation failure.

### No Inline If-Braces for Vector/Struct Assignments
`if (cond) { var = float4(...) }` on a single line causes compilation failure for vector types. Always use multiline blocks.

### No Early Returns of Vector Types
Cannot use `if (x) { return float4(...) }`. Use a mutable variable with a single return at the end.

### Compilation Errors Are Often Silent
Engine reports "compilation failed" but error text is frequently empty/truncated. Debug by bisecting — comment out half the code until error is found.

### Enum/Bitfield Access Syntax
Use dot notation: `MeshVisibility.VisibleInAnyCamera`. Some engine enums use space syntax: `MouseButton Left` — try dot first.

## Deprecated Functions — Do Not Use

A subset of the engine API is marked deprecated. **You may not ship a game that calls a deprecated function** — the publish build fails the call as a hard error; in the editor it surfaces as a warning. If you find an existing project using one, replace it with the recommended alternative.

## Input — Action Sets

Bind logical actions (e.g. `"acceleration"`, `"jump"`, `"fire"`) to one or more physical inputs (keyboard keys, mouse buttons, gamepad sticks/buttons). The same action works across keyboard, mouse, and gamepad without per-frame edge-detection or per-device branching.

### Defining and Activating an Action Set
```das
def init_input() {
    add_and_activate_action_set("input", {
        "acceleration" => Action(
            axisActions = AxisAction(
                keyboardAxis = [
                    KeyboardBtnAxisInput(negativeIdx = KeyCode.S, positiveIdx = KeyCode.W),
                ],
                stickAxis = [GamepadAxisInput(idx = GamepadAxis.LThumbV)]
            )
        ),
        "jump" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx = KeyCode.Space)],
                gamepadButtons = [GamepadButtonInput(idx = GamepadButton.A)],
            )
        )
    })
}
```
Call `init_input()` once from `on_initialize`.

`Action` is a variant — pick the field matching the input shape: `buttonActions` (digital, edge-detected), `axisActions` (1D ±1), `triggerActions` (1D 0..1), `joystickActions` (2D ±1), `pointerActions` (mouse cursor).

### Reading Actions Per Frame
- `get_action_axis("name") : float` — analog axis in `[-1, 1]` (sticks, or +1/-1/0 from keyboard pairs)
- `get_action_vector2("name") : float2` — 2D analog (sticks, or paired keyboard axes)
- `is_action_pressed("name") : bool` — true while the button action is held down
- `is_action_just_pressed("name") : bool` — true on the frame the button becomes pressed (press edge)
- `is_action_just_released("name") : bool` — true on the frame the button is released (release edge)
- `is_action_state_active("name") : bool` — true if the action is enabled and returns a non-default value (works for both buttons and axes)

No manual previous-frame tracking — the action API gives you edges directly.

### Mouse Position
Use `get_ui_mouse_position(nodeId)` on a child of a `UICanvas`. Returns `float3`: offset from viewport center, Y axis points DOWN. To convert to pixel coordinates, calibrate viewport center using `cam.worldToScreen(float3(0,0,0))` at init, then: `pixel = float2(uiPos.x + viewOffX, uiPos.y + viewOffY)`.

## Mesh Creation

- Sphere: `create_sphere_mesh(SphereInit(subdivisions = 24, radius = 0.5))`
- Cylinder: `create_cylinder_mesh(CylinderInit(height = 1.4, radius = 0.28))` — default axis Y
- Custom: `create_mesh(geo)` from `create_sphere_mesh_geometry(...)` (requires `engine.gen_geometry.mesh_structures`)
- Visibility: `node?.Mesh.visibility = MeshVisibility.VisibleInAnyCamera` (no shadows), `MeshVisibility.FullVisibility` (default)

## Physics / Ray Picking

### Collider Setup
`add_component(node, new Collider(shape = box_shape()))` — also `sphere_shape(radius=...)`, `cylinder_shape(radius=..., height=...)`. Colliders work without Mesh.

### Raycasting
`trace(RayCast(ray = ray)) $(hit) { ... }` — only detects nodes with Collider or RigidBody. Hit provides: `position`, `nodeId`, `normal`, `distance`. For all hits: `trace_all(rayCast) $(hits) { ... }`

## Camera

- Orthographic: `cam.orthographic = true; cam.orthographicSize = 8.0`
- `cam.screenToRay(float2(px, py))` — screen pixels to world ray
- `cam.worldToScreen(float3(x,y,z))` — world to screen pixels (z = depth)
- `cam.screenToWorldDepth(float2(px,py), depth)` — screen to world at depth
- `quat4(rx, ry, rz)` — rotation in radians: `quat4(PI*0.5, 0, 0)` = 90° around X

## UI System

### Core Architecture
- All UI elements must be children of a node with `UICanvas`. A `Camera` must exist for UI to render.
- **UIFrame** is the fundamental positioning/sizing primitive. Auto-added by UIText, UIAnchor, and layout components.
- Every UIFrame that participates in layout or anchoring **must have its size set explicitly**, except:
  - UIText with `autoResizeFrame = true` (auto-sizes from text content)
  - Children force-expanded by parent layout (`childForceExpandWidth`/`childForceExpandHeight`)

### UICanvas Frame Size — CRITICAL
The UICanvas node's UIFrame defaults to **0x0**. UIAnchor computes positions relative to parent UIFrame. If canvas frame is 0x0, all anchors resolve to (0,0) — everything stays centered. **Always set the canvas frame size**:
```
get_component(canvasNode) $(var frame : UIFrame?) {
    frame.size = float2(946.0, 763.0)  // match viewport
}
```

### UIAnchor
Positions a node relative to parent UIFrame. Coordinate system: **(0,0) = top-left, (1,1) = bottom-right**.

**Pivot matters**: Default pivot (0.5,0.5) aligns the *center* at the anchor point. For edge anchoring, set pivot to match the anchor corner:
- Top-right anchor: `set_frame_pivot(node, float2(1.0, 0.0))`
- Right-center anchor: `set_frame_pivot(node, float2(1.0, 0.5))`

### UIAnchor + Layout Components
UIAnchor and layout components (UIVerticalLayout, UIHorizontalLayout) **CAN be on the same node**. What does NOT work: UIAnchor on children of layout components.

Valid: `node [UIAnchor + UIVerticalLayout]` → `child [UIText]`, `child [UIText]`
Invalid: `node [UIVerticalLayout]` → `child [UIAnchor]`

### UIText + UIAnchor — Required Settings
For UIAnchor to control UIText positioning, you **MUST** set both:
1. `node?.UIText.fontScaling = false`
2. `node?.UIText.autoResizeFrame = true`

Without both, UIAnchor has no effect on UIText nodes.

### Layout Components
- **UIVerticalLayout**: `spacing`, `padding` (float4: left,top,right,bottom), `alignment` (e.g. `LayoutAlignment.MiddleRight`), `childForceExpandWidth`, `childForceExpandHeight`
- **UIHorizontalLayout**: Same properties, arranges left-to-right
- Children **must have UIFrame** to participate in layout

### fast_ui Functions (Preferred for Building UI from Code)
Much more concise than manual component creation. Supports pipe `|>`.

**Creating elements:**
- `text("content")` — text node with UIText + UIFrame
- `vbox(children)` / `hbox(children)` — layout containers
- `panel(size, children)` — sized panel
- `flow(children)` — flow layout

**Modifying elements (return NodeId for chaining):**
- `set_text_font_size(node, size)`, `set_text_color(node, color)`
- `set_frame_size(node, size)`, `set_frame_pos(node, pos)`, `set_frame_pivot(node, pivot)`
- `set_spacing(node, value)`, `set_padding(node, float4)`
- `add_anchor(node, float2)` — anchorMin=anchorMax to same point
- `add_anchor(node, anchorMin, anchorMax)` — stretch anchor

**Example — text anchored to top-right:**
```
dayText = text("MON\n0") |> set_text_font_size(28.0) |> set_text_color(float4(0.12, 0.12, 0.15, 1.0))
dayText.set_parent(canvasNode, AddChildStrategy.KeepLocalTransform)
dayText?.UIText.fontScaling = false
dayText?.UIText.autoResizeFrame = true
add_anchor(dayText, float2(1.0, 0.0))
set_frame_pos(dayText, float2(-15.0, 15.0))
set_frame_pivot(dayText, float2(1.0, 0.0))
```

**Example — vbox anchored to right-center:**
```
var children : array<NodeId>
for (i in range(3)) {
    let lnode = text("O") |> set_text_font_size(32.0) |> set_text_color(color)
    lnode?.UIText.fontScaling = false
    lnode?.UIText.autoResizeFrame = true
    push(children, lnode)
}
let panel = vbox(children) |> set_spacing(10.0)
panel.set_parent(canvasNode, AddChildStrategy.KeepLocalTransform)
add_anchor(panel, float2(1.0, 0.5))
set_frame_size(panel, float2(50.0, 200.0))
set_frame_pivot(panel, float2(1.0, 0.5))
```

### Other UI Components
- `UIButton`: `new UIButton()`, set `onClick = @() { ... }`
- `create_debug_text(text, topLeftMargin, anchor)` — quick debug overlay, self-contained canvas

### UI Pitfalls
1. **Canvas frame 0x0**: All anchors resolve to center. Always set canvas frame size.
2. **fontScaling not disabled**: UIAnchor has no effect on UIText.
3. **autoResizeFrame not enabled**: UIText frame stays 0x0, invisible to layouts/anchors.
4. **Default pivot (0.5,0.5)**: Elements anchored to edges get half-clipped off-screen.
5. **UIAnchor on layout children**: Does not work. Anchor the container, not children.
6. **Missing UIFrame on layout children**: Children without UIFrame are ignored by layouts.

## Utility Functions
- `get_delta_time()` — frame delta time in seconds
- `show_mouse_cursor(true/false)` — show/hide system cursor
- `remove_node(nodeId)` — destroy a scene node
- `nodeId.isAlive` — check if node still exists
- `create_render_settings()` — required once for rendering to work

## Textures — Filtering & Addressing

Visible texture artifacts (edge bleeding, blurry or shimmering pixels) almost always come from the wrong **filter** + **addressing** combination. Set both per texture in its sidecar `<texture>.png.meta` file:

- `filter:t="Point"` — nearest-neighbour, crisp texels (no blur/shimmer)
- `filter:t="Bilinear"` — smooth interpolation between texels
- `addressing:t="Clamp"` — UVs outside `0..1` clamp to the edge (no wrap-around bleed)
- `addressing:t="Wrap"` — UVs tile/repeat

**Pick by game type:**
- **Pixel-art / 2D sprite games → `Point` + `Clamp`.** Point keeps pixels sharp; Clamp stops neighbouring sprites or atlas tiles bleeding across UV edges.
- **3D games where textures feed materials → `Bilinear` + `Wrap`.** Bilinear smooths surfaces; Wrap lets tiling materials repeat. Keep `generateMipLevels:b=yes` and `anisotropicLevel:i=4` for surfaces seen at grazing angles.

When unsure, default to **`Clamp`** addressing — wrap-around bleed at texture edges is the single most common visible artifact. For procedural/runtime textures pass the matching filter explicitly, e.g. `TextureDeclaration(filter = TextureFilter.Point, ...)`.

## User Pixel Shaders

You can author custom pixel shaders in Daslang. Create a `foo.shader` file (in any folder) and a matching `foo.material` to apply it to a mesh — only the filename matters, not the location. Edit a `.shader` file in the IDE and changes hot-reload — saving from outside the IDE may not trigger a rebuild, so use Save (Ctrl+S) in the editor.

```das
require engine.render.shader_dsl

var {
    @color tint = float3(0.2, 0.8, 1.0)   // material property, editable per-material
    speed = 2.0
}

[pixel_shader] // use UnlitInput, UnlitOutput for unlit shader (no NdotL lighting term)
def my_effect(inp : PbrInput) {
    let n = noise(inp.worldPos)
    let pulse = sin(g_Time * speed) * 0.5 + 0.5

    return PbrOutput(
        albedo = tint * n,
        emission = tint * pulse,
        emissionStrength = pulse * 0.5,
        metalness = 0.0,
        roughness = 1.0,
        ao = 1.0
    )
}
```

### Inputs and outputs
- **Geometry inputs** (via `inp : PbrInput`): `inp.uv : float2`, `inp.worldPos : float3`, `inp.worldNormal : float3`, `inp.viewDir : float3`, `inp.localPos : float3`, `inp.localNormal : float3`
- **Global inputs** (direct name): `g_Time : float`, `g_LightDirection : float3` (toward sun, normalized)
- **Outputs** (via `return PbrOutput(...)`): `albedo : float3`, `alpha : float`, `alphaCutoff : float`, `metalness : float`, `roughness : float`, `emission : float3`, `emissionStrength : float`, `normalMap : float3`, `ao : float` — all have sensible defaults; specify only what you need
- **`@color`** annotation provides a color-picker UI in the material editor — prefer it for tint/color fields

### Built-in operations
- Math: `abs`, `min`, `max`, `clamp`, `saturate`, `frac`, `floor`, `ceil`, `mad`, `lerp`, `sqrt`, `pow`, `sin`, `cos`, `atan2`, `log`, `exp`, `sign` — all overloaded for `float`/`float2`/`float3`/`float4`
- Vector: `dot`, `cross`, `length`, `normalize`
- Surface: `fresnel(power, inp.worldNormal, inp.viewDir)` — view-angle-dependent edge value 0..1
- Noise: `noise(float2)`, `noise(float3)` — both return 0..1
- Utility: `remap(x, inRange, outRange)`, `one_minus(x)`, `step(edge, x)`, `smooth_step(lo, hi, x)`, `unpack_normal(sample)`
- Texture: `tex2d(sampler, uv) : float4` — declare a texture as `myTex : Sampler2D = Sampler2D("path/to.png")`

### Material properties
Module-level `var` declarations become per-material properties exposed in the editor. Supported types: `float`, `float2`, `float3`, `float4`, `Sampler2D` (texture). Defaults must be constant literals.

### DSL constraints — what bites
- All swizzles work: `float3(1,2,3).zyx` → `float3(3,2,1)`, `float4(1,2,3,4).xxyy` → `float4(1,1,2,2)`, etc.
- `xyz`, `xy`, `x` swizzles cost no extra slots — prefer them over individual `.x`/`.y` reads where possible.
- **`float2(s)`, `float3(s)`, `float4(s)` with a single scalar are free.** The compiler passes the scalar through without emitting any node — the register file broadcasts floats as `.xxxx` automatically. Mixing int and float is fine: `float3(0, t, 0)`, `float2(-1, 1)`, `float3(0)` all work.
- **`float2(a,b)`, `float3(a,b,c)` with multiple arguments each cost a register** (emits a combine node). Avoid combining when the result is only used in one place; pass components directly instead.
- **12-register hard limit.** Errors as `Too many constants: N`. Each operation costs a slot until freed. If you hit the limit:
   - Vectorize: three `sin(a + phase_n)` → one `sin(float3(a+p0, a+p1, a+p2))`
   - Drop dead terms (`x * 0.0` is **not** folded by the compiler — remove it explicitly)
   - Avoid re-reading the same input attribute in unrelated sub-expressions; the compiler CSE-deduplicates identical subgraphs (e.g. four reads of `worldPos.y` collapse to one), but only when the full expression trees match
- **`a * b + c` is automatically fused into a single `mad` instruction** — no need to restructure manually for performance.
- **`albedo` is modulated by scene lighting** (PBR pipeline applies NdotL × sun on top). Don't pre-multiply your own lighting into albedo or you'll get a hard split between lit/shadow halves. For self-lit effects, use `emission`.
