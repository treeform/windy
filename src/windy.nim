import unicode, vmath, windy/common

when defined(emscripten):
  import windy/platforms/emscripten/platform
elif defined(windows):
  import windy/platforms/win32/platform
elif defined(macosx):
  import windy/platforms/macos/platform
elif defined(linux):
  import windy/platforms/linux/platform

export common, platform, unicode, vmath

when not defined(emscripten):
  proc run*(window: Window, mainLoop: proc(), onExit: proc() = empty) =
    while not window.closeRequested:
      mainLoop()
    onExit()