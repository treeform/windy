import
  std/[math, unicode],
  pixie,
  ../../common,
  events, uidefs

export events

{.compile: "protocols.m".}
{.compile("services.m", "-fobjc-arc").}

proc windyIosNativeProtocol(name: cstring): pointer {.importc, cdecl.}
  ## References UIKit protocol metadata emitted by the SDK's Objective-C headers.

type
  NativeTextEdit = proc(
    kind: cint, text: cstring, textLength: csize_t, start, length: int
  ) {.cdecl.}
  NativeTextKeyCallback = proc(
    usage, pressed: cint, modifiers: uint
  ) {.cdecl.}

proc windyIosClipboardImage(
  bytes: ptr pointer, length: ptr csize_t
): cint {.importc, cdecl.}
  ## Copies clipboard PNG data into a caller-owned allocation.
proc windyIosSetClipboardImage(
  bytes: pointer, length: csize_t
): cint {.importc, cdecl.}
  ## Decodes PNG data and copies it into the native clipboard.
proc windyIosHasClipboardImage(): cint {.importc, cdecl.}
  ## Checks pasteboard image types without reading protected contents.
proc windyIosFreeClipboardImage(bytes: pointer) {.importc, cdecl.}
  ## Releases the clipboard PNG allocation.
proc windyIosSetTextInputState(
  host: pointer, identity, text: cstring, textLength: csize_t,
  selectionStart, selectionEnd: int, x, y, width, height: float64,
  multiline, password: cint, edit: NativeTextEdit, key: NativeTextKeyCallback
) {.importc, cdecl.}
  ## Publishes editor state to UIKit's text-input responder.
proc windyIosSetTextKeyboardVisible(visible: cint): cint {.importc, cdecl.}
  ## Transfers keyboard ownership when a native text editor is active.
proc windyIosKeyboardInset(host: pointer): float64 {.importc, cdecl.}
  ## Returns bottom-docked keyboard occlusion in UIKit points.
proc windyIosObserveKeyboard(changed: proc() {.cdecl.}) {.importc, cdecl.}
  ## Observes keyboard transitions even before text services are focused.
proc windyIosWakeEvents() {.importc, cdecl, gcsafe.}
  ## Posts an event to UIKit's main queue from any thread.

const
  ControlModifier = 1'u shl 18
  CommandModifier = 1'u shl 20
  KeyboardReturn = 0x28
  KeyboardKeypadReturn = 0x58
  KeyboardTab = 0x2b
  KeyboardBackspace = 0x2a
  PixelFormatBgra8Unorm = 80'u
  FlexibleWidthAndHeight = 2'u or 16'u
  ClipboardPixelLimit = 16 * 1024 * 1024

var
  callbacks: NativeCallbacks
  appDelegateClass, sceneDelegateClass, controllerClass: Class
  viewClass, renderDelegateClass: Class
  nativeWindow: UIWindow
  nativeController: UIViewController
  nativeView: MTKView
  renderDelegate: ID
  initialized, active, stopped, keyboardRequested: bool
  updatingSurface, running: bool
  lastWidth, lastHeight: int32
  lastScale = 1.0'f

proc stopNativeRendering*() =
  ## Stops native frame production while retaining the borrowed view handles.
  stopped = true
  discard windyIosSetTextKeyboardVisible(0)
  windyIosSetTextInputState(
    nil, nil, nil, 0, 0, 0, 0, 0, 0, 0, 0, 0, nil, nil
  )
  if nativeView.int != 0:
    nativeView.setPaused(true)

proc reportFailure(message: string) =
  ## Contains failures at the Objective-C callback boundary.
  stopNativeRendering()
  if callbacks.onError != nil:
    try:
      callbacks.onError(message)
    except Exception as error:
      stderr.writeLine("Windy UIKit error callback: " & error.msg)
  else:
    stderr.writeLine("Windy UIKit: " & message)

template nativeCallback(body: untyped) =
  ## Keeps Nim exceptions from unwinding into UIKit or MetalKit.
  try:
    body
  except Exception as error:
    reportFailure(error.msg)

proc requireHandle[T](handle: T, message: string) =
  ## Rejects a missing native object before attempting to use it.
  if cast[int](handle) == 0:
    raise newException(WindyError, message)

proc nativeMetalView*(): pointer =
  ## Borrows Windy's singleton MTKView for the Metal renderer.
  cast[pointer](nativeView)

