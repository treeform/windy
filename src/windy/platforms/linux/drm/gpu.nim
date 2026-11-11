# Included by the DRM backend to share its private native bindings.
type
  GpuGbmHandle {.union.} = object
    pointerValue: pointer
    u32: uint32
    u64: uint64
  GpuAtomicRequest = pointer
  GpuAtomicApi = object
    alloc: proc(): GpuAtomicRequest {.cdecl.}
    free: proc(request: GpuAtomicRequest) {.cdecl.}
    add: proc(request: GpuAtomicRequest, id, gpuProperty: uint32, value: uint64): cint {.cdecl.}
    gpuCommit: proc(fd: cint, request: GpuAtomicRequest, flags: uint32, data: pointer): cint {.cdecl.}
    createBlob: proc(fd: cint, data: pointer, size: csize_t, id: ptr uint32): cint {.cdecl.}
    destroyBlob: proc(fd: cint, id: uint32): cint {.cdecl.}
  GpuAtomicValue = object
    id, gpuProperty: uint32
    value: uint64
  GpuPairEvents = object
    version: cint
    vblank, flip: FlipHandler
    flip2: proc(fd: cint, sequence, seconds, microseconds, crtc: cuint,
      data: pointer) {.cdecl.}
  GpuApi = ref object
    gbmLibrary, eglLibrary, glesLibrary: LibHandle
    gbm_create_device: proc(fd: cint): pointer {.cdecl.}
    gbm_device_destroy: proc(device: pointer) {.cdecl.}
    gbm_surface_create_with_modifiers2: proc(device: pointer, width, height, format: uint32,
      modifiers: ptr uint64, count, flags: uint32): pointer {.cdecl.}
    gbm_surface_destroy: proc(surface: pointer) {.cdecl.}
    gbm_surface_lock_front_buffer: proc(surface: pointer): pointer {.cdecl.}
    gbm_surface_release_buffer: proc(surface, bo: pointer) {.cdecl.}
    gbm_bo_get_handle: proc(bo: pointer): GpuGbmHandle {.cdecl.}
    gbm_bo_get_stride: proc(bo: pointer): uint32 {.cdecl.}
    gbm_bo_get_modifier: proc(bo: pointer): uint64 {.cdecl.}
    eglGetPlatformDisplay: proc(platform: cuint, native: pointer, attributes: pointer): pointer {.cdecl.}
    eglInitialize: proc(display: pointer, major, minor: ptr cint): cuint {.cdecl.}
    eglBindAPI: proc(api: cuint): cuint {.cdecl.}
    eglChooseConfig: proc(display: pointer, attributes: ptr cint, configs: ptr pointer,
      count: cint, found: ptr cint): cuint {.cdecl.}
    eglGetConfigAttrib: proc(display, config: pointer, attribute: cint, value: ptr cint): cuint {.cdecl.}
    eglCreateContext: proc(display, config, share: pointer, attributes: ptr cint): pointer {.cdecl.}
    eglCreateWindowSurface: proc(display, config, window: pointer, attributes: pointer): pointer {.cdecl.}
    eglMakeCurrent: proc(display, gpuDraw, read, context: pointer): cuint {.cdecl.}
    eglSwapInterval: proc(display: pointer, interval: cint): cuint {.cdecl.}
    eglSwapBuffers: proc(display, surface: pointer): cuint {.cdecl.}
    eglDestroyContext: proc(display, context: pointer): cuint {.cdecl.}
    eglDestroySurface: proc(display, surface: pointer): cuint {.cdecl.}
    eglTerminate: proc(display: pointer): cuint {.cdecl.}
    eglGetError: proc(): cuint {.cdecl.}
    glGetString: proc(name: cuint): cstring {.cdecl.}
    glCreateShader: proc(kind: cuint): cuint {.cdecl.}
    glShaderSource: proc(gpuShader: cuint, count: cint, source: ptr cstring, lengths: pointer) {.cdecl.}
    glCompileShader: proc(gpuShader: cuint) {.cdecl.}
    glGetShaderiv: proc(gpuShader, name: cuint, value: ptr cint) {.cdecl.}
    glGetShaderInfoLog: proc(gpuShader: cuint, size: cint, length: ptr cint, log: cstring) {.cdecl.}
    glDeleteShader: proc(gpuShader: cuint) {.cdecl.}
    glCreateProgram: proc(): cuint {.cdecl.}
    glAttachShader: proc(program, gpuShader: cuint) {.cdecl.}
    glBindAttribLocation: proc(program, index: cuint, name: cstring) {.cdecl.}
    glLinkProgram: proc(program: cuint) {.cdecl.}
    glGetProgramiv: proc(program, name: cuint, value: ptr cint) {.cdecl.}
    glGetProgramInfoLog: proc(program: cuint, size: cint, length: ptr cint, log: cstring) {.cdecl.}
    glDeleteProgram: proc(program: cuint) {.cdecl.}
    glUseProgram: proc(program: cuint) {.cdecl.}
    glGetUniformLocation: proc(program: cuint, name: cstring): cint {.cdecl.}
    glUniform1i: proc(location, value: cint) {.cdecl.}
    glGenTextures: proc(count: cint, textures: ptr cuint) {.cdecl.}
    glDeleteTextures: proc(count: cint, textures: ptr cuint) {.cdecl.}
    glGenBuffers: proc(count: cint, buffers: ptr cuint) {.cdecl.}
    glBindBuffer: proc(target, buffer: cuint) {.cdecl.}
    glBufferData: proc(target: cuint, size: int, data: pointer, usage: cuint) {.cdecl.}
    glDeleteBuffers: proc(count: cint, buffers: ptr cuint) {.cdecl.}
    glBindTexture: proc(target, texture: cuint) {.cdecl.}
    glTexParameteri: proc(target, name: cuint, value: cint) {.cdecl.}
    glTexImage2D: proc(target: cuint, level, internal, width, height, border: cint,
      format, kind: cuint, data: pointer) {.cdecl.}
    glTexSubImage2D: proc(target: cuint, level, x, y, width, height: cint,
      format, kind: cuint, data: pointer) {.cdecl.}
    glViewport: proc(x, y, width, height: cint) {.cdecl.}
    glScissor: proc(x, y, width, height: cint) {.cdecl.}
    glEnable: proc(capability: cuint) {.cdecl.}
    glDisable: proc(capability: cuint) {.cdecl.}
    glGetIntegerv: proc(name: cuint, value: ptr cint) {.cdecl.}
    glClearColor: proc(red, green, blue, alpha: cfloat) {.cdecl.}
    glClear: proc(mask: cuint) {.cdecl.}
    glEnableVertexAttribArray: proc(index: cuint) {.cdecl.}
    glVertexAttribPointer: proc(index: cuint, size: cint, kind: cuint, normalized: uint8,
      stride: cint, data: pointer) {.cdecl.}
    glDrawArrays: proc(mode: cuint, first, count: cint) {.cdecl.}
    glFinish: proc() {.cdecl.}
    glReadPixels: proc(x, y, width, height: cint, format, kind: cuint, data: pointer) {.cdecl.}
    glGetError: proc(): cuint {.cdecl.}
  GpuDisplay* = ref object
    gpu: GpuApi
    display: DrmDisplay
    atomic: GpuAtomicApi
    restore, properties: seq[GpuAtomicValue]
    blobs: seq[uint32]
    planes: array[2, uint32]
    fbProperties: array[2, uint32]
    pair: GpuFlipPair
    armed, pending: bool
    callbackError: string
    gbm, surface, egl, context, eglSurface: pointer
    program, texture, vertices: uint32
    gbmFrames: seq[tuple[bo: pointer, fb: uint32]]
    locked: seq[pointer]
    front: pointer
    outputs: array[2, DrmScreen]
    regions: array[2, PixelRegion]
    panelWidth, panelHeight, textureWidth, textureHeight: int
    maximumTextureSize: cint

