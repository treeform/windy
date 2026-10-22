import
  std/os,
  pixie, windy

proc main() =
  let useDrm = paramStr(1) == "drm"
  if useDrm:
    doAssert paramCount() == 3, "Choose two DRM connectors."
  setLinuxBackend(if useDrm: DrmBackend else: FbdevBackend)
  for attempt in 0 .. 1:
    let first = newWindow("First output", ivec2(0, 0), vsync = false,
      linuxOptions = LinuxWindowOptions(output: paramStr(2)))
    var image = newImage(first.framebufferSize.x, first.framebufferSize.y)
    image.fill(color(1, 0, 0, 1))
    first.presentPixels(image)
    if useDrm:
      let second = newWindow("Second output", ivec2(0, 0), vsync = false,
        linuxOptions = LinuxWindowOptions(output: paramStr(3)))
      image = newImage(second.framebufferSize.x, second.framebufferSize.y)
      image.fill(color(0, 1, 0, 1))
      second.presentPixels(image)
      var rejected = false
      try:
        discard newWindow("Duplicate", ivec2(0, 0), vsync = false,
          linuxOptions = LinuxWindowOptions(output: paramStr(3)))
      except IOError: rejected = true
      doAssert rejected
      first.close()
      image.fill(color(0, 0, 1, 1))
      second.presentPixels(image)
      second.close()
    else:
      first.close()
    doAssert first.closed

main()