proc nativeViewController*(): pointer =
  ## Borrows the UIKit controller that owns Windy's view.
  cast[pointer](nativeController)

proc nativeSize*(): tuple[width, height: int32] =
  ## Returns the current Metal drawable dimensions in framebuffer pixels.
  if nativeView.int != 0:
    let size = nativeView.drawableSize()
    result = (size.width.round.int32, size.height.round.int32)

proc nativeScale*(): float32 =
  ## Returns framebuffer pixels per UIKit point.
  if nativeView.int != 0:
    result = nativeView.contentScaleFactor().float32
  else:
    result = 1

proc nativeKeyboardOcclusionHeight*(): float32 =
  ## Returns a docked keyboard's overlap in framebuffer pixels.
  if nativeView.int != 0:
    result = (windyIosKeyboardInset(cast[pointer](nativeView)) *
      nativeScale().float64).float32

proc wakeNativeEvents*() {.gcsafe.} =
  ## Wakes UIKit's main loop safely from a worker thread.
  windyIosWakeEvents()

proc nativeSafeAreaInsets*(): tuple[top, right, bottom, left: float32] =
  ## Converts UIKit's safe area from points to framebuffer pixels.
  if nativeView.int != 0:
    let
      insets = nativeView.safeAreaInsets()
      scale = nativeView.contentScaleFactor()
    result = (
      (insets.top * scale).float32,
      (insets.right * scale).float32,
      (insets.bottom * scale).float32,
      (insets.left * scale).float32
    )

proc nativeClipboardText*(): string =
  ## Copies the system clipboard text into a Nim string.
  autoreleasepool:
    result = $UIPasteboard.generalPasteboard().string()

proc setNativeClipboardText*(text: string) =
  ## Copies a Nim string to the system clipboard.
  autoreleasepool:
    UIPasteboard.generalPasteboard().setString(@text)

proc nativeHasClipboardText*(): bool =
  ## Checks for clipboard text without reading protected clipboard contents.
  UIPasteboard.generalPasteboard().hasStrings()

proc nativeClipboardImage*(): Image =
  ## Copies the native clipboard image into an owned Pixie image.
  var
    bytes: pointer
    length: csize_t
  let status = windyIosClipboardImage(bytes.addr, length.addr)
  if status == 0:
    return nil
  if status < 0:
    raise newException(WindyError,
      "Could not read clipboard image (maximum 16 megapixels or 64 MB)")
  defer: windyIosFreeClipboardImage(bytes)
  var data = newString(length.int)
  if data.len > 0:
    copyMem(data[0].addr, bytes, data.len)
  try:
    let size = decodeImageDimensions(data)
    if size.width.int64 * size.height.int64 > ClipboardPixelLimit:
      raise newException(WindyError, "Clipboard image exceeds 16 megapixels")
    result = decodeImage(data)
  except PixieError as error:
    raise newException(WindyError,
      "Could not decode clipboard image: " & error.msg, error)

proc setNativeClipboardImage*(image: Image) =
  ## Copies a Pixie image into UIKit's image clipboard.
  if image == nil:
    raise newException(WindyError, "Cannot copy a nil image to the clipboard")
  if image.width.int64 * image.height.int64 > ClipboardPixelLimit:
    raise newException(WindyError, "Clipboard image exceeds 16 megapixels")
  try:
    let data = image.encodeImage(PngFormat)
    if windyIosSetClipboardImage(data.cstring, data.len.csize_t) == 0:
      raise newException(WindyError, "Could not copy image to the clipboard")
  except PixieError as error:
    raise newException(WindyError,
      "Could not encode clipboard image: " & error.msg, error)

proc nativeHasClipboardImage*(): bool =
  ## Checks for native clipboard images without reading their contents.
  windyIosHasClipboardImage() != 0

proc setNativeKeyboardVisible*(visible: bool) =
  ## Transfers first-responder ownership between text input and raw keys.
  keyboardRequested = visible
  if nativeView.int == 0:
    return
  if windyIosSetTextKeyboardVisible(visible.cint) != 0:
    if not visible and nativeController.int != 0:
      discard nativeController.becomeFirstResponder()
    return
  if visible:
    discard nativeView.becomeFirstResponder()
  else:
    discard nativeView.resignFirstResponder()
    if nativeController.int != 0:
      discard nativeController.becomeFirstResponder()

