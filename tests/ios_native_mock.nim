import ../src/windy/platforms/ios/events
export events

var
  callbacks*: NativeCallbacks
  nativeReady*: bool
  keyboardVisible*: bool
  renderingStopped*: bool
  clipboard: string

proc runNativeApplication*(
  argc: cint, argv: ptr cstring, handlers: NativeCallbacks
): cint =
  ## Initializes a deterministic host without loading UIKit on the Mac.
  callbacks = handlers
  nativeReady = true
  callbacks.onInitialize()
  callbacks.onResize(640, 480, 2)
  callbacks.onFocus(true)

proc nativeMetalView*(): pointer =
  ## Returns a sentinel handle once the host creates its view.
  if nativeReady:
    cast[pointer](1)
  else:
    nil

proc nativeViewController*(): pointer =
  ## Returns a sentinel controller handle.
  cast[pointer](2)

proc nativeSize*(): tuple[width, height: int32] =
  ## Returns the initial mock drawable size.
  (640'i32, 480'i32)

proc nativeScale*(): float32 =
  ## Returns a Retina display scale for unit tests.
  2

proc nativeSafeAreaInsets*(): tuple[top, right, bottom, left: float32] =
  ## Returns distinct pixel insets so field ordering can be checked.
  (10'f, 20'f, 30'f, 40'f)

proc setNativeKeyboardVisible*(visible: bool) =
  ## Records software keyboard visibility requests.
  keyboardVisible = visible

proc stopNativeRendering*() =
  ## Records that drawing has been stopped after close or an error.
  renderingStopped = true

proc nativeClipboardText*(): string =
  ## Returns the mock clipboard contents.
  clipboard

proc setNativeClipboardText*(text: string) =
  ## Stores clipboard text without touching the user's pasteboard.
  clipboard = text

proc nativeHasClipboardText*(): bool =
  ## Reports whether the mock clipboard contains text.
  clipboard.len > 0
