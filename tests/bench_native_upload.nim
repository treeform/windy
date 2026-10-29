import
  std/[monotimes, os, times],
  pixie,
  windy/platforms/linux/native/drm

proc main() =
  doAssert paramCount() == 1, "Choose a DRM connector."
  let display = openDrm("/dev/dri/card0")
  defer: display.close()
  display.openOutput(@[paramStr(1)], 0)
  let image = newImage(display.screens[0].width, display.screens[0].height)
  image.fill(color(0.2, 0.4, 0.8, 1))
  let started = getMonoTime()
  for iteration in 0 ..< 20:
    display.upload(0, image)
  echo "Upload mean us: ", (getMonoTime() - started).inMicroseconds div 20

main()