const
  GpuPlaneObject = 0xeeeeeeee'u32
  GpuCrtcObject = 0xcccccccc'u32
  GpuConnectorObject = 0xc0c0c0c0'u32
  GpuAtomicTest = 0x100'u32
  GpuAtomicNonblock = 0x200'u32
  GpuAllowModeset = 0x400'u32
  GpuXrgb8888 = 0x34325258'u32
  GpuGlTexture = 0x0de1'u32
  GpuGlRgba = 0x1908'u32
  GpuGlByte = 0x1401'u32
  GpuGlFloat = 0x1406'u32
  GpuGlTriangles = 4'u32
  GpuGlColourBuffer = 0x4000'u32
  GpuGlScissor = 0x0c11'u32
  GpuGlMaxTextureSize = 0x0d33'u32
  GpuGlRenderer = 0x1f01'u32
  GpuGlVersion = 0x1f02'u32
  GpuGlVertexShader = 0x8b31'u32
  GpuGlFragmentShader = 0x8b30'u32
  GpuGlCompileStatus = 0x8b81'u32
  GpuGlLinkStatus = 0x8b82'u32
  GpuGlMagFilter = 0x2800'u32
  GpuGlMinFilter = 0x2801'u32
  GpuGlWrapS = 0x2802'u32
  GpuGlWrapT = 0x2803'u32
  GpuGlNearest = 0x2600.cint
  GpuGlClampEdge = 0x812f.cint
  GpuEglGbm = 0x31d7'u32
  GpuEglEsApi = 0x30a0'u32
  GpuEglNativeVisual = 0x302e.cint
  GpuEglClientVersion = 0x3098.cint
  GpuEglDepthSize = 0x3025.cint
  GpuEglStencilSize = 0x3026.cint
  GpuEglSamples = 0x3031.cint
  GpuEglSampleBuffers = 0x3032.cint
  GpuAtomicCapability = 3'u64
  GpuPrimaryPlane = 1'u64
  GpuGbmScanoutRendering = 5'u32
  GpuGlArrayBuffer = 0x8892'u32
  GpuGlStaticDraw = 0x88e4'u32
  GpuVerticesPerPanel = 6
  GpuVertexStride = 4 * sizeof(cfloat)
  GpuEglNone = 0x3038.cint
  GpuEglConfigAttributes = [0x3033.cint, 4, 0x3040, 4, 0x3024, 8,
    0x3023, 8, 0x3022, 8, 0x3025, 0, 0x3026, 0, GpuEglNone]
  GpuVertexSource = "attribute vec2 position; attribute vec2 uv; varying vec2 tex; void main(){tex=uv;gl_Position=vec4(position,0.0,1.0);}"
  GpuFragmentSource = "precision highp float; varying vec2 tex; uniform sampler2D image; void main(){gl_FragColor=vec4(texture2D(image,tex).rgb,1.0);}"

