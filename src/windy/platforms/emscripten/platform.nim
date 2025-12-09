import
  std/[tables, strutils, unicode, times],
  ../../common, ../../internal, vmath, pixie

import emdefs

type
  Window* = ref object
    onCloseRequest*: Callback
    onFrame*: Callback
    onMove*: Callback
    onResize*: Callback
    onFocusChange*: Callback
    onMouseMove*: Callback
    onScroll*: Callback
    onButtonPress*: ButtonCallback
    onButtonRelease*: ButtonCallback
    onRune*: RuneCallback
    onImeChange*: Callback

    ## In Emscripten, the canvas is the more or less the window.
    canvas: cstring
    state: WindowState
    cachedTitle: string

  # use HttpRequestHandle from common.nim
  EmsHttpRequestState = ref object
    url, verb: string
    headers: seq[HttpHeader]
    requestBody: string
    deadline: float64
    startTime: float64
    canceled: bool
    completed: bool

    onError: HttpErrorCallback
    onResponse: HttpResponseCallback
    onUploadProgress: HttpProgressCallback
    onDownloadProgress: HttpProgressCallback

    # Fetch specific
    fetch*: ptr emscripten_fetch_t
    bodyKeepAlive*: string

var
  quitRequested*: bool
  onQuitRequest*: Callback
  multiClickInterval*: Duration = initDuration(milliseconds = 200)
  multiClickRadius*: float = 4

  initialized: bool
  windows: seq[Window]
  currentContext: EMSCRIPTEN_WEBGL_CONTEXT_HANDLE
  mainWindow: Window  # Track the main window for events
  httpRequests: Table[HttpRequestHandle, EmsHttpRequestState]

proc handleButtonPress(window: Window, button: Button)
proc handleButtonRelease(window: Window, button: Button)
proc handleRune(window: Window, rune: Rune)
proc setupEventHandlers(window: Window)  # Forward declaration

proc init =
  if initialized:
    return
  initialized = true

proc makeContextCurrent*(window: Window) =
  if currentContext != 0:
    discard emscripten_webgl_make_context_current(currentContext)

proc swapBuffers*(window: Window) =
  # In Emscripten/WebGL, swapping is automatic
  discard

proc close*(window: Window) =
  ## Emscripten windows cannot be closed.
  warn "Emscripten windows cannot be closed"

proc closeRequested*(window: Window): bool =
  return false

proc pollHttp() =
  ## Poll HTTP requests.
  let now = epochTime()
  # Deadline checks
  for handle, state in httpRequests:
    if state.completed: continue
    if state.deadline > 0 and state.deadline <= now:
      state.completed = true
      if state.onError != nil:
        state.onError("Deadline exceeded")

proc pollEvents*() =
  ## Polls for events.
  ## Note: Will block to match frames per second.
  if mainWindow != nil:
    if mainWindow.onFrame != nil:
      mainWindow.onFrame()
    mainWindow.state.perFrame = PerFrame()
  pollHttp()
  emscripten_sleep(0)

proc run*(window: Window) =
  proc mainLoop() {.cdecl.} =
    if mainWindow != nil:
      if mainWindow.onFrame != nil:
        mainWindow.onFrame()
      mainWindow.state.perFrame = PerFrame()
    pollHttp()
  emscripten_set_main_loop(mainLoop, 0, true)

proc size*(window: Window): IVec2 =
  # Get the size of the canvas.
  result.x = get_window_width() * get_device_pixel_ratio().int32
  result.y = get_window_height() * get_device_pixel_ratio().int32

proc `size=`*(window: Window, size: IVec2) =
  ## Size cannot be set on emscripten windows.
  warn "Size cannot be set on emscripten windows"

proc `title=`*(window: Window, title: string) =
  ## Sets the title of the window.
  window.cachedTitle = title
  set_document_title(title.cstring)

proc `title`*(window: Window): string =
  ## Gets the title of the window.
  window.cachedTitle

proc visible*(window: Window): bool =
  ## Gets the visibility of the window.
  #TODO: Implement HTML visibility.
  true

