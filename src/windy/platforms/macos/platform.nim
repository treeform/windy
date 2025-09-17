import ../../common, ../../internal, macdefs, opengl, pixie/fileformats/png,
    pixie/images, times, unicode, utils, vmath

# TODO: Use macos native http client, fallback to windy http client.
import ../../http
export http

type
  Window* = ref object
    onCloseRequest*: Callback
    onFrame*: Callback
    onMove*: Callback
    onResize*: Callback
    onFocusChange*: Callback
    onMouseMove*: Callback
    onScroll*: Callback
    onButtonPress*: ButtonCallback
    onButtonRelease*: ButtonCallback
    onRune*: RuneCallback
    onImeChange*: Callback
    imePos*: IVec2

    state: WindowState

    inner: NSWindow
    trackingArea: NSTrackingArea
    markedText: NSString

const
  decoratedResizableWindowMask =
    NSWindowStyleMaskTitled or NSWindowStyleMaskClosable or
    NSWindowStyleMaskMiniaturizable or NSWindowStyleMaskResizable
  decoratedWindowMask =
    NSWindowStyleMaskTitled or NSWindowStyleMaskClosable or
    NSWindowStyleMaskMiniaturizable
  undecoratedWindowMask =
    NSWindowStyleMaskBorderless or NSWindowStyleMaskMiniaturizable

var
  WindyAppDelegate, WindyWindow, WindyView: Class
  windows: seq[Window]

proc indexForNSWindow(windows: seq[Window], inner: NSWindow): int =
  ## Returns the window for this handle, else -1
  for i, window in windows:
    if window.inner.int == inner.int:
      return i
  -1

proc forNSWindow(windows: seq[Window], inner: NSWindow): Window =
  ## Returns the window for this window handle, else nil
  let index = windows.indexForNSWindow(inner)
  if index == -1:
    return nil
  windows[index]

proc visible*(window: Window): bool =
  window.inner.isVisible

proc style*(window: Window): WindowStyle =
  let styleMask = window.inner.styleMask
  if (styleMask and NSWindowStyleMaskTitled) != 0:
    if (styleMask and NSWindowStyleMaskResizable) != 0:
      DecoratedResizable
    else:
      Decorated
  else:
    var opaque: GLint
    window.inner.contentView.NSOpenGLView.openGLContext.getValues(
      opaque.addr,
      NSOpenGLContextParameterSurfaceOpacity
    )
    if opaque == 0:
      Transparent
    else:
      Undecorated

proc fullscreen*(window: Window): bool =
  (window.inner.styleMask and NSWindowStyleMaskFullScreen) != 0

proc floating*(window: Window): bool =
  window.inner.level == NSFloatingWindowLevel

proc contentScale*(window: Window): float32 =
  autoreleasepool:
    let
      contentView = window.inner.contentView
      frame = contentView.frame
      backing = contentView.convertRectToBacking(frame)
    result = backing.size.width / frame.size.width

proc size*(window: Window): IVec2 =
  autoreleasepool:
    let
      contentView = window.inner.contentView
      frame = contentView.frame
      backing = contentView.convertRectToBacking(frame)
    result = ivec2(backing.size.width.int32, backing.size.height.int32)

proc pos*(window: Window): IVec2 =
  autoreleasepool:
    let
      windowFrame = window.inner.frame
      screenFrame = window.inner.screen.frame
    result = vec2(
      windowFrame.origin.x,
      screenFrame.size.height - windowFrame.origin.y - windowFrame.size.height - 1
    ).ivec2

proc minimized*(window: Window): bool =
  window.inner.isMiniaturized

proc maximized*(window: Window): bool =
  window.inner.isZoomed

proc focused*(window: Window): bool =
  window.inner.isKeyWindow

