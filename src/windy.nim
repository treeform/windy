import unicode, vmath, windy/common

when defined(ios):
  import windy/platforms/ios/platform
elif defined(emscripten):
  import windy/platforms/emscripten/platform
elif defined(windows):
  import windy/platforms/win32/platform
elif defined(macosx):
  import windy/platforms/macos/platform
elif defined(linux):
  import windy/platforms/linux/platform

export common, platform, unicode, vmath

when not defined(ios):
  proc pointerSource*(window: Window): PointerSource =
    ## Returns the mouse source used by desktop and browser pointer events.
    MousePointer

  proc pointerVelocity*(window: Window): Vec2 =
    ## Returns zero where native touch velocity sampling is unavailable.
    vec2(0)

when not defined(ios) and
  (defined(emscripten) or not (defined(macosx) or defined(windows))):
  proc setTextInputState*(window: Window, state: TextInputState) =
    ## Publishes focused editor state for native text services where supported.
    ## This is a no-op on platforms without native editor-state integration.
    discard
