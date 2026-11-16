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

when defined(emscripten) or not (defined(macosx) or defined(windows)):
  proc setTextInputState*(window: Window, state: TextInputState) =
    ## Publishes focused editor state for native text services where supported.
    ## This is a no-op on platforms without native editor-state integration.
    discard

when defined(emscripten) or not defined(macosx):
  from pixie import Rect

  proc mouseConfinementSupported*(window: Window): bool {.raises: [].} =
    ## Returns false where native visible cursor confinement is unsupported.
    false

  proc mouseConfined*(window: Window): bool {.raises: [].} =
    ## Returns false where native visible cursor confinement is unsupported.
    false

  proc releaseMouseConfinement*(window: Window) {.raises: [].} =
    ## Does nothing where native visible cursor confinement is unsupported.
    discard

  proc confineMouse*(window: Window) {.raises: [WindyError].} =
    ## Raises when native visible cursor confinement is unsupported.
    raise newException(WindyError,
      "Native mouse confinement is unsupported on this platform")

  proc confineMouse*(window: Window, region: Rect) {.raises: [WindyError].} =
    ## Raises when native visible cursor confinement is unsupported.
    raise newException(WindyError,
      "Native mouse confinement is unsupported on this platform")
