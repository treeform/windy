import ../../common, ../../internal, times, unicode, utils, vmath

{.
  passL: "-framework Cocoa",
  compile: "macos.m",
.}

type
  Window* = ref object
    onCloseRequest*: Callback
    onMove*: Callback
    onResize*: Callback
    onFocusChange*: Callback
    onMouseMove*: Callback
    onScroll*: Callback
    onButtonPress*: ButtonCallback
    onButtonRelease*: ButtonCallback
    onRune*: RuneCallback
    onImeChange*: Callback

    state: State

    windowPtr: pointer

  InnerHandler = proc(windowPtr: pointer) {.cdecl.}
  InnerMouseHandler = proc(windowPtr: pointer, x, y: int32) {.cdecl.}
  InnerScrollHandler = proc(windowPtr: pointer, x, y: float32) {.cdecl.}
  InnerKeyHandler = proc(windowPtr: pointer, keyCode: int32) {.cdecl.}
  InnerRuneHandler = proc(windowPtr: pointer, rune: uint32) {.cdecl.}

var windows: seq[Window]

proc indexForPointer(windows: seq[Window], windowPtr: pointer): int =
  ## Returns the window for this pointer, else -1
  for i, window in windows:
    if window.windowPtr == windowPtr:
      return i
  -1

proc forPointer(windows: seq[Window], windowPtr: pointer): Window =
  ## Returns the window for this pointer, else nil
  let index = windows.indexForPointer(windowPtr)
  if index == -1:
    return nil
  windows[index]

proc innerGetDoubleClickInterval(): float64 {.importc.}

proc innerGetVisible(windowPtr: pointer): bool {.importc.}

proc innerGetDecorated(windowPtr: pointer): bool {.importc.}

proc innerGetResizable(windowPtr: pointer): bool {.importc.}

proc innerGetSize(windowPtr: pointer, width, height: ptr int32) {.importc.}

proc innerGetPos(windowPtr: pointer, x, y: ptr int32) {.importc.}

proc innerGetFramebufferSize(windowPtr: pointer, x, y: ptr int32) {.importc.}

proc innerGetContentScale(windowPtr: pointer, scale: ptr float32) {.importc.}

proc innerGetFocused(windowPtr: pointer): bool {.importc.}

proc innerGetMinimized(windowPtr: pointer): bool {.importc.}

proc innerGetMaximized(windowPtr: pointer): bool {.importc.}

proc innerSetTitle(windowPtr: pointer, title: cstring) {.importc.}

proc innerSetVisible(windowPtr: pointer, visible: bool) {.importc.}

proc innerSetDecorated(windowPtr: pointer, decorated: bool) {.importc.}

proc innerSetResizable(windowPtr: pointer, resizable: bool) {.importc.}

proc innerSetSize(windowPtr: pointer, width, height: int32) {.importc.}

proc innerSetPos(windowPtr: pointer, x, y: int32) {.importc.}

proc innerSetMinimized(windowPtr: pointer, minimized: bool) {.importc.}

proc innerSetMaximized(windowPtr: pointer, maximized: bool) {.importc.}

proc innerInit(
  handleMove, handleResize, handleCloseRequested, handleFocusChange: InnerHandler,
  handleMouseMove: InnerMouseHandler,
  handleScroll: InnerScrollHandler,
  handleKeyDown, handleKeyUp, handleFlagsChanged: InnerKeyHandler,
  handleRune: InnerRuneHandler
) {.importc.}

proc innerPollEvents() {.importc.}

proc innerMakeContextCurrent(windowPtr: pointer) {.importc.}

proc innerSwapBuffers(windowPtr: pointer) {.importc.}

proc innerNewWindow(
  title: cstring,
  width: int32,
  height: int32,
  vsync: bool,
  openglMajorVersion: int32,
  openglMinorVersion: int32,
  msaa: int32,
  depthBits: int32,
  stencilBits: int32
): pointer {.importc.}

proc innerGetClipboardString(): cstring {.importc.}

proc innerSetClipboardString(value: cstring) {.importc.}