proc `visible=`*(window: Window, visible: bool) =
  # Visible is always cannot be set on emscripten windows.
  warn "Visible cannot be set on emscripten windows"

proc runeInputEnabled*(window: Window): bool =
  window.state.runeInputEnabled

proc `runeInputEnabled=`*(window: Window, enabled: bool) =
  window.state.runeInputEnabled = enabled

proc pos*(window: Window): IVec2 =
  ## Position cannot be gotten on emscripten windows.
  warn "Position cannot be gotten on emscripten windows"

proc `pos=`*(window: Window, pos: IVec2) =
  ## Position cannot be set on emscripten windows.
  warn "Position cannot be set on emscripten windows"

proc url*(window: Window): string =
  ## Gets the URL of the window.
  let len = get_window_url_length()
  if len <= 1:
    return ""
  var s = newString(len - 1)
  discard get_window_url_into(s.cstring, len)
  return s

proc framebufferSize*(window: Window): IVec2 =
  ## Gets the framebuffer size of the window.
  result.x = get_canvas_width()
  result.y = get_canvas_height()

proc minimized*(window: Window): bool =
  false  # Not tracked in browser context

proc `minimized=`*(window: Window, minimized: bool) =
  discard  # Not applicable in browser

proc maximized*(window: Window): bool =
  false  # Not tracked in browser context

proc `maximized=`*(window: Window, maximized: bool) =
  discard  # Not applicable in browser

proc fullscreen*(window: Window): bool =
  false  # Could be implemented with Fullscreen API

proc `fullscreen=`*(window: Window, fullscreen: bool) =
  discard

proc focused*(window: Window): bool =
  true  # Not applicable in browser.

proc `focused=`*(window: Window, focused: bool) =
  discard  # Focus is controlled by browser

proc updateCanvasSize(window: Window) =
  let
    width = get_window_width().int32
    height = get_window_height().int32
    contentScale = get_device_pixel_ratio().float32
    size = ivec2(width, height)
  set_canvas_size(
    (size.x.float32 * contentScale).int32,
    (size.y.float32 * contentScale).int32
  )

proc contentScale*(window: Window): float32 =
  ## Gets the content scale of the window.
  let contentScale = get_device_pixel_ratio().float32
  if window.state.contentScale != contentScale:
    window.state.contentScale = contentScale
    window.updateCanvasSize()
  return window.state.contentScale

proc newWindow*(
  title = "",
  size = ivec2(0, 0),
  pos = ivec2(0, 0),
  screen = 0,
  visible = true,
  vsync = true,
  openglVersion = OpenGL3Dot3,
  msaa = msaaDisabled,
  depthBits = 24,
  stencilBits = 8,
  redBits = 8,
  greenBits = 8,
  blueBits = 8,
  alphaBits = 8,
  decorated = true,
  transparent = false,
  floating = false,
  resizable = true,
  maximized = false,
  minimized = false,
  fullscreen = false,
  focus = true
): Window =
  init()

  result = Window()
  result.canvas = "#canvas"

  # Create WebGL context
  var attrs: EmscriptenWebGLContextAttributes
  emscripten_webgl_init_context_attributes(attrs.addr)

  attrs.alpha = alphaBits > 0
  attrs.depth = depthBits > 0
  attrs.stencil = stencilBits > 0
  attrs.antialias = msaa != msaaDisabled
  attrs.premultipliedAlpha = true
  attrs.preserveDrawingBuffer = false
  attrs.majorVersion = 2  # WebGL 2.0
  attrs.minorVersion = 0
  attrs.enableExtensionsByDefault = true

  currentContext = emscripten_webgl_create_context(result.canvas, attrs.addr)
  if currentContext == 0:
    # Try WebGL 1.0 if 2.0 fails
    attrs.majorVersion = 1
    currentContext = emscripten_webgl_create_context(result.canvas, attrs.addr)
    if currentContext == 0:
      raise WindyError.newException("Failed to create WebGL context")

  windows.add(result)
  mainWindow = result

  # Initialize event state
  result.state.perFrame = PerFrame()

  # Setup event handlers
  setupEventHandlers(result)

  # Set the title of the window.
  result.title = title

  # Set the correct canvas size based on the window size and content scale.
  result.updateCanvasSize()

  # Make canvas focusable for keyboard input
  make_canvas_focusable()

