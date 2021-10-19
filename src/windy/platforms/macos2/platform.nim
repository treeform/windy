{.
  passL: "-framework Cocoa",
  compile: "macos.m",
.}

import ../../common, vmath

type PlatformWindow* = ref object
  windowPtr: pointer

proc innerInit() {.importc.}

proc innerNewPlatformWindow(
  title: cstring,
  width: int32,
  height: int32,
  vsync: bool,
  openglMajorVersion: int32,
  openglMinorVersion: int32,
  msaa: int32,
  depthBits: int32,
  stencilBits: int32,
  windowRet: ptr pointer
) {.importc.}

proc innerMakeContextCurrent(windowPtr: pointer) {.importc.}

proc innerSwapBuffers(windowPtr: pointer) {.importc.}

proc innerPollEvents() {.importc.}

proc innerGetVisible(windowPtr: pointer): bool {.importc.}

proc innerSetVisible(windowPtr: pointer, visible: bool) {.importc.}

proc innerGetDecorated(windowPtr: pointer): bool {.importc.}

proc innerSetDecorated(windowPtr: pointer, decorated: bool) {.importc.}

proc innerGetResizable(windowPtr: pointer): bool {.importc.}

proc innerSetResizable(windowPtr: pointer, resizable: bool) {.importc.}

proc innerGetSize(windowPtr: pointer, width, height: ptr int32) {.importc.}

proc innerSetSize(windowPtr: pointer, width, height: int32) {.importc.}

proc innerGetPos(windowPtr: pointer, x, y: ptr int32) {.importc.}

proc innerSetPos(windowPtr: pointer, x, y: int32) {.importc.}

proc innerGetFramebufferSize(windowPtr: pointer, x, y: ptr int32) {.importc.}

proc platformInit*() =
  innerInit()

proc newPlatformWindow*(
  title: string,
  size: IVec2,
  vsync: bool,
  openglMajorVersion: int,
  openglMinorVersion: int,
  msaa: MSAA,
  depthBits: int,
  stencilBits: int
): PlatformWindow =
  result = PlatformWindow()
  innerNewPlatformWindow(
    title,
    size.x,
    size.y,
    vsync,
    openglMajorVersion.int32,
    openglMinorVersion.int32,
    msaa.int32,
    depthBits.int32,
    stencilBits.int32,
    result.windowPtr.addr
  )

proc makeContextCurrent*(window: PlatformWindow) =
  innerMakeContextCurrent(window.windowPtr)

proc swapBuffers*(window: PlatformWindow) =
  innerSwapBuffers(window.windowPtr)

proc platformPollEvents*() =
  innerPollEvents()

proc visible*(window: PlatformWindow): bool =
  innerGetVisible(window.windowPtr)

proc `visible=`*(window: PlatformWindow, visible: bool) =
  innerSetVisible(window.windowPtr, visible)

proc decorated*(window: PlatformWindow): bool =
  innerGetDecorated(window.windowPtr)

proc `decorated=`*(window: PlatformWindow, decorated: bool) =
  innerSetDecorated(window.windowPtr, decorated)

proc resizable*(window: PlatformWindow): bool =
  innerGetResizable(window.windowPtr)

proc `resizable=`*(window: PlatformWindow, resizable: bool) =
  innerSetResizable(window.windowPtr, resizable)

proc size*(window: PlatformWindow): IVec2 =
  var width, height: int32
  innerGetSize(window.windowPtr, width.addr, height.addr)
  ivec2(width, height)

proc `size=`*(window: PlatformWindow, size: IVec2) =
  innerSetSize(window.windowPtr, size.x, size.y)

proc pos*(window: PlatformWindow): IVec2 =
  var x, y: int32
  innerGetPos(window.windowPtr, x.addr, y.addr)
  ivec2(x, y)

proc `pos=`*(window: PlatformWindow, pos: IVec2) =
  innerSetPos(window.windowPtr, pos.x, pos.y)

proc framebufferSize*(window: PlatformWindow): IVec2 =
  var width, height: int32
  innerGetFramebufferSize(window.windowPtr, width.addr, height.addr)
  ivec2(width, height)
