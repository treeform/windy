# This diagnostic deliberately keeps experimental bindings outside Windy's API.
import
  std/[algorithm, parseutils],
  ./drm_gpu_patterns

include windy/platforms/linux/drm/display

type
  GbmHandle {.union.} = object
    pointerValue: pointer
    u32: uint32
    u64: uint64
  AtomicRequest = pointer
  AtomicApi = object
    alloc: proc(): AtomicRequest {.cdecl.}
    free: proc(request: AtomicRequest) {.cdecl.}
    add: proc(request: AtomicRequest, id, property: uint32, value: uint64): cint {.cdecl.}
    commit: proc(fd: cint, request: AtomicRequest, flags: uint32, data: pointer): cint {.cdecl.}
    createBlob: proc(fd: cint, data: pointer, size: csize_t, id: ptr uint32): cint {.cdecl.}
    destroyBlob: proc(fd: cint, id: uint32): cint {.cdecl.}
  AtomicValue = object
    id, property: uint32
    value: uint64
  PairEvents = object
    version: cint
    vblank, flip: FlipHandler
    flip2: proc(fd: cint, sequence, seconds, microseconds, crtc: cuint,
      data: pointer) {.cdecl.}
  Probe = ref object
    display: DrmDisplay
    atomic: AtomicApi
    restore, properties: seq[AtomicValue]
    blobs: seq[uint32]
    planes: array[2, uint32]
    fbProperties: array[2, uint32]
    pair: PairedFlip
    armed, pending: bool
    callbackError: string
    gbm, surface, egl, context, eglSurface: pointer
    program, texture, vertices: uint32
    gbmFrames: seq[tuple[bo: pointer, fb: uint32]]
    locked: seq[pointer]
    front: pointer
    pixels: seq[uint32]
    panelWidth, panelHeight, sourceHeight: int
    layout: PixelLayout
    skew: seq[float64]
  Samples = object
    generate, upload, render, submit, wait: seq[float64]
    draw, swap, finish, acquire: seq[float64]

const
  PlaneObject = 0xeeeeeeee'u32
  CrtcObject = 0xcccccccc'u32
  ConnectorObject = 0xc0c0c0c0'u32
  AtomicTest = 0x100'u32
  AtomicNonblock = 0x200'u32
  AllowModeset = 0x400'u32
  Xrgb8888 = 0x34325258'u32
  GlTexture = 0x0de1'u32
  GlRgba = 0x1908'u32
  GlByte = 0x1401'u32
  GlFloat = 0x1406'u32
  GlTriangles = 4'u32
  GlColourBuffer = 0x4000'u32
  GlRenderer = 0x1f01'u32
  GlVersion = 0x1f02'u32
  GlVertexShader = 0x8b31'u32
  GlFragmentShader = 0x8b30'u32
  GlCompileStatus = 0x8b81'u32
  GlLinkStatus = 0x8b82'u32
  GlMagFilter = 0x2800'u32
  GlMinFilter = 0x2801'u32
  GlWrapS = 0x2802'u32
  GlWrapT = 0x2803'u32
  GlNearest = 0x2600.cint
  GlClampEdge = 0x812f.cint
  EglGbm = 0x31d7'u32
  EglEsApi = 0x30a0'u32
  EglNativeVisual = 0x302e.cint
  EglClientVersion = 0x3098.cint
  EglDepthSize = 0x3025.cint
  EglStencilSize = 0x3026.cint
  EglSamples = 0x3031.cint
  EglSampleBuffers = 0x3032.cint
  AtomicCapability = 3'u64
  PrimaryPlane = 1'u64
  GbmScanoutRendering = 5'u32
  GlArrayBuffer = 0x8892'u32
  GlStaticDraw = 0x88e4'u32
  VerticesPerPanel = 6
  VertexStride = 4 * sizeof(cfloat)
  EglNone = 0x3038.cint
  EglConfigAttributes = [0x3033.cint, 4, 0x3040, 4, 0x3024, 8,
    0x3023, 8, 0x3022, 8, 0x3025, 0, 0x3026, 0, EglNone]
  VertexSource = "attribute vec2 position; attribute vec2 uv; varying vec2 tex; void main(){tex=uv;gl_Position=vec4(position,0.0,1.0);}"
  FragmentSource = "precision highp float; varying vec2 tex; uniform sampler2D image; uniform float swapRB; void main(){vec4 c=texture2D(image,tex);gl_FragColor=vec4(mix(c.rgb,c.bgr,swapRB),1.0);}"

