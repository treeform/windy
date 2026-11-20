import
  std/[times, unicode],
  pixie, vmath,
  ../../common, ../../internal, motions

when defined(windyIosTesting):
  import ios_native_mock as native
else:
  import uikit as native

when defined(ios) and not defined(windyIosTesting):
  {.compile: "entry.c".}

const MaxTouchSpeed = 12000.0'f

type
  Window* = ref object
    onCloseRequest*, onFrame*, onMove*, onResize*: Callback
    onFocusChange*, onMouseMove*, onScroll*: Callback
    onButtonPress*, onButtonRelease*: ButtonCallback
    onRune*: RuneCallback
    onTextInput*: TextInputCallback
    onTextEdit*: TextInputEditCallback
    onImeChange*: Callback
    onFileDrop*: FileDropCallback
    onFileDropPaths*: FileDropPathsCallback
    imePos*: IVec2
    state: WindowState
    drawableSize: IVec2
    hasFocus: bool
    ready: bool
    primaryTouch: int
    pointerKind: PointerSource
    pointerMotion: PointerMotion
    textInput: TextInputState
    textMenuGeneration: uint64

var
  applicationInit: Callback
  applicationStarted: bool
  applicationWindow: Window

proc contentScale*(window: Window): float32 =
  ## Returns framebuffer pixels per UIKit point.
  window.state.contentScale

proc size*(window: Window): IVec2 =
  ## Returns the drawable dimensions in framebuffer pixels.
  window.drawableSize

proc safeAreaInsets*(
  window: Window
): tuple[top, right, bottom, left: float32] =
  ## Returns UIKit safe area insets in framebuffer pixels for this frame.
  if applicationStarted and not window.state.closed:
    result = native.nativeSafeAreaInsets()

proc keyboardOcclusionHeight*(window: Window): float32 =
  ## Returns the keyboard's overlap at the drawable's bottom in pixels.
  if applicationStarted and not window.state.closed:
    result = native.nativeKeyboardOcclusionHeight()

proc focused*(window: Window): bool =
  ## Returns whether the application is active.
  window.hasFocus

proc continuousRendering*(window: Window): bool =
  ## Reports whether UIKit produces frames at the display refresh cadence.
  native.nativeContinuousRendering()

proc `continuousRendering=`*(window: Window, enabled: bool) =
  ## Selects display-driven games or explicitly scheduled application frames.
  if not window.state.closed:
    native.setNativeContinuousRendering(enabled)

proc requestFrame*(window: Window, delayMs = 0) =
  ## Schedules an on-demand callback; input and wakeEvents also request one.
  if not window.state.closed:
    native.requestNativeFrame(delayMs)

proc dismissTextEditMenu*(window: Window) =
  ## Invalidates actions from the window's current native editing menu.
  inc window.textMenuGeneration
  native.dismissNativeTextEditMenu()

proc showTextEditMenu*(
  window: Window, bounds: Rect, actions: set[TextEditAction],
  callback: TextEditActionCallback
): bool {.discardable.} =
  ## Presents editing actions around framebuffer bounds without focus changes.
  ## Returns false if the window cannot present menus or iOS is older than 16.
  window.dismissTextEditMenu()
  if window.state.closed or not window.hasFocus or callback == nil or
    actions == {}:
      return false
  let generation = window.textMenuGeneration
  native.showNativeTextEditMenu(bounds, actions, proc(action: TextEditAction) =
    ## Discards delayed selections after dismissal, focus loss, or replacement.
    if window.state.closed or not window.hasFocus or
      window.textMenuGeneration != generation or action notin actions:
        return
    inc window.textMenuGeneration
    native.requestNativeFrame()
    callback(action)
  )

proc visible*(window: Window): bool =
  ## Reports whether UIKit can present the application window.
  not window.state.closed and window.hasFocus

proc minimized*(window: Window): bool =
  ## Treats application suspension as unavailable for presentation.
  not window.hasFocus