proc nativeTextEdited(
  kind: cint, text: cstring, textLength: csize_t, start, length: int
) {.cdecl.} =
  ## Copies native edit buffers before returning across the Objective-C ABI.
  nativeCallback:
    if not initialized or not active or stopped or
        not keyboardRequested or callbacks.onTextEdit == nil:
      return
    var edit = TextInputEdit(
      kind: (if kind == 0: ReplaceText else: SelectText),
      start: start,
      length: length
    )
    if kind == 0 and textLength > 0:
      edit.text = newString(textLength.int)
      copyMem(edit.text[0].addr, text, textLength.int)
    callbacks.onTextEdit(edit)

proc nativeTextKey(
  usage, pressed: cint, modifiers: uint
) {.cdecl.} =
  ## Preserves application shortcuts while UIKit owns editor navigation.
  nativeCallback:
    if initialized and active and not stopped and
        keyboardRequested and callbacks.onKey != nil:
      callbacks.onKey(
        usage.int,
        (if pressed != 0: NativeKeyPressed else: NativeKeyReleased),
        modifiers
      )

proc setNativeTextInputState*(state: TextInputState) =
  ## Synchronizes native text services using framebuffer-based field bounds.
  let scale = nativeScale().float64
  windyIosSetTextInputState(
    cast[pointer](nativeView), state.id.cstring, state.text.cstring,
    state.text.len.csize_t, state.selectionStart, state.selectionEnd,
    state.bounds.x.float64 / scale, state.bounds.y.float64 / scale,
    state.bounds.w.float64 / scale, state.bounds.h.float64 / scale,
    state.multiline.cint, state.password.cint,
    nativeTextEdited, nativeTextKey
  )
  setNativeKeyboardVisible(keyboardRequested)

proc superVoid(self: ID, className, selector: string) =
  ## Calls a zero-argument superclass implementation using its exact ABI.
  var parent = objc_super(
    receiver: self,
    super_class: objc_getClass(className.cstring)
  )
  let send = cast[proc(
    parent: ptr objc_super, selector: SEL
  ) {.cdecl.}](objc_msgSendSuper)
  send(parent.addr, s(selector))

proc superPresses(
  self: ID, className, selector: string, presses: NSSet, event: UIEvent
) =
  ## Forwards unhandled presses so UIKit supplies native text-input behavior.
  var parent = objc_super(
    receiver: self,
    super_class: objc_getClass(className.cstring)
  )
  let send = cast[proc(
    parent: ptr objc_super, selector: SEL, presses: NSSet, event: UIEvent
  ) {.cdecl.}](objc_msgSendSuper)
  send(parent.addr, s(selector), presses, event)

proc updateSurface(force = false) =
  ## Sizes the drawable once in pixels and notifies Nim after initialization.
  if nativeView.int == 0 or updatingSurface:
    return
  updatingSurface = true
  defer: updatingSurface = false
  let
    bounds = nativeView.bounds()
    screen =
      if nativeWindow.int != 0: nativeWindow.screen()
      else: UIScreen.mainScreen()
    scale = screen.scale()
  if scale <= 0 or bounds.size.width <= 0 or bounds.size.height <= 0:
    return
  if nativeView.contentScaleFactor() != scale:
    nativeView.setContentScaleFactor(scale)
  let
    width = round(bounds.size.width * scale).int32
    height = round(bounds.size.height * scale).int32
    current = nativeView.drawableSize()
  if current.width != width.float64 or current.height != height.float64:
    nativeView.setDrawableSize(CGSize(
      width: width.float64,
      height: height.float64
    ))
  let changed = force or width != lastWidth or height != lastHeight or
    scale.float32 != lastScale
  lastWidth = width
  lastHeight = height
  lastScale = scale.float32
  if initialized and changed and callbacks.onResize != nil:
    callbacks.onResize(width, height, lastScale)

proc setActive(value: bool) =
  ## Pauses MetalKit before notifying Windy about application deactivation.
  if nativeView.int != 0 and not value:
    nativeView.setPaused(true)
  let changed = active != value
  active = value
  if initialized and changed and callbacks.onFocus != nil:
    callbacks.onFocus(value)
  if nativeView.int != 0:
    nativeView.setPaused(not (active and initialized and not stopped))

proc nativeKeyboardChanged() {.cdecl.} =
  ## Invalidates application layout even when the drawable size is unchanged.
  nativeCallback:
    updateSurface(true)

