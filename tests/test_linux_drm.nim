include windy/platforms/linux/native/drm

var
  signalFd: cint
  queued: seq[pointer]
  modesets, flips: int
  failFlip, failEvents: bool

proc setCrtc(fd: cint, id, buffer, x, y: uint32, connectors: ptr uint32,
    count: cint, mode: ptr ModeInfo): cint {.cdecl.} =
  ## Capture activation and restore calls without changing a physical display.
  inc modesets

proc pageFlip(fd: cint, crtc, framebuffer, flags: uint32, data: pointer): cint {.cdecl.} =
  ## Queue completion notifications while preserving the active buffer.
  doAssert flags == FlipEvent
  if failFlip: return -1
  inc flips
  queued.add data
  var signal = 'F'
  doAssert posix.write(signalFd, addr signal, 1) == 1

proc handleEvent(fd: cint, context: ptr EventContext): cint {.cdecl.} =
  ## Deliver a completion through the real callback signature after polling a pipe.
  if failEvents: return -1
  doAssert context.version == 2
  var signal: char
  doAssert posix.read(fd, addr signal, 1) == 1
  let data = queued[0]
  queued.delete(0)
  context.pageFlipHandler(fd, 0, 0, 0, data)

proc removeFb(fd: cint, id: uint32): cint {.cdecl.} =
  ## Accept cleanup of a test-owned framebuffer registration.
  discard

proc newScreen(vsync: bool): DrmScreen =
  ## Allocate padded anonymous buffers with the same lifetime as DRM mappings.
  result = DrmScreen(name: "Test", width: 2, height: 2, rgba: true, vsync: vsync)
  result.buffers.setLen(if vsync: 2 else: 1)
  for index, scanout in result.buffers.mpairs:
    scanout.buffer = DumbBuffer(width: 2, height: 2, pitch: 12, size: 24)
    scanout.framebuffer = uint32(index + 1)
    scanout.memory = mmap(nil, 24, PROT_READ or PROT_WRITE, MAP_PRIVATE or MAP_ANONYMOUS, -1, 0)
    doAssert scanout.memory != MAP_FAILED

proc firstPixel(screen: DrmScreen, index: int): ColorRGBX =
  ## Observe a buffer without retaining a mutable alias.
  cast[ptr ColorRGBX](screen.buffers[index].memory)[]

proc main() =
  ## Verify independent page flips, buffer ownership, failures and pending cleanup.
  var pipeFds: array[2, cint]
  doAssert pipe(pipeFds) == 0
  signalFd = pipeFds[1]
  defer:
    doAssert posix.close(pipeFds[0]) == 0
    doAssert posix.close(pipeFds[1]) == 0
  let
    top = newScreen(true)
    bottom = newScreen(true)
    unsynced = newScreen(false)
    display = DrmDisplay(fd: pipeFds[0], master: true, screens: @[top, bottom, unsynced],
      api: DrmApi(setCrtc: setCrtc, pageFlip: pageFlip, handleEvent: handleEvent, removeFb: removeFb))
    image = newImage(2, 2)
  image.fill(rgbx(255, 0, 0, 255))
  display.present(0, image)
  display.present(1, image)
  doAssert modesets == 2 and flips == 0
  image.fill(rgbx(0, 255, 0, 255))
  display.present(0, image)
  display.present(1, image)
  doAssert flips == 2 and top.pending and bottom.pending
  doAssert top.firstPixel(0) == rgbx(255, 0, 0, 255)
  doAssert top.firstPixel(1) == rgbx(0, 255, 0, 255)
  doAssert top.front == 0
  image.fill(rgbx(0, 0, 255, 255))
  display.present(1, image)
  doAssert not top.pending and top.front == 1
  doAssert bottom.pending and bottom.front == 1
  doAssert bottom.firstPixel(1) == rgbx(0, 255, 0, 255)
  doAssert bottom.firstPixel(0) == rgbx(0, 0, 255, 255)
  display.present(0, image)
  doAssert top.firstPixel(1) == rgbx(0, 255, 0, 255)
  doAssert top.firstPixel(0) == rgbx(0, 0, 255, 255)
  display.closeScreen(bottom)
  display.closeScreen(top)
  doAssert not top.pending and not bottom.pending and queued.len == 0
  doAssert modesets == 4

  display.present(2, image)
  image.fill(rgbx(12, 34, 56, 255))
  display.present(2, image)
  doAssert unsynced.firstPixel(0) == rgbx(12, 34, 56, 255)
  doAssert not unsynced.pending and flips == 4
  display.closeScreen(unsynced)

  let failed = newScreen(true)
  display.screens.add failed
  display.present(3, image)
  failFlip = true
  var rejected = false
  try: display.present(3, image)
  except OSError: rejected = true
  doAssert rejected and not failed.pending
  display.closeScreen(failed)

  failFlip = false
  let late = newScreen(true)
  display.screens.add late
  display.present(4, image)
  display.present(4, image)
  failEvents = true
  rejected = false
  try: display.closeScreen(late)
  except IOError: rejected = true
  doAssert rejected and display.retiredScreens == @[late]
  display.screens.delete(4)
  failEvents = false
  let next = newScreen(true)
  display.screens.add next
  display.present(4, image)
  display.present(4, image)
  display.waitForFlip(next)
  doAssert not late.pending and not next.pending and queued.len == 0
  next.pending = true
  rejected = false
  try: display.waitForFlip(next)
  except IOError as error:
    rejected = error.msg.startsWith("Timed out")
  doAssert rejected
  next.pending = false
  display.closeScreen(next)

main()
