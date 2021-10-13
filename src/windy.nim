import windy/common

export common

when defined(windows):
  import windy/platforms/win32/platform
elif defined(linux):
  import windy/platforms/x11/platform

type
  App* = ref object
    platform: PlatformApp

  Window* = ref object
    platform: PlatformWindow

let app = App()

proc getApp*(): App =
  app

proc init*(app: App) {.raises: [WindyError]} =
  if app.platform != nil:
    raise newException(WindyError, "Windy is already initialized")
  app.platform = newPlatformApp()

proc newWindow*(
  app: App, windowTitle: string, width, height: int
): Window {.raises: [WindyError]} =
  result = Window()
  result.platform = app.platform.newWindow(windowTitle, width, height)

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
