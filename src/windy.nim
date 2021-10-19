import vmath, windy/common

export common, vmath

when defined(windows):
  import windy/platforms/win32/platform
elif defined(macosx):
  import windy/platforms/macos/platform
elif defined(linux):
  import windy/platforms/linux/platform

type
  Window* = ref object
    platform: PlatformWindow

proc init*() {.raises: [WindyError]} =
  platformInit()

proc newWindow*(
  title: string,
  size: IVec2,
  vsync = true,
  openglMajorVersion = 4,
  openglMinorVersion = 1,
  msaa = msaaDisabled,
  depthBits = 24,
  stencilBits = 8
): Window {.raises: [WindyError]} =
  result = Window()
  try:
    result.platform = newPlatformWindow(
      title,
      size,
      vsync,
      openglMajorVersion,
      openglMinorVersion,
      msaa,
      depthBits,
      stencilBits
    )
  except:
    raise newException(
      WindyError,
      "Creating native window failed",
      getCurrentException()
    )

proc makeContextCurrent*(window: Window) =
  window.platform.makeContextCurrent()

proc swapBuffers*(window: Window) =
  window.platform.swapBuffers()

proc pollEvents*() =
  platformPollEvents()

proc visible*(window: Window): bool =
  window.platform.visible

proc `visible=`*(window: Window, visible: bool) =
  window.platform.visible = visible

proc decorated*(window: Window): bool =
  window.platform.decorated

proc `decorated=`*(window: Window, decorated: bool) =
  window.platform.decorated = decorated

proc resizable*(window: Window): bool =
  window.platform.resizable

proc `resizable=`*(window: Window, resizable: bool) =
  window.platform.resizable = resizable

proc size*(window: Window): IVec2 =
  window.platform.size

proc `size=`*(window: Window, size: IVec2) =
  window.platform.size = size

proc pos*(window: Window): IVec2 =
  window.platform.pos

proc `pos=`*(window: Window, pos: IVec2) =
  window.platform.pos = pos

proc framebufferSize*(window: Window): IVec2 =
  window.platform.framebufferSize
