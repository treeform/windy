import ../../common, vmath

{.
  passL: "-framework Cocoa",
  compile: "macos.m",
.}

type Window* = ref object
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

  closeRequested, closed: bool

  windowPtr: pointer

var
  initialized: bool

proc innerGetVisible(windowPtr: pointer): bool {.importc.}

proc innerGetDecorated(windowPtr: pointer): bool {.importc.}

proc innerGetResizable(windowPtr: pointer): bool {.importc.}

proc innerGetSize(windowPtr: pointer, width, height: ptr int32) {.importc.}

proc innerGetPos(windowPtr: pointer, x, y: ptr int32) {.importc.}

proc innerGetFramebufferSize(windowPtr: pointer, x, y: ptr int32) {.importc.}

proc innerSetVisible(windowPtr: pointer, visible: bool) {.importc.}

proc innerSetDecorated(windowPtr: pointer, decorated: bool) {.importc.}

proc innerSetResizable(windowPtr: pointer, resizable: bool) {.importc.}

proc innerSetSize(windowPtr: pointer, width, height: int32) {.importc.}

proc innerSetPos(windowPtr: pointer, x, y: int32) {.importc.}

proc innerInit() {.importc.}

proc innerPollEvents() {.importc.}

proc innerMakeContextCurrent(windowPtr: pointer) {.importc.}

proc innerSwapBuffers(windowPtr: pointer) {.importc.}

proc innerNewWindow(
  title: cstring,
  width: int32,
  height: int32,
  visible: bool,
  vsync: bool,
  openglMajorVersion: int32,
  openglMinorVersion: int32,
  msaa: int32,
  depthBits: int32,
  stencilBits: int32,
  windowRet: ptr pointer
) {.importc.}


proc title*(window: Window): string =
  discard

proc closed*(window: Window): bool =
  discard

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
  discard

proc maximized*(window: Window): bool =
  discard

proc framebufferSize*(window: Window): IVec2 =
  innerGetFramebufferSize(window.windowPtr, result.x.addr, result.y.addr)

proc contentScale*(window: Window): float32 =
  discard

proc focused*(window: Window): bool =
  discard

proc mousePos*(window: Window): IVec2 =
  discard

proc mousePrevPos*(window: Window): IVec2 =
  discard

proc mouseDelta*(window: Window): IVec2 =
  discard

proc scrollDelta*(window: Window): Vec2 =
  discard

proc closeRequested*(window: Window): bool =
  window.closeRequested

proc imeCursorIndex*(window: Window): int =
  discard

proc imeCompositionString*(window: Window): string =
  discard

proc runeInputEnabled*(window: Window): bool =
  discard

proc `title=`*(window: Window, title: string) =
  discard

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
  discard

proc `maximized=`*(window: Window, maximized: bool) =
  discard

proc `closeRequested=`*(window: Window, closeRequested: bool) =
  discard

proc `runeInputEnabled=`*(window: Window, runeInputEnabled: bool) =
  discard

proc init*() =
  if not initialized:
    innerInit()
    initialized = true

proc pollEvents*() =
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
  innerNewWindow(
    title,
    size.x,
    size.y,
    visible,
    vsync,
    openglMajorVersion.int32,
    openglMinorVersion.int32,
    msaa.int32,
    depthBits.int32,
    stencilBits.int32,
    result.windowPtr.addr
  )

proc buttonDown*(window: Window): ButtonView =
  discard

proc buttonPressed*(window: Window): ButtonView =
  discard

proc buttonReleased*(window: Window): ButtonView =
  discard

proc buttonToggle*(window: Window): ButtonView =
  discard

proc getClipboardString*(): string =
  init()

proc setClipboardString*(value: string) =
  init()