proc surfaceReady*(window: Window): bool =
  ## Returns whether the Metal view has a drawable surface.
  window.ready and not window.state.closed

proc metalView*(window: Window): pointer =
  ## Borrows Windy's MTKView while the window's surface is available.
  if window.surfaceReady:
    result = native.nativeMetalView()

proc nativeView*(window: Window): pointer =
  ## Borrows the same MTKView exposed by metalView.
  window.metalView

proc nativeViewController*(window: Window): pointer =
  ## Borrows the UIKit view controller owned by Windy.
  if applicationStarted and not window.state.closed:
    result = native.nativeViewController()

proc handleButtonPress(window: Window, button: Button) =
  ## Updates input state before invoking a press callback.
  handleButtonPressTemplate()

proc handleButtonRelease(window: Window, button: Button) =
  ## Releases a held button once, including synthetic multiple clicks.
  if button in window.state.buttonDown:
    handleButtonReleaseTemplate()

proc clearButtons(window: Window) =
  ## Releases held input when the native application deactivates.
  window.primaryTouch = -1
  window.pointerMotion.clear()
  clearButtonsTemplate()

proc cancelPointer(window: Window) =
  ## Releases cancelled input outside the content so it cannot activate UI.
  window.primaryTouch = -1
  window.pointerMotion.clear()
  window.state.mouseInside = false
  window.state.hasPrevMouse = false
  window.state.mousePos = ivec2(-1, -1)
  window.state.mousePrevPos = window.state.mousePos
  window.state.perFrame.mouseDelta = ivec2(0, 0)
  for button in [MouseLeft, DoubleClick, TripleClick, QuadrupleClick]:
    window.state.perFrame.buttonPressed.excl button
  window.state.doubleClickTime = 0
  window.state.tripleClickTimes = [0.0, 0.0]
  window.state.quadrupleClickTimes = [0.0, 0.0, 0.0]
  window.handleButtonRelease(MouseLeft)

proc handleRune(window: Window, rune: Rune) =
  ## Delivers printable committed characters when text input is enabled.
  handleRuneTemplate()

proc handleMouseMove(window: Window, x, y: float64) =
  ## Accumulates pointer movement in framebuffer pixels for this frame.
  let position = ivec2(x.int32, y.int32)
  window.state.mousePrevPos = window.state.mousePos
  if window.state.hasPrevMouse:
    window.state.perFrame.mouseDelta += position - window.state.mousePos
  else:
    window.state.mousePrevPos = position
    window.state.hasPrevMouse = true
  window.state.mousePos = position
  window.state.mouseInside = true
  if window.onMouseMove != nil:
    window.onMouseMove()

proc failCallback(message: string) =
  ## Stops rendering and reports failures without unwinding through UIKit.
  stderr.writeLine("Windy iOS: " & message)
  native.stopNativeRendering()
  if applicationWindow != nil:
    applicationWindow.state.closeRequested = true
    applicationWindow.state.closed = true
    applicationWindow.primaryTouch = -1
    applicationWindow.pointerMotion.clear()
    applicationWindow.state.buttonDown = {}

proc close*(window: Window)

proc renderCallback() =
  ## Lets UIKit drive one application frame and then resets transient input.
  let window = applicationWindow
  if window == nil or window.state.closed or not window.ready or
    not window.hasFocus:
      return
  try:
    if window.onFrame != nil:
      window.onFrame()
    if not window.state.closed and window.state.closeRequested:
      if window.onCloseRequest != nil:
        window.onCloseRequest()
      if not window.state.closed and window.state.closeRequested:
        window.close()
  except Exception as error:
    failCallback(error.msg)
  finally:
    window.state.perFrame = PerFrame()

