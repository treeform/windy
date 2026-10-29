import
  std/[dynlib, monotimes, os, posix, strformat, strutils, times],
  pixie,
  ./[framebuffer, pixels]

type
  ModeInfo = object
    clock: uint32
    hdisplay, hsyncStart, hsyncEnd, htotal, hskew: uint16
    vdisplay, vsyncStart, vsyncEnd, vtotal, vscan: uint16
    refresh, flags, modeType: uint32
    name: array[32, char]
  Resources = object
    countFbs: cint
    fbs: ptr UncheckedArray[uint32]
    countCrtcs: cint
    crtcs: ptr UncheckedArray[uint32]
    countConnectors: cint
    connectors: ptr UncheckedArray[uint32]
    countEncoders: cint
    encoders: ptr UncheckedArray[uint32]
    minWidth, maxWidth, minHeight, maxHeight: uint32
  Connector = object
    id, encoderId, connectorType, typeId: uint32
    connection: cint
    mmWidth, mmHeight: uint32
    subpixel, countModes: cint
    modes: ptr UncheckedArray[ModeInfo]
    countProperties: cint
    properties: ptr UncheckedArray[uint32]
    values: ptr UncheckedArray[uint64]
    countEncoders: cint
    encoders: ptr UncheckedArray[uint32]
  Encoder = object
    id, encoderType, crtcId, possibleCrtcs, possibleClones: uint32
  Crtc = object
    id, bufferId, x, y, width, height: uint32
    modeValid: cint
    mode: ModeInfo
    gammaSize: cint
  DumbBuffer = object
    height, width, bpp, flags, handle, pitch: uint32
    size: uint64
  MapBuffer = object
    handle, padding: uint32
    offset: uint64
  FramebufferInfo = object
    id, width, height, pitch, bpp, depth, handle: uint32
  GemClose = object
    handle, padding: uint32
  PlaneResources = object
    count: uint32
    planes: ptr UncheckedArray[uint32]
  Plane = object
    countFormats: uint32
    formats: ptr UncheckedArray[uint32]
    id, crtc, framebuffer, crtcX, crtcY, x, y, possibleCrtcs, gammaSize: uint32
  ObjectProperties = object
    count: uint32
    ids: ptr UncheckedArray[uint32]
    values: ptr UncheckedArray[uint64]
  Property = object
    id, flags: uint32
    name: array[32, char]
    countValues: cint
    values: pointer
    countEnums: cint
    enums: pointer
    countBlobs: cint
    blobs: pointer
  FlipHandler = proc(fd: cint, sequence, seconds, microseconds: cuint,
    data: pointer) {.cdecl.}
  EventContext = object
    # Version 2 uses only this prefix of libdrm's extensible event context.
    version: cint
    vblankHandler, pageFlipHandler: FlipHandler
  Scanout = object
    buffer: DumbBuffer
    memory: pointer
    framebuffer: uint32
  DrmApi = object
    library: LibHandle
    getResources: proc(fd: cint): ptr Resources {.cdecl.}
    freeResources: proc(value: ptr Resources) {.cdecl.}
    getConnector: proc(fd: cint, id: uint32): ptr Connector {.cdecl.}
    freeConnector: proc(value: ptr Connector) {.cdecl.}
    getEncoder: proc(fd: cint, id: uint32): ptr Encoder {.cdecl.}
    freeEncoder: proc(value: ptr Encoder) {.cdecl.}
    getCrtc: proc(fd: cint, id: uint32): ptr Crtc {.cdecl.}
    freeCrtc: proc(value: ptr Crtc) {.cdecl.}
    setCrtc: proc(fd: cint, id, buffer, x, y: uint32, connectors: ptr uint32,
      count: cint, mode: ptr ModeInfo): cint {.cdecl.}
    pageFlip: proc(fd: cint, crtc, framebuffer, flags: uint32,
      data: pointer): cint {.cdecl.}
    handleEvent: proc(fd: cint, context: ptr EventContext): cint {.cdecl.}
    addFb: proc(fd: cint, width, height: uint32, depth, bpp: uint8,
      pitch, handle: uint32, id: ptr uint32): cint {.cdecl.}
    removeFb: proc(fd: cint, id: uint32): cint {.cdecl.}
    getFb: proc(fd: cint, id: uint32): ptr FramebufferInfo {.cdecl.}
    freeFb: proc(value: ptr FramebufferInfo) {.cdecl.}
    setMaster, dropMaster: proc(fd: cint): cint {.cdecl.}
    setClientCap: proc(fd: cint, capability, value: uint64): cint {.cdecl.}
    getPlaneResources: proc(fd: cint): ptr PlaneResources {.cdecl.}
    freePlaneResources: proc(value: ptr PlaneResources) {.cdecl.}
    getPlane: proc(fd: cint, id: uint32): ptr Plane {.cdecl.}
    freePlane: proc(value: ptr Plane) {.cdecl.}
    getProperties: proc(fd: cint, id, kind: uint32): ptr ObjectProperties {.cdecl.}
    freeProperties: proc(value: ptr ObjectProperties) {.cdecl.}
    getProperty: proc(fd: cint, id: uint32): ptr Property {.cdecl.}
    freeProperty: proc(value: ptr Property) {.cdecl.}
    addFb2: proc(fd: cint, width, height, format: uint32,
      handles, pitches, offsets: ptr uint32, id: ptr uint32, flags: uint32): cint {.cdecl.}
  DrmScreen* = ref object
    name*: string
    width*, height*: int
    rotation: int
    connector, crtc: uint32
    mode: ModeInfo
    original: Crtc
    originalConnectors: seq[uint32]
    buffers: seq[Scanout]
    front, draw: int
    vsync, pending: bool
    pixels: seq[uint32]
    rgba: bool
    activated: bool
  DrmDisplay* = ref object
    api: DrmApi
    fd: cint
    master: bool
    screens*: seq[DrmScreen]
    retiredScreens: seq[DrmScreen]

