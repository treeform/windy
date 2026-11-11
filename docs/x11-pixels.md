# X11 GPU pixels

Use the X11 pixel presenter to scale a Pixie image on the GPU, with optional vsync.
It works in CPU pixel builds, so an app can choose between CPU and GPU rendering.
Add `switch("define", "useCpu")` to your application's `config.nims`.
The default Linux backend is X11.

```nim
import
  pixie, windy,
  windy/platforms/linux/x11pixels

proc main() =
  ## Draw a Pixie image with the X11 GPU presenter.
  let window = newWindow("GPU pixels", ivec2(800, 600), vsync = true,
    linuxOptions = LinuxWindowOptions(gpuPixels: true))
  defer: window.close()
  let presenter = newX11PixelPresenter(window)
  defer: presenter.close()
  let image = newImage(256, 224)
  image.fill(color(0.2, 0.4, 0.8, 1))
  while not window.closeRequested:
    pollEvents()
    presenter.drawPixels(image, PixelRegion(width: image.width, height: image.height))
    presenter.swap()

main()
```

The region uses coordinates from the image's top-left corner. Pixels are drawn
opaque, scaled by a whole number and centered with black borders. You can request
an exact size with `scale = 2`, or allow shrinking into a small window with
`fitDown = true`.

Pass `changed = false` when the image has not changed to avoid uploading it again.
You must still draw and swap after a window resize or a change to the region.
To clear the window to black, pass a nil image and an empty `PixelRegion()`.

Keep the presenter on the window thread and close it before closing the window.
It requires OpenGL 2.1. With `vsync = true`, startup fails if the GLX driver cannot
configure vsync; use `vsync = false` when you do not need it.

For two windows, draw both before swapping either. X11 does not guarantee an
atomic update across windows. For coordinated updates on direct Linux displays,
see [DRM GPU pixels](drm-pixel-pairs.md).

Run `nim r tests/test_x11_pixels.nim` for the headless rendering test. It requires
Xvfb and Mesa and checks the rendered pixels. Physical vsync still needs testing
on a real display.