proc updateSurface(width, height: int32, scale: float32) =
  ## Updates drawable dimensions and scale before notifying the application.
  let window = applicationWindow
  if window == nil or window.state.closed:
    return
  if scale <= 0:
    raise newException(WindyError, "UIKit reported an invalid display scale.")
  window.drawableSize = ivec2(width, height)
  window.state.contentScale = scale
  window.ready = width > 0 and height > 0
  native.requestNativeFrame()
  if window.onResize != nil:
    window.onResize()

proc surfaceCallback(width, height: int32, scale: float32) =
  ## Handles initial drawable creation and later size or scale changes.
  try:
    updateSurface(width, height, scale)
  except Exception as error:
    failCallback(error.msg)

proc focusCallback(focused: bool) =
  ## Releases held buttons on suspension and reports activation changes.
  let window = applicationWindow
  if window == nil or window.state.closed:
    return
  try:
    window.hasFocus = focused
    native.requestNativeFrame()
    if not focused:
      window.dismissTextEditMenu()
      window.cancelPointer()
      window.clearButtons()
      window.state.perFrame.buttonPressed = {}
    if window.onFocusChange != nil:
      window.onFocusChange()
  except Exception as error:
    failCallback(error.msg)

proc touchCallback(
  touch: int, phase: NativeTouchPhase, x, y: float64, source: PointerSource,
  timestamp: float64 = 0
) =
  ## Maps a stable primary touch to the pointer and left mouse button.
  let window = applicationWindow
  if window == nil or window.state.closed or not window.hasFocus:
    return
  native.requestNativeFrame()
  try:
    case phase
    of NativeTouchHover:
      # Preserve the stroke endpoint until the application consumes its frame.
      let pendingPen = window.pointerKind == PenPointer and
        (MouseLeft in window.state.perFrame.buttonPressed or
          MouseLeft in window.state.perFrame.buttonReleased)
      if window.primaryTouch == -1 and not pendingPen:
        window.pointerKind = source
        window.pointerMotion.clear()
        window.handleMouseMove(x, y)
    of NativeTouchBegan:
      if source == PenPointer and window.pointerKind == TouchPointer and
        window.primaryTouch != -1:
          # Let the Pencil replace a resting palm without activating its target.
          window.cancelPointer()
          for button in [MouseLeft, DoubleClick, TripleClick, QuadrupleClick]:
            window.state.perFrame.buttonReleased.excl button
      if window.primaryTouch == -1:
        window.primaryTouch = touch
        window.pointerKind = source
        window.pointerMotion.clear()
        if source == TouchPointer:
          window.pointerMotion.sample(
            vec2(x.float32, y.float32), timestamp,
            MaxTouchSpeed * window.contentScale
          )
        window.state.hasPrevMouse = false
        # Preserve the press origin when an entire gesture arrives in one frame.
        window.state.perFrame.mouseDelta = ivec2(0, 0)
        window.handleMouseMove(x, y)
        window.handleButtonPress(MouseLeft)
    of NativeTouchMoved:
      if window.primaryTouch == touch:
        window.pointerKind = source
        if source == TouchPointer:
          window.pointerMotion.sample(
            vec2(x.float32, y.float32), timestamp,
            MaxTouchSpeed * window.contentScale
          )
        else:
          window.pointerMotion.clear()
        window.handleMouseMove(x, y)
    of NativeTouchEnded:
      if window.primaryTouch == touch:
        window.pointerKind = source
        if source == TouchPointer:
          window.pointerMotion.sample(
            vec2(x.float32, y.float32), timestamp,
            MaxTouchSpeed * window.contentScale
          )
        else:
          window.pointerMotion.clear()
        window.handleMouseMove(x, y)
        window.primaryTouch = -1
        window.handleButtonRelease(MouseLeft)
    of NativeTouchCancelled:
      if window.primaryTouch == touch:
        window.pointerKind = source
        window.cancelPointer()
  except Exception as error:
    failCallback(error.msg)