static:
  doAssert cpuEndian == littleEndian
  doAssert sizeof(GpuGbmHandle) == 8
  doAssert sizeof(GpuPairEvents) == 32

proc close(api: GpuApi) =
  ## Release only libraries opened for this GPU session.
  if api == nil: return
  for library in [api.glesLibrary, api.eglLibrary, api.gbmLibrary]:
    if library != nil: unloadLib(library)

proc gpuLoadApi(): GpuApi =
  ## Resolve GPU entry points lazily so CPU-only applications need no Mesa.
  result = GpuApi()
  try:
    result.gbmLibrary = loadLib("libgbm.so.1")
    result.eglLibrary = loadLib("libEGL.so.1")
    result.glesLibrary = loadLib("libGLESv2.so.2")
    if result.gbmLibrary == nil or result.eglLibrary == nil or result.glesLibrary == nil:
      raise newException(IOError, "GPU pixel presentation requires GBM, EGL and GLESv2")
    template bindSymbol(field, library: untyped, name: string) =
      result.field = cast[type(result.field)](symAddr(result.library, name))
      if result.field == nil: raise newException(IOError, "Missing GPU entry point: " & name)
    bindSymbol(gbm_create_device, gbmLibrary, "gbm_create_device")
    bindSymbol(gbm_device_destroy, gbmLibrary, "gbm_device_destroy")
    bindSymbol(gbm_surface_create_with_modifiers2, gbmLibrary, "gbm_surface_create_with_modifiers2")
    bindSymbol(gbm_surface_destroy, gbmLibrary, "gbm_surface_destroy")
    bindSymbol(gbm_surface_lock_front_buffer, gbmLibrary, "gbm_surface_lock_front_buffer")
    bindSymbol(gbm_surface_release_buffer, gbmLibrary, "gbm_surface_release_buffer")
    bindSymbol(gbm_bo_get_handle, gbmLibrary, "gbm_bo_get_handle")
    bindSymbol(gbm_bo_get_stride, gbmLibrary, "gbm_bo_get_stride")
    bindSymbol(gbm_bo_get_modifier, gbmLibrary, "gbm_bo_get_modifier")
    bindSymbol(eglGetPlatformDisplay, eglLibrary, "eglGetPlatformDisplay")
    bindSymbol(eglInitialize, eglLibrary, "eglInitialize")
    bindSymbol(eglBindAPI, eglLibrary, "eglBindAPI")
    bindSymbol(eglChooseConfig, eglLibrary, "eglChooseConfig")
    bindSymbol(eglGetConfigAttrib, eglLibrary, "eglGetConfigAttrib")
    bindSymbol(eglCreateContext, eglLibrary, "eglCreateContext")
    bindSymbol(eglCreateWindowSurface, eglLibrary, "eglCreateWindowSurface")
    bindSymbol(eglMakeCurrent, eglLibrary, "eglMakeCurrent")
    bindSymbol(eglSwapInterval, eglLibrary, "eglSwapInterval")
    bindSymbol(eglSwapBuffers, eglLibrary, "eglSwapBuffers")
    bindSymbol(eglDestroyContext, eglLibrary, "eglDestroyContext")
    bindSymbol(eglDestroySurface, eglLibrary, "eglDestroySurface")
    bindSymbol(eglTerminate, eglLibrary, "eglTerminate")
    bindSymbol(eglGetError, eglLibrary, "eglGetError")
    bindSymbol(glGetString, glesLibrary, "glGetString")
    bindSymbol(glCreateShader, glesLibrary, "glCreateShader")
    bindSymbol(glShaderSource, glesLibrary, "glShaderSource")
    bindSymbol(glCompileShader, glesLibrary, "glCompileShader")
    bindSymbol(glGetShaderiv, glesLibrary, "glGetShaderiv")
    bindSymbol(glGetShaderInfoLog, glesLibrary, "glGetShaderInfoLog")
    bindSymbol(glDeleteShader, glesLibrary, "glDeleteShader")
    bindSymbol(glCreateProgram, glesLibrary, "glCreateProgram")
    bindSymbol(glAttachShader, glesLibrary, "glAttachShader")
    bindSymbol(glBindAttribLocation, glesLibrary, "glBindAttribLocation")
    bindSymbol(glLinkProgram, glesLibrary, "glLinkProgram")
    bindSymbol(glGetProgramiv, glesLibrary, "glGetProgramiv")
    bindSymbol(glGetProgramInfoLog, glesLibrary, "glGetProgramInfoLog")
    bindSymbol(glDeleteProgram, glesLibrary, "glDeleteProgram")
    bindSymbol(glUseProgram, glesLibrary, "glUseProgram")
    bindSymbol(glGetUniformLocation, glesLibrary, "glGetUniformLocation")
    bindSymbol(glUniform1i, glesLibrary, "glUniform1i")
    bindSymbol(glGenTextures, glesLibrary, "glGenTextures")
    bindSymbol(glDeleteTextures, glesLibrary, "glDeleteTextures")
    bindSymbol(glGenBuffers, glesLibrary, "glGenBuffers")
    bindSymbol(glBindBuffer, glesLibrary, "glBindBuffer")
    bindSymbol(glBufferData, glesLibrary, "glBufferData")
    bindSymbol(glDeleteBuffers, glesLibrary, "glDeleteBuffers")
    bindSymbol(glBindTexture, glesLibrary, "glBindTexture")
    bindSymbol(glTexParameteri, glesLibrary, "glTexParameteri")
    bindSymbol(glTexImage2D, glesLibrary, "glTexImage2D")
    bindSymbol(glTexSubImage2D, glesLibrary, "glTexSubImage2D")
    bindSymbol(glViewport, glesLibrary, "glViewport")
    bindSymbol(glScissor, glesLibrary, "glScissor")
    bindSymbol(glEnable, glesLibrary, "glEnable")
    bindSymbol(glDisable, glesLibrary, "glDisable")
    bindSymbol(glGetIntegerv, glesLibrary, "glGetIntegerv")
    bindSymbol(glClearColor, glesLibrary, "glClearColor")
    bindSymbol(glClear, glesLibrary, "glClear")
    bindSymbol(glEnableVertexAttribArray, glesLibrary, "glEnableVertexAttribArray")
    bindSymbol(glVertexAttribPointer, glesLibrary, "glVertexAttribPointer")
    bindSymbol(glDrawArrays, glesLibrary, "glDrawArrays")
    bindSymbol(glFinish, glesLibrary, "glFinish")
    bindSymbol(glReadPixels, glesLibrary, "glReadPixels")
    bindSymbol(glGetError, glesLibrary, "glGetError")
  except:
    result.close()
    raise