proc viewLayout(self: ID, selector: SEL) {.cdecl.} =
  ## Lets MetalKit lay out first, then synchronizes drawable dimensions.
  nativeCallback:
    superVoid(self, "MTKView", "layoutSubviews")
    updateSurface()

proc controllerLayout(self: ID, selector: SEL) {.cdecl.} =
  ## Refreshes scale and safe-area-dependent layout after controller changes.
  nativeCallback:
    superVoid(self, "UIViewController", "viewDidLayoutSubviews")
    updateSurface()

proc safeAreaChanged(self: ID, selector: SEL) {.cdecl.} =
  ## Refreshes public size notifications when UIKit changes its safe area.
  nativeCallback:
    superVoid(self, "UIViewController", "viewSafeAreaInsetsDidChange")
    updateSurface(true)

proc drawInMetalView(self: ID, selector: SEL, view: MTKView) {.cdecl.} =
  ## Delivers one frame without acquiring or presenting the renderer's drawable.
  if not initialized or not active or stopped:
    return
  nativeCallback:
    autoreleasepool:
      updateSurface()
      if callbacks.onFrame != nil:
        callbacks.onFrame()

proc drawableSizeChanged(
  self: ID, selector: SEL, view: MTKView, size: CGSize
) {.cdecl.} =
  ## Observes MetalKit drawable sizing while avoiding recursive notifications.
  nativeCallback:
    updateSurface()

proc deliverTouches(touches: NSSet, phase: NativeTouchPhase) =
  ## Converts stable UITouch identities and positions to framebuffer pixels.
  if not initialized or not active or stopped or callbacks.onTouch == nil:
    return
  let
    objects = touches.allObjects()
    scale = nativeView.contentScaleFactor()
  for i in 0'u ..< objects.count():
    let
      touch = UITouch(objects.objectAtIndex(i).int)
      position = touch.locationInView(nativeView)
    callbacks.onTouch(
      touch.int,
      phase,
      position.x * scale,
      position.y * scale
    )

proc touchesBegan(
  self: ID, selector: SEL, touches: NSSet, event: UIEvent
) {.cdecl.} =
  ## Starts native touches without assigning an artificial slot identifier.
  nativeCallback:
    deliverTouches(touches, NativeTouchBegan)

proc touchesMoved(
  self: ID, selector: SEL, touches: NSSet, event: UIEvent
) {.cdecl.} =
  ## Updates native touch positions.
  nativeCallback:
    deliverTouches(touches, NativeTouchMoved)

proc touchesEnded(
  self: ID, selector: SEL, touches: NSSet, event: UIEvent
) {.cdecl.} =
  ## Finishes native touches normally.
  nativeCallback:
    deliverTouches(touches, NativeTouchEnded)

proc touchesCancelled(
  self: ID, selector: SEL, touches: NSSet, event: UIEvent
) {.cdecl.} =
  ## Cancels native touches without turning cancellation into a tap.
  nativeCallback:
    deliverTouches(touches, NativeTouchCancelled)

proc hoverChanged(
  self: ID, selector: SEL, recognizer: UIHoverGestureRecognizer
) {.cdecl.} =
  ## Maps an attached pointer's hover location to the Windy pointer.
  nativeCallback:
    if initialized and active and not stopped and callbacks.onTouch != nil:
      let
        position = recognizer.locationInView(nativeView)
        scale = nativeView.contentScaleFactor()
      callbacks.onTouch(
        0, NativeTouchHover, position.x * scale, position.y * scale
      )

proc scrollChanged(
  self: ID, selector: SEL, recognizer: UIPanGestureRecognizer
) {.cdecl.} =
  ## Converts external pointer scrolling without recognizing finger pans.
  nativeCallback:
    let delta = recognizer.translationInView(nativeView)
    recognizer.setTranslation(CGPoint(), nativeView)
    if initialized and active and not stopped and callbacks.onScroll != nil:
      let
        position = recognizer.locationInView(nativeView)
        scale = nativeView.contentScaleFactor()
      if delta.x != 0 or delta.y != 0:
        callbacks.onScroll(
          position.x * scale, position.y * scale, delta.x, delta.y
        )

proc canBecomeResponder(self: ID, selector: SEL): bool {.cdecl.} =
  ## Permits explicit first-responder transfer for hardware and software keys.
  true