proc keyButton(usage: int): Button =
  ## Maps UIKit's USB HID keyboard usages to Windy's button enum.
  case usage
  of 0x04 .. 0x1d:
    Button(KeyA.ord + usage - 0x04)
  of 0x1e .. 0x26:
    Button(Key1.ord + usage - 0x1e)
  of 0x3a .. 0x45:
    Button(KeyF1.ord + usage - 0x3a)
  of 0x59 .. 0x61:
    Button(Numpad1.ord + usage - 0x59)
  of 0x27: Key0
  of 0x28: KeyEnter
  of 0x29: KeyEscape
  of 0x2a: KeyBackspace
  of 0x2b: KeyTab
  of 0x2c: KeySpace
  of 0x2d: KeyMinus
  of 0x2e: KeyEqual
  of 0x2f: KeyLeftBracket
  of 0x30: KeyRightBracket
  of 0x31, 0x64: KeyBackslash
  of 0x33: KeySemicolon
  of 0x34: KeyApostrophe
  of 0x35: KeyBacktick
  of 0x36: KeyComma
  of 0x37: KeyPeriod
  of 0x38: KeySlash
  of 0x39: KeyCapsLock
  of 0x46: KeyPrintScreen
  of 0x47: KeyScrollLock
  of 0x48: KeyPause
  of 0x49: KeyInsert
  of 0x4a: KeyHome
  of 0x4b: KeyPageUp
  of 0x4c: KeyDelete
  of 0x4d: KeyEnd
  of 0x4e: KeyPageDown
  of 0x4f: KeyRight
  of 0x50: KeyLeft
  of 0x51: KeyDown
  of 0x52: KeyUp
  of 0x53: KeyNumLock
  of 0x54: NumpadDivide
  of 0x55: NumpadMultiply
  of 0x56: NumpadSubtract
  of 0x57: NumpadAdd
  of 0x58: NumpadEnter
  of 0x62: Numpad0
  of 0x63: NumpadDecimal
  of 0x65: KeyMenu
  of 0x67: NumpadEqual
  of 0xe0: KeyLeftControl
  of 0xe1: KeyLeftShift
  of 0xe2: KeyLeftAlt
  of 0xe3: KeyLeftSuper
  of 0xe4: KeyRightControl
  of 0xe5: KeyRightShift
  of 0xe6: KeyRightAlt
  of 0xe7: KeyRightSuper
  else: ButtonUnknown

proc syncModifier(
  window: Window, active: bool, left, right, eventButton: Button
) =
  ## Makes modifier state visible before the associated key callback.
  if active:
    if left notin window.state.buttonDown and
      right notin window.state.buttonDown:
        let button = if eventButton == right: right else: left
        window.handleButtonPress(button)
  else:
    window.handleButtonRelease(left)
    window.handleButtonRelease(right)