proc mousePos*(window: Window): IVec2 =
  (window.state.mousePos.vec2 * window.contentScale).ivec2

proc mousePrevPos*(window: Window): IVec2 =
  (window.state.mousePrevPos.vec2 * window.contentScale).ivec2

proc mouseDelta*(window: Window): IVec2 =
  (window.state.perFrame.mouseDelta.vec2 * window.contentScale).ivec2

proc scrollDelta*(window: Window): Vec2 =
  window.state.perFrame.scrollDelta

proc screenToContent*(window: Window, v: Vec2): Vec2 =
  v

proc contentToScreen*(window: Window, v: Vec2): Vec2 =
  v

proc buttonDown*(window: Window): ButtonView =
  window.state.buttonDown.ButtonView

proc buttonPressed*(window: Window): ButtonView =
  window.state.perFrame.buttonPressed.ButtonView

proc buttonReleased*(window: Window): ButtonView =
  window.state.perFrame.buttonReleased.ButtonView

proc buttonToggle*(window: Window): ButtonView =
  window.state.buttonToggle.ButtonView

# Clipboard functions
proc clipboardContent*(): string =
  ""  # Would need JavaScript interop

proc `clipboardContent=`*(content: string) =
  discard  # Would need JavaScript interop

# Screen functions
proc getScreens*(): seq[Screen] =
  @[Screen(
    left: 0,
    right: 1920,  # Would need to query actual screen size
    top: 0,
    bottom: 1080,
    primary: true
  )]

# Cursor functions
proc cursor*(window: Window): Cursor =
  window.state.cursor

proc `cursor=`*(window: Window, cursor: Cursor) =
  window.state.cursor = cursor
  # TODO: Apply CSS cursor style based on cursor type

# Style functions
proc style*(window: Window): WindowStyle =
  DecoratedResizable

proc `style=`*(window: Window, style: WindowStyle) =
  discard

# Icon functions
proc icon*(window: Window): Image =
  nil

proc `icon=`*(window: Window, icon: Image) =
  discard

proc startDrag*(window: Window, pos: IVec2) =
  discard

proc stopDrag*(window: Window) =
  discard

proc startResize*(window: Window, pos: IVec2, direction: int) =
  discard

proc stopResize*(window: Window) =
  discard

proc vsync*(window: Window): bool =
  true  # Browser controls vsync

proc `vsync=`*(window: Window, vsync: bool) =
  discard

proc openglVersion*(window: Window): OpenGLVersion =
  OpenGL3Dot0  # WebGL 2.0 ~ OpenGL ES 3.0

proc msaa*(window: Window): MSAA =
  msaaDisabled

proc redBits*(window: Window): int =
  8

proc greenBits*(window: Window): int =
  8

proc blueBits*(window: Window): int =
  8

proc alphaBits*(window: Window): int =
  8

proc depthBits*(window: Window): int =
  24

proc stencilBits*(window: Window): int =
  8

proc setClipboardString*(s: string) =
  # TODO: Implement clipboard with Emscripten.
  raise newException(
    Exception,
    "setClipboardString is not supported on emscripten"
  )

proc getClipboardString*(): string =
  # TODO: Implement clipboard with Emscripten.
  raise newException(
    Exception,
    "getClipboardString is not supported on emscripten"
  )

proc closeIme*(window: Window) =
  if window.state.imeCompositionString.len > 0:
    window.state.imeCompositionString = ""
    window.state.imeCursorIndex = 0
    if window.onImeChange != nil:
      window.onImeChange()

proc imeCursorIndex*(window: Window): int =
  window.state.imeCursorIndex

proc imeCompositionString*(window: Window): string =
  window.state.imeCompositionString

# OpenGL extension loading
proc loadExtensions*() =
  # Extensions are loaded automatically in WebGL
  discard

