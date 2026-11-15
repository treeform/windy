# Mouse confinement and macOS fullscreen

Mouse confinement keeps the native cursor visible and limits its movement to
the window content or a rectangular part of it. Mouse positions remain
absolute. It works with system and custom cursors.

- `window.mouseConfinementSupported` checks whether the live window supports
  native confinement.
- `window.confineMouse()` requests confinement to the entire content area.
  This region follows changes to the window size and backing scale.
- `window.confineMouse(region)` requests a `Rect` in framebuffer pixels,
  measured from the top-left of the content area.
- `window.mouseConfined` reports whether confinement is currently active.
- `window.releaseMouseConfinement()` cancels the request and releases the
  cursor immediately. Releasing an inactive request is safe.

Confinement becomes active during `pollEvents()` after the native window
geometry has settled. It may remain pending for more than one poll after a
resize or fullscreen change. A successful request does not mean
`mouseConfined` is already true. Keep polling while the window is open.

Regions must have finite coordinates and positive width and height. Zero or
negative dimensions, NaN, and infinity raise `WindyError`. A valid region is
clipped to the content area. If there is no overlap, confinement is suspended
until a later geometry or region change provides an overlap.

Losing focus, hiding or minimizing the window, or changing its geometry
releases the active clip. The request remains and can resume when the window
is visible and focused again. A confinement request can temporarily disable
window dragging and native resize handles. These controls are restored when
confinement is suspended or released. Programmatic geometry changes remain
available in windowed mode.

`captureMouse()` selects relative mouse input, hides the cursor, and cancels
any confinement request. Calling `confineMouse()` while relative capture is
active raises `WindyError`; call `releaseMouse()` first. Closing the window
cleans up both modes.

```nim
import windy, pixie

let window = newWindow("Confined cursor", ivec2(800, 600))

if window.mouseConfinementSupported:
  window.confineMouse(rect(100, 80, 600, 440))

window.onButtonPress = proc(button: Button) =
  if button == KeyEscape:
    window.releaseMouseConfinement()

while not window.closeRequested:
  pollEvents()

window.close()
```

Native confinement is currently implemented on macOS. It uses an undocumented
AppKit selector whose availability is checked at runtime. Support depends on
the running system, so check `mouseConfinementSupported`. Other platforms
expose the same API: the two queries return false, releasing is a no-op, and
either `confineMouse` overload raises `WindyError`.

On macOS, `window.fullscreen = true` uses a borderless window on the current
desktop without creating a separate fullscreen Space or changing the display
mode. It covers the full display, including the area beside the camera notch.
The menu bar and Dock are hidden while the fullscreen window is focused and
the application is active. Switching applications restores normal desktop
presentation while preserving the window's logical fullscreen state.

Fullscreen keeps the native cursor available; confinement is optional and
requested separately. Leaving fullscreen restores the window's frame and
appearance. Assignments to `style`, `size`, and `pos` are ignored while
fullscreen is enabled, matching the Windows backend.