const
  FlipEvent = 1'u32
  FlipTimeoutMs = 1000
  CreateDumb = 0xc02064b2.culong
  MapDumb = 0xc01064b3.culong
  DestroyDumb = 0xc00464b4.culong
  CloseGem = 0x40086409.culong
  Connected = 1
  PreferredMode = 1'u32 shl 3
  Xbgr8888 = 0x34324258'u32
  Abgr8888 = 0x34324241'u32
  MaximumBufferBytes = 512 * 1024 * 1024
  ConnectorNames = ["Unknown", "VGA", "DVI-I", "DVI-D", "DVI-A", "Composite",
    "SVIDEO", "LVDS", "Component", "DIN", "DP", "HDMI-A", "HDMI-B", "TV",
    "eDP", "Virtual", "DSI", "DPI", "Writeback", "SPI", "USB"]

static:
  doAssert sizeof(pointer) == 8
  doAssert sizeof(ModeInfo) == 68
  doAssert sizeof(Resources) == 80
  doAssert sizeof(Connector) == 88
  doAssert sizeof(Crtc) == 100
  doAssert sizeof(Encoder) == 20
  doAssert sizeof(DumbBuffer) == 32
  doAssert sizeof(MapBuffer) == 16
  doAssert sizeof(FramebufferInfo) == 28
  doAssert sizeof(GemClose) == 8
  doAssert sizeof(EventContext) == 24

proc loadDrm(): DrmApi =
  ## Load DRM only when a DRM display is requested.
  result.library = loadLib("libdrm.so.2")
  if result.library == nil:
    raise newException(IOError, "Cannot load libdrm.so.2; install libdrm for DRM displays")
  template bindSymbol(field: untyped, name: string) =
    result.field = cast[type(result.field)](symAddr(result.library, name))
    if result.field == nil:
      unloadLib(result.library)
      raise newException(IOError, "Missing DRM symbol: " & name)
  bindSymbol(getResources, "drmModeGetResources")
  bindSymbol(freeResources, "drmModeFreeResources")
  bindSymbol(getConnector, "drmModeGetConnector")
  bindSymbol(freeConnector, "drmModeFreeConnector")
  bindSymbol(getEncoder, "drmModeGetEncoder")
  bindSymbol(freeEncoder, "drmModeFreeEncoder")
  bindSymbol(getCrtc, "drmModeGetCrtc")
  bindSymbol(freeCrtc, "drmModeFreeCrtc")
  bindSymbol(setCrtc, "drmModeSetCrtc")
  bindSymbol(pageFlip, "drmModePageFlip")
  bindSymbol(handleEvent, "drmHandleEvent")
  bindSymbol(addFb, "drmModeAddFB")
  bindSymbol(removeFb, "drmModeRmFB")
  bindSymbol(getFb, "drmModeGetFB")
  bindSymbol(freeFb, "drmModeFreeFB")
  bindSymbol(setMaster, "drmSetMaster")
  bindSymbol(dropMaster, "drmDropMaster")
  bindSymbol(setClientCap, "drmSetClientCap")
  bindSymbol(getPlaneResources, "drmModeGetPlaneResources")
  bindSymbol(freePlaneResources, "drmModeFreePlaneResources")
  bindSymbol(getPlane, "drmModeGetPlane")
  bindSymbol(freePlane, "drmModeFreePlane")
  bindSymbol(getProperties, "drmModeObjectGetProperties")
  bindSymbol(freeProperties, "drmModeFreeObjectProperties")
  bindSymbol(getProperty, "drmModeGetProperty")
  bindSymbol(freeProperty, "drmModeFreeProperty")
  bindSymbol(addFb2, "drmModeAddFB2")