proc gpuChecked(value: bool, operation: string) =
  ## Fail with the operation and current system error instead of continuing.
  if not value: raise newException(IOError, operation & ": " & $osLastError())

proc gpuCheckedEgl(probe: GpuDisplay, value: cuint, operation: string) =
  ## Include EGL's own error code when context or buffer operations fail.
  if value == 0: raise newException(IOError, operation & ": EGL " & $probe.gpu.eglGetError())

proc gpuLoadAtomic(display: DrmDisplay): GpuAtomicApi =
  ## Load experimental entry points without changing the normal DRM backend.
  template bindField(field: untyped, name: string) =
    result.field = cast[type(result.field)](symAddr(display.api.library, name))
    gpuChecked(result.field != nil, name)
  bindField(alloc, "drmModeAtomicAlloc")
  bindField(free, "drmModeAtomicFree")
  bindField(add, "drmModeAtomicAddProperty")
  bindField(gpuCommit, "drmModeAtomicCommit")
  bindField(createBlob, "drmModeCreatePropertyBlob")
  bindField(destroyBlob, "drmModeDestroyPropertyBlob")

proc gpuProperty(probe: GpuDisplay, id, kind: uint32, name: string): GpuAtomicValue =
  ## Find a gpuProperty by name and retain its original value for restoration.
  let
    api = probe.display.api
    values = api.getProperties(probe.display.fd, id, kind)
  gpuChecked(values != nil, "Reading properties")
  defer: api.freeProperties(values)
  for index in 0 ..< int(values.count):
    let item = api.getProperty(probe.display.fd, values.ids[index])
    gpuChecked(item != nil, "Reading property")
    let matches = $cast[cstring](addr item.name[0]) == name
    api.freeProperty(item)
    if matches:
      return GpuAtomicValue(id: id, gpuProperty: values.ids[index], value: values.values[index])
  raise newException(IOError, "Missing DRM property " & name & " on " & $id)

proc gpuSet(probe: GpuDisplay, id, kind: uint32, name: string, value: uint64) =
  ## Append an atomic update and the matching original state exactly once.
  let previous = probe.gpuProperty(id, kind, name)
  probe.restore.add previous
  probe.properties.add GpuAtomicValue(id: id, gpuProperty: previous.gpuProperty, value: value)

proc gpuBlob(probe: GpuDisplay, mode: var ModeInfo): uint32 =
  ## Retain a mode gpuBlob until after the display has been restored.
  gpuChecked(probe.atomic.createBlob(probe.display.fd, addr mode, csize_t(sizeof(mode)), addr result) == 0,
    "Creating mode blob")
  probe.blobs.add result

