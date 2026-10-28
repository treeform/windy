import
  std/os,
  pixie, windy

when HasX11:
  import windy/platforms/linux/x11/[xlib, x]

  proc getImage(d: xlib.Display, drawable: x.Drawable, x, y: cint,
    width, height: cuint, planes: culong, format: cint): pointer
    {.cdecl, importc: "XGetImage", dynlib: libX11.}
  proc getPixel(image: pointer, x, y: cint): culong
    {.cdecl, importc: "XGetPixel", dynlib: libX11.}
  proc destroyImage(image: pointer): cint
    {.cdecl, importc: "XDestroyImage", dynlib: libX11.}
  proc closeDisplay(d: xlib.Display): cint
    {.cdecl, importc: "XCloseDisplay", dynlib: libX11.}

  setLinuxBackend(X11Backend)
  let window = newWindow("Windy CPU regression", ivec2(64, 48), vsync = false)
  let image = newImage(63, 47)
  for index in 0 ..< image.data.len:
    image.data[index] = rgbx(uint8(index mod 256), uint8((index div 63) * 5),
      uint8((index mod 8) * 31), 255)
  window.presentPixels(image)
  pollEvents()
  doAssert window.framebufferSize == ivec2(64, 48)
  doAssert window.touches.len == 0
  let d = XOpenDisplay(cstring(getEnv("DISPLAY")))
  doAssert d != nil
  d.XSync(false)
  let captured = getImage(d, d.defaultRootWindow, 0, 0, 63, 47, culong.high, 2)
  doAssert captured != nil
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let
        pixel = image.data[y * image.width + x]
        expected = culong(pixel.r) shl 16 or culong(pixel.g) shl 8 or culong(pixel.b)
      doAssert getPixel(captured, cint(x), cint(y)) == expected
  discard destroyImage(captured)
  discard closeDisplay(d)
  when HasDirect:
    var rejected = false
    try: setLinuxBackend(FbdevBackend)
    except WindyError: rejected = true
    doAssert rejected
  window.close()
  pollEvents()
  doAssert window.closed

when HasFbdev:
  setLinuxBackend(FbdevBackend)
  var rejectedFramebuffer = false
  try:
    discard newWindow("Invalid framebuffer", ivec2(0, 0), vsync = false,
      linuxOptions = LinuxWindowOptions(device: "/dev/null"))
  except OSError:
    rejectedFramebuffer = true
  doAssert rejectedFramebuffer
  setLinuxBackend(FbdevBackend)
