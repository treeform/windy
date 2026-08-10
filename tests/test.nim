import windy

proc checkVsyncApi(window: Window) {.used.} =
  window.vsync = false
  discard window.vsync
