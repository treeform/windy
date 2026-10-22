# Direct Linux displays (experimental)

These CPU pixel backends support Linux systems without X11. The default build
still uses X11/OpenGL. Put the desired settings in your application's
`config.nims`:

```nim
switch("define", "useCpu")
switch("define", "windyBackends=fbdev,drm")
```

`windyBackends` accepts `x11`, `fbdev`, `drm`, or a comma-separated combination.
Direct-only builds do not need X11 libraries. DRM loads `libdrm.so.2` when opened
and currently requires a 64-bit target. Combined builds include X11's library
dependencies even when selecting a direct display.

Select the backend before creating windows:

```nim
import pixie, windy

setLinuxBackend(DrmBackend)
let window = newWindow("Panel", ivec2(0, 0), vsync = false,
  linuxOptions = LinuxWindowOptions(
    device: "/dev/dri/card0",
    output: "DSI-1",
    touchDevice: "/dev/input/event1"))
let image = newImage(window.framebufferSize.x, window.framebufferSize.y)
image.fill(color(0.2, 0.4, 0.8, 1))
window.presentPixels(image)
while not window.closeRequested:
  pollEvents()
window.close()
```

Choose connector and input paths for your system. Multiple DRM windows can own
separate connectors on the same device. For fbdev, select `FbdevBackend` and
`LinuxWindowOptions(device: "/dev/fb0")`; only one window can own that framebuffer.
Windows use the panel's native size. `rotation` and `touchRotation` accept
0, 90, 180 or 270 degrees. Device discovery and board-specific configuration
belong to the application.

`window.onTouch` receives begin/move/end/cancel events with stable contact IDs
and window-local pixel positions. `window.touches` contains active contacts.
Evdev single-touch and slot-based multitouch are supported, without smoothing,
gestures or mouse synthesis. X11, browser, Windows and macOS touch delivery is
not implemented in this draft.

The application needs permission to open its display and input devices, and
exclusive display ownership. Close windows before switching backends. Native
desktop operations such as resizing, clipboard access or OpenGL contexts raise
`WindyError`. Keyboard, mouse and controller input are not supplied by these
direct backends; use the application's input library for controllers.

Presentation copies into scanout memory. There is no page-flip queue or vblank
pacing, so `vsync` must be false and tearing is possible. Normal close restores
the saved display state when it is still available. If the kernel retired the
previous DRM framebuffer, the output is disabled instead.

Run `nim r tests/test_native_input.nim` for touch lifecycle and pixel tests.
`WINDY_TEST_BACKENDS=x11,fbdev,drm nim r tests/test_linux_display.nim` checks
combined backend selection and X11 CPU pixels; use an isolated Xvfb display.
`nim r tests/test_linux_glx.nim` checks the default OpenGL path.

On a dedicated test device, compile `tests/manual_direct_displays.nim` with
`WINDY_TEST_BACKENDS=fbdev,drm` and run it with `fbdev`, or with
`drm CONNECTOR1 CONNECTOR2`. This temporarily changes both outputs and checks
independent ownership and cleanup; stop other display applications first.