proc rgbaFormat(display: DrmDisplay, crtcIndex: int): uint32 =
  let api = display.api
  if api.setClientCap(display.fd, 2, 1) < 0:
    if osLastError() == OSErrorCode(EINVAL): return 0
    raiseOSError(osLastError(), "Enabling universal DRM planes")
  let resources = api.getPlaneResources(display.fd)
  if resources == nil:
    raiseOSError(osLastError(), "Reading DRM planes")
  defer: api.freePlaneResources(resources)
  for index in 0 ..< int(resources.count):
    let plane = api.getPlane(display.fd, resources.planes[index])
    if plane == nil: raiseOSError(osLastError(), "Reading DRM plane")
    defer: api.freePlane(plane)
    if (plane.possibleCrtcs and (1'u32 shl crtcIndex)) == 0: continue
    let properties = api.getProperties(display.fd, plane.id, 0xeeeeeeee'u32)
    if properties == nil: raiseOSError(osLastError(), "Reading DRM plane properties")
    defer: api.freeProperties(properties)
    var primary = false
    for propertyIndex in 0 ..< int(properties.count):
      let property = api.getProperty(display.fd, properties.ids[propertyIndex])
      if property == nil: raiseOSError(osLastError(), "Reading DRM property")
      if $cast[cstring](addr property.name[0]) == "type":
        primary = properties.values[propertyIndex] == 1
      api.freeProperty(property)
    if primary:
      for format in [Xbgr8888, Abgr8888]:
        for formatIndex in 0 ..< int(plane.countFormats):
          if plane.formats[formatIndex] == format: return format

proc flipComplete(fd: cint, sequence, seconds, microseconds: cuint,
    data: pointer) {.cdecl.} =
  ## Mark a screen's queued buffer as scanned out after its vblank event.
  let screen = cast[DrmScreen](data)
  screen.front = screen.draw
  screen.pending = false

proc waitForFlip(display: DrmDisplay, screen: DrmScreen) =
  ## Wait before reusing scanout storage, dispatching events for every output.
  if not screen.pending: return
  let deadline = getMonoTime() + initDuration(milliseconds = FlipTimeoutMs)
  var context = EventContext(version: 2, pageFlipHandler: flipComplete)
  while screen.pending:
    let remaining = (deadline - getMonoTime()).inMilliseconds
    if remaining <= 0:
      raise newException(IOError, "Timed out waiting for DRM page flip on " & screen.name)
    var descriptor = TPollfd(fd: display.fd, events: POLLIN)
    let count = poll(addr descriptor, 1, cint(remaining))
    if count < 0:
      if osLastError() == OSErrorCode(EINTR): continue
      raiseOSError(osLastError(), "Waiting for DRM page flip")
    if count == 0: continue
    if (descriptor.revents and (POLLERR or POLLHUP or POLLNVAL)) != 0:
      raise newException(IOError, "DRM event descriptor became unavailable")
    if display.api.handleEvent(display.fd, addr context) < 0:
      if osLastError() == OSErrorCode(EINTR): continue
      raiseOSError(osLastError(), "Reading DRM page flip events")

proc closeScreen*(display: DrmDisplay, screen: DrmScreen) =
  var errors: seq[string]
  try:
    display.waitForFlip(screen)
  except CatchableError as error:
    errors.add error.msg
    # A late event still contains this screen's address until the DRM fd closes.
    display.retiredScreens.add screen
  if screen.activated:
    var
      original = screen.original
      connectors = screen.originalConnectors
      enabled = original.modeValid != 0 and original.bufferId != 0
    if enabled:
      let framebuffer = display.api.getFb(display.fd, original.bufferId)
      if framebuffer == nil:
        let error = osLastError()
        enabled = false
        if error == OSErrorCode(ENOENT):
          echo "Original framebuffer retired by kernel; disabling ", screen.name, " on exit"
        else:
          errors.add "Querying original framebuffer for " & screen.name & ": " & $error
      else:
        if framebuffer.handle != 0:
          var handle = GemClose(handle: framebuffer.handle)
          if deviceIoctl(display.fd, CloseGem, addr handle) < 0:
            errors.add "Closing original GEM handle for " & screen.name
        display.api.freeFb(framebuffer)
    let
      connectorPointer = if enabled and connectors.len > 0: addr connectors[0] else: nil
      modePointer = if enabled: addr original.mode else: nil
      count = if enabled: cint(connectors.len) else: 0.cint
      buffer = if enabled: original.bufferId else: 0'u32
    if display.api.setCrtc(display.fd, screen.crtc, buffer, original.x,
        original.y, connectorPointer, count, modePointer) < 0:
      errors.add "Restoring " & screen.name
    screen.activated = false
  for scanout in screen.buffers.mitems:
    if scanout.memory != nil:
      if munmap(scanout.memory, int(scanout.buffer.size)) < 0:
        errors.add "Unmapping " & screen.name
      scanout.memory = nil
    if scanout.framebuffer != 0:
      if display.api.removeFb(display.fd, scanout.framebuffer) < 0:
        errors.add "Removing framebuffer for " & screen.name
      scanout.framebuffer = 0
    if scanout.buffer.handle != 0:
      if deviceIoctl(display.fd, DestroyDumb, addr scanout.buffer.handle) < 0:
        errors.add "Destroying buffer for " & screen.name
      scanout.buffer.handle = 0

  if errors.len > 0:
    raise newException(IOError, errors.join("; "))

proc close*(display: DrmDisplay) =
  var errors: seq[string]
  for screen in display.screens:
    try:
      display.closeScreen(screen)
    except IOError as error:
      errors.add error.msg
  if display.fd >= 0:
    if display.master and display.api.dropMaster(display.fd) < 0:
      errors.add "Releasing DRM master"
    if posix.close(display.fd) < 0:
      errors.add "Closing DRM device"
    display.fd = -1
  display.retiredScreens.setLen(0)
  if display.api.library != nil:
    unloadLib(display.api.library)
    display.api.library = nil
  if errors.len > 0:
    raise newException(IOError, errors.join("; "))

proc connectorName(connector: ptr Connector): string =
  ## Format the kernel connector type and instance as a stable output name.
  let prefix = if connector.connectorType < uint32(ConnectorNames.len):
    ConnectorNames[connector.connectorType] else: "Connector" & $connector.connectorType
  prefix & "-" & $connector.typeId

proc chooseCrtc*(ids: openArray[uint32], current, possible: uint32,
    unavailable: openArray[uint32]): uint32 =
  ## Prefer the current compatible controller without taking another output's controller.
  for index, id in ids:
    if index < 32 and (possible and (1'u32 shl index)) != 0 and
        id notin unavailable and id == current:
      return id
  for index, id in ids:
    if index < 32 and (possible and (1'u32 shl index)) != 0 and id notin unavailable:
      return id
  raise newException(IOError, "No independent display controller is available")

proc openOutput*(result: DrmDisplay, outputs: seq[string], rotation: int, vsync = false) =
  ## Prepare independent CPU scanout buffers without changing the active display.
  if rotation notin [0, 90, 180, 270]:
    raise newException(ValueError, "Rotation must be 0, 90, 180 or 270")
  let originalCount = result.screens.len
  try:
    let
      api = result.api
      resources = api.getResources(result.fd)
    if resources == nil:
      raiseOSError(osLastError(), "Reading DRM resources")
    defer: api.freeResources(resources)
    var
      connectors: seq[ptr Connector]
      names: seq[string]
      crtcs: seq[uint32]
      used: seq[uint32]
      requested = outputs
    defer:
      for connector in connectors:
        api.freeConnector(connector)
    for screen in result.screens:
      used.add screen.crtc
    for index in 0 ..< int(resources.countCrtcs):
      crtcs.add resources.crtcs[index]
    for index in 0 ..< int(resources.countConnectors):
      let connector = api.getConnector(result.fd, resources.connectors[index])
      if connector == nil:
        raiseOSError(osLastError(), "Reading DRM connector")
      connectors.add connector
      names.add connector.connectorName()
      if outputs.len == 0 and connector.connection == Connected and connector.countModes > 0:
        requested.add names[^1]
    if requested.len == 0:
      raise newException(IOError, "No connected DRM displays")
    for name in requested:
      for screen in result.screens:
        if screen.name == name:
          raise newException(IOError, "DRM output is already owned: " & name)
      let index = names.find(name)
      if index < 0:
        raise newException(IOError, "DRM output not found: " & name)
      let connector = connectors[index]
      if connector.connection != Connected or connector.countModes == 0:
        raise newException(IOError, "DRM output has no connected mode: " & name)
      var
        possible = 0'u32
        current = 0'u32
      for index in 0 ..< int(connector.countEncoders):
        let encoder = api.getEncoder(result.fd, connector.encoders[index])
        if encoder == nil:
          raiseOSError(osLastError(), "Reading DRM encoder")
        possible = possible or encoder.possibleCrtcs
        if encoder.id == connector.encoderId:
          current = encoder.crtcId
        api.freeEncoder(encoder)
      var unavailable = used
      for other in connectors:
        if other.connectorName() notin requested and other.encoderId != 0:
          let encoder = api.getEncoder(result.fd, other.encoderId)
          if encoder == nil:
            raiseOSError(osLastError(), "Reading existing DRM route")
          if encoder.crtcId != 0:
            unavailable.add encoder.crtcId
          api.freeEncoder(encoder)
      let
        id = chooseCrtc(crtcs, current, possible, unavailable)
        original = api.getCrtc(result.fd, id)
      if original == nil:
        raiseOSError(osLastError(), "Saving DRM scanout")
      let screen = DrmScreen(name: name, connector: connector.id, crtc: id,
        original: original[], mode: connector.modes[0], rotation: rotation, vsync: vsync)
      api.freeCrtc(original)
      result.screens.add screen
      used.add id
      for modeIndex in 0 ..< int(connector.countModes):
        if (connector.modes[modeIndex].modeType and PreferredMode) != 0:
          screen.mode = connector.modes[modeIndex]
          break
      if screen.original.modeValid != 0:
        screen.mode = screen.original.mode
      for other in connectors:
        if other.encoderId != 0:
          let encoder = api.getEncoder(result.fd, other.encoderId)
          if encoder == nil:
            raiseOSError(osLastError(), "Saving DRM connector routing")
          if encoder.crtcId == id:
            screen.originalConnectors.add other.id
          api.freeEncoder(encoder)
      screen.width = int(if rotation in [90, 270]: screen.mode.vdisplay else: screen.mode.hdisplay)
      screen.height = int(if rotation in [90, 270]: screen.mode.hdisplay else: screen.mode.vdisplay)
      let format = result.rgbaFormat(crtcs.find(id))
      screen.rgba = format != 0
      screen.buffers.setLen(if vsync: 2 else: 1)
      for scanout in screen.buffers.mitems:
        scanout.buffer = DumbBuffer(width: uint32(screen.mode.hdisplay),
          height: uint32(screen.mode.vdisplay), bpp: 32)
        if deviceIoctl(result.fd, CreateDumb, addr scanout.buffer) < 0:
          raiseOSError(osLastError(), "Allocating DRM scanout buffer")
        if scanout.buffer.pitch < scanout.buffer.width * 4 or
            scanout.buffer.size < uint64(scanout.buffer.pitch) * scanout.buffer.height or
            scanout.buffer.size > MaximumBufferBytes:
          raise newException(IOError, "Unsupported DRM buffer geometry")
        if screen.rgba:
          var
            handles = [scanout.buffer.handle, 0'u32, 0, 0]
            pitches = [scanout.buffer.pitch, 0'u32, 0, 0]
            offsets: array[4, uint32]
          if api.addFb2(result.fd, scanout.buffer.width, scanout.buffer.height, format,
              addr handles[0], addr pitches[0], addr offsets[0], addr scanout.framebuffer, 0) < 0:
            raiseOSError(osLastError(), "Registering RGBA DRM framebuffer")
        elif api.addFb(result.fd, scanout.buffer.width, scanout.buffer.height, 24, 32,
            scanout.buffer.pitch, scanout.buffer.handle, addr scanout.framebuffer) < 0:
            raiseOSError(osLastError(), "Registering DRM framebuffer")
        var mapping = MapBuffer(handle: scanout.buffer.handle)
        if deviceIoctl(result.fd, MapDumb, addr mapping) < 0:
          raiseOSError(osLastError(), "Mapping DRM buffer")
        scanout.memory = mmap(nil, int(scanout.buffer.size), PROT_READ or PROT_WRITE,
          MAP_SHARED, result.fd, Off(mapping.offset))
        if scanout.memory == MAP_FAILED:
          scanout.memory = nil
          raiseOSError(osLastError(), "Mapping DRM scanout memory")
  except:
    while result.screens.len > originalCount:
      let screen = result.screens.pop()
      result.closeScreen(screen)
    raise

proc upload*(display: DrmDisplay, index: int, image: Image) =
  ## Upload a frame, waiting before reusing storage still owned by scanout.
  let screen = display.screens[index]
  if image.width != screen.width or image.height != screen.height:
    raise newException(ValueError, "Canvas does not match DRM screen")
  display.waitForFlip(screen)
  screen.draw = if screen.vsync and screen.activated: 1 - screen.front else: 0
  let scanout = screen.buffers[screen.draw]
  let destination = cast[ptr UncheckedArray[uint32]](scanout.memory)
  if screen.rgba and screen.rotation == 0:
    for row in 0 ..< image.height:
      copyMem(addr destination[row * int(scanout.buffer.pitch) div 4],
        unsafeAddr image.data[row * image.width], image.width * 4)
    return
  screen.pixels.setLen(image.data.len)
  if screen.rotation == 0:
    for index, pixel in image.data:
      screen.pixels[index] = rgb(pixel)
  else:
    for y in 0 ..< image.height:
      for x in 0 ..< image.width:
        let point = rotatedPoint(x, y, image.width, image.height, screen.rotation)
        screen.pixels[point.y * int(scanout.buffer.width) + point.x] =
          (if screen.rgba: cast[uint32](image.data[y * image.width + x])
          else: rgb(image.data[y * image.width + x]))
  for row in 0 ..< int(scanout.buffer.height):
    copyMem(addr destination[row * int(scanout.buffer.pitch) div 4],
      addr screen.pixels[row * int(scanout.buffer.width)], int(scanout.buffer.width) * 4)

proc present*(display: DrmDisplay, index: int, image: Image) =
  display.upload(index, image)
  let screen = display.screens[index]
  if not screen.activated:
    if not display.master:
      if display.api.setMaster(display.fd) < 0:
        raiseOSError(osLastError(), "Acquiring DRM master; another display application may be running")
      display.master = true
    if display.api.setCrtc(display.fd, screen.crtc, screen.buffers[screen.draw].framebuffer, 0, 0,
        addr screen.connector, 1, addr screen.mode) < 0:
      raiseOSError(osLastError(), "Displaying " & screen.name)
    screen.activated = true
    screen.front = screen.draw
  elif screen.vsync:
    if display.api.pageFlip(display.fd, screen.crtc,
        screen.buffers[screen.draw].framebuffer, FlipEvent, cast[pointer](screen)) < 0:
      raiseOSError(osLastError(), "Queuing DRM page flip on " & screen.name)
    screen.pending = true

proc describe*(screen: DrmScreen): string =
  ## Describe the selected connector, logical geometry and controller.
  &"{screen.name}: {screen.width}x{screen.height}, CRTC {screen.crtc}, rotation {screen.rotation}"
proc openDrm*(path: string): DrmDisplay =
  result = DrmDisplay(fd: -1, api: loadDrm())
  result.fd = posix.open(path.cstring, O_RDWR or O_CLOEXEC)
  if result.fd < 0:
    let error = osLastError()
    result.close()
    raiseOSError(error, path)