# Convert JavaScript key codes to windy Button enum
proc keyCodeToButton(keyCode: culong): Button =
  case keyCode:
  of 27: KeyEscape
  of 32: KeySpace
  of 13: KeyEnter
  of 8: KeyBackspace
  of 9: KeyTab
  of 16: KeyLeftShift
  of 17: KeyLeftControl
  of 18: KeyLeftAlt
  of 20: KeyCapsLock
  of 33: KeyPageUp
  of 34: KeyPageDown
  of 35: KeyEnd
  of 36: KeyHome
  of 37: KeyLeft
  of 38: KeyUp
  of 39: KeyRight
  of 40: KeyDown
  of 46: KeyDelete
  of 65: KeyA
  of 66: KeyB
  of 67: KeyC
  of 68: KeyD
  of 69: KeyE
  of 70: KeyF
  of 71: KeyG
  of 72: KeyH
  of 73: KeyI
  of 74: KeyJ
  of 75: KeyK
  of 76: KeyL
  of 77: KeyM
  of 78: KeyN
  of 79: KeyO
  of 80: KeyP
  of 81: KeyQ
  of 82: KeyR
  of 83: KeyS
  of 84: KeyT
  of 85: KeyU
  of 86: KeyV
  of 87: KeyW
  of 88: KeyX
  of 89: KeyY
  of 90: KeyZ
  of 48: Key0
  of 49: Key1
  of 50: Key2
  of 51: Key3
  of 52: Key4
  of 53: Key5
  of 54: Key6
  of 55: Key7
  of 56: Key8
  of 57: Key9
  of 186: KeySemicolon
  of 187: KeyEqual
  of 188: KeyComma
  of 189: KeyMinus
  of 190: KeyPeriod
  of 191: KeySlash
  of 192: KeyBacktick
  of 219: KeyLeftBracket
  of 220: KeyBackslash
  of 221: KeyRightBracket
  of 222: KeyApostrophe
  else: ButtonUnknown

proc mouseButtonToButton(button: cushort): Button =
  case button:
  of 0: MouseLeft
  of 1: MouseMiddle
  of 2: MouseRight
  else: MouseButton4

