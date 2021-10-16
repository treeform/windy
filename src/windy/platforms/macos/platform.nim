{.
  passL: "-framework Cocoa -framework OpenGL -framework Metal -framework QuartzCore",
  compile: "macos.m",
.}

import ../../common

type
  PlatformWindow* = ref object
    windowPtr: pointer
    viewPtr: pointer

proc innerInit() {.importc.}
proc innerNewPlatformWindow(
  titie: cstring,
  w:cint,
  h:cint,
  windowPtr: ptr[pointer],
  viewPtr: ptr[pointer]
) {.importc.}
proc innerPollEvents() {.importc.}
proc innerMakeContextCurrent(viewPtr: pointer) {.importc.}
proc innerSwapBuffers(viewPtr: pointer) {.importc.}

proc platformInit*() =
  innerInit()

proc newPlatformWindow*(
  title: string,
  w: int,
  h: int,
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
    w.cint,
    h.cint,
    result.windowPtr.addr,
    result.viewPtr.addr
  )

proc makeContextCurrent*(window: PlatformWindow) =
  innerMakeContextCurrent(window.viewPtr)

proc swapBuffers*(window: PlatformWindow) =
  innerSwapBuffers(window.viewPtr)

proc platformPollEvents*() =
  innerPollEvents()
