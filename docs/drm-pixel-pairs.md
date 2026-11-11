# DRM GPU pixels

Use a DRM pixel pair when your app needs to scale images on the GPU and update
two displays together. Windy uploads one Pixie image, draws a region of it for
each display, and submits both displays in one atomic DRM update.

The displays must be equally sized, unrotated, and on the same DRM device. This
requires hardware GPU rendering, GBM, EGL and OpenGL ES. Enable `useCpu` and the
`drm` backend in `config.nims` as shown in [the display setup](linux-direct.md).

This example displays the top and bottom halves of an image on two connectors:

```nim
import
  pixie, windy,
  windy/platforms/linux/drmpixels

proc main() =
  ## Display one image across two DRM outputs.
  setLinuxBackend(DrmBackend)
  let
    first = newWindow("First", ivec2(0, 0),
      linuxOptions = LinuxWindowOptions(device: "/dev/dri/card0", output: "DSI-1"))
    second = newWindow("Second", ivec2(0, 0),
      linuxOptions = LinuxWindowOptions(device: "/dev/dri/card0", output: "DSI-2"))
  defer: first.close()
  defer: second.close()

  let pair = newDrmPixelPair(first, second)
  defer: pair.close()
  let image = newImage(256, 384)
  image.fill(color(0.2, 0.4, 0.8, 1))
  while not first.closeRequested and not second.closeRequested:
    pollEvents()
    pair.presentPixels(image, [
      PixelRegion(width: 256, height: 192),
      PixelRegion(y: 192, width: 256, height: 192)])

main()
```

Choose the connector order for your app. Region coordinates start at the image's
top-left corner. Each region is scaled by a whole number and centered, with black
borders. An empty region leaves that display black. Images larger than a display
are shown at 1× and clipped.

Create the pair before calling either window's CPU `presentPixels`. Keep it alive
across frames, use it on the window thread, and close it before closing the windows.
The windows still handle input while the pair handles rendering.

`presentPixels` waits for both displays to finish their page flips before allowing
the old buffer to be reused. Both outputs receive the same frame update, although
the physical panels may refresh at different times. Unsupported hardware raises
an error; the pair does not automatically switch to CPU rendering.

Run `nim r tests/test_drm_pixelpair.nim` for the headless tests. The hardware test
is `tests/manual_drm_pixelpair.nim`; it needs exclusive access to both displays.