static:
  doAssert cpuEndian == littleEndian
  doAssert sizeof(GbmHandle) == 8
  doAssert sizeof(PairEvents) == 32

{.push cdecl, importc, dynlib: "libgbm.so.1".}
proc gbm_create_device(fd: cint): pointer
proc gbm_device_destroy(device: pointer)
proc gbm_surface_create_with_modifiers2(device: pointer, width, height, format: uint32,
  modifiers: ptr uint64, count, flags: uint32): pointer
proc gbm_surface_destroy(surface: pointer)
proc gbm_surface_lock_front_buffer(surface: pointer): pointer
proc gbm_surface_release_buffer(surface, bo: pointer)
proc gbm_bo_get_handle(bo: pointer): GbmHandle
proc gbm_bo_get_stride(bo: pointer): uint32
proc gbm_bo_get_modifier(bo: pointer): uint64
{.pop.}

{.push cdecl, importc, dynlib: "libEGL.so.1".}
proc eglGetPlatformDisplay(platform: cuint, native: pointer, attributes: pointer): pointer
proc eglInitialize(display: pointer, major, minor: ptr cint): cuint
proc eglBindAPI(api: cuint): cuint
proc eglChooseConfig(display: pointer, attributes: ptr cint, configs: ptr pointer,
  count: cint, found: ptr cint): cuint
proc eglGetConfigAttrib(display, config: pointer, attribute: cint, value: ptr cint): cuint
proc eglCreateContext(display, config, share: pointer, attributes: ptr cint): pointer
proc eglCreateWindowSurface(display, config, window: pointer, attributes: pointer): pointer
proc eglMakeCurrent(display, draw, read, context: pointer): cuint
proc eglSwapInterval(display: pointer, interval: cint): cuint
proc eglSwapBuffers(display, surface: pointer): cuint
proc eglDestroyContext(display, context: pointer): cuint
proc eglDestroySurface(display, surface: pointer): cuint
proc eglTerminate(display: pointer): cuint
proc eglGetError(): cuint
{.pop.}

{.push cdecl, importc, dynlib: "libGLESv2.so.2".}
proc glGetString(name: cuint): cstring
proc glCreateShader(kind: cuint): cuint
proc glShaderSource(shader: cuint, count: cint, source: ptr cstring, lengths: pointer)
proc glCompileShader(shader: cuint)
proc glGetShaderiv(shader, name: cuint, value: ptr cint)
proc glGetShaderInfoLog(shader: cuint, size: cint, length: ptr cint, log: cstring)
proc glDeleteShader(shader: cuint)
proc glCreateProgram(): cuint
proc glAttachShader(program, shader: cuint)
proc glBindAttribLocation(program, index: cuint, name: cstring)
proc glLinkProgram(program: cuint)
proc glGetProgramiv(program, name: cuint, value: ptr cint)
proc glGetProgramInfoLog(program: cuint, size: cint, length: ptr cint, log: cstring)
proc glDeleteProgram(program: cuint)
proc glUseProgram(program: cuint)
proc glGetUniformLocation(program: cuint, name: cstring): cint
proc glUniform1f(location: cint, value: cfloat)
proc glUniform1i(location, value: cint)
proc glGenTextures(count: cint, textures: ptr cuint)
proc glDeleteTextures(count: cint, textures: ptr cuint)
proc glGenBuffers(count: cint, buffers: ptr cuint)
proc glBindBuffer(target, buffer: cuint)
proc glBufferData(target: cuint, size: int, data: pointer, usage: cuint)
proc glDeleteBuffers(count: cint, buffers: ptr cuint)
proc glBindTexture(target, texture: cuint)
proc glTexParameteri(target, name: cuint, value: cint)
proc glTexImage2D(target: cuint, level, internal, width, height, border: cint,
  format, kind: cuint, data: pointer)
proc glTexSubImage2D(target: cuint, level, x, y, width, height: cint,
  format, kind: cuint, data: pointer)
proc glViewport(x, y, width, height: cint)
proc glClearColor(red, green, blue, alpha: cfloat)
proc glClear(mask: cuint)
proc glEnableVertexAttribArray(index: cuint)
proc glVertexAttribPointer(index: cuint, size: cint, kind: cuint, normalized: uint8,
  stride: cint, data: pointer)