proc hasText(self: ID, selector: SEL): bool {.cdecl.} =
  ## Allows UIKit to deliver deletion to the application's text model.
  keyboardRequested

proc syntheticKey(usage: int) =
  ## Sends a software-keyboard control key without changing hardware modifiers.
  if callbacks.onKey != nil:
    callbacks.onKey(usage, NativeKeyPressed, uint.high)
    callbacks.onKey(usage, NativeKeyReleased, uint.high)

proc insertText(self: ID, selector: SEL, text: NSString) {.cdecl.} =
  ## Delivers only committed UIKit text, keeping control keys as button events.
  nativeCallback:
    if not initialized or not active or stopped or not keyboardRequested:
      return
    var chunk: string
    for rune in ($text).runes:
      if rune.int in [9, 10, 13]:
        if chunk.len > 0 and callbacks.onText != nil:
          callbacks.onText(chunk)
          chunk.setLen(0)
        syntheticKey(if rune.int == 9: KeyboardTab else: KeyboardReturn)
      else:
        chunk.add($rune)
    if chunk.len > 0 and callbacks.onText != nil:
      callbacks.onText(chunk)

proc deleteBackward(self: ID, selector: SEL) {.cdecl.} =
  ## Lets UIKit repeat software and hardware text deletion naturally.
  nativeCallback:
    if initialized and active and not stopped and keyboardRequested:
      syntheticKey(KeyboardBackspace)

proc handlePresses(
  self: ID, presses: NSSet, event: UIEvent, action: NativeKeyAction,
  selector: string, controller: bool
) =
  ## Sends physical keys once and forwards text presses to native UIKeyInput.
  let superName = if controller: "UIViewController" else: "MTKView"
  if not initialized or not active or stopped or
      (controller and keyboardRequested):
    superPresses(self, superName, selector, presses, event)
    return
  let
    objects = presses.allObjects()
    forwarded = NSMutableSet.setWithCapacity(objects.count())
  for i in 0'u ..< objects.count():
    let
      press = UIPress(objects.objectAtIndex(i).int)
      key = press.key()
    if key.int == 0:
      forwarded.addObject(ID(press.int))
      continue
    let
      usage = key.keyCode()
      modifiers = key.modifierFlags()
      textControl = usage in [
        KeyboardReturn, KeyboardKeypadReturn, KeyboardTab, KeyboardBackspace
      ]
      forwardText = not controller and keyboardRequested and
        (modifiers and (ControlModifier or CommandModifier)) == 0 and
        (textControl or ($key.characters()).len > 0) and
        usage notin {0x29, 0x39, 0x46 .. 0x52, 0xe0 .. 0xe7}
    if not (forwardText and textControl) and callbacks.onKey != nil:
      callbacks.onKey(usage, action, modifiers)
    if forwardText:
      forwarded.addObject(ID(press.int))
  if forwarded.count() > 0:
    superPresses(self, superName, selector, forwarded, event)

proc viewPressesBegan(
  self: ID, selector: SEL, presses: NSSet, event: UIEvent
) {.cdecl.} =
  ## Starts physical key input in the text responder.
  nativeCallback:
    handlePresses(
      self,
      presses,
      event,
      NativeKeyPressed,
      "pressesBegan:withEvent:",
      false
    )

proc viewPressesEnded(
  self: ID, selector: SEL, presses: NSSet, event: UIEvent
) {.cdecl.} =
  ## Releases physical key input in the text responder.
  nativeCallback:
    handlePresses(
      self,
      presses,
      event,
      NativeKeyReleased,
      "pressesEnded:withEvent:",
      false
    )

proc viewPressesCancelled(
  self: ID, selector: SEL, presses: NSSet, event: UIEvent
) {.cdecl.} =
  ## Releases cancelled hardware keys without retaining a held state.
  nativeCallback:
    handlePresses(
      self,
      presses,
      event,
      NativeKeyReleased,
      "pressesCancelled:withEvent:",
      false
    )

proc controllerPressesBegan(
  self: ID, selector: SEL, presses: NSSet, event: UIEvent
) {.cdecl.} =
  ## Starts raw hardware keys when the software keyboard is hidden.
  nativeCallback:
    handlePresses(
      self,
      presses,
      event,
      NativeKeyPressed,
      "pressesBegan:withEvent:",
      true
    )