proc visible*(window: Window): bool =
  innerGetVisible(window.windowPtr)

proc decorated*(window: Window): bool =
  innerGetDecorated(window.windowPtr)

proc resizable*(window: Window): bool =
  innerGetResizable(window.windowPtr)

proc fullscreen*(window: Window): bool =
  discard

proc size*(window: Window): IVec2 =
  innerGetSize(window.windowPtr, result.x.addr, result.y.addr)

proc pos*(window: Window): IVec2 =
  innerGetPos(window.windowPtr, result.x.addr, result.y.addr)

proc minimized*(window: Window): bool =
  innerGetMinimized(window.windowPtr)

proc maximized*(window: Window): bool =
  innerGetMaximized(window.windowPtr)

proc framebufferSize*(window: Window): IVec2 =
  innerGetFramebufferSize(window.windowPtr, result.x.addr, result.y.addr)

proc contentScale*(window: Window): float32 =
  innerGetContentScale(window.windowPtr, result.addr)

proc focused*(window: Window): bool =
  innerGetFocused(window.windowPtr)

proc `title=`*(window: Window, title: string) =
  innerSetTitle(window.windowPtr, title.cstring)

proc `visible=`*(window: Window, visible: bool) =
  innerSetVisible(window.windowPtr, visible)

proc `decorated=`*(window: Window, decorated: bool) =
  innerSetDecorated(window.windowPtr, decorated)

proc `resizable=`*(window: Window, resizable: bool) =
  innerSetResizable(window.windowPtr, resizable)

proc `fullscreen=`*(window: Window, fullscreen: bool) =
  discard

proc `size=`*(window: Window, size: IVec2) =
  innerSetSize(window.windowPtr, size.x, size.y)

proc `pos=`*(window: Window, pos: IVec2) =
  innerSetPos(window.windowPtr, pos.x, pos.y)

proc `minimized=`*(window: Window, minimized: bool) =
  innerSetMinimized(window.windowPtr, minimized);

proc `maximized=`*(window: Window, maximized: bool) =
  innerSetMaximized(window.windowPtr, maximized);

proc `closeRequested=`*(window: Window, closeRequested: bool) =
  window.state.closeRequested = closeRequested
  if closeRequested:
    if window.onCloseRequest != nil:
      window.onCloseRequest()

proc `runeInputEnabled=`*(window: Window, runeInputEnabled: bool) =
  window.state.runeInputEnabled = runeInputEnabled

proc handleButtonPress(window: Window, button: Button) =
  handleButtonPressTemplate()

proc handleButtonRelease(window: Window, button: Button) =
  handleButtonReleaseTemplate()

proc handleRune(window: Window, rune: Rune) =
  handleRuneTemplate()

proc handleMove(windowPtr: pointer) {.cdecl.} =
  let window = windows.forPointer(windowPtr)
  if window == nil:
    return

  if window.onMove != nil:
    window.onMove()

proc handleResize(windowPtr: pointer) {.cdecl.} =
  let window = windows.forPointer(windowPtr)
  if window == nil:
    return

  if window.onResize != nil:
    window.onResize()

proc handleCloseRequested(windowPtr: pointer) {.cdecl.} =
  let window = windows.forPointer(windowPtr)
  if window == nil:
    return

  window.closeRequested = true

proc handleFocusChange(windowPtr: pointer) {.cdecl.} =
  let window = windows.forPointer(windowPtr)
  if window == nil:
    return

  if window.onFocusChange != nil:
    window.onFocusChange()

proc handleMouseMove(windowPtr: pointer, x, y: int32) {.cdecl.} =
  let window = windows.forPointer(windowPtr)
  if window == nil:
    return

  window.state.perFrame.mousePrevPos = window.state.mousePos
  window.state.mousePos = ivec2(x, y)
  window.state.perFrame.mouseDelta =
    window.state.mousePos - window.state.perFrame.mousePrevPos

  if window.onMouseMove != nil:
    window.onMouseMove()

proc handleScroll(windowPtr: pointer, x, y: float32) {.cdecl.} =
  let window = windows.forPointer(windowPtr)
  if window == nil:
    return

  window.state.perFrame.scrollDelta = vec2(x, y)
  if window.onScroll != nil:
    window.onScroll()