proc glDrawArrays(mode: cuint, first, count: cint)
proc glFinish()
proc glReadPixels(x, y, width, height: cint, format, kind: cuint, data: pointer)
proc glGetError(): cuint
{.pop.}

proc checked(value: bool, operation: string) =
  ## Fail with the operation and current system error instead of continuing.
  if not value: raise newException(IOError, operation & ": " & $osLastError())

proc checkedEgl(value: cuint, operation: string) =
  ## Include EGL's own error code when context or buffer operations fail.
  if value == 0: raise newException(IOError, operation & ": EGL " & $eglGetError())

proc loadAtomic(display: DrmDisplay): AtomicApi =
  ## Load experimental entry points without changing the normal DRM backend.
  template bindField(field: untyped, name: string) =
    result.field = cast[type(result.field)](symAddr(display.api.library, name))
    checked(result.field != nil, name)
  bindField(alloc, "drmModeAtomicAlloc")
  bindField(free, "drmModeAtomicFree")
  bindField(add, "drmModeAtomicAddProperty")
  bindField(commit, "drmModeAtomicCommit")
  bindField(createBlob, "drmModeCreatePropertyBlob")
  bindField(destroyBlob, "drmModeDestroyPropertyBlob")

proc property(probe: Probe, id, kind: uint32, name: string): AtomicValue =
  ## Find a property by name and retain its original value for restoration.
  let
    api = probe.display.api
    values = api.getProperties(probe.display.fd, id, kind)
  checked(values != nil, "Reading properties")
  defer: api.freeProperties(values)
  for index in 0 ..< int(values.count):
    let item = api.getProperty(probe.display.fd, values.ids[index])
    checked(item != nil, "Reading property")
    let matches = $cast[cstring](addr item.name[0]) == name
    api.freeProperty(item)
    if matches:
      return AtomicValue(id: id, property: values.ids[index], value: values.values[index])
  raise newException(IOError, "Missing DRM property " & name & " on " & $id)

proc set(probe: Probe, id, kind: uint32, name: string, value: uint64) =
  ## Append an atomic update and the matching original state exactly once.
  let previous = probe.property(id, kind, name)
  probe.restore.add previous
  probe.properties.add AtomicValue(id: id, property: previous.property, value: value)

proc blob(probe: Probe, mode: var ModeInfo): uint32 =
  ## Retain a mode blob until after the display has been restored.
  checked(probe.atomic.createBlob(probe.display.fd, addr mode, csize_t(sizeof(mode)), addr result) == 0,
    "Creating mode blob")
  probe.blobs.add result

