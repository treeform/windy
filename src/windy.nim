import windy/common

export common

when defined(windows):
  import windy/platforms/win32/platform

type
  Window* = ref object
    platform: PlatformWindow

proc init*() {.raises: [WindyError]} =
  platformInit()

proc newWindow*(
  windowTitle: string, width, height: int
): Window {.raises: [WindyError]} =
  result = Window()
  result.platform = newPlatformWindow(windowTitle, width, height)

proc makeContextCurrent*(window: Window) {.raises: [WindyError]} =
  window.platform.makeContextCurrent()

proc swapBuffers*(window: Window) {.raises: [WindyError]} =
  window.platform.swapBuffers()

proc `visible`*(window: Window): bool =
  discard

proc `visible=`*(window: Window, visible: bool) =
  if visible:
    window.platform.show()
  else:
    window.platform.hide()
