import ../../common, ../../internal, vmath, pixie, unicode, times
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

    size: IVec2
    title: string
    isCloseRequested: bool
    canvas: cstring

    state: WindowState

var
  quitRequested*: bool
  onQuitRequest*: Callback
  multiClickInterval*: Duration = initDuration(milliseconds = 200)
  multiClickRadius*: float = 4

  initialized: bool
  windows: seq[Window]
  currentContext: EMSCRIPTEN_WEBGL_CONTEXT_HANDLE
  mainWindow: Window  # Track the main window for events

proc handleButtonPress(window: Window, button: Button)
proc handleButtonRelease(window: Window, button: Button)
proc handleRune(window: Window, rune: Rune)
proc setupEventHandlers(window: Window)  # Forward declaration

proc init =
  if initialized:
    return
  initialized = true

proc newWindow*(
  title = "",
  size = ivec2(1280, 720),
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
  result.title = title
  result.size = size
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

    # Set canvas size
  set_canvas_size(size.x.cint, size.y.cint)

  # Make canvas focusable for keyboard input
  make_canvas_focusable()

  windows.add(result)
  mainWindow = result

  # Initialize event state
  result.state.perFrame = PerFrame()

  # Setup event handlers
  setupEventHandlers(result)

proc makeContextCurrent*(window: Window) =
  if currentContext != 0:
    discard emscripten_webgl_make_context_current(currentContext)

proc swapBuffers*(window: Window) =
  # In Emscripten/WebGL, swapping is automatic
  discard

proc close*(window: Window) =
  window.isCloseRequested = true
  let idx = windows.find(window)
  if idx != -1:
    windows.del(idx)

proc closeRequested*(window: Window): bool =
  window.isCloseRequested

proc pollEvents*() =
  # Emscripten doesn't need to poll events, only callbacks.
  discard

proc size*(window: Window): IVec2 =
  # Get the size of the canvas.
  window.size.x = canvas_get_width().int32
  window.size.y = canvas_get_height().int32
  window.size

proc `size=`*(window: Window, size: IVec2) =
  window.size = size
  set_canvas_size(size.x.cint, size.y.cint)

proc title*(window: Window): string =
  window.title

proc `title=`*(window: Window, title: string) =
  window.title = title
  # In browser context, we could set document.title here

proc visible*(window: Window): bool =
  true

proc `visible=`*(window: Window, visible: bool) =
  # Canvas is always visible in browser
  discard

proc runeInputEnabled*(window: Window): bool =
  window.state.runeInputEnabled

proc `runeInputEnabled=`*(window: Window, enabled: bool) =
  window.state.runeInputEnabled = enabled

proc pos*(window: Window): IVec2 =
  ivec2(0, 0)  # Canvas position is controlled by HTML/CSS

proc `pos=`*(window: Window, pos: IVec2) =
  # Canvas position is controlled by HTML/CSS
  discard

proc framebufferSize*(window: Window): IVec2 =
  result.x = canvas_get_width().int32
  result.y = canvas_get_height().int32

proc contentScale*(window: Window): float32 =
  1.0  # Fixed at 1.0 for Emscripten, could query device pixel ratio in future

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

proc mousePos*(window: Window): IVec2 =
  window.state.mousePos

proc mousePrevPos*(window: Window): IVec2 =
  window.state.mousePrevPos

proc mouseDelta*(window: Window): IVec2 =
  window.state.perFrame.mouseDelta

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
  discard

proc getClipboardString*(): string =
  # TODO: Implement clipboard with Emscripten.
  ""

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

# HTTP functions (if needed)
when defined(windyUseStdHttp):
  import ../../http
  export http

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
  let normalizedDeltaX = wheelEvent.deltaX.float32 * 0.01
  let normalizedDeltaY = wheelEvent.deltaY.float32 * 0.01
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
  set_canvas_size(uiEvent.windowInnerWidth, uiEvent.windowInnerHeight)
  window.size = ivec2(canvas_get_width().int32, canvas_get_height().int32)
  if window.onResize != nil:
    window.onResize()
  return 1

# Callback for JavaScript resize events
proc onCanvasResize(userData: pointer) {.cdecl, exportc.} =
  let window = cast[Window](userData)
  # Update the window size based on current canvas size
  let newWidth = canvas_get_width()
  let newHeight = canvas_get_height()
  if newWidth != window.size.x or newHeight != window.size.y:
    window.size = ivec2(newWidth, newHeight)
    if window.onResize != nil:
      window.onResize()

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

  # Set up resize observer using JavaScript
  setup_resize_observer(cast[pointer](window))

proc handleButtonPress(window: Window, button: Button) =
  handleButtonPressTemplate()

proc handleButtonRelease(window: Window, button: Button) =
  handleButtonReleaseTemplate()

proc handleRune(window: Window, rune: Rune) =
  handleRuneTemplate()

var mainLoopProc: proc() {.cdecl.}

proc frameWrapper() {.cdecl.} =
  # Run frame logic for main window
  if mainWindow != nil:
    if mainWindow.onFrame != nil:
      mainWindow.onFrame()
  if mainLoopProc != nil:
    mainLoopProc()
  # Clear per-frame data
  if mainWindow != nil:
    mainWindow.state.perFrame = PerFrame()

proc run*(window: Window, mainLoop: proc() {.cdecl.}) =
  ## This is the only way to run a loop in emscripten.
  mainLoopProc = mainLoop
  emscripten_set_main_loop(frameWrapper, 0, true)
