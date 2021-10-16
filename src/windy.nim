import windy/common

export common

when defined(windows):
  import windy/platforms/win32/platform
elif defined(macosx):
  import windy/platforms/macos/platform
elif defined(linux):
  import windy/platforms/x11/platform

type
  Window* = ref object
    platform: PlatformWindow

proc init*() {.raises: [WindyError]} =
  platformInit()

proc newWindow*(
  title: string,
  w: int,
  h: int,
  vsync = true,
  openglMajorVersion = 4,
  openglMinorVersion = 1,
  msaa = msaaDisabled,
  depthBits = 24,
  stencilBits = 8
): Window {.raises: [WindyError]} =
  # resizeable, fullscreen, transparent, decorated, floating
  result = Window()
  try:
    result.platform = newPlatformWindow(
      title,
      w,
      h,
      vsync,
      openglMajorVersion,
      openglMinorVersion,
      msaa,
      depthBits,
      stencilBits
    )
  except:
    raise newException(WindyError, "Creating native window failed: " & getCurrentExceptionMsg())

proc makeContextCurrent*(window: Window) {.raises: [WindyError]} =
  window.platform.makeContextCurrent()

proc swapBuffers*(window: Window) {.raises: [WindyError]} =
  window.platform.swapBuffers()

proc show*(window: PlatformWindow) =
  discard

proc hide*(window: PlatformWindow) =
  discard

proc pollEvents*() =
  platformPollEvents()

proc `visible`*(window: Window): bool =
  discard

proc `visible=`*(window: Window, visible: bool) =
  if visible:
    window.platform.show()
  else:
    window.platform.hide()
