# Windy

**This library is still in development and is not ready to use.**

Windy is a windowing library for Nim that uses native OS APIs to
manage windows, set up OpenGL or CPU pixel presentation, and receive mouse and
keyboard input.

`nimble install windy`

![GitHub Actions](https://github.com/treeform/windy/workflows/Github%20Actions/badge.svg)

[API reference](https://treeform.github.io/windy)

Windy will work great for 2D and 3D OpenGL games, as well as GUI apps
using OpenGL. Using this library should feel similar to GLFW or SDL.

Features:
* Multi-platform (Windows, macOS, Linux)
* Manage one or many windows
* Customizable windows (resizable, hidden, fullscreen and more)
* Use custom window icons and cursors
* DPI and content-scaling aware
* Mouse input (position, clicks, scroll)
* Double-click, triple-click and quadruple-click events
* Keyboard input (key events + unicode)
* Easy polling of keyboard state via `buttonDown[Button]` and more
* IME support (for Chinese, Japanese, etc. text input)
* System clipboard (copy and paste) support
* Show a system tray icon and menu (Windows and Linux)
* Send desktop notifications (Linux)
* Non-blocking HTTP requests and WebSockets

## Basic Example

```nim
import opengl, windy

let window = newWindow("Windy Example", ivec2(1280, 800))

window.makeContextCurrent()
loadExtensions()

proc display() =
  glClear(GL_COLOR_BUFFER_BIT)
  # Your OpenGL display code here
  window.swapBuffers()

while not window.closeRequested:
  display()
  pollEvents()
```

[Check out more examples here.](https://github.com/treeform/windy/tree/master/examples)

## Tray icons

`showTrayIcon(image, tooltip, onClick, menu)` shows one icon;
calling it again replaces the icon and menu. Call `pollEvents()` to process
interaction, and `hideTrayIcon()` to remove it. See [examples/tray.nim](examples/tray.nim).

Linux selects an available StatusNotifierItem host, or an XEmbed tray when
SNI is unavailable. It waits if neither exists and recovers when the tray host
restarts. SNI uses the optional `libdbus-1.so.3` runtime library. XEmbed uses
Xlib with a basic popup menu; SNI menus follow the desktop's presentation.
Tray-only Linux applications do not need to create a window or OpenGL context.

## Desktop notifications

On Linux, `sendNotification(title, body, icon = nil, onClick = nil, onError = nil)`
returns a notification handle. Call `pollEvents()` to send queued requests and
process callbacks. The handle supports `update(title, body, icon = nil)`, `close()`,
and the `pending` and `closed` properties. An omitted error callback causes
delivery errors to raise `WindyError` from `pollEvents()`.

Notifications use the desktop's D-Bus service and do not require a tray icon or
window. Click support and popup presentation depend on the desktop's capabilities
and notification settings. See [examples/notifications.nim](examples/notifications.nim).

## CPU Pixels

On Windows and X11 Linux, compile with `-d:useCpu` to create a plain window without an
OpenGL context. CPU renderers can update the client area by passing a Pixie
image to `window.presentPixels(image)`.

Linux also has experimental fbdev, DRM and evdev touch backends
for applications running without a window server.


### Why not just use GLFW or SDL?

Here are a few reasons that may be worth considering:

* Windy is written in Nim, so it will be more natural to use than
  bindings to other libraries. For example, making a window fullscreen
  is as easy as `window.fullscreen = true`. Consider browsing some of
  the examples and whether you would find this Nim-first API more
  pleasant to work with.

* Windy includes events for double, triple and quadruple clicks. Furthermore, Windy maintains the keyboard and mouse state in a way that makes reacting to input state easier each frame. See `buttonPressed[]`, `buttonDown[]`, `buttonReleased[]` and `buttonToggle[]` on `Window`.

* Windy has IME input support for Chinese, Japanese, Korean and other languages. Text input can also be enabled or disabled at any time (for example, to avoid opening the IME editor when a user just wants to use WASD in a game).

## Native text services

Custom text widgets on macOS and Windows can publish their focused editor with
`window.setTextInputState(state)` and handle selection or replacement requests
through `window.onTextEdit`. Ranges use half-open Unicode rune offsets; bounds
use framebuffer pixels. Enable `runeInputEnabled` first, republish after edits
or layout changes, and publish an empty id to clear the field. Password fields
are not exposed.

Windows exposes UI Automation Value and Text patterns and handles native paste
messages, synthesized shortcuts without scan codes, and UTF-16 character input.
It uses a C++ COM bridge built by the normal Nim command; MinGW runtime libraries
are linked statically. See [Windows text services](docs/windows-text-input.md)
for the regression commands and the current geometry limitations.

## Emscripten

Windy can be compiled to WebAssembly using Emscripten. See the [Emscripten tutorial](https://github.com/treeform/nim_emscripten_tutorial) for more information on how Emscripten works with Nim and things you need to know.

To compile any of the examples:
```sh
nim c -d:emscripten examples/basic_triangle.nim
```

This will generate:
* HTML shell: `examples/basic_triangle.html`
* Preloaded data: `examples/basic_triangle.data`
* JavaScript: `examples/basic_triangle.js`
* WebAssembly: `examples/basic_triangle.wasm`

Then run the compiled HTML file:
```sh
emrun examples/basic_triangle.html
```

Some operations like closing, moving, minimizing and resizing the window do not make sense in the browser, so these are not supported.