proc keyCallback(usage: int, action: NativeKeyAction, modifiers: uint) =
  ## Delivers hardware or software keys with modifiers synchronized first.
  let window = applicationWindow
  if window == nil or window.state.closed or not window.hasFocus:
    return
  native.requestNativeFrame()
  let button = keyButton(usage)
  try:
    if modifiers != uint.high:
      for pair in [
        (1'u shl 17, KeyLeftShift, KeyRightShift),
        (1'u shl 18, KeyLeftControl, KeyRightControl),
        (1'u shl 19, KeyLeftAlt, KeyRightAlt),
        (1'u shl 20, KeyLeftSuper, KeyRightSuper)
      ]:
        # UIKit flags describe modifiers held in addition to this key.
        # Its own side's press or release is the authoritative event.
        if button notin {pair[1], pair[2]}:
          window.syncModifier(
            (modifiers and pair[0]) != 0, pair[1], pair[2], button
          )
    if button == ButtonUnknown:
      return
    case action
    of NativeKeyPressed:
      if button notin window.state.buttonDown:
        window.handleButtonPress(button)
    of NativeKeyRepeated:
      if button notin window.state.buttonDown:
        window.handleButtonPress(button)
      else:
        window.state.perFrame.buttonPressed.incl button
        if window.onButtonPress != nil:
          window.onButtonPress(button)
    of NativeKeyReleased:
      window.handleButtonRelease(button)
  except Exception as error:
    failCallback(error.msg)

proc textCallback(text: string) =
  ## Preserves a native commit as one edit with legacy rune fallback.
  let window = applicationWindow
  if window == nil or window.state.closed or not window.hasFocus:
    return
  native.requestNativeFrame()
  try:
    handleTextInputTemplate(text)
  except Exception as error:
    failCallback(error.msg)

proc textEditCallback(edit: TextInputEdit) =
  ## Mirrors rune-based UIKit edits before queueing them for the application.
  let window = applicationWindow
  if window == nil or window.state.closed or not window.hasFocus or
    not window.state.runeInputEnabled or window.textInput.id.len == 0 or
    window.onTextEdit == nil:
      return
  native.requestNativeFrame()
  try:
    let
      runes = window.textInput.text.toRunes
      first = clamp(edit.start, 0, runes.len)
      last = first + clamp(edit.length, 0, runes.len - first)
    var bounded = edit
    bounded.start = first
    bounded.length = last - first
    case edit.kind
    of SelectText:
      window.textInput.selectionStart = first
      window.textInput.selectionEnd = last
    of ReplaceText:
      var text: string
      for i in 0 ..< first:
        text.add($runes[i])
      text.add(edit.text)
      for i in last ..< runes.len:
        text.add($runes[i])
      window.textInput.text = text
      window.textInput.selectionStart = first + edit.text.runeLen
      window.textInput.selectionEnd = window.textInput.selectionStart
    window.onTextEdit(bounded)
  except Exception as error:
    failCallback(error.msg)

proc scrollCallback(x, y, deltaX, deltaY: float64) =
  ## Accumulates scrolling from an attached mouse or trackpad.
  let window = applicationWindow
  if window == nil or window.state.closed or not window.hasFocus:
    return
  native.requestNativeFrame()
  try:
    window.pointerKind = MousePointer
    window.pointerMotion.clear()
    window.handleMouseMove(x, y)
    window.state.perFrame.scrollDelta += vec2(
      deltaX.float32, -deltaY.float32
    )
    if window.onScroll != nil:
      window.onScroll()
  except Exception as error:
    failCallback(error.msg)

proc runApplication*(onInit: Callback) =
  ## Registers initialization during NimMain; UIKit owns the event loop.
  if onInit == nil:
    raise newException(WindyError, "An iOS application needs an initializer.")
  if applicationInit != nil or applicationStarted:
    raise newException(WindyError, "The iOS application is already registered.")
  applicationInit = onInit

proc initializeCallback() =
  ## Initializes the application after UIKit creates its native window.
  try:
    if applicationInit == nil:
      raise newException(WindyError, "Register the app with runApplication.")
    applicationInit()
  except Exception as error:
    failCallback(error.msg)

proc windyIosMain(argc: cint, argv: ptr cstring): cint {.exportc, cdecl.} =
  ## Starts Windy's UIKit application after the generated Nim initializer.
  try:
    if applicationStarted:
      raise newException(WindyError, "The iOS application is already running.")
    if applicationInit == nil:
      raise newException(WindyError, "Register the app with runApplication.")
    applicationStarted = true
    platformDoubleClickInterval = 0.5
    result = native.runNativeApplication(argc, argv, NativeCallbacks(
      onInitialize: initializeCallback,
      onFrame: renderCallback,
      onResize: surfaceCallback,
      onFocus: focusCallback,
      onTouch: touchCallback,
      onKey: keyCallback,
      onText: textCallback,
      onTextEdit: textEditCallback,
      onScroll: scrollCallback,
      onError: failCallback
    ))
  except Exception as error:
    failCallback(error.msg)
    result = 1

proc newWindow*(
  title: string,
  size: IVec2,
  style = DecoratedResizable,
  visible = true,
  vsync = true,
  openglVersion = OpenGL4Dot1,
  msaa = msaaDisabled,
  depthBits = 24,
  stencilBits = 8,
  opengl = false
): Window =
  ## Creates the singleton UIKit window; iOS controls its actual dimensions.
  if not applicationStarted or native.nativeMetalView() == nil:
    raise newException(WindyError, "Create the window inside runApplication.")
  if applicationWindow != nil:
    raise newException(WindyError, "iOS supports one Windy window.")
  if opengl:
    raise newException(WindyError, "The iOS Windy backend requires Metal.")
  if not visible or not vsync or style == Transparent or msaa != msaaDisabled:
    raise newException(WindyError, "Unsupported iOS window configuration.")
  result = Window(primaryTouch: -1)
  result.state.title = title
  result.state.contentScale = native.nativeScale()
  result.state.cursor = Cursor(kind: ArrowCursor)
  let size = native.nativeSize()
  result.drawableSize = ivec2(size.width, size.height)
  result.ready = size.width > 0 and size.height > 0
  applicationWindow = result

proc close*(window: Window) =
  ## Stops callbacks without terminating the UIKit application.
  if not window.state.closed:
    window.dismissTextEditMenu()
    window.cancelPointer()
    window.clearButtons()
    native.setNativeKeyboardVisible(false)
    native.setNativeTextInputState(TextInputState())
    native.stopNativeRendering()
    window.state.runeInputEnabled = false
    window.state.closeRequested = true
    window.state.closed = true
    window.textInput = TextInputState()
    window.onCloseRequest = nil
    window.onFrame = nil
    window.onMove = nil
    window.onResize = nil
    window.onFocusChange = nil
    window.onMouseMove = nil
    window.onScroll = nil
    window.onButtonPress = nil
    window.onButtonRelease = nil
    window.onRune = nil
    window.onTextInput = nil
    window.onTextEdit = nil
    window.onImeChange = nil
    window.onFileDrop = nil
    window.onFileDropPaths = nil

proc pollEvents*() =
  ## Rejects desktop event loops because UIKit dispatches iOS events.
  raise newException(WindyError, "Use runApplication and onFrame on iOS.")

proc waitEvents*(timeoutMs: int) =
  ## Rejects blocking the UIKit thread; the native host delivers callbacks.
  raise newException(WindyError, "Use runApplication and onFrame on iOS.")

proc wakeEvents*() {.raises: [], gcsafe.} =
  ## Requests a frame on UIKit's main thread from a background worker.
  native.wakeNativeEvents()

proc makeContextCurrent*(window: Window) =
  ## Rejects OpenGL context operations on the Metal backend.
  raise newException(WindyError, "Metal has no current OpenGL context.")

proc swapBuffers*(window: Window) =
  ## Rejects OpenGL presentation; the Metal command buffer presents frames.
  raise newException(WindyError, "Present the Metal command buffer on iOS.")

proc title*(window: Window): string =
  ## Returns the cached application window label.
  window.state.title

proc `title=`*(window: Window, title: string) =
  ## Caches a label because UIKit windows have no desktop title bar.
  window.state.title = title

proc icon*(window: Window): Image =
  ## Returns the cached icon; the installed app icon comes from its bundle.
  window.state.icon

proc `icon=`*(window: Window, icon: Image) =
  ## Caches a desktop icon without changing the installed application icon.
  window.state.icon = icon

proc mousePos*(window: Window): IVec2 =
  ## Returns the primary touch or pointer position in framebuffer pixels.
  window.state.mousePos

proc pointerSource*(window: Window): PointerSource =
  ## Returns the latest pointer's source, retained after release or cancel.
  window.pointerKind

proc pointerVelocity*(window: Window): Vec2 =
  ## Returns recent touch pixels per second, retained through normal release.
  window.pointerMotion.velocity

proc mousePrevPos*(window: Window): IVec2 =
  ## Returns the position preceding the latest pointer event.
  window.state.mousePrevPos

proc mouseDelta*(window: Window): IVec2 =
  ## Returns movement since the previous frame or latest pointer press.
  window.state.perFrame.mouseDelta

proc mouseInside*(window: Window): bool =
  ## Returns whether the application has a current pointer position.
  window.state.mouseInside

proc scrollDelta*(window: Window): Vec2 =
  ## Returns accumulated attached pointer scrolling for this frame.
  window.state.perFrame.scrollDelta

proc buttonDown*(window: Window): ButtonView =
  ## Returns the currently held buttons.
  window.state.buttonDown.ButtonView

proc buttonPressed*(window: Window): ButtonView =
  ## Returns buttons pressed since the previous frame.
  window.state.perFrame.buttonPressed.ButtonView

proc buttonReleased*(window: Window): ButtonView =
  ## Returns buttons released since the previous frame.
  window.state.perFrame.buttonReleased.ButtonView

proc buttonToggle*(window: Window): ButtonView =
  ## Returns the toggle state of each button.
  window.state.buttonToggle.ButtonView

proc runeInputEnabled*(window: Window): bool =
  ## Returns whether committed text input is enabled.
  window.state.runeInputEnabled

proc `runeInputEnabled=`*(window: Window, enabled: bool) =
  ## Enables committed text input and controls the software keyboard.
  if window.state.closed:
    raise newException(WindyError, "The iOS window is closed.")
  if window.state.runeInputEnabled != enabled:
    window.state.runeInputEnabled = enabled
    native.setNativeKeyboardVisible(enabled)

proc setTextInputState*(window: Window, state: TextInputState) =
  ## Publishes the focused editor for UIKit keyboard, IME and dictation input.
  ## Selection offsets are runes and bounds are framebuffer pixels.
  ## Publish an empty id when the application no longer has a focused editor.
  if window.state.closed:
    return
  window.textInput = state
  let count = state.text.runeLen
  window.textInput.selectionStart = clamp(state.selectionStart, 0, count)
  window.textInput.selectionEnd = clamp(state.selectionEnd, 0, count)
  window.textInput.visibleStart = clamp(state.visibleStart, 0, count)
  window.textInput.visibleEnd = clamp(state.visibleEnd, 0, count)
  native.setNativeTextInputState(window.textInput)

proc cursor*(window: Window): Cursor =
  ## Returns the requested desktop cursor appearance.
  window.state.cursor

proc `cursor=`*(window: Window, cursor: Cursor) =
  ## Caches cursor appearance while UIKit owns pointer presentation.
  window.state.cursor = cursor

proc closeRequested*(window: Window): bool =
  ## Returns whether the application requested its window to close.
  window.state.closeRequested

proc `closeRequested=`*(window: Window, requested: bool) =
  ## Sets the application's logical close request.
  window.state.closeRequested = requested

proc closed*(window: Window): bool =
  ## Returns whether the logical window has been closed.
  window.state.closed

proc getClipboardString*(): string =
  ## Reads clipboard text synchronously; UIKit may request paste permission.
  native.nativeClipboardText()

proc setClipboardString*(text: string) =
  ## Copies text to the system clipboard.
  native.setNativeClipboardText(text)

proc getClipboardImage*(): Image =
  ## Reads an image from the system clipboard after UIKit's paste approval.
  native.nativeClipboardImage()

proc setClipboardImage*(image: Image) =
  ## Copies an image to the system clipboard as PNG data.
  native.setNativeClipboardImage(image)

proc getClipboardContentKinds*(): set[ClipboardContentKind] =
  ## Returns the clipboard kinds currently supported by this backend.
  if native.nativeHasClipboardText():
    result.incl TextContent
  if native.nativeHasClipboardImage():
    result.incl ImageContent

proc getScreens*(): seq[Screen] =
  ## Returns the current application's drawable as its available screen.
  if applicationWindow != nil:
    let size = applicationWindow.size
    result.add(Screen(right: size.x, bottom: size.y, primary: true))