proc configure(probe: Probe) =
  ## Discover primary planes and construct one transaction for two active outputs.
  let
    display = probe.display
    api = display.api
    planes = api.getPlaneResources(display.fd)
    resources = api.getResources(display.fd)
  checked(planes != nil and resources != nil, "Enumerating planes")
  defer:
    api.freePlaneResources(planes)
    api.freeResources(resources)
  for index, screen in display.screens:
    var crtcIndex = -1
    for candidate in 0 ..< int(resources.countCrtcs):
      if resources.crtcs[candidate] == screen.crtc: crtcIndex = candidate
    checked(crtcIndex >= 0, "Finding CRTC index")
    for candidate in 0 ..< int(planes.count):
      let plane = api.getPlane(display.fd, planes.planes[candidate])
      checked(plane != nil, "Reading plane")
      defer: api.freePlane(plane)
      if (plane.possibleCrtcs and (1'u32 shl crtcIndex)) == 0: continue
      if probe.property(plane.id, PlaneObject, "type").value != PrimaryPlane: continue
      if plane.crtc notin [0'u32, screen.crtc]: continue
      if plane.id in probe.planes: continue
      var compatible = false
      for format in 0 ..< int(plane.countFormats):
        if plane.formats[format] == Xrgb8888: compatible = true
      if compatible:
        probe.planes[index] = plane.id
        break
    checked(probe.planes[index] != 0, "Finding compatible primary plane")
    let plane = probe.planes[index]
    probe.pair.crtcs[index] = screen.crtc
    probe.set(screen.connector, ConnectorObject, "CRTC_ID", screen.crtc)
    probe.set(screen.crtc, CrtcObject, "ACTIVE", 1)
    probe.set(screen.crtc, CrtcObject, "MODE_ID", probe.blob(screen.mode))
    # Copy an active original mode into our own blob instead of retaining its ID.
    if screen.original.modeValid != 0:
      probe.restore[^1].value = probe.blob(screen.original.mode)
    probe.set(plane, PlaneObject, "CRTC_ID", screen.crtc)
    probe.set(plane, PlaneObject, "FB_ID", 0)
    probe.fbProperties[index] = probe.properties[^1].property
    probe.set(plane, PlaneObject, "SRC_X", 0)
    probe.set(plane, PlaneObject, "SRC_Y", uint64(index * probe.panelHeight) shl 16)
    probe.set(plane, PlaneObject, "SRC_W", uint64(probe.panelWidth) shl 16)
    probe.set(plane, PlaneObject, "SRC_H", uint64(probe.panelHeight) shl 16)
    probe.set(plane, PlaneObject, "CRTC_X", 0)
    probe.set(plane, PlaneObject, "CRTC_Y", 0)
    probe.set(plane, PlaneObject, "CRTC_W", uint64(probe.panelWidth))
    probe.set(plane, PlaneObject, "CRTC_H", uint64(probe.panelHeight))
    echo screen.name, ": CRTC ", screen.crtc, ", plane ", plane

proc commit(probe: Probe, values: seq[AtomicValue], flags: uint32, data: pointer = nil) =
  ## Submit a complete transaction or leave the current state unchanged on error.
  let request = probe.atomic.alloc()
  checked(request != nil, "Allocating atomic request")
  defer: probe.atomic.free(request)
  for item in values:
    checked(probe.atomic.add(request, item.id, item.property, item.value) >= 0, "Adding atomic property")
  checked(probe.atomic.commit(probe.display.fd, request, flags, data) == 0, "Committing paired display update")

proc flip2(fd: cint, sequence, seconds, microseconds, crtc: cuint, data: pointer) {.cdecl.} =
  ## Handle both events without allowing a Nim exception across a C callback.
  let probe = cast[Probe](data)
  try:
    probe.pair.complete(crtc, uint64(seconds) * 1_000_000 + uint64(microseconds))
  except ValueError as error:
    probe.callbackError = error.msg

proc waitPair(probe: Probe) =
  ## Retire a generation only after both display controllers have completed it.
  if not probe.pending: return
  let started = getMonoTime()
  var context = PairEvents(version: 3, flip2: flip2)
  while not probe.pair.ready:
    let remaining = FlipTimeoutMs - int((getMonoTime() - started).inMilliseconds)
    checked(remaining > 0, "Timed out waiting for paired flip")
    var descriptor = TPollfd(fd: probe.display.fd, events: POLLIN)
    let polled = posix.poll(addr descriptor, 1, cint(remaining))
    if polled < 0 and osLastError() == OSErrorCode(EINTR): continue
    checked(polled > 0 and (descriptor.revents and POLLIN) != 0, "Polling paired flip")
    checked(probe.display.api.handleEvent(probe.display.fd, cast[ptr EventContext](addr context)) == 0,
      "Reading paired flip")
    if probe.callbackError.len > 0: raise newException(IOError, probe.callbackError)
  probe.pending = false
  let timestamps = probe.pair.timestamps
  probe.skew.add abs(timestamps[0].float64 - timestamps[1].float64) / 1000

proc shader(kind: uint32, source: string): uint32 =
  ## Compile a shader and report the driver's compiler log on failure.
  result = glCreateShader(kind)
  var
    text = source.cstring
    compiled: cint
  glShaderSource(result, 1, addr text, nil)
  glCompileShader(result)
  glGetShaderiv(result, GlCompileStatus, addr compiled)
  if compiled == 0:
    var log = newString(4096)
    glGetShaderInfoLog(result, cint(log.len), nil, log.cstring)
    glDeleteShader(result)
    raise newException(IOError, "Compiling shader: " & log)

proc openGpu(probe: Probe) =
  ## Create one EGL context and one linear GBM render target for both panels.
  probe.gbm = gbm_create_device(probe.display.fd)
  checked(probe.gbm != nil, "Creating GBM device")
  var linear = 0'u64
  probe.surface = gbm_surface_create_with_modifiers2(probe.gbm, uint32(probe.panelWidth),
    uint32(probe.panelHeight * 2), Xrgb8888, addr linear, 1, GbmScanoutRendering)
  checked(probe.surface != nil, "Creating linear combined GBM surface")
  probe.egl = eglGetPlatformDisplay(EglGbm, probe.gbm, nil)
  checked(probe.egl != nil, "Opening GBM EGL display")
  checkedEgl(eglInitialize(probe.egl, nil, nil), "Initializing EGL")
  checkedEgl(eglBindAPI(EglEsApi), "Selecting OpenGL ES")
  var
    attributes = EglConfigAttributes
    count: cint
    selected: pointer
  checkedEgl(eglChooseConfig(probe.egl, addr attributes[0], nil, 0, addr count), "Counting EGL configs")
  checked(count > 0, "Expected a window-compatible EGL config")
  var
    configs = newSeq[pointer](count)
    sizes: array[4, cint]
  checkedEgl(eglChooseConfig(probe.egl, addr attributes[0], addr configs[0], count, addr count), "Choosing EGL config")
  for index in 0 ..< int(count):
    var visual: cint
    checkedEgl(eglGetConfigAttrib(probe.egl, configs[index], EglNativeVisual, addr visual), "Reading EGL visual")
    if uint32(visual) != Xrgb8888: continue
    for field, name in [EglDepthSize, EglStencilSize, EglSamples, EglSampleBuffers]:
      checkedEgl(eglGetConfigAttrib(probe.egl, configs[index], name, addr sizes[field]), "Reading EGL buffers")
    # EGL's zero attributes specify minimum sizes, not the absence of MSAA/depth.
    if sizes == [0.cint, 0, 0, 0]:
      selected = configs[index]
      break
  checked(selected != nil, "Finding XRGB EGL config without depth, stencil or MSAA")
  echo "EGL depth/stencil/samples/sample buffers: ", sizes
  var contextAttributes = [EglClientVersion, 2.cint, EglNone]
  probe.context = eglCreateContext(probe.egl, selected, nil, addr contextAttributes[0])
  checked(probe.context != nil, "Creating GLES2 context")
  probe.eglSurface = eglCreateWindowSurface(probe.egl, selected, probe.surface, nil)
  checked(probe.eglSurface != nil, "Creating EGL window surface")
  checkedEgl(eglMakeCurrent(probe.egl, probe.eglSurface, probe.eglSurface, probe.context), "Making context current")
  checkedEgl(eglSwapInterval(probe.egl, 0), "Disabling EGL's separate refresh wait")
  let
    renderer = $glGetString(GlRenderer)
    version = $glGetString(GlVersion)
  echo "GPU: ", renderer, "; GLES: ", version
  checked(renderer.len > 0, "Expected a hardware renderer")
  for software in ["llvmpipe", "softpipe", "swrast", "swiftshader"]:
    checked(software notin renderer.toLowerAscii, "Software rendering is not a GPU proof: " & renderer)
  let
    vertex = shader(GlVertexShader, VertexSource)
    fragment = shader(GlFragmentShader, FragmentSource)
  defer:
    glDeleteShader(vertex)
    glDeleteShader(fragment)
  probe.program = glCreateProgram()
  glAttachShader(probe.program, vertex)
  glAttachShader(probe.program, fragment)
  glBindAttribLocation(probe.program, 0, "position")
  glBindAttribLocation(probe.program, 1, "uv")
  glLinkProgram(probe.program)
  var linked: cint
  glGetProgramiv(probe.program, GlLinkStatus, addr linked)
  if linked == 0:
    var log = newString(4096)
    glGetProgramInfoLog(probe.program, cint(log.len), nil, log.cstring)
    raise newException(IOError, "Linking program: " & log)
  glUseProgram(probe.program)
  glUniform1i(glGetUniformLocation(probe.program, "image"), 0)
  glUniform1f(glGetUniformLocation(probe.program, "swapRB"), if probe.layout == xrgbPixels: 1 else: 0)
  glGenTextures(1, addr probe.texture)
  glBindTexture(GlTexture, probe.texture)
  for name in [GlMagFilter, GlMinFilter]: glTexParameteri(GlTexture, name, GlNearest)
  for name in [GlWrapS, GlWrapT]: glTexParameteri(GlTexture, name, GlClampEdge)
  glTexImage2D(GlTexture, 0, cint(GlRgba), SourceWidth, cint(probe.sourceHeight * 2), 0, GlRgba, GlByte, nil)
  glEnableVertexAttribArray(0)
  glEnableVertexAttribArray(1)
  var vertices: seq[cfloat]
  for index in 0..1:
    let
      first = cfloat(index) * 0.5
      last = first + 0.5
    vertices.add @[-1.cfloat, -1, 0, last, 1, -1, 1, last, -1, 1, 0, first,
      -1, 1, 0, first, 1, -1, 1, last, 1, 1, 1, first]
  glGenBuffers(1, addr probe.vertices)
  glBindBuffer(GlArrayBuffer, probe.vertices)
  glBufferData(GlArrayBuffer, vertices.len * sizeof(cfloat), addr vertices[0], GlStaticDraw)

proc draw(probe: Probe) =
  ## Enlarge two cropped texture regions with nearest-neighbour sampling.
  glClearColor(0, 0, 0, 1)
  glClear(GlColourBuffer)
  let view = fit(SourceWidth, probe.sourceHeight, probe.panelWidth, probe.panelHeight)
  for index in 0..1:
    let offset = index * VerticesPerPanel * VertexStride
    glViewport(cint(view.x), cint((1 - index) * probe.panelHeight + view.y), cint(view.width), cint(view.height))
    glVertexAttribPointer(0, 2, GlFloat, 0, VertexStride, cast[pointer](offset))
    glVertexAttribPointer(1, 2, GlFloat, 0, VertexStride, cast[pointer](offset + 2 * sizeof(cfloat)))
    glDrawArrays(GlTriangles, 0, VerticesPerPanel)
  checked(glGetError() == 0, "Drawing GPU pattern")

proc readback(probe: Probe) =
  ## Validate every rendered pixel, including borders, before touching scanout.
  let
    width = probe.panelWidth
    height = probe.panelHeight * 2
    view = fit(SourceWidth, probe.sourceHeight, width, probe.panelHeight)
    scale = view.width div SourceWidth
  var output = newSeq[uint32](width * height)
  glReadPixels(0, 0, cint(width), cint(height), GlRgba, GlByte, addr output[0])
  checked(glGetError() == 0, "Reading GPU pixels")
  for y in 0 ..< height:
    let localY = y mod probe.panelHeight
    for x in 0 ..< width:
      var expected = 0xff000000'u32
      if x >= view.x and x < view.x + view.width and localY >= view.y and localY < view.y + view.height:
        expected = pixel((x - view.x) div scale, (localY - view.y) div scale +
          (y div probe.panelHeight) * probe.sourceHeight, 0, probe.sourceHeight)
      let actual = output[(height - 1 - y) * width + x] or 0xff000000'u32
      if actual != expected:
        raise newException(IOError, &"GPU readback mismatch at {x},{y}: {actual} != {expected}")
  echo "GPU readback: exact nearest-neighbour pixels and borders verified"

proc framebuffer(probe: Probe, bo: pointer): uint32 =
  ## Register each GBM allocation once and reject non-linear storage explicitly.
  for frame in probe.gbmFrames:
    if frame.bo == bo: return frame.fb
  checked(gbm_bo_get_modifier(bo) == 0, "Expected a linear GBM buffer")
  var
    handles = [gbm_bo_get_handle(bo).u32, 0'u32, 0, 0]
    pitches = [gbm_bo_get_stride(bo), 0'u32, 0, 0]
    offsets: array[4, uint32]
  checked(probe.display.api.addFb2(probe.display.fd, uint32(probe.panelWidth),
    uint32(probe.panelHeight * 2), Xrgb8888, addr handles[0], addr pitches[0],
    addr offsets[0], addr result, 0) == 0, "Registering combined GBM framebuffer")
  probe.gbmFrames.add (bo, result)

proc submit(probe: Probe, fb: uint32) =
  ## Test the initial pair and then submit one vblank-synchronized transaction.
  var values: seq[AtomicValue]
  for item in probe.properties:
    if probe.armed and item.property notin probe.fbProperties: continue
    var value = item
    if item.id in probe.planes:
      for index in 0..1:
        if item.id == probe.planes[index] and item.property == probe.fbProperties[index]:
          value.value = fb
    values.add value
  if not probe.armed:
    probe.commit(values, AtomicTest or AllowModeset)
    echo "Atomic TEST_ONLY: combined framebuffer accepted by both outputs"
    probe.commit(values, AllowModeset)
    probe.armed = true
  else:
    probe.pair.completed = {}
    probe.commit(values, AtomicNonblock or FlipEvent, cast[pointer](probe))
    probe.pending = true

proc close(probe: Probe) =
  ## Restore the saved transaction before freeing anything still used for scanout.
  if probe.display == nil: return
  var errors: seq[string]
  template attempt(body: untyped) =
    try: body
    except CatchableError as error: errors.add error.msg
  if probe.armed:
    attempt: probe.waitPair()
    attempt:
      probe.commit(probe.restore, AllowModeset)
      probe.armed = false
    if probe.armed:
      # A failed restore must not leave scanout pointing at freed GPU storage.
      var disabled = true
      for screen in probe.display.screens:
        if probe.display.api.setCrtc(probe.display.fd, screen.crtc, 0, 0, 0, nil, 0, nil) < 0:
          disabled = false
          errors.add "Disabling output after failed restore: " & screen.name
      if not disabled:
        attempt: checked(posix.close(probe.display.fd) == 0, "Closing failed DRM session")
        probe.display.fd = -1
        for screen in probe.display.screens:
          for scanout in screen.buffers:
            attempt: checked(munmap(scanout.memory, int(scanout.buffer.size)) == 0, "Unmapping abandoned CPU buffer")
          screen.buffers.setLen(0)
  for bo in probe.locked: gbm_surface_release_buffer(probe.surface, bo)
  probe.locked.setLen(0)
  for frame in probe.gbmFrames:
    if probe.display.fd >= 0:
      attempt: checked(probe.display.api.removeFb(probe.display.fd, frame.fb) == 0, "Removing GPU framebuffer")
  if probe.egl != nil:
    if probe.context != nil:
      if probe.texture != 0: glDeleteTextures(1, addr probe.texture)
      if probe.vertices != 0: glDeleteBuffers(1, addr probe.vertices)
      if probe.program != 0: glDeleteProgram(probe.program)
    attempt: checkedEgl(eglMakeCurrent(probe.egl, nil, nil, nil), "Releasing EGL context")
    if probe.eglSurface != nil:
      attempt: checkedEgl(eglDestroySurface(probe.egl, probe.eglSurface), "Destroying EGL surface")
    if probe.context != nil:
      attempt: checkedEgl(eglDestroyContext(probe.egl, probe.context), "Destroying EGL context")
    attempt: checkedEgl(eglTerminate(probe.egl), "Terminating EGL")
  if probe.surface != nil: gbm_surface_destroy(probe.surface)
  if probe.gbm != nil: gbm_device_destroy(probe.gbm)
  if probe.display.fd >= 0:
    for blob in probe.blobs:
      attempt: checked(probe.atomic.destroyBlob(probe.display.fd, blob) == 0, "Destroying mode blob")
  attempt: probe.display.close()
  probe.display = nil
  if errors.len > 0: raise newException(IOError, errors.join("; "))

proc elapsed(started: MonoTime): float64 =
  ## Measure an operation in milliseconds using the monotonic clock.
  (getMonoTime() - started).inNanoseconds.float64 / 1_000_000

proc report(name: string, samples: seq[float64]) =
  ## Print mean, tail and peak rather than hiding hitches behind average FPS.
  if samples.len == 0: return
  var
    ordered = samples.sorted()
    total = 0.0
  for sample in samples: total += sample
  echo name, " ms mean/p95/max: ", formatFloat(total / samples.len.float64, ffDecimal, 3), "/",
    formatFloat(ordered[min(ordered.high, ordered.len * 95 div 100)], ffDecimal, 3), "/",
    formatFloat(ordered[^1], ffDecimal, 3)

proc main() =
  ## Run an explicitly selected, bounded diagnostic without opening game data.
  if paramCount() notin [6, 7]:
    raise newException(ValueError, "Usage: manual_drm_gpu CARD TOP BOTTOM ds|earthbound xbgr|xrgb gpu|cpu|inspect [seconds<=8]")
  if paramStr(4) notin ["ds", "earthbound"] or paramStr(5) notin ["xbgr", "xrgb"] or
      paramStr(6) notin ["gpu", "cpu", "inspect"]:
    raise newException(ValueError, "Unknown layout, format or mode")
  var seconds = 8
  if paramCount() == 7:
    let value = paramStr(7)
    if parseInt(value, seconds) != value.len or seconds notin 1..8:
      raise newException(ValueError, "Duration must be 1..8 seconds")
  let probe = Probe(sourceHeight: (if paramStr(4) == "ds": 192 else: 224),
    layout: (if paramStr(5) == "xbgr": xbgrPixels else: xrgbPixels))
  defer: probe.close()
  probe.display = openDrm(paramStr(1))
  probe.display.openOutput(@[paramStr(2), paramStr(3)], 0, vsync = true)
  let first = probe.display.screens[0]
  probe.panelWidth = first.width
  probe.panelHeight = first.height
  let second = probe.display.screens[1]
  checked(first.width == second.width and first.height == second.height, "Expected equal panel sizes")
  checked(first.crtc != second.crtc, "Expected independent display controllers")
  probe.atomic = loadAtomic(probe.display)
  checked(probe.display.api.setClientCap(probe.display.fd, AtomicCapability, 1) == 0, "Enabling atomic KMS")
  probe.configure()
  generate(probe.pixels, probe.sourceHeight, 0, probe.layout)
  if paramStr(6) != "cpu":
    # Retain discovery metadata without reserving unused CPU scanout storage.
    for screen in probe.display.screens:
      probe.display.closeScreen(screen)
      screen.buffers.setLen(0)
    probe.openGpu()
    glTexSubImage2D(GlTexture, 0, 0, 0, SourceWidth, cint(probe.sourceHeight * 2), GlRgba, GlByte, addr probe.pixels[0])
    probe.draw()
    probe.readback()
    if paramStr(6) == "inspect": return
  checked(probe.display.api.setMaster(probe.display.fd) == 0, "Acquiring DRM master")
  probe.display.master = true
  var
    timings: Samples
    frames = 0
    late = 0
    images = [newImage(probe.panelWidth, probe.panelHeight), newImage(probe.panelWidth, probe.panelHeight)]
  let
    started = getMonoTime()
    cpuStarted = cpuTime()
  while (getMonoTime() - started).inMilliseconds < seconds * 1000:
    let frameStarted = getMonoTime()
    var step = getMonoTime()
    generate(probe.pixels, probe.sourceHeight, frames, probe.layout)
    timings.generate.add elapsed(step)
    if paramStr(6) == "gpu":
      step = getMonoTime()
      glTexSubImage2D(GlTexture, 0, 0, 0, SourceWidth, cint(probe.sourceHeight * 2), GlRgba, GlByte, addr probe.pixels[0])
      timings.upload.add elapsed(step)
      step = getMonoTime()
      probe.draw()
      timings.draw.add elapsed(step)
      var gpuStep = getMonoTime()
      checkedEgl(eglSwapBuffers(probe.egl, probe.eglSurface), "Swapping EGL render buffer")
      timings.swap.add elapsed(gpuStep)
      # Include any resolve queued by EGL's swap before exposing the BO to KMS.
      gpuStep = getMonoTime()
      glFinish()
      checked(glGetError() == 0, "Finishing GPU presentation")
      timings.finish.add elapsed(gpuStep)
      gpuStep = getMonoTime()
      let bo = gbm_surface_lock_front_buffer(probe.surface)
      checked(bo != nil, "Locking completed GBM buffer")
      probe.locked.add bo
      timings.acquire.add elapsed(gpuStep)
      timings.render.add elapsed(step)
      step = getMonoTime()
      probe.submit(probe.framebuffer(bo))
      timings.submit.add elapsed(step)
      step = getMonoTime()
      probe.waitPair()
      timings.wait.add elapsed(step)
      if probe.front != nil:
        gbm_surface_release_buffer(probe.surface, probe.front)
        probe.locked.delete(probe.locked.find(probe.front))
      probe.front = bo
    else:
      step = getMonoTime()
      for index in 0..1:
        scalePanel(probe.pixels, index, probe.sourceHeight, probe.layout, images[index].data,
          probe.panelWidth, probe.panelHeight)
      timings.render.add elapsed(step)
      step = getMonoTime()
      for index in 0..1:
        probe.display.present(index, images[index])
      timings.submit.add elapsed(step)
      step = getMonoTime()
      for screen in probe.display.screens: probe.display.waitForFlip(screen)
      timings.wait.add elapsed(step)
    inc frames
    if elapsed(frameStarted) > 20: inc late
  echo "Mode: ", paramStr(6), "; layout: ", paramStr(4), "; format: ", paramStr(5),
    "; frames: ", frames, "; elapsed ms: ", elapsed(started), "; frames over 20 ms: ", late
  echo "Main-thread CPU ms/frame: ", (cpuTime() - cpuStarted) * 1000 / frames.float64
  report("Generate", timings.generate)
  report("Upload", timings.upload)
  report("Render/finish", timings.render)
  report("Draw calls", timings.draw)
  report("EGL swap", timings.swap)
  report("GL finish", timings.finish)
  report("GBM acquire", timings.acquire)
  report("Submit", timings.submit)
  report("Wait", timings.wait)
  report("Panel completion skew", probe.skew)

when isMainModule:
  main()