proc gpuConfigure(probe: GpuDisplay) =
  ## Discover primary planes and construct one transaction for two active outputs.
  let
    display = probe.display
    api = display.api
    planes = api.getPlaneResources(display.fd)
    resources = api.getResources(display.fd)
  gpuChecked(planes != nil and resources != nil, "Enumerating planes")
  defer:
    api.freePlaneResources(planes)
    api.freeResources(resources)
  for index, screen in probe.outputs:
    var crtcIndex = -1
    for candidate in 0 ..< int(resources.countCrtcs):
      if resources.crtcs[candidate] == screen.crtc: crtcIndex = candidate
    gpuChecked(crtcIndex >= 0, "Finding CRTC index")
    for candidate in 0 ..< int(planes.count):
      let plane = api.getPlane(display.fd, planes.planes[candidate])
      gpuChecked(plane != nil, "Reading plane")
      defer: api.freePlane(plane)
      if (plane.possibleCrtcs and (1'u32 shl crtcIndex)) == 0: continue
      if probe.gpuProperty(plane.id, GpuPlaneObject, "type").value != GpuPrimaryPlane: continue
      if plane.crtc notin [0'u32, screen.crtc]: continue
      if plane.id in probe.planes: continue
      var compatible = false
      for format in 0 ..< int(plane.countFormats):
        if plane.formats[format] == GpuXrgb8888: compatible = true
      if compatible:
        probe.planes[index] = plane.id
        break
    gpuChecked(probe.planes[index] != 0, "Finding compatible primary plane")
    let plane = probe.planes[index]
    probe.pair.crtcs[index] = screen.crtc
    probe.gpuSet(screen.connector, GpuConnectorObject, "CRTC_ID", screen.crtc)
    probe.gpuSet(screen.crtc, GpuCrtcObject, "ACTIVE", 1)
    probe.gpuSet(screen.crtc, GpuCrtcObject, "MODE_ID", probe.gpuBlob(screen.mode))
    # Copy an active original mode into our own gpuBlob instead of retaining its ID.
    if screen.original.modeValid != 0:
      probe.restore[^1].value = probe.gpuBlob(screen.original.mode)
    probe.gpuSet(plane, GpuPlaneObject, "CRTC_ID", screen.crtc)
    probe.gpuSet(plane, GpuPlaneObject, "FB_ID", 0)
    probe.fbProperties[index] = probe.properties[^1].gpuProperty
    probe.gpuSet(plane, GpuPlaneObject, "SRC_X", 0)
    probe.gpuSet(plane, GpuPlaneObject, "SRC_Y", uint64(index * probe.panelHeight) shl 16)
    probe.gpuSet(plane, GpuPlaneObject, "SRC_W", uint64(probe.panelWidth) shl 16)
    probe.gpuSet(plane, GpuPlaneObject, "SRC_H", uint64(probe.panelHeight) shl 16)
    probe.gpuSet(plane, GpuPlaneObject, "CRTC_X", 0)
    probe.gpuSet(plane, GpuPlaneObject, "CRTC_Y", 0)
    probe.gpuSet(plane, GpuPlaneObject, "CRTC_W", uint64(probe.panelWidth))
    probe.gpuSet(plane, GpuPlaneObject, "CRTC_H", uint64(probe.panelHeight))
    echo screen.name, ": CRTC ", screen.crtc, ", plane ", plane

proc gpuCommit(probe: GpuDisplay, values: seq[GpuAtomicValue], flags: uint32, data: pointer = nil) =
  ## Submit a complete transaction or leave the current state unchanged on error.
  let request = probe.atomic.alloc()
  gpuChecked(request != nil, "Allocating atomic request")
  defer: probe.atomic.free(request)
  for item in values:
    gpuChecked(probe.atomic.add(request, item.id, item.gpuProperty, item.value) >= 0, "Adding atomic property")
  gpuChecked(probe.atomic.gpuCommit(probe.display.fd, request, flags, data) == 0, "Committing paired display update")

proc gpuFlip2(fd: cint, sequence, seconds, microseconds, crtc: cuint, data: pointer) {.cdecl.} =
  ## Handle both events without allowing a Nim exception across a C callback.
  let probe = cast[GpuDisplay](data)
  try:
    probe.pair.complete(crtc, uint64(seconds) * 1_000_000 + uint64(microseconds))
  except ValueError as error:
    probe.callbackError = error.msg

proc gpuWaitPair(probe: GpuDisplay) =
  ## Retire a generation only after both display controllers have completed it.
  if not probe.pending: return
  let started = getMonoTime()
  var context = GpuPairEvents(version: 3, flip2: gpuFlip2)
  while not probe.pair.ready:
    let remaining = FlipTimeoutMs - int((getMonoTime() - started).inMilliseconds)
    gpuChecked(remaining > 0, "Timed out waiting for paired flip")
    var descriptor = TPollfd(fd: probe.display.fd, events: POLLIN)
    let polled = posix.poll(addr descriptor, 1, cint(remaining))
    if polled < 0 and osLastError() == OSErrorCode(EINTR): continue
    gpuChecked(polled > 0 and (descriptor.revents and POLLIN) != 0, "Polling paired flip")
    gpuChecked(probe.display.api.handleEvent(probe.display.fd, cast[ptr EventContext](addr context)) == 0,
      "Reading paired flip")
    if probe.callbackError.len > 0: raise newException(IOError, probe.callbackError)
  probe.pending = false

proc gpuShader(probe: GpuDisplay, kind: uint32, source: string): uint32 =
  ## Compile a shader and report the driver's compiler log on failure.
  result = probe.gpu.glCreateShader(kind)
  var
    text = source.cstring
    compiled: cint
  probe.gpu.glShaderSource(result, 1, addr text, nil)
  probe.gpu.glCompileShader(result)
  probe.gpu.glGetShaderiv(result, GpuGlCompileStatus, addr compiled)
  if compiled == 0:
    var log = newString(4096)
    probe.gpu.glGetShaderInfoLog(result, cint(log.len), nil, log.cstring)
    probe.gpu.glDeleteShader(result)
    raise newException(IOError, "Compiling shader: " & log)

proc gpuInitialize(probe: GpuDisplay) =
  ## Create one EGL context and one linear GBM render target for both panels.
  probe.gbm = probe.gpu.gbm_create_device(probe.display.fd)
  gpuChecked(probe.gbm != nil, "Creating GBM device")
  var linear = 0'u64
  probe.surface = probe.gpu.gbm_surface_create_with_modifiers2(probe.gbm, uint32(probe.panelWidth),
    uint32(probe.panelHeight * 2), GpuXrgb8888, addr linear, 1, GpuGbmScanoutRendering)
  gpuChecked(probe.surface != nil, "Creating linear combined GBM surface")
  probe.egl = probe.gpu.eglGetPlatformDisplay(GpuEglGbm, probe.gbm, nil)
  gpuChecked(probe.egl != nil, "Opening GBM EGL display")
  probe.gpuCheckedEgl(probe.gpu.eglInitialize(probe.egl, nil, nil), "Initializing EGL")
  probe.gpuCheckedEgl(probe.gpu.eglBindAPI(GpuEglEsApi), "Selecting OpenGL ES")
  var
    attributes = GpuEglConfigAttributes
    count: cint
    selected: pointer
  probe.gpuCheckedEgl(probe.gpu.eglChooseConfig(probe.egl, addr attributes[0], nil, 0, addr count), "Counting EGL configs")
  gpuChecked(count > 0, "Expected a window-compatible EGL config")
  var
    configs = newSeq[pointer](count)
    sizes: array[4, cint]
  probe.gpuCheckedEgl(probe.gpu.eglChooseConfig(probe.egl, addr attributes[0], addr configs[0], count, addr count), "Choosing EGL config")
  for index in 0 ..< int(count):
    var visual: cint
    probe.gpuCheckedEgl(probe.gpu.eglGetConfigAttrib(probe.egl, configs[index], GpuEglNativeVisual, addr visual), "Reading EGL visual")
    if uint32(visual) != GpuXrgb8888: continue
    for field, name in [GpuEglDepthSize, GpuEglStencilSize, GpuEglSamples, GpuEglSampleBuffers]:
      probe.gpuCheckedEgl(probe.gpu.eglGetConfigAttrib(probe.egl, configs[index], name, addr sizes[field]), "Reading EGL buffers")
    # EGL's zero attributes specify minimum sizes, not the absence of MSAA/depth.
    if sizes == [0.cint, 0, 0, 0]:
      selected = configs[index]
      break
  gpuChecked(selected != nil, "Finding XRGB EGL config without depth, stencil or MSAA")
  echo "EGL depth/stencil/samples/sample buffers: ", sizes
  var contextAttributes = [GpuEglClientVersion, 2.cint, GpuEglNone]
  probe.context = probe.gpu.eglCreateContext(probe.egl, selected, nil, addr contextAttributes[0])
  gpuChecked(probe.context != nil, "Creating GLES2 context")
  probe.eglSurface = probe.gpu.eglCreateWindowSurface(probe.egl, selected, probe.surface, nil)
  gpuChecked(probe.eglSurface != nil, "Creating EGL window surface")
  probe.gpuCheckedEgl(probe.gpu.eglMakeCurrent(probe.egl, probe.eglSurface, probe.eglSurface, probe.context), "Making context current")
  probe.gpuCheckedEgl(probe.gpu.eglSwapInterval(probe.egl, 0), "Disabling EGL's separate refresh wait")
  let
    renderer = $probe.gpu.glGetString(GpuGlRenderer)
    version = $probe.gpu.glGetString(GpuGlVersion)
  echo "GPU: ", renderer, "; GLES: ", version
  gpuChecked(renderer.len > 0, "Expected a hardware renderer")
  for software in ["llvmpipe", "softpipe", "swrast", "swiftshader"]:
    gpuChecked(software notin renderer.toLowerAscii, "Software rendering is not a GPU proof: " & renderer)
  let
    vertex = probe.gpuShader(GpuGlVertexShader, GpuVertexSource)
    fragment = probe.gpuShader(GpuGlFragmentShader, GpuFragmentSource)
  defer:
    probe.gpu.glDeleteShader(vertex)
    probe.gpu.glDeleteShader(fragment)
  probe.program = probe.gpu.glCreateProgram()
  probe.gpu.glAttachShader(probe.program, vertex)
  probe.gpu.glAttachShader(probe.program, fragment)
  probe.gpu.glBindAttribLocation(probe.program, 0, "position")
  probe.gpu.glBindAttribLocation(probe.program, 1, "uv")
  probe.gpu.glLinkProgram(probe.program)
  var linked: cint
  probe.gpu.glGetProgramiv(probe.program, GpuGlLinkStatus, addr linked)
  if linked == 0:
    var log = newString(4096)
    probe.gpu.glGetProgramInfoLog(probe.program, cint(log.len), nil, log.cstring)
    raise newException(IOError, "Linking program: " & log)
  probe.gpu.glUseProgram(probe.program)
  probe.gpu.glUniform1i(probe.gpu.glGetUniformLocation(probe.program, "image"), 0)
  probe.gpu.glGenTextures(1, addr probe.texture)
  probe.gpu.glBindTexture(GpuGlTexture, probe.texture)
  for name in [GpuGlMagFilter, GpuGlMinFilter]: probe.gpu.glTexParameteri(GpuGlTexture, name, GpuGlNearest)
  for name in [GpuGlWrapS, GpuGlWrapT]: probe.gpu.glTexParameteri(GpuGlTexture, name, GpuGlClampEdge)
  probe.gpu.glGetIntegerv(GpuGlMaxTextureSize, addr probe.maximumTextureSize)
  gpuChecked(probe.maximumTextureSize > 0, "Reading GPU texture capacity")
  probe.gpu.glEnableVertexAttribArray(0)
  probe.gpu.glEnableVertexAttribArray(1)
  probe.gpu.glGenBuffers(1, addr probe.vertices)
  probe.gpu.glBindBuffer(GpuGlArrayBuffer, probe.vertices)

proc gpuUpload(probe: GpuDisplay, image: Image, regions: array[2, PixelRegion]) =
  ## Upload one native-size image and retain geometry until its crops change.
  let
    width = if image == nil: 0 else: image.width
    height = if image == nil: 0 else: image.height
  validateRegions(width, height, regions)
  if image == nil:
    probe.regions = regions
    return
  if width <= 0 or height <= 0 or width > int(probe.maximumTextureSize) or
      height > int(probe.maximumTextureSize) or image.data.len != width * height:
    raise newException(ValueError, "Invalid GPU source image dimensions")
  let resized = width != probe.textureWidth or height != probe.textureHeight
  if resized or regions != probe.regions:
    var vertices = pixelVertices(width, height, regions)
    probe.gpu.glBufferData(GpuGlArrayBuffer, sizeof(vertices), addr vertices[0], GpuGlStaticDraw)
  if resized:
    probe.gpu.glTexImage2D(GpuGlTexture, 0, cint(GpuGlRgba), cint(width), cint(height),
      0, GpuGlRgba, GpuGlByte, unsafeAddr image.data[0])
  else:
    probe.gpu.glTexSubImage2D(GpuGlTexture, 0, 0, 0, cint(width), cint(height),
      GpuGlRgba, GpuGlByte, unsafeAddr image.data[0])
  probe.textureWidth = width
  probe.textureHeight = height
  probe.regions = regions
  gpuChecked(probe.gpu.glGetError() == 0, "Uploading GPU pixels")

proc gpuDraw(probe: GpuDisplay) =
  ## Enlarge two cropped texture regions with nearest-neighbour sampling.
  probe.gpu.glDisable(GpuGlScissor)
  probe.gpu.glClearColor(0, 0, 0, 1)
  probe.gpu.glClear(GpuGlColourBuffer)
  probe.gpu.glEnable(GpuGlScissor)
  for index in 0..1:
    if probe.regions[index] == PixelRegion(): continue
    let
      offset = index * GpuVerticesPerPanel * GpuVertexStride
      view = pixelViewport(probe.regions[index], probe.panelWidth, probe.panelHeight)
    probe.gpu.glScissor(0, cint((1 - index) * probe.panelHeight),
      cint(probe.panelWidth), cint(probe.panelHeight))
    probe.gpu.glViewport(cint(view.x), cint((2 - index) * probe.panelHeight - view.y - view.height),
      cint(view.width), cint(view.height))
    probe.gpu.glVertexAttribPointer(0, 2, GpuGlFloat, 0, GpuVertexStride, cast[pointer](offset))
    probe.gpu.glVertexAttribPointer(1, 2, GpuGlFloat, 0, GpuVertexStride, cast[pointer](offset + 2 * sizeof(cfloat)))
    probe.gpu.glDrawArrays(GpuGlTriangles, 0, GpuVerticesPerPanel)
  gpuChecked(probe.gpu.glGetError() == 0, "Drawing GPU pixels")

proc gpuFramebuffer(probe: GpuDisplay, bo: pointer): uint32 =
  ## Register each GBM allocation once and reject non-linear storage explicitly.
  for frame in probe.gbmFrames:
    if frame.bo == bo: return frame.fb
  gpuChecked(probe.gpu.gbm_bo_get_modifier(bo) == 0, "Expected a linear GBM buffer")
  var
    handles = [probe.gpu.gbm_bo_get_handle(bo).u32, 0'u32, 0, 0]
    pitches = [probe.gpu.gbm_bo_get_stride(bo), 0'u32, 0, 0]
    offsets: array[4, uint32]
  gpuChecked(probe.display.api.addFb2(probe.display.fd, uint32(probe.panelWidth),
    uint32(probe.panelHeight * 2), GpuXrgb8888, addr handles[0], addr pitches[0],
    addr offsets[0], addr result, 0) == 0, "Registering combined GBM framebuffer")
  probe.gbmFrames.add (bo, result)

proc gpuSubmit(probe: GpuDisplay, fb: uint32) =
  ## Test the initial pair and then submit one vblank-synchronized transaction.
  var values: seq[GpuAtomicValue]
  for item in probe.properties:
    if probe.armed and item.gpuProperty notin probe.fbProperties: continue
    var value = item
    if item.id in probe.planes:
      for index in 0..1:
        if item.id == probe.planes[index] and item.gpuProperty == probe.fbProperties[index]:
          value.value = fb
    values.add value
  if not probe.armed:
    probe.gpuCommit(values, GpuAtomicTest or GpuAllowModeset)
    echo "Atomic TEST_ONLY: combined framebuffer accepted by both outputs"
    probe.gpuCommit(values, GpuAllowModeset)
    probe.armed = true
  else:
    probe.pair.completed = {}
    probe.gpuCommit(values, GpuAtomicNonblock or FlipEvent, cast[pointer](probe))
    probe.pending = true

proc close*(probe: GpuDisplay) =
  ## Restore the saved transaction before freeing anything still used for scanout.
  if probe == nil or probe.display == nil: return
  var errors: seq[string]
  template attempt(body: untyped) =
    try: body
    except CatchableError as error: errors.add error.msg
  if probe.armed:
    attempt: probe.gpuWaitPair()
    attempt:
      probe.gpuCommit(probe.restore, GpuAllowModeset)
      probe.armed = false
    if probe.armed:
      # A failed restore must not leave scanout pointing at freed GPU storage.
      var disabled = true
      for screen in probe.display.screens:
        if probe.display.api.setCrtc(probe.display.fd, screen.crtc, 0, 0, 0, nil, 0, nil) < 0:
          disabled = false
          errors.add "Disabling output after failed restore: " & screen.name
      if not disabled:
        attempt: gpuChecked(posix.close(probe.display.fd) == 0, "Closing failed DRM session")
        probe.display.fd = -1
        for screen in probe.display.screens:
          for scanout in screen.buffers:
            attempt: gpuChecked(munmap(scanout.memory, int(scanout.buffer.size)) == 0, "Unmapping abandoned CPU buffer")
          screen.buffers.setLen(0)
  for bo in probe.locked: probe.gpu.gbm_surface_release_buffer(probe.surface, bo)
  probe.locked.setLen(0)
  for frame in probe.gbmFrames:
    if probe.display.fd >= 0:
      attempt: gpuChecked(probe.display.api.removeFb(probe.display.fd, frame.fb) == 0, "Removing GPU framebuffer")
  if probe.egl != nil:
    if probe.context != nil:
      attempt:
        probe.gpuCheckedEgl(probe.gpu.eglMakeCurrent(probe.egl, probe.eglSurface,
          probe.eglSurface, probe.context), "Activating context for GPU cleanup")
        if probe.texture != 0: probe.gpu.glDeleteTextures(1, addr probe.texture)
        if probe.vertices != 0: probe.gpu.glDeleteBuffers(1, addr probe.vertices)
        if probe.program != 0: probe.gpu.glDeleteProgram(probe.program)
    attempt: probe.gpuCheckedEgl(probe.gpu.eglMakeCurrent(probe.egl, nil, nil, nil), "Releasing EGL context")
    if probe.eglSurface != nil:
      attempt: probe.gpuCheckedEgl(probe.gpu.eglDestroySurface(probe.egl, probe.eglSurface), "Destroying EGL surface")
    if probe.context != nil:
      attempt: probe.gpuCheckedEgl(probe.gpu.eglDestroyContext(probe.egl, probe.context), "Destroying EGL context")
    attempt: probe.gpuCheckedEgl(probe.gpu.eglTerminate(probe.egl), "Terminating EGL")
  if probe.surface != nil: probe.gpu.gbm_surface_destroy(probe.surface)
  if probe.gbm != nil: probe.gpu.gbm_device_destroy(probe.gbm)
  if probe.display.fd >= 0:
    for gpuBlob in probe.blobs:
      attempt: gpuChecked(probe.atomic.destroyBlob(probe.display.fd, gpuBlob) == 0, "Destroying mode blob")
  probe.display.gpuOwned = false
  probe.display = nil
  probe.gpu.close()
  probe.gpu = nil
  if errors.len > 0: raise newException(IOError, errors.join("; "))

proc newGpuDisplay*(display: DrmDisplay, outputs: array[2, DrmScreen]): GpuDisplay =
  ## Claim two idle unrotated outputs; close this presenter before its windows.
  if display == nil or display.fd < 0 or display.gpuOwned or
      display.screens.len != 2 or outputs[0] == outputs[1]:
    raise newException(ValueError, "GPU pixels require two exclusively owned DRM outputs")
  for screen in outputs:
    if screen notin display.screens or screen.rotation != 0 or screen.activated or screen.pending:
      raise newException(ValueError, "GPU pixels require idle, unrotated DRM windows")
  if outputs[0].crtc == outputs[1].crtc:
    raise newException(ValueError, "GPU pixels require independent display controllers")
  if outputs[0].width != outputs[1].width or outputs[0].height != outputs[1].height:
    raise newException(ValueError, "GPU pixels require equally sized outputs")
  result = GpuDisplay(display: display, outputs: outputs,
    panelWidth: outputs[0].width, panelHeight: outputs[0].height)
  try:
    result.gpu = gpuLoadApi()
    result.atomic = gpuLoadAtomic(display)
    gpuChecked(display.api.setClientCap(display.fd, GpuAtomicCapability, 1) == 0, "Enabling atomic KMS")
    result.gpuConfigure()
    for screen in outputs:
      display.closeScreen(screen)
      screen.buffers.setLen(0)
    result.gpuInitialize()
    gpuChecked(display.api.setMaster(display.fd) == 0, "Acquiring DRM master")
    display.master = true
    display.gpuOwned = true
  except:
    result.close()
    raise

proc presentGpuPixels*(probe: GpuDisplay, image: Image, regions: array[2, PixelRegion]) =
  ## Upload once, scale on the GPU, and retire storage after both vblank events.
  if probe == nil or probe.display == nil:
    raise newException(ValueError, "GPU pixel presenter is closed")
  probe.gpuCheckedEgl(probe.gpu.eglMakeCurrent(probe.egl, probe.eglSurface,
    probe.eglSurface, probe.context), "Activating GPU pixel context")
  probe.gpuUpload(image, regions)
  probe.gpuDraw()
  probe.gpuCheckedEgl(probe.gpu.eglSwapBuffers(probe.egl, probe.eglSurface), "Swapping EGL render buffer")
  probe.gpu.glFinish()
  gpuChecked(probe.gpu.glGetError() == 0, "Finishing GPU pixels")
  let bo = probe.gpu.gbm_surface_lock_front_buffer(probe.surface)
  gpuChecked(bo != nil, "Locking completed GBM buffer")
  probe.locked.add bo
  probe.gpuSubmit(probe.gpuFramebuffer(bo))
  probe.gpuWaitPair()
  if probe.front != nil:
    probe.gpu.gbm_surface_release_buffer(probe.surface, probe.front)
    probe.locked.delete(probe.locked.find(probe.front))
  probe.front = bo