proc closeIme*(window: Window) =
  if not window.focused:
    return

  if window.markedText.int != 0:
    window.inner.contentView.NSTextInputClient.insertText(
      window.markedText.ID,
      kEmptyRange
    )

  let inputContext = window.inner.contentView.inputContext
  inputContext.discardMarkedText()

  # This should not be required but without this the Pinyin IME candidate
  # window will not close.
  inputContext.deactivate()
  inputContext.activate()

proc `title=`*(window: Window, title: string) =
  autoreleasepool:
    window.state.title = title
    window.inner.setTitle(@title)

proc `icon=`*(window: Window, icon: Image) =
  window.state.icon = icon

proc `visible=`*(window: Window, visible: bool) =
  autoreleasepool:
    if visible:
      window.inner.makeKeyAndOrderFront(0.ID)
    else:
      window.inner.orderOut(0.ID)

proc `style=`*(window: Window, windowStyle: WindowStyle) =
  autoreleasepool:
    case windowStyle:
    of DecoratedResizable:
      window.inner.setStyleMask(decoratedResizableWindowMask)
    of Decorated:
      window.inner.setStyleMask(decoratedWindowMask)
    of Undecorated, Transparent:
      window.inner.setStyleMask(undecoratedWindowMask)

    var opaque: GLint = if windowStyle == Transparent: 0 else: 1
    autoreleasepool:
      window.inner.contentView.NSOpenGLView.openGLContext.setValues(
        opaque.addr,
        NSOpenGLContextParameterSurfaceOpacity
      )

proc `fullscreen=`*(window: Window, fullscreen: bool) =
  if window.fullscreen == fullscreen:
    return
  autoreleasepool:
    window.inner.toggleFullscreen(0.ID)

proc `floating=`*(window: Window, floating: bool) =
  if window.floating == floating:
    return
  autoreleasepool:
    let level =
      if floating:
        NSFloatingWindowLevel
      else:
        NSNormalWindowLevel
    window.inner.setLevel(level)

proc `size=`*(window: Window, size: IVec2) =
  autoreleasepool:
    let virtualSize = (size.vec2 / window.contentScale)

    var contentRect = window.inner.contentRectForFrameRect(window.inner.frame)
    contentRect.origin.y += contentRect.size.height - virtualSize.y
    contentRect.size = NSMakeSize(virtualSize.x, virtualSize.y)

    let frameRect = window.inner.frameRectForContentRect(contentRect)
    window.inner.setFrame(frameRect, true)

proc `pos=`*(window: Window, pos: IVec2) =
  autoreleasepool:
    let
      windowFrame = window.inner.frame
      screenFrame = window.inner.screen.frame
      newOrigin = NSPoint(
        x: pos.x.float64,
        y: screenFrame.size.height - windowFrame.size.height - pos.y.float64 - 1
      )
    window.inner.setFrameOrigin(newOrigin)

proc `minimized=`*(window: Window, minimized: bool) =
  autoreleasepool:
    if minimized and not window.minimized:
      window.inner.miniaturize(0.ID)
    elif not minimized and window.minimized:
      window.inner.deminiaturize(0.ID)

proc `maximized=`*(window: Window, maximized: bool) =
  if window.maximized == maximized:
    return
  autoreleasepool:
    window.inner.zoom(0.ID)

proc `closeRequested=`*(window: Window, closeRequested: bool) =
  window.state.closeRequested = closeRequested
  if closeRequested:
    if window.onCloseRequest != nil:
      window.onCloseRequest()

proc `runeInputEnabled=`*(window: Window, runeInputEnabled: bool) =
  window.state.runeInputEnabled = runeInputEnabled
  if not runeInputEnabled:
    window.closeIme()

proc `cursor=`*(window: Window, cursor: Cursor) =
  window.state.cursor = cursor
  autoreleasepool:
    window.inner.invalidateCursorRectsForView(window.inner.contentView)

