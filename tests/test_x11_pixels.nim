import
  std/[monotimes, os, osproc, streams, strutils, times, unittest],
  opengl, pixie, windy,
  windy/platforms/linux/x11pixels

proc readBack(window: Window): Image =
  ## Read only synthetic pixels from the back buffer on the isolated test display.
  window.makeContextCurrent()
  let size = window.framebufferSize
  result = newImage(size.x, size.y)
  glReadBuffer(GL_BACK)
  glPixelStorei(GL_PACK_ALIGNMENT, 1)
  glReadPixels(0, 0, size.x.GLsizei, size.y.GLsizei, GL_RGBA, GL_UNSIGNED_BYTE,
    addr result.data[0])
  doAssert glGetError() == GL_NO_ERROR
  for y in 0 ..< result.height div 2:
    for x in 0 ..< result.width:
      swap(result.data[y * result.width + x],
        result.data[(result.height - 1 - y) * result.width + x])

proc checkCrop(presenter: X11PixelPresenter, window: Window, source: Image,
    crop: PixelRegion, scale = 0, changed = true) =
  ## Compare every GPU output pixel with an independent nearest-neighbor CPU reference.
  presenter.drawPixels(source, crop, changed, scale)
  let
    output = readBack(window)
    factor = if scale > 0: scale else:
      max(1, min(output.width div crop.width, output.height div crop.height))
    left = (output.width - crop.width * factor) div 2
    top = (output.height - crop.height * factor) div 2
  for y in 0 ..< output.height:
    for x in 0 ..< output.width:
      let
        sx = (x - left) div factor
        sy = (y - top) div factor
      var expected = rgbx(0, 0, 0, 255)
      if x >= left and y >= top and x < left + crop.width * factor and
          y < top + crop.height * factor:
        let pixel = source[crop.x + sx, crop.y + sy]
        expected = rgbx(pixel.r, pixel.g, pixel.b, 255)
      doAssert output[x, y] == expected,
        "GPU crop/orientation/scale/opacity differed at " & $x & "," & $y

proc main() =
  ## Exercise real GLX contexts under a private Xvfb server, never the user's desktop.
  let
    executable = findExe("Xvfb")
    oldDisplay = getEnv("DISPLAY")
    oldSoftware = getEnv("LIBGL_ALWAYS_SOFTWARE")
  doAssert executable.len > 0, "Xvfb is required for this headless-only test."
  let server = startProcess(executable, args = ["-displayfd", "1", "-screen", "0",
    "1280x1024x24", "+extension", "GLX", "-nolisten", "tcp"], options = {})
  defer:
    if server.running: server.terminate()
    discard server.waitForExit(5000)
    server.close()
    putEnv("DISPLAY", oldDisplay)
    if oldSoftware.len > 0: putEnv("LIBGL_ALWAYS_SOFTWARE", oldSoftware)
    else: delEnv("LIBGL_ALWAYS_SOFTWARE")
  let number = server.outputStream.readLine().strip()
  doAssert number.len > 0 and number.allCharsInSet({'0' .. '9'})
  putEnv("DISPLAY", ":" & number)
  putEnv("LIBGL_ALWAYS_SOFTWARE", "1")
  block:
    let cpu = newWindow("Headless CPU", ivec2(8, 8))
    doAssert not cpu.hasGpuPixelContext and not cpu.gpuPixelVsync
    cpu.close()
  let
    first = newWindow("Headless GPU first", ivec2(67, 55), vsync = false,
      linuxOptions = LinuxWindowOptions(gpuPixels: true))
    second = newWindow("Headless GPU second", ivec2(83, 69), vsync = false,
      linuxOptions = LinuxWindowOptions(gpuPixels: true))
  defer: first.close()
  defer: second.close()
  let
    a = newX11PixelPresenter(first)
    b = newX11PixelPresenter(second)
    source = newImage(17, 19)
  defer: a.close()
  defer: b.close()
  for y in 0 ..< source.height:
    for x in 0 ..< source.width:
      source[x, y] = ColorRGBX(r: uint8(x * 13), g: uint8(y * 11),
        b: uint8((x + y) * 7), a: 0)
  let
    top = PixelRegion(x: 1, y: 2, width: 13, height: 7)
    bottom = PixelRegion(x: 3, y: 11, width: 11, height: 8)
  for frame in 0 ..< 5:
    checkCrop(a, first, source, top, changed = frame == 0)
    checkCrop(b, second, source, bottom, changed = frame == 0)
    a.swap()
    b.swap()
  let larger = newImage(29, 31)
  larger.fill(rgbx(17, 31, 173, 255))
  checkCrop(a, first, larger, bottom, changed = false)
  checkCrop(a, first, source, top, changed = false)
  checkCrop(a, first, source, top, scale = 2, changed = false)
  expect ValueError: a.drawPixels(source, top, scale = 100)
  expect ValueError: a.drawPixels(source, PixelRegion(x: 18, width: 1, height: 1))
  first.size = ivec2(7, 5)
  pollEvents()
  a.drawPixels(source, top, changed = false, fitDown = true)
  let fitted = readBack(first)
  for y in 0 ..< fitted.height:
    for x in 0 ..< fitted.width:
      var expected = rgbx(0, 0, 0, 255)
      if y in 1 .. 3:
        let pixel = source[top.x + (2 * x + 1) * top.width div 14,
          top.y + (2 * (y - 1) + 1) * top.height div 6]
        expected = rgbx(pixel.r, pixel.g, pixel.b, 255)
      doAssert fitted[x, y] == expected
  first.size = ivec2(67, 55)
  pollEvents()
  let start = getMonoTime()
  for frame in 0 ..< 60:
    a.drawPixels(source, top, false)
    b.drawPixels(source, bottom, false)
    a.swap()
    b.swap()
  doAssert (getMonoTime() - start).inSeconds < 10, "Paired submission stalled."
  a.drawPixels(nil, PixelRegion())
  for pixel in readBack(first).data: doAssert pixel == rgbx(0, 0, 0, 255)
  a.close()
  a.close()
  first.close()
  first.close()
  b.close()
  second.close()
  second.close()

main()