proc handleKeyDown(windowPtr: pointer, keyCode: int32) {.cdecl.} =
  let window = windows.forPointer(windowPtr)
  if window == nil:
    return

  window.handleButtonPress(keyCodeToButton[keyCode])

proc handleKeyUp(windowPtr: pointer, keyCode: int32) {.cdecl.} =
  let window = windows.forPointer(windowPtr)
  if window == nil:
    return

  window.handleButtonRelease(keyCodeToButton[keyCode])

proc handleFlagsChanged(windowPtr: pointer, keyCode: int32) {.cdecl.} =
  let window = windows.forPointer(windowPtr)
  if window == nil:
    return

  let button = keyCodeToButton[keyCode]
  if button in window.state.buttonDown:
    window.handleButtonRelease(button)
  else:
    window.handleButtonPress(button)

proc handleRune(windowPtr: pointer, rune: uint32) {.cdecl.} =
  let window = windows.forPointer(windowPtr)
  if window == nil:
    return

  window.handleRune(Rune(rune))

proc init*() =
  if not initialized:
    innerInit(
      handleMove,
      handleResize,
      handleCloseRequested,
      handleFocusChange,
      handleMouseMove,
      handleScroll,
      handleKeyDown,
      handleKeyUp,
      handleFlagsChanged,
      handleRune
    )
    platformDoubleClickInterval = innerGetDoubleClickInterval()
    initialized = true

proc pollEvents*() =
  # Clear all per-frame data
  for window in windows:
    window.state.perFrame = PerFrame()

  innerPollEvents()

proc makeContextCurrent*(window: Window) =
  innerMakeContextCurrent(window.windowPtr)

proc swapBuffers*(window: Window) =
  innerSwapBuffers(window.windowPtr)

proc close*(window: Window) =
  discard

proc closeIme*(window: Window) =
  discard

proc newWindow*(
  title: string,
  size: IVec2,
  visible = true,
  vsync = true,
  openglMajorVersion = 4,
  openglMinorVersion = 1,
  msaa = msaaDisabled,
  depthBits = 24,
  stencilBits = 8
): Window =
  init()

  result = Window()
  result.title = title
  result.windowPtr = innerNewWindow(
    title.cstring,
    size.x,
    size.y,
    vsync,
    openglMajorVersion.int32,
    openglMinorVersion.int32,
    msaa.int32,
    depthBits.int32,
    stencilBits.int32
  )

  if result.windowPtr == nil:
    raise newException(WindyError, "Creating window failed")

  windows.add(result)

  result.visible = visible

proc title*(window: Window): string =
  window.state.title

proc mousePos*(window: Window): IVec2 =
  window.state.mousePos

proc mousePrevPos*(window: Window): IVec2 =
  window.state.perFrame.mousePrevPos

proc mouseDelta*(window: Window): IVec2 =
  window.state.perFrame.mouseDelta

proc scrollDelta*(window: Window): Vec2 =
  window.state.perFrame.scrollDelta

proc imeCursorIndex*(window: Window): int =
  window.state.imeCursorIndex

proc imeCompositionString*(window: Window): string =
  window.state.imeCompositionString

proc runeInputEnabled*(window: Window): bool =
  window.state.runeInputEnabled

proc closeRequested*(window: Window): bool =
  window.state.closeRequested

proc closed*(window: Window): bool =
  window.state.closed

proc buttonDown*(window: Window): ButtonView =
  window.state.buttonDown.ButtonView

proc buttonPressed*(window: Window): ButtonView =
  window.state.perFrame.buttonPressed.ButtonView

proc buttonReleased*(window: Window): ButtonView =
  window.state.perFrame.buttonReleased.ButtonView

proc buttonToggle*(window: Window): ButtonView =
  window.state.buttonToggle.ButtonView

proc getClipboardString*(): string =
  init()
  $innerGetClipboardString()

proc setClipboardString*(value: string) =
  init()
  innerSetClipboardString(value.cstring)