proc handleMouseMove(window: Window, location: NSPoint) =
  let
    x = round(location.x)
    y = round(window.inner.contentView.bounds.size.height - location.y)

  window.state.mousePrevPos = window.state.mousePos
  window.state.mousePos = (vec2(x, y) * window.contentScale).ivec2
  window.state.perFrame.mouseDelta +=
    window.state.mousePos - window.state.mousePrevPos

  if window.onMouseMove != nil:
    window.onMouseMove()

proc handleButtonPress(window: Window, button: Button) =
  handleButtonPressTemplate()

proc handleButtonRelease(window: Window, button: Button) =
  handleButtonReleaseTemplate()

proc handleRune(window: Window, rune: Rune) =
  handleRuneTemplate()

proc createMenuBar() =
  let
    menuBar = NSMenu.new()
    appMenuItem = NSMenuItem.new()
  menuBar.addItem(appMenuItem)
  NSApp.setMainMenu(menuBar)

  let
    appMenu = NSMenu.new()
    processName = NSProcessInfo.processinfo.processName
    quitTitle = @("Quit " & $processName)
    quitMenuitem = NSMenuItem.alloc().initWithTitle(
      quitTitle,
      s"terminate:",
      @"q"
    )
  appMenu.addItem(quitMenuItem)
  appMenuItem.setSubmenu(appMenu)

proc applicationWillFinishLaunching(
  self: ID,
  cmd: SEL,
  notification: NSNotification
): ID {.cdecl.} =
  createMenuBar()

proc applicationDidFinishLaunching(
  self: ID,
  cmd: SEL,
  notification: NSNotification
): ID {.cdecl.} =
  NSApp.setPresentationOptions(NSApplicationPresentationDefault)
  NSApp.setActivationPolicy(NSApplicationActivationPolicyRegular)
  NSApp.activateIgnoringOtherApps(true)

proc windowDidResize(
  self: ID,
  cmd: SEL,
  notification: NSNotification
): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSWindow)
  if window == nil:
    return
  if window.onResize != nil:
    window.onResize()
  if window.onFrame != nil:
    window.onFrame()

proc windowDidMove(
  self: ID,
  cmd: SEL,
  notification: NSNotification
): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSWindow)
  if window != nil and window.onMove != nil:
    window.onMove()

proc canBecomeKeyWindow(
  self: ID,
  cmd: SEL,
  notification: NSNotification
): bool {.cdecl.} =
  true

proc windowDidBecomeKey(
  self: ID,
  cmd: SEL,
  notification: NSNotification
): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSWindow)
  if window == nil:
    return
  if window.onFocusChange != nil:
    window.onFocusChange()
  handleMouseMove(window, window.inner.mouseLocationOutsideOfEventStream)

proc windowDidResignKey(
  self: ID,
  cmd: SEL,
  notification: NSNotification
): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSWindow)
  if window != nil and window.onFocusChange != nil:
    window.onFocusChange()

proc windowShouldClose(
  self: ID,
  cmd: SEL,
  notification: NSNotification
): bool {.cdecl.} =
  let window = windows.forNSWindow(self.NSWindow)
  if window == nil:
    return
  window.closeRequested = true
  false

proc acceptsFirstResponder(self: ID, cmd: SEL): bool {.cdecl.} =
  true

proc canBecomeKeyView(self: ID, cmd: SEL): bool {.cdecl.} =
  true

proc acceptsFirstMouse(self: ID, cmd: SEL, event: NSEvent): bool {.cdecl.} =
  true

proc viewDidChangeBackingProperties(self: ID, cmd: SEL): ID {.cdecl.} =
  callSuper(self, cmd)

  let window = windows.forNSWindow(self.NSview.window)
  if window == nil:
    return
  if window.onResize != nil:
    window.onResize()
  if window.onFrame != nil:
    window.onFrame()

