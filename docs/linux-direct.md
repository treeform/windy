# Linux displays without X11

Windy can draw Pixie images directly to a Linux display through fbdev or DRM.
These backends are experimental and currently require a 64-bit Linux target.
Your app needs access to the display and input devices, with no other application
controlling the display.

Put the backends you need in your application's `config.nims`:

```nim
switch("define", "useCpu")
switch("define", "windyBackends=fbdev,drm")
```

You can include `x11` in the list for an app that also runs on a desktop.
Builds without `x11` do not need X11 libraries. DRM needs `libdrm.so.2` at runtime.

Choose the backend before opening a window. For example, to fill a DRM display:

```nim
import pixie, windy

setLinuxBackend(DrmBackend)
let window = newWindow("Panel", ivec2(0, 0), vsync = true,
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

Replace the device, connector and touch paths with those for your system. Omit
`touchDevice` if you do not need touch. Each window fills its display; the size
passed to `newWindow` is ignored. You can open separate windows on different DRM
connectors on the same device.

For fbdev, choose `FbdevBackend` and open a window with `vsync = false` and
`LinuxWindowOptions(device: "/dev/fb0")`. Only one window can use that framebuffer.
Both backends accept `rotation` and `touchRotation` of 0, 90, 180 or 270 degrees.

DRM's `vsync = true` draws into a second buffer and switches buffers between
refreshes to avoid tearing. Without vsync, and on fbdev, writes go straight to the
displayed buffer and can tear. Close all windows before switching backends.

Touch events arrive through `window.onTouch`; `window.touches` holds the active
contacts. Positions are in window pixels. Both single-touch and multitouch evdev
devices are supported. Touch is not yet implemented for X11 or the other platforms.

These backends do not provide keyboard, mouse or controller input. Desktop
operations such as resizing and clipboard access are also unavailable. Device
selection and controller input belong in the application.

For GPU scaling and coordinated updates to two displays, see
[DRM GPU pixels](drm-pixel-pairs.md). Desktop GPU rendering is covered in
[X11 GPU pixels](x11-pixels.md).
