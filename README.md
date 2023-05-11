# Windy

**This library is still in development and is not ready to be used.**

Windy is a windowing library for Nim that uses OS native APIs to manage windows, set up OpenGL and receive mouse and keyboard input.

`nimble install windy`

![Github Actions](https://github.com/treeform/windy/workflows/Github%20Actions/badge.svg)

[API reference](https://treeform.github.io/windy)

Windy will work great for 2D and 3D OpenGL games as well as GUI apps using OpenGL. Using this library should feel similar to GLFW or SDL.

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
* IME support (for Chinese, Japanese etc text input)
* System clipboard (copy and paste) support
* Show a system tray icon and menu (Windows only)
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


### Why not just use GLFW or SDL?

Here are a few reasons that may be worth considering:

* Windy is written in Nim so it will be more natural to use than bindings to other libraries. For example, making a window fullscreen is as easy as `window.fullscreen = true`. Consider browsing some of the examples and consider if you would find this Nim-first API more pleasant to work with.

* Windy includes events for double, triple and quadruple clicks. Furthermore, Windy maintains the keyboard and mouse state in a way that makes reacting to input state easier each frame. See `buttonPressed[]`, `buttonDown[]`, `buttonReleased[]` and `buttonToggle[]` on `Window`.

* Windy has IME input support for Chinese, Japanese, Korean and other languages. Text input can also be enabled or disabled at any time (for example, to avoid opening the IME editor when a user just wants to use WASD in a game).
