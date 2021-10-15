import windy/common

export common

when defined(windows):
  import windy/platforms/win32/platform
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
  # resizable, fullscreen, transparent, decorated, floating
  result = Window()
  when defined(windows):
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
  elif defined(linux):
    result.platform = newPlatformWindow(
      title,
      w, h,
      vsync,
      true, # resizable
      false, # fullscreen
      false, # transparent
      true, # decorated
    )

proc makeContextCurrent*(window: Window) {.raises: [WindyError]} =
  window.platform.makeContextCurrent()

proc swapBuffers*(window: Window) {.raises: [WindyError]} =
  window.platform.swapBuffers()

proc pollEvents*() =
  platformPollEvents()

proc `visible`*(window: Window): bool =
  discard

proc `visible=`*(window: Window, visible: bool) =
  if visible:
    window.platform.show()
  else:
    window.platform.hide()