proc updateTrackingAreas(self: ID, cmd: SEL): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window == nil:
    return

  if window.trackingArea.int != 0:
    self.NSView.removeTrackingArea(window.trackingArea)
    window.trackingArea.ID.release()
    window.trackingArea = 0.NSTrackingArea

  let options =
    NSTrackingMouseEnteredAndExited or
    NSTrackingMouseMoved or
    NSTrackingActiveInKeyWindow or
    NSTrackingCursorUpdate or
    NSTrackingInVisibleRect or
    NSTrackingAssumeInside

  window.trackingArea = NSTrackingArea.alloc().initWithRect(
    NSMakeRect(0, 0, 0, 0),
    options,
    self,
    0.ID
  )

  self.NSView.addTrackingArea(window.trackingArea)

  callSuper(self, cmd)

proc mouseMoved(self: ID, cmd: SEL, event: NSEvent): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window == nil:
    return
  handleMouseMove(window, event.locationInWindow)

proc mouseDragged(self: ID, cmd: SEL, event: NSEvent): ID {.cdecl.} =
  mouseMoved(self, cmd, event)

proc rightMouseDragged(
  self: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  mouseMoved(self, cmd, event)

proc otherMouseDragged(
  self: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  mouseMoved(self, cmd, event)

proc scrollWheel(self: ID, cmd: SEL, event: NSEvent): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window == nil:
    return

  var
    deltaX = event.scrollingDeltaX
    deltaY = event.scrollingDeltaY

  if event.hasPreciseScrollingDeltas:
    deltaX *= 0.1
    deltaY *= 0.1

  if abs(deltaX) > 0 or abs(deltaY) > 0:
    window.state.perFrame.scrollDelta += vec2(deltaX, deltaY)
    if window.onScroll != nil:
      window.onScroll()

proc mouseDown(self: ID, cmd: SEL, event: NSEvent): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window == nil:
    return
  window.handleButtonPress(MouseLeft)

proc mouseUp(self: ID, cmd: SEL, event: NSEvent): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window == nil:
    return
  window.handleButtonRelease(MouseLeft)

proc rightMouseDown(self: ID, cmd: SEL, event: NSEvent): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window == nil:
    return
  window.handleButtonPress(MouseRight)

proc rightMouseUp(self: ID, cmd: SEL, event: NSEvent): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window == nil:
    return
  window.handleButtonRelease(MouseRight)

proc otherMouseDown(self: ID, cmd: SEL, event: NSEvent): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window == nil:
    return

  case event.buttonNumber:
  of 2:
    window.handleButtonPress(MouseMiddle)
  of 3:
    window.handleButtonPress(MouseButton4)
  of 4:
    window.handleButtonPress(MouseButton5)
  else:
    discard

proc otherMouseUp(self: ID, cmd: SEL, event: NSEvent): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window == nil:
    return

  case event.buttonNumber:
  of 2:
    window.handleButtonRelease(MouseMiddle)
  of 3:
    window.handleButtonRelease(MouseButton4)
  of 4:
    window.handleButtonRelease(MouseButton5)
  else:
    discard


proc hasMarkedText(self: ID, cmd: SEL): bool {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window != nil and window.markedText.int != 0:
    true
  else:
    false

proc markedRange(self: ID, cmd: SEL): NSRange {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window != nil and window.markedText.int != 0:
    result = NSMakeRange(0, window.markedText.length)
  else:
    result = kEmptyRange

proc selectedRange(self: ID, cmd: SEL): NSRange {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window != nil:
    NSMakeRange(window.state.imeCursorIndex.uint, 0)
  else:
    kEmptyRange

proc setMarkedText(
  self: ID,
  cmd: SEL,
  obj: ID,
  selectedRange: NSRange,
  replacementRange: NSRange
): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window == nil:
    return

  var characters: NSString
  if obj.NSObject.isKindOfClass(NSAttributedString.getClass()):
    characters = obj.NSAttributedString.string()
  else:
    characters = obj.NSString

  if window.markedText.int != 0:
    window.markedText.ID.release()

  window.markedText = NSString.stringWithString(characters)
  window.markedText.ID.retain()
  window.state.imeCompositionString = $characters
  window.state.imeCursorIndex = selectedRange.location.int

  if window.onImeChange != nil:
    window.onImeChange()

proc unmarkText(self: ID, cmd: SEL): ID {.cdecl.} =
  # Should accept / commit the marked text, but I cannot get this called to test.
  discard

proc validAttributesForMarkedText(self: ID, cmd: SEL): NSArray {.cdecl.} =
  NSArray.array

proc attributedSubstringForProposedRange(
  self: ID,
  cmd: SEL,
  range: NSRange,
  actualRange: NSRangePointer
): NSAttributedString =
  discard

proc insertText2(
  self: ID,
  cmd: SEL,
  obj: ID,
  replacementRange: NSRange
): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window == nil:
    return

  var characters: NSString
  if obj.NSObject.isKindOfClass(NSAttributedString.getClass()):
    characters = obj.NSAttributedString.string()
  else:
    characters = obj.NSString

  var range = NSMakeRange(0, characters.length.uint)
  while range.length > 0:
    var
      codepoint: uint32
      usedLength: uint
    discard characters.getBytes(
      codepoint.addr,
      sizeof(codepoint).uint,
      usedLength.addr,
      NSUTF32StringEncoding,
      0.NSStringEncodingConversionOptions,
      range,
      range.addr
    )
    if codepoint >= 0xf700 and codepoint <= 0xf7ff:
      continue
    window.handleRune(Rune(codepoint))

  if window.markedText.int != 0:
    window.markedText.ID.release()
    window.markedText = 0.NSString

  if window.state.imeCompositionString.len > 0:
    window.state.imeCompositionString = ""
    window.state.imeCursorIndex = 0
    if window.onImeChange != nil:
      window.onImeChange()

proc characterIndexForPoint(
  self: ID,
  cmd: SEL,
  point: NSPoint
): uint {.cdecl.} =
  cast[uint](NSNotFound)

proc firstRectForCharacterRange(
  self: ID,
  cmd: SEL,
  range: NSRange,
  actualRange: NSRangePointer
): NSRect {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window == nil:
    return

  let contentRect = window.inner.contentRectForFrameRect(window.inner.frame)
  NSMakeRect(
    contentRect.origin.x + window.imePos.x.float,
    contentRect.origin.y + contentRect.size.height - 1 - window.imePos.y.float,
    0,
    0
  )

proc doCommandBySelector(self: ID, cmd: SEL, selector: SEL): ID {.cdecl.} =
  discard

proc resetCursorRects(self: ID, cmd: SEL): ID {.cdecl.} =
  let window = windows.forNSWindow(self.NSView.window)
  if window == nil:
    return

  case window.state.cursor.kind:
  of DefaultCursor:
    discard
  else:
    let
      encodedPng = window.state.cursor.image.encodePng()
      image = NSImage.alloc().initWithData(NSData.dataWithBytes(
        encodedPng[0].unsafeAddr,
        encodedPng.len
      ))
      hotspot = NSMakePoint(
        window.state.cursor.hotspot.x.float,
        window.state.cursor.hotspot.y.float
      )
      cursor = NSCursor.alloc().initWithImage(image, hotspot)
    self.NSView.addCursorRect(self.NSView.bounds, cursor)

proc init() {.raises: [].} =
  if initialized:
    return

  autoreleasepool:
    discard NSApplication.sharedApplication()

    addClass "WindyAppDelegate", "NSObject", WindyAppDelegate:
      addMethod "applicationWillFinishLaunching:", applicationWillFinishLaunching
      addMethod "applicationDidFinishLaunching:", applicationDidFinishLaunching

    addClass "WindyWindow", "NSWindow", WindyWindow:
      addMethod "windowDidResize:", windowDidResize
      addMethod "windowDidMove:", windowDidMove
      addMethod "canBecomeKeyWindow:", canBecomeKeyWindow
      addMethod "windowDidBecomeKey:", windowDidBecomeKey
      addMethod "windowDidResignKey:", windowDidResignKey
      addMethod "windowShouldClose:", windowShouldClose

    addClass "WindyView", "NSOpenGLView", WindyView:
      addProtocol "NSTextInputClient"
      addMethod "acceptsFirstResponder", acceptsFirstResponder
      addMethod "canBecomeKeyView", canBecomeKeyView
      addMethod "acceptsFirstMouse:", acceptsFirstMouse
      addMethod "viewDidChangeBackingProperties", viewDidChangeBackingProperties
      addMethod "updateTrackingAreas", updateTrackingAreas
      addMethod "mouseMoved:", mouseMoved
      addMethod "mouseDragged:", mouseDragged
      addMethod "rightMouseDragged:", rightMouseDragged
      addMethod "otherMouseDragged:", otherMouseDragged
      addMethod "scrollWheel:", scrollWheel
      addMethod "mouseDown:", mouseDown
      addMethod "mouseUp:", mouseUp
      addMethod "rightMouseDown:", rightMouseDown
      addMethod "rightMouseUp:", rightMouseUp
      addMethod "otherMouseDown:", otherMouseDown
      addMethod "otherMouseUp:", otherMouseUp
      addMethod "hasMarkedText", hasMarkedText
      addMethod "markedRange", markedRange
      addMethod "selectedRange", selectedRange
      addMethod "setMarkedText:selectedRange:replacementRange:", setMarkedText
      addMethod "unmarkText", unmarkText
      addMethod "validAttributesForMarkedText", validAttributesForMarkedText
      addMethod "attributedSubstringForProposedRange:actualRange:", attributedSubstringForProposedRange
      addMethod "insertText:replacementRange:", insertText2
      addMethod "characterIndexForPoint:", characterIndexForPoint
      addMethod "firstRectForCharacterRange:actualRange:", firstRectForCharacterRange
      addMethod "doCommandBySelector:", doCommandBySelector
      addMethod "resetCursorRects", resetCursorRects

    let appDelegate = WindyAppDelegate.new()
    NSApp.setDelegate(appDelegate)

    NSApp.finishLaunching()

    platformDoubleClickInterval = NSEvent.doubleClickInterval

  initialized = true

proc processKeyDown(event: NSEvent) =
  let nsWindow = event.window()
  let window = windows.forNSWindow(nsWindow)
  if window == nil:
    return

  window.handleButtonPress(keyCodeToButton[event.keyCode.int])
  if window.state.runeInputEnabled:
    discard nsWindow.contentView().inputContext.handleEvent(event)

proc processKeyUp(event: NSEvent) =
  let window = windows.forNSWindow(event.window())
  if window == nil:
    return
  window.handleButtonRelease(keyCodeToButton[event.keyCode.int])

proc processFlagsChanged(event: NSEvent) =
  let window = windows.forNSWindow(event.window())
  if window == nil:
    return

  let button = keyCodeToButton[event.keyCode]
  if button in window.state.buttonDown:
    window.handleButtonRelease(button)
  else:
    window.handleButtonPress(button)

proc pollEvents*() =
  # Draw first (in case a message closes a window or similar)
  for window in windows:
    if window.onFrame != nil:
      window.onFrame()

  # Clear all per-frame data
  for window in windows:
    window.state.perFrame = PerFrame()

  autoreleasepool:
    while true:
      let event = NSApp.nextEventMatchingMask(
        NSEventMaskAny,
        NSDate.distantPast,
        NSDefaultRunLoopMode,
        true
      )
      if event.int == 0:
        break

      # NSApplication misses keyUp events when command, alt, meta, etc.
      # are held down. So we use the event polling approach. See:
      # - https://stackoverflow.com/questions/24099063/how-do-i-detect-keyup-in-my-nsview-with-the-command-key-held
      # - https://lists.apple.com/archives/cocoa-dev/2003/Oct/msg00442.html
      # - https://github.com/andlabs/ui/blob/bc848f5c4078b999dbe6ef1cd90e16290a0d1c3a/delegateuitask_darwin.m#L46
      if event.`type`() == NSEventTypeKeyDown:
        processKeyDown(event)
      elif event.`type`() == NSEventTypeKeyUp:
        processKeyUp(event)
      elif event.`type`() == NSEventTypeFlagsChanged:
        processFlagsChanged(event)

      # Forward event for app to handle.
      NSApp.sendEvent(event)

  when defined(windyUseStdHttp):
    pollHttp()

proc centerWindow(window: Window) =
  ## Calculate centered position for a window on the primary screen.
  let
    screenFrame = window.inner.screen.frame
    screenWidth = screenFrame.size.width.int
    screenHeight = screenFrame.size.height.int
    # Calculate center position.
    x = screenFrame.origin.x.int + (screenWidth - window.size.x) div 2
    y = screenFrame.origin.y.int + (screenHeight - window.size.y) div 2
  window.pos = ivec2(x.int32, y.int32)

proc makeContextCurrent*(window: Window) =
  window.inner.contentView.NSOpenGLView.openGLContext.makeCurrentContext()

proc swapBuffers*(window: Window) =
  window.inner.contentView.NSOpenGLView.openGLContext.flushBuffer()

proc close*(window: Window) =
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
  window.onImeChange = nil

  if window.inner.int != 0:
    autoreleasepool:
      window.inner.close()

    let index = windows.indexForNSWindow(window.inner)
    if index != -1:
      windows.delete(index)
    window.inner = 0.NSWindow

  window.state.closed = true

proc newWindow*(
  title: string,
  size: IVec2,
  style = DecoratedResizable,
  visible = true,
  vsync = true,
  openglVersion = OpenGL4Dot1,
  msaa = msaaDisabled,
  depthBits = 24,
  stencilBits = 8
): Window =
  result = Window()

  init()

  let openGlProfile: uint32 = case openglVersion:
    of OpenGL4Dot1:
      NSOpenGLProfileVersion4_1Core
    else:
      raise newException(WindyError, "Unsupported OpenGL version")


  autoreleasepool:
    result.inner = WindyWindow.alloc().NSWindow.initWithContentRect(
      NSMakeRect(0, 0, 400, 400),
      decoratedResizableWindowMask,
      NSBackingStoreBuffered,
      false
    )

    let
      pixelFormatAttribs = [
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFASampleBuffers, if msaa != msaaDisabled: 1 else: 0,
        NSOpenGLPFASamples, msaa.uint32,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADepthSize, depthBits.uint32,
        NSOpenGLPFAStencilSize, stencilBits.uint32,
        NSOpenGLPFAOpenGLProfile, openGlProfile,
        0
      ]
      pixelFormat = NSOpenGLPixelFormat.alloc().initWithAttributes(
        pixelFormatAttribs[0].unsafeAddr
      )

    let openglView = WindyView.alloc().NSOpenGLView.initWithFrame(
      result.inner.contentView.frame,
      pixelFormat
    )
    openglView.setWantsBestResolutionOpenGLSurface(true)

    openglView.openGLContext.makeCurrentContext()

    var swapInterval: GLint = if vsync: 1 else: 0
    openglView.openGLContext.setValues(
      swapInterval.addr,
      NSOpenGLContextParameterSwapInterval
    )

    # Handle transparency for Transparent style
    if style == Transparent:
      var opaque: GLint = 0
      openglView.openGLContext.setValues(
        opaque.addr,
        NSOpenGLContextParameterSurfaceOpacity
      )

    result.inner.setDelegate(result.inner.ID)
    result.inner.setContentView(openglView.NSView)
    discard result.inner.makeFirstResponder(openglView.NSView)
    result.inner.setRestorable(false)

    windows.add(result)

    result.title = title
    result.size = size

    # Center window on screen by default (macOS standard behavior).
    result.centerWindow()

    result.style = style
    result.visible = visible

  pollEvents() # This can cause lots of issues, potential workaround needed

proc title*(window: Window): string =
  window.state.title

proc icon*(window: Window): Image =
  window.state.icon

proc mousePos*(window: Window): IVec2 =
  window.state.mousePos

proc mousePrevPos*(window: Window): IVec2 =
  window.state.mousePrevPos

proc mouseDelta*(window: Window): IVec2 =
  window.state.perFrame.mouseDelta

proc scrollDelta*(window: Window): Vec2 =
  window.state.perFrame.scrollDelta * 10

proc runeInputEnabled*(window: Window): bool =
  window.state.runeInputEnabled

proc cursor*(window: Window): Cursor =
  window.state.cursor

proc imeCursorIndex*(window: Window): int =
  window.state.imeCursorIndex

proc imeCompositionString*(window: Window): string =
  window.state.imeCompositionString

proc closeRequested*(window: Window): bool =
  window.state.closeRequested

proc closed*(window: Window): bool =
  window.state.closed

proc buttonDown*(window: Window): ButtonView =
  window.state.buttonDown.ButtonView

proc buttonPressed*(window: Window): ButtonView =
  window.state.perFrame.buttonPressed.ButtonView

proc buttonReleased*(window: Window): ButtonView =
  window.state.perFrame.buttonReleased.ButtonView

proc buttonToggle*(window: Window): ButtonView =
  window.state.buttonToggle.ButtonView

proc getClipboardContentKinds*(): set[ClipboardContentKind] =
  init()
  autoreleasepool:
    let
      pboard = NSPasteboard.generalPasteboard()
      types = pboard.types

    if types.int == 0:
      return

    if types.containsObject(NSPasteboardTypeString.ID):
      result.incl TextContent
    if types.containsObject(NSPasteboardTypeTIFF.ID):
      result.incl ImageContent

proc getClipboardImage*(): Image =
  init()
  autoreleasepool:
    let
      pboard = NSPasteboard.generalPasteboard()
      types = pboard.types

    if types.int == 0:
      return

    if not types.containsObject(NSPasteboardTypeTIFF.ID):
      return

    let data = pboard.dataForType(NSPasteboardTypeTIFF)
    if data.int == 0:
      return

    let bitmap = NSBitmapImageRep.alloc().initWithData(data)
    if bitmap.int == 0:
      return

    let pngData = bitmap.representationUsingType(
      NSBitmapImageFileTypePNG,
      0.NSDictionary
    )
    if pngData.int == 0:
      return

    try:
      result = decodePng(pngData.bytes, pngData.length.int).convertToImage()
    except:
      return

proc getClipboardString*(): string =
  ## Gets the clipboard content as a string.
  init()
  autoreleasepool:
    let
      pboard = NSPasteboard.generalPasteboard()
      types = pboard.types

    if types.int == 0:
      return

    if not types.containsObject(NSPasteboardTypeString.ID):
      return

    let value = pboard.stringForType(NSPasteboardTypeString)
    if value.int == 0:
      return

    result = $value

proc setClipboardString*(value: string) =
  ## Sets the clipboard content to the given string.
  init()
  autoreleasepool:
    let pboard = NSPasteboard.generalPasteboard
    pboard.clearContents()
    pboard.setString(@value, NSPasteboardTypeString)

proc getScreens*(): seq[Screen] =
  ## Queries and returns the currently connected screens.
  init()
  autoreleasepool:
    let screensArray = NSScreen.screens
    for i in 0 ..< screensArray.count.int:
      let
        screen = screensArray[i].NSScreen
        frame = screen.frame
      result.add Screen(
        left: frame.origin.x.int,
        right: frame.origin.x.int + frame.size.width.int,
        top: frame.origin.y.int,
        bottom: frame.origin.y.int + frame.size.height.int,
        primary: i == 0
      )