proc controllerPressesEnded(
  self: ID, selector: SEL, presses: NSSet, event: UIEvent
) {.cdecl.} =
  ## Releases raw hardware keys when the software keyboard is hidden.
  nativeCallback:
    handlePresses(
      self,
      presses,
      event,
      NativeKeyReleased,
      "pressesEnded:withEvent:",
      true
    )

proc controllerPressesCancelled(
  self: ID, selector: SEL, presses: NSSet, event: UIEvent
) {.cdecl.} =
  ## Releases cancelled keys in the controller responder.
  nativeCallback:
    handlePresses(
      self,
      presses,
      event,
      NativeKeyReleased,
      "pressesCancelled:withEvent:",
      true
    )

proc statusBarHidden(self: ID, selector: SEL): bool {.cdecl.} =
  ## Lets the application's own UI occupy the screen with safe-area insets.
  true

proc supportedOrientations(self: ID, selector: SEL): uint {.cdecl.} =
  ## Supports portrait and both landscape orientations on the singleton window.
  (1'u shl 1) or (1'u shl 3) or (1'u shl 4)

proc attachScene(scene: UIWindowScene) =
  ## Attaches the persistent Metal view to a UIKit-managed window scene.
  requireHandle(scene, "UIKit did not provide a window scene")
  if nativeWindow.int != 0:
    if nativeWindow.windowScene().int == scene.int:
      return
    raise newException(WindyError, "Windy iOS supports one window scene")
  nativeWindow = UIWindow.alloc().initWithWindowScene(scene)
  requireHandle(nativeWindow, "Could not create the UIKit window")
  if nativeView.int == 0:
    let device = MTLCreateSystemDefaultDevice()
    requireHandle(device, "Could not create the Metal device")
    defer: device.release()
    nativeView = MTKView(viewClass.alloc().int).initWithFrame(
      nativeWindow.bounds(), device
    )
    requireHandle(nativeView, "Could not create Windy's Metal view")
    nativeView.setPaused(true)
    nativeView.setEnableSetNeedsDisplay(false)
    nativeView.setAutoResizeDrawable(false)
    nativeView.setColorPixelFormat(PixelFormatBgra8Unorm)
    nativeView.setDepthStencilPixelFormat(0)
    nativeView.setFramebufferOnly(true)
    nativeView.setPreferredFramesPerSecond(60)
    nativeView.setMultipleTouchEnabled(true)
    nativeView.setUserInteractionEnabled(true)
    nativeView.setAutoresizingMask(FlexibleWidthAndHeight)
    nativeView.setBackgroundColor(UIColor.blackColor())
    renderDelegate = renderDelegateClass.new()
    requireHandle(renderDelegate, "Could not create the MetalKit delegate")
    nativeView.setDelegate(renderDelegate)
    nativeController = UIViewController(controllerClass.new().int)
    requireHandle(nativeController, "Could not create the UIKit controller")
    nativeController.setView(nativeView)
    windyIosObserveKeyboard(nativeKeyboardChanged)
    let hover = UIHoverGestureRecognizer.alloc().initWithTarget(
      ID(nativeView.int), s"windyHover:"
    )
    requireHandle(hover, "Could not create the pointer hover recognizer")
    defer: hover.release()
    hover.setCancelsTouchesInView(false)
    hover.setDelaysTouchesBegan(false)
    hover.setDelaysTouchesEnded(false)
    nativeView.addGestureRecognizer(hover)
    let scroll = UIPanGestureRecognizer.alloc().initWithTarget(
      ID(nativeView.int), s"windyScroll:"
    )
    requireHandle(scroll, "Could not create the pointer scroll recognizer")
    defer: scroll.release()
    scroll.setAllowedTouchTypes(NSArray.array())
    scroll.setAllowedScrollTypesMask(3)
    scroll.setCancelsTouchesInView(false)
    scroll.setDelaysTouchesBegan(false)
    scroll.setDelaysTouchesEnded(false)
    nativeView.addGestureRecognizer(scroll)
  nativeView.setContentScaleFactor(scene.screen().scale())
  nativeView.setFrame(nativeWindow.bounds())
  nativeWindow.setRootViewController(nativeController)
  nativeWindow.makeKeyAndVisible()
  updateSurface()
  if not initialized:
    if callbacks.onInitialize == nil:
      raise newException(WindyError, "Windy UIKit needs an initializer")
    callbacks.onInitialize()
    initialized = true
  updateSurface(true)
  setNativeKeyboardVisible(keyboardRequested)
  setActive(scene.activationState() == 0)

proc sceneConnected(
  self: ID, selector: SEL, scene: UIScene, session, options: ID
) {.cdecl.} =
  ## Creates Windy's window for the UIKit scene connection.
  nativeCallback:
    if not scene.isKindOfClass(objc_getClass("UIWindowScene")):
      raise newException(WindyError, "Unsupported UIKit scene type")
    attachScene(UIWindowScene(scene.int))

proc sceneActive(self: ID, selector: SEL, scene: UIScene) {.cdecl.} =
  ## Resumes display callbacks after the scene becomes interactive.
  nativeCallback:
    updateSurface(true)
    setActive(true)

proc sceneInactive(self: ID, selector: SEL, scene: UIScene) {.cdecl.} =
  ## Stops GPU submission before UIKit deactivates the scene.
  nativeCallback:
    setActive(false)

proc sceneDisconnected(self: ID, selector: SEL, scene: UIScene) {.cdecl.} =
  ## Detaches a window while preserving the renderer's borrowed Metal view.
  nativeCallback:
    setActive(false)
    if nativeWindow.int != 0:
      nativeWindow.setHidden(true)
      nativeWindow.setRootViewController(0.UIViewController)
      nativeWindow.release()
      nativeWindow = 0.UIWindow

proc sceneWindow(self: ID, selector: SEL): UIWindow {.cdecl.} =
  ## Exposes the window managed by the singleton scene delegate.
  nativeWindow

proc appLaunched(
  self: ID, selector: SEL, application: UIApplication, options: ID
): bool {.cdecl.} =
  ## Defers window creation until UIKit supplies a window scene.
  true

proc sceneConfiguration(
  self: ID, selector: SEL, application: UIApplication,
  session: UISceneSession, options: ID
): UISceneConfiguration {.cdecl.} =
  ## Chooses Windy's runtime-registered scene delegate without a storyboard.
  nativeCallback:
    result = UISceneConfiguration.alloc().initWithName(
      @"Windy", session.role()
    )
    requireHandle(result, "Could not create the UIKit scene configuration")
    result.setDelegateClass(sceneDelegateClass)
    result.autorelease()

proc newClass(name, parent: string): Class =
  ## Creates one runtime class only when its UIKit superclass is available.
  let superclass = objc_getClass(parent.cstring)
  requireHandle(superclass, "Missing Objective-C class: " & parent)
  result = objc_allocateClassPair(superclass, name.cstring, 0)
  requireHandle(result, "Could not register Objective-C class: " & name)

proc addNativeProtocol(cls: Class, name: string) =
  ## Adds a checked native protocol to a runtime class.
  let protocol = cast[Protocol](windyIosNativeProtocol(name.cstring))
  requireHandle(protocol, "Missing Objective-C protocol: " & name)
  if not class_addProtocol(cls, protocol):
    raise newException(
      WindyError,
      "Could not add Objective-C protocol: " & name
    )

template addNativeMethod(
  cls: Class, selector, encoding: string, implementation: untyped
) =
  ## Registers a method with the exact Objective-C return and argument ABI.
  if not class_addMethod(
    cls, s(selector), cast[IMP](implementation), encoding.cstring
  ):
    raise newException(WindyError, "Could not register selector: " & selector)

proc registerClasses() =
  ## Registers Windy's UIKit objects using the shared Apple Objective-C runtime.
  appDelegateClass = newClass("WindyIosAppDelegate", "UIResponder")
  appDelegateClass.addNativeProtocol("UIApplicationDelegate")
  appDelegateClass.addNativeMethod(
    "application:didFinishLaunchingWithOptions:", "B@:@@", appLaunched
  )
  appDelegateClass.addNativeMethod(
    "application:configurationForConnectingSceneSession:options:",
    "@@:@@@", sceneConfiguration
  )
  objc_registerClassPair(appDelegateClass)

  sceneDelegateClass = newClass("WindyIosSceneDelegate", "UIResponder")
  sceneDelegateClass.addNativeProtocol("UIWindowSceneDelegate")
  sceneDelegateClass.addNativeMethod(
    "scene:willConnectToSession:options:", "v@:@@@", sceneConnected
  )
  sceneDelegateClass.addNativeMethod(
    "sceneDidBecomeActive:",
    "v@:@",
    sceneActive
  )
  sceneDelegateClass.addNativeMethod(
    "sceneWillResignActive:",
    "v@:@",
    sceneInactive
  )
  sceneDelegateClass.addNativeMethod(
    "sceneDidEnterBackground:",
    "v@:@",
    sceneInactive
  )
  sceneDelegateClass.addNativeMethod(
    "sceneDidDisconnect:",
    "v@:@",
    sceneDisconnected
  )
  sceneDelegateClass.addNativeMethod("window", "@@:", sceneWindow)
  objc_registerClassPair(sceneDelegateClass)

  controllerClass = newClass("WindyIosViewController", "UIViewController")
  controllerClass.addNativeMethod(
    "canBecomeFirstResponder",
    "B@:",
    canBecomeResponder
  )
  controllerClass.addNativeMethod(
    "prefersStatusBarHidden",
    "B@:",
    statusBarHidden
  )
  controllerClass.addNativeMethod(
    "supportedInterfaceOrientations",
    "Q@:",
    supportedOrientations
  )
  controllerClass.addNativeMethod(
    "viewDidLayoutSubviews",
    "v@:",
    controllerLayout
  )
  controllerClass.addNativeMethod(
    "viewSafeAreaInsetsDidChange",
    "v@:",
    safeAreaChanged
  )
  controllerClass.addNativeMethod(
    "pressesBegan:withEvent:",
    "v@:@@",
    controllerPressesBegan
  )
  controllerClass.addNativeMethod(
    "pressesEnded:withEvent:",
    "v@:@@",
    controllerPressesEnded
  )
  controllerClass.addNativeMethod(
    "pressesCancelled:withEvent:",
    "v@:@@",
    controllerPressesCancelled
  )
  objc_registerClassPair(controllerClass)

  viewClass = newClass("WindyIosMetalView", "MTKView")
  viewClass.addNativeProtocol("UIKeyInput")
  viewClass.addNativeMethod("layoutSubviews", "v@:", viewLayout)
  viewClass.addNativeMethod(
    "canBecomeFirstResponder",
    "B@:",
    canBecomeResponder
  )
  viewClass.addNativeMethod("hasText", "B@:", hasText)
  viewClass.addNativeMethod("insertText:", "v@:@", insertText)
  viewClass.addNativeMethod("deleteBackward", "v@:", deleteBackward)
  viewClass.addNativeMethod("touchesBegan:withEvent:", "v@:@@", touchesBegan)
  viewClass.addNativeMethod("touchesMoved:withEvent:", "v@:@@", touchesMoved)
  viewClass.addNativeMethod("touchesEnded:withEvent:", "v@:@@", touchesEnded)
  viewClass.addNativeMethod(
    "touchesCancelled:withEvent:",
    "v@:@@",
    touchesCancelled
  )
  viewClass.addNativeMethod(
    "pressesBegan:withEvent:",
    "v@:@@",
    viewPressesBegan
  )
  viewClass.addNativeMethod(
    "pressesEnded:withEvent:",
    "v@:@@",
    viewPressesEnded
  )
  viewClass.addNativeMethod(
    "pressesCancelled:withEvent:",
    "v@:@@",
    viewPressesCancelled
  )
  viewClass.addNativeMethod("windyHover:", "v@:@", hoverChanged)
  viewClass.addNativeMethod("windyScroll:", "v@:@", scrollChanged)
  objc_registerClassPair(viewClass)

  renderDelegateClass = newClass("WindyIosMetalDelegate", "NSObject")
  renderDelegateClass.addNativeProtocol("MTKViewDelegate")
  renderDelegateClass.addNativeMethod("drawInMTKView:", "v@:@", drawInMetalView)
  renderDelegateClass.addNativeMethod(
    "mtkView:drawableSizeWillChange:", "v@:@{CGSize=dd}", drawableSizeChanged
  )
  objc_registerClassPair(renderDelegateClass)

proc runNativeApplication*(
  argc: cint, argv: ptr cstring, handlers: NativeCallbacks
): cint =
  ## Starts UIKit with Windy's own delegates, view, and event implementation.
  if running:
    raise newException(
      WindyError,
      "The native iOS application is already running"
    )
  running = true
  callbacks = handlers
  autoreleasepool:
    registerClasses()
    result = UIApplicationMain(argc, argv, 0.NSString, @"WindyIosAppDelegate")