# Event handlers
proc onMouseDown(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
  let window = cast[Window](userData)
  # Ensure canvas has focus when clicked
  make_canvas_focusable()
  let button = mouseButtonToButton(mouseEvent.button)
  window.handleButtonPress(button)
  return 1

proc onMouseUp(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
  let window = cast[Window](userData)
  let button = mouseButtonToButton(mouseEvent.button)
  window.handleButtonRelease(button)
  return 1

proc onMouseMove(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
  let window = cast[Window](userData)
  window.state.mousePrevPos = window.state.mousePos
  # Use clientX/clientY as they are more reliably populated
  window.state.mousePos = ivec2(mouseEvent.clientX.int32, mouseEvent.clientY.int32)
  window.state.perFrame.mouseDelta += window.state.mousePos - window.state.mousePrevPos
  if window.onMouseMove != nil:
    window.onMouseMove()
  return 1

proc onWheel(eventType: cint, wheelEvent: ptr EmscriptenWheelEvent, userData: pointer): EM_BOOL {.cdecl.} =
  let window = cast[Window](userData)
  # Normalize web wheel events to match other platforms.
  let normalizedDeltaX = wheelEvent.deltaX.float32
  let normalizedDeltaY = wheelEvent.deltaY.float32
  window.state.perFrame.scrollDelta += vec2(normalizedDeltaX, normalizedDeltaY)
  if window.onScroll != nil:
    window.onScroll()
  return 1

proc onKeyDown(eventType: cint, keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer): EM_BOOL {.cdecl.} =
  let window = cast[Window](userData)
  let button = keyCodeToButton(keyEvent.keyCode)
  window.handleButtonPress(button)
  return 1

proc onKeyUp(eventType: cint, keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer): EM_BOOL {.cdecl.} =
  let window = cast[Window](userData)
  let button = keyCodeToButton(keyEvent.keyCode)
  window.handleButtonRelease(button)
  return 1

proc onKeyPress(eventType: cint, keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer): EM_BOOL {.cdecl.} =
  let window = cast[Window](userData)
  if keyEvent.charCode > 0:
    window.handleRune(Rune(keyEvent.charCode))
  return 1

proc onFocus(eventType: cint, focusEvent: ptr EmscriptenFocusEvent, userData: pointer): EM_BOOL {.cdecl.} =
  let window = cast[Window](userData)
  if window.onFocusChange != nil:
    window.onFocusChange()
  return 1

proc onBlur(eventType: cint, focusEvent: ptr EmscriptenFocusEvent, userData: pointer): EM_BOOL {.cdecl.} =
  let window = cast[Window](userData)
  if window.onFocusChange != nil:
    window.onFocusChange()
  return 1

proc onResize(eventType: cint, uiEvent: ptr EmscriptenUiEvent, userData: pointer): EM_BOOL {.cdecl.} =
  let window = cast[Window](userData)
  window.updateCanvasSize()

  if window.onResize != nil:
    window.onResize()
  return 1

proc setupEventHandlers(window: Window) =
  # Mouse events
  discard emscripten_set_mousedown_callback_on_thread(window.canvas, cast[pointer](window), 1, onMouseDown, EM_CALLBACK_THREAD_CONTEXT)
  discard emscripten_set_mouseup_callback_on_thread(window.canvas, cast[pointer](window), 1, onMouseUp, EM_CALLBACK_THREAD_CONTEXT)
  discard emscripten_set_mousemove_callback_on_thread(window.canvas, cast[pointer](window), 1, onMouseMove, EM_CALLBACK_THREAD_CONTEXT)

  # Wheel event
  discard emscripten_set_wheel_callback_on_thread(window.canvas, cast[pointer](window), 1, onWheel, EM_CALLBACK_THREAD_CONTEXT)

  # Keyboard events (use canvas to avoid querySelector issues)
  discard emscripten_set_keydown_callback_on_thread(window.canvas, cast[pointer](window), 1, onKeyDown, EM_CALLBACK_THREAD_CONTEXT)
  discard emscripten_set_keyup_callback_on_thread(window.canvas, cast[pointer](window), 1, onKeyUp, EM_CALLBACK_THREAD_CONTEXT)
  discard emscripten_set_keypress_callback_on_thread(window.canvas, cast[pointer](window), 1, onKeyPress, EM_CALLBACK_THREAD_CONTEXT)

  # Focus events
  discard emscripten_set_focus_callback_on_thread(window.canvas, cast[pointer](window), 1, onFocus, EM_CALLBACK_THREAD_CONTEXT)
  discard emscripten_set_blur_callback_on_thread(window.canvas, cast[pointer](window), 1, onBlur, EM_CALLBACK_THREAD_CONTEXT)

  # Window resize handler
  discard emscripten_set_resize_callback_on_thread(EMSCRIPTEN_EVENT_TARGET_WINDOW, cast[pointer](window), 1, onResize, EM_CALLBACK_THREAD_CONTEXT)

proc handleButtonPress(window: Window, button: Button) =
  handleButtonPressTemplate()

proc handleButtonRelease(window: Window, button: Button) =
  handleButtonReleaseTemplate()

proc handleRune(window: Window, rune: Rune) =
  handleRuneTemplate()

proc getState(fetch: ptr emscripten_fetch_t): EmsHttpRequestState =
  cast[EmsHttpRequestState](fetch.userData)

proc onFetchSuccess(fetch: ptr emscripten_fetch_t) {.cdecl.} =
  let state = getState(fetch)
  if state == nil: return
  state.completed = true
  var response = HttpResponse()
  response.code = int(fetch.status)
  if fetch.numBytes > 0 and fetch.data != nil:
    let len = int(fetch.numBytes)
    response.body.setLen(len)
    copyMem(response.body[0].addr, fetch.data, len)
  # Headers: responseHeaders is a raw header block; keep as empty for now
  if state.onResponse != nil:
    state.onResponse(response)
  emscripten_fetch_close(fetch)

proc onFetchError(fetch: ptr emscripten_fetch_t) {.cdecl.} =
  let state = getState(fetch)
  if state == nil: return
  state.completed = true
  if state.onError != nil:
    var msg = $fetch.status & " "
    for c in fetch.statusText:
      if c == '\0': break
      msg &= $c
    state.onError(msg)
  emscripten_fetch_close(fetch)

proc onFetchProgress(fetch: ptr emscripten_fetch_t) {.cdecl.} =
  let state = getState(fetch)
  if state == nil: return
  if state.onDownloadProgress != nil:
    let completed = int(fetch.dataOffset + fetch.numBytes)
    let total = (if fetch.totalBytes == 0: -1 else: int(fetch.totalBytes))
    state.onDownloadProgress(completed, total)

proc startHttpRequest*(
  url: string,
  verb = "GET",
  headers = newSeq[HttpHeader](),
  body = "",
  deadline = defaultHttpDeadline
): HttpRequestHandle {.raises: [].} =
  ## Start an HTTP request.
  init()
  var headers = headers
  headers.addDefaultHeaders()

  # Create handle and state (reuse std/http pattern: random handle)
  var handle: HttpRequestHandle
  var state = EmsHttpRequestState()
  while true:
    handle = windyRand.next().HttpRequestHandle
    if handle notin httpRequests:
      httpRequests[handle] = state
      break

  state.url = url
  state.verb = verb
  state.headers = headers
  state.requestBody = body
  state.deadline = (if deadline >= 0: epochTime() + deadline.float64 else: -1.0)
  state.startTime = epochTime()

  # Setup fetch attrs
  var attr: emscripten_fetch_attr_t
  emscripten_fetch_attr_init(addr attr)
  # Copy HTTP method
  let httpMethod = verb.toUpperAscii()
  for i in 0 ..< min(httpMethod.len, attr.requestMethod.len):
    attr.requestMethod[i] = httpMethod[i]
  if httpMethod.len < attr.requestMethod.len:
    attr.requestMethod[httpMethod.len] = '\0'

  attr.userData = cast[pointer](state)
  attr.onsuccess = onFetchSuccess
  attr.onerror = onFetchError
  attr.onprogress = onFetchProgress
  attr.attributes = EMSCRIPTEN_FETCH_LOAD_TO_MEMORY

  if state.requestBody.len > 0:
    state.bodyKeepAlive = state.requestBody
    attr.requestData = cast[ptr char](state.bodyKeepAlive.cstring)
    attr.requestDataSize = csize_t(state.requestBody.len)

  # Headers array (optional): omit for now to avoid pointer array complexities
  attr.requestHeaders = nil

  discard emscripten_fetch(addr attr, url.cstring)
  result = handle

proc cancel*(handle: HttpRequestHandle) {.raises: [].} =
  ## Cancel an HTTP request.
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil: return
  state.canceled = true
  # There is no direct cancel from C API here; closing will abort if still active
  if state.fetch != nil:
    emscripten_fetch_close(state.fetch)

proc deadline*(handle: HttpRequestHandle): float64 =
  ## Get the deadline of an HTTP request.
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil: return
  state.deadline

proc `deadline=`*(handle: HttpRequestHandle, deadline: float64) =
  ## Set the deadline of an HTTP request.
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil: return
  state.deadline = deadline

proc `onError=`*(handle: HttpRequestHandle, callback: HttpErrorCallback) =
  ## Set the error callback of an HTTP request.
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil: return
  state.onError = callback

proc `onResponse=`*(handle: HttpRequestHandle, callback: HttpResponseCallback) =
  ## Set the response callback of an HTTP request.
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil: return
  state.onResponse = callback

proc `onUploadProgress=`*(handle: HttpRequestHandle, callback: HttpProgressCallback) =
  ## Set the upload progress callback of an HTTP request.
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil: return
  state.onUploadProgress = callback

proc `onDownloadProgress=`*(handle: HttpRequestHandle, callback: HttpProgressCallback) =
  ## Set the download progress callback of an HTTP request.
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil: return
  state.onDownloadProgress = callback

proc openTempTextFile*(title, text: string) =
  ## Open a new tab in the browser.
  open_temp_text_file(title.cstring, text.cstring)
