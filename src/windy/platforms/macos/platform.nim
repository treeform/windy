import ../../common, ../../internal, macdefs, opengl, pixie/images,
    pixie/fileformats/png, times, unicode, utils, vmath

type
  Window* = ref object
    onCloseRequest*: Callback
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

    state: State

    inner: NSWindow
    trackingArea: NSTrackingArea

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
    Undecorated

proc fullscreen*(window: Window): bool =
  (window.inner.styleMask and NSWindowStyleMaskFullScreen) != 0

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

proc `title=`*(window: Window, title: string) =
  autoreleasepool:
    window.state.title = title
    window.inner.setTitle(@title)

proc `icon=`*(window: Window, icon: Image) =
  window.state.icon = icon

proc `visible=`*(window: Window, visible: bool) =
  autoreleasepool:
    if visible:
      window.inner.orderFront(0.ID)
    else:
      window.inner.orderOut(0.ID)

proc `style=`*(window: Window, windowStyle: WindowStyle) =
  autoreleasepool:
    case windowStyle:
    of DecoratedResizable:
      window.inner.setStyleMask(decoratedResizableWindowMask)
    of Decorated:
      window.inner.setStyleMask(decoratedWindowMask)
    of Undecorated:
      window.inner.setStyleMask(undecoratedWindowMask)

proc `fullscreen=`*(window: Window, fullscreen: bool) =
  if window.fullscreen == fullscreen:
    return
  window.inner.toggleFullscreen(0.ID)

proc `size=`*(window: Window, size: IVec2) =
  autoreleasepool:
    let virtualSize = (size.vec2 / window.contentScale)

    var contentRect = window.inner.contentRectForFrameRect(window.inner.frame)
    contentRect.origin.y += contentRect.size.height - virtualSize.y
    contentRect.size = NSMakeSize(virtualSize.x, virtualSize.y)

    let frameRect = window.inner.frameRectForContentRect(contentRect)
    window.inner.setFrame(frameRect, YES)

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
  autoreleasepool:
    if maximized and not window.maximized:
      window.inner.zoom(0.ID)
    elif not maximized and window.maximized:
      window.inner.zoom(0.ID)

proc `closeRequested=`*(window: Window, closeRequested: bool) =
  window.state.closeRequested = closeRequested
  if closeRequested:
    if window.onCloseRequest != nil:
      window.onCloseRequest()

proc `runeInputEnabled=`*(window: Window, runeInputEnabled: bool) =
  window.state.runeInputEnabled = runeInputEnabled

proc `cursor=`*(window: Window, cursor: Cursor) =
  window.state.cursor = cursor
  autoreleasepool:
    window.inner.invalidateCursorRectsForView(window.inner.contentView)

proc handleButtonPress(window: Window, button: Button) =
  handleButtonPressTemplate()

proc handleButtonRelease(window: Window, button: Button) =
  handleButtonReleaseTemplate()

proc handleRune(window: Window, rune: Rune) =
  handleRuneTemplate()

proc createMenuBar() =
  let
    menuBar = NSMenu.getClass().new().NSMenu
    appMenuItem = NSMenuItem.getClass().new().NSMenuItem
  menuBar.addItem(appMenuItem)
  NSApp.setMainMenu(menuBar)

  let
    appMenu = NSMenu.getClass().new().NSMenu
    processName = NSProcessInfo.processinfo.processName
    quitTitle = @("Quit " & $processName)
    quitMenuitem = NSMenuItem.getClass().alloc().NSMenuItem
  quitMenuitem.initWithTitle(
    quitTitle,
    sel_registerName("terminate:".cstring),
    @"q"
  )
  appMenu.addItem(quitMenuItem)
  appMenuItem.setSubmenu(appMenu)

proc applicationWillFinishLaunching(
  sender: ID,
  cmd: SEL,
  notification: NSNotification
): ID {.cdecl.} =
  createMenuBar()

proc applicationDidFinishLaunching(
  sender: ID,
  cmd: SEL,
  notification: NSNotification
): ID {.cdecl.} =
  NSApp.setPresentationOptions(NSApplicationPresentationDefault)
  NSApp.setActivationPolicy(NSApplicationActivationPolicyRegular)
  NSApp.activateIgnoringOtherApps(YES)

proc windowDidResize(
  sender: ID,
  cmd: SEL,
  notification: NSNotification
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSWindow)
  if window == nil:
    return
  if window.onResize != nil:
    window.onResize()

proc windowDidMove(
  sender: ID,
  cmd: SEL,
  notification: NSNotification
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSWindow)
  if window == nil:
    return
  if window.onMove != nil:
    window.onMove()

proc canBecomeKeyWindow(
  sender: ID,
  cmd: SEL,
  notification: NSNotification
): BOOL {.cdecl.} =
  YES

proc windowDidBecomeKey(
  sender: ID,
  cmd: SEL,
  notification: NSNotification
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSWindow)
  if window == nil:
    return
  if window.onFocusChange != nil:
    window.onFocusChange()

proc windowDidResignKey(
  sender: ID,
  cmd: SEL,
  notification: NSNotification
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSWindow)
  if window == nil:
    return
  if window.onFocusChange != nil:
    window.onFocusChange()

proc windowShouldClose(
  sender: ID,
  cmd: SEL,
  notification: NSNotification
): BOOL {.cdecl.} =
  let window = windows.forNSWindow(sender.NSWindow)
  if window == nil:
    return
  window.closeRequested = true
  NO

proc acceptsFirstResponder(sender: ID, cmd: SEL): BOOL {.cdecl.} =
  YES

proc canBecomeKeyView(sender: ID, cmd: SEL): BOOL {.cdecl.} =
  YES

proc acceptsFirstMouse(sender: ID, cmd: SEL, event: NSEvent): BOOL {.cdecl.} =
  YES

proc viewDidChangeBackingProperties(sender: ID, cmd: SEL): ID {.cdecl.} =
  callSuper(sender, cmd)

  let window = windows.forNSWindow(sender.NSview.window)
  if window == nil:
    return
  if window.onResize != nil:
    window.onResize()

proc updateTrackingAreas(sender: ID, cmd: SEL): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
  if window == nil:
    return

  if window.trackingArea.int != 0:
    sender.NSView.removeTrackingArea(window.trackingArea)
    window.trackingArea.ID.release()
    window.trackingArea = 0.NSTrackingArea

  let options =
    NSTrackingMouseEnteredAndExited or
    NSTrackingMouseMoved or
    NSTrackingActiveInKeyWindow or
    NSTrackingCursorUpdate or
    NSTrackingInVisibleRect or
    NSTrackingAssumeInside

  window.trackingArea = NSTrackingArea.getClass().alloc().NSTrackingArea
  window.trackingArea.initWithRect(
    NSMakeRect(0, 0, 0, 0),
    options,
    sender
  )

  sender.NSView.addTrackingArea(window.trackingArea)

  callSuper(sender, cmd)

proc mouseMoved(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
  if window == nil:
    return

  let
    locationInWindow = event.locationInWindow
    x = round(locationInWindow.x).int32
    y = round(sender.NSView.bounds.size.height - locationInWindow.y).int32

  window.state.mousePrevPos = window.state.mousePos
  window.state.mousePos = ivec2(x, y)
  window.state.perFrame.mouseDelta +=
    window.state.mousePos - window.state.mousePrevPos

  if window.onMouseMove != nil:
    window.onMouseMove()

proc mouseDragged(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  mouseMoved(sender, cmd, event)

proc rightMouseDragged(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  mouseMoved(sender, cmd, event)

proc otherMouseDragged(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  mouseMoved(sender, cmd, event)

proc scrollWheel(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
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

proc mouseDown(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
  if window == nil:
    return
  window.handleButtonPress(MouseLeft)

proc mouseUp(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
  if window == nil:
    return
  window.handleButtonRelease(MouseLeft)

proc rightMouseDown(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
  if window == nil:
    return
  window.handleButtonPress(MouseRight)

proc rightMouseUp(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
  if window == nil:
    return
  window.handleButtonRelease(MouseRight)

proc otherMouseDown(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
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

proc otherMouseUp(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
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

proc keyDown(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
  if window == nil:
    return
  window.handleButtonPress(keyCodeToButton[event.keyCode.int])
  sender.NSResponder.interpretKeyEvents(NSArray.arrayWithObject(event.ID))

proc keyUp(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
  if window == nil:
    return
  window.handleButtonRelease(keyCodeToButton[event.keyCode.int])

proc flagsChanged(
  sender: ID,
  cmd: SEL,
  event: NSEvent
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
  if window == nil:
    return

  let button = keyCodeToButton[event.keyCode]
  if button in window.state.buttonDown:
    window.handleButtonRelease(button)
  else:
    window.handleButtonPress(button)

proc hasMarkedText(sender: ID, cmd: SEL): BOOL {.cdecl.} =
  NO

proc markedRange(sender: ID, cmd: SEL): NSRange {.cdecl.} =
  kEmptyRange

proc selectedRange(sender: ID, cmd: SEL): NSRange {.cdecl.} =
  kEmptyRange

proc setMarkedText(
  sender: ID,
  cmd: SEL,
  s: NSString,
  selectedRange: NSRange,
  replacementRange: NSRange
): ID {.cdecl.} =
  discard

proc unmarkText(sender: ID, cmd: SEL): ID {.cdecl.} =
  discard

proc validAttributesForMarkedText(sender: ID, cmd: SEL): NSArray {.cdecl.} =
  NSArray.array

proc attributedSubstringForProposedRange(
  sender: ID,
  cmd: SEL,
  range: NSRange,
  actualRange: NSRangePointer
): NSAttributedString =
  discard

proc insertText(
  sender: ID,
  cmd: SEL,
  obj: ID,
  replacementRange: NSRange
): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
  if window == nil:
    return

  var characters: NSString
  if obj.NSObject.isKindOfClass(NSAttributedString.getClass()):
    characters = obj.NSAttributedString.str()
  else:
    characters = obj.NSString

  var range = NSMakeRange(0, characters.length.uint)
  while range.length > 0:
    var codepoint: uint
    discard characters.getBytes(
      codepoint.addr,
      sizeof(codepoint).uint,
      0,
      NSUTF32StringEncoding,
      0.NSStringEncodingConversionOptions,
      range,
      range.addr
    )
    if codepoint >= 0xf700 and codepoint <= 0xf7ff:
      continue
    window.handleRune(Rune(codepoint))

proc characterIndexForPoint(
  sender: ID,
  cmd: SEL,
  point: NSPoint
): uint {.cdecl.} =
  0

proc firstRectForCharacterRange(
  sender: ID,
  cmd: SEL,
  range: NSRange,
  actualRange: NSRangePointer
): NSRect {.cdecl.} =
  NSMakeRect(0, 0, 0, 0)

proc doCommandBySelector(sender: ID, cmd: SEL, selector: SEL): ID {.cdecl.} =
  discard

proc resetCursorRects(sender: ID, cmd: SEL): ID {.cdecl.} =
  let window = windows.forNSWindow(sender.NSView.window)
  if window == nil:
    return

  case window.state.cursor.kind:
  of DefaultCursor:
    discard
  else:
    let
      encodedPng = window.state.cursor.image.encodePng()
      image = NSImage.getClass().alloc().NSImage
      cursor = NSCursor.getClass().alloc().NSCursor
      hotspot = NSMakePoint(
        window.state.cursor.hotspot.x.float,
        window.state.cursor.hotspot.y.float
      )
    image.initWithData(NSData.dataWithBytes(
      encodedPng[0].unsafeAddr,
      encodedPng.len
    ))
    cursor.initWithImage(image, hotspot)
    sender.NSView.addCursorRect(sender.NSView.bounds, cursor)

proc init() =
  if initialized:
    return

  autoreleasepool:
    NSApplication.sharedApplication()

    block:
      WindyAppDelegate = objc_allocateClassPair(
        objc_getClass("NSObject".cstring),
        "WindyAppDelegate".cstring
      )
      discard class_addMethod(
        WindyAppDelegate,
        sel_registerName("applicationWillFinishLaunching:".cstring),
        cast[IMP](applicationWillFinishLaunching),
        "".cstring
      )
      discard class_addMethod(
        WindyAppDelegate,
        sel_registerName("applicationDidFinishLaunching:".cstring),
        cast[IMP](applicationDidFinishLaunching),
        "".cstring
      )
      objc_registerClassPair(WindyAppDelegate)

    block:
      WindyWindow = objc_allocateClassPair(
        objc_getClass("NSWindow".cstring),
        "WindyWindow".cstring
      )
      discard class_addMethod(
        WindyWindow,
        sel_registerName("windowDidResize:".cstring),
        cast[IMP](windowDidResize),
        "".cstring
      )
      discard class_addMethod(
        WindyWindow,
        sel_registerName("windowDidMove:".cstring),
        cast[IMP](windowDidMove),
        "".cstring
      )
      discard class_addMethod(
        WindyWindow,
        sel_registerName("canBecomeKeyWindow:".cstring),
        cast[IMP](canBecomeKeyWindow),
        "".cstring
      )
      discard class_addMethod(
        WindyWindow,
        sel_registerName("windowDidBecomeKey:".cstring),
        cast[IMP](windowDidBecomeKey),
        "".cstring
      )
      discard class_addMethod(
        WindyWindow,
        sel_registerName("windowDidResignKey:".cstring),
        cast[IMP](windowDidResignKey),
        "".cstring
      )
      discard class_addMethod(
        WindyWindow,
        sel_registerName("windowShouldClose:".cstring),
        cast[IMP](windowShouldClose),
        "".cstring
      )
      objc_registerClassPair(WindyWindow)

    block:
      WindyView = objc_allocateClassPair(
        objc_getClass("NSOpenGLView".cstring),
        "WindyView".cstring
      )
      discard class_addProtocol(WindyView, objc_getProtocol("NSTextInputClient".cstring))
      discard class_addMethod(
        WindyView,
        sel_registerName("acceptsFirstResponder".cstring),
        cast[IMP](acceptsFirstResponder),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("canBecomeKeyView".cstring),
        cast[IMP](canBecomeKeyView),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("acceptsFirstMouse:".cstring),
        cast[IMP](acceptsFirstMouse),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("viewDidChangeBackingProperties".cstring),
        cast[IMP](viewDidChangeBackingProperties),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("updateTrackingAreas".cstring),
        cast[IMP](updateTrackingAreas),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("mouseMoved:".cstring),
        cast[IMP](mouseMoved),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("mouseDragged:".cstring),
        cast[IMP](mouseDragged),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("rightMouseDragged:".cstring),
        cast[IMP](rightMouseDragged),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("otherMouseDragged:".cstring),
        cast[IMP](otherMouseDragged),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("scrollWheel:".cstring),
        cast[IMP](scrollWheel),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("mouseDown:".cstring),
        cast[IMP](mouseDown),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("mouseUp:".cstring),
        cast[IMP](mouseUp),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("rightMouseDown:".cstring),
        cast[IMP](rightMouseDown),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("rightMouseUp:".cstring),
        cast[IMP](rightMouseUp),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("otherMouseDown:".cstring),
        cast[IMP](otherMouseDown),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("otherMouseUp:".cstring),
        cast[IMP](otherMouseUp),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("keyDown:".cstring),
        cast[IMP](keyDown),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("keyUp:".cstring),
        cast[IMP](keyUp),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("flagsChanged:".cstring),
        cast[IMP](flagsChanged),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("hasMarkedText".cstring),
        cast[IMP](hasMarkedText),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("markedRange".cstring),
        cast[IMP](markedRange),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("selectedRange".cstring),
        cast[IMP](selectedRange),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("setMarkedText:selectedRange:replacementRange:".cstring),
        cast[IMP](setMarkedText),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("unmarkText".cstring),
        cast[IMP](unmarkText),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("validAttributesForMarkedText".cstring),
        cast[IMP](validAttributesForMarkedText),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("attributedSubstringForProposedRange:actualRange:".cstring),
        cast[IMP](attributedSubstringForProposedRange),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("insertText:replacementRange:".cstring),
        cast[IMP](insertText),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("characterIndexForPoint:".cstring),
        cast[IMP](characterIndexForPoint),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("firstRectForCharacterRange:actualRange:".cstring),
        cast[IMP](firstRectForCharacterRange),
        "".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("doCommandBySelector:".cstring),
        cast[IMP](doCommandBySelector),
        ":".cstring
      )
      discard class_addMethod(
        WindyView,
        sel_registerName("resetCursorRects".cstring),
        cast[IMP](resetCursorRects),
        "".cstring
      )
      objc_registerClassPair(WindyView)

    let appDelegate = objc_msgSend(
      WindyAppDelegate.ID,
      sel_registerName("new".cstring)
    )
    NSApp.setDelegate(appDelegate)

    NSApp.finishLaunching()

    platformDoubleClickInterval = NSEvent.doubleClickInterval
    initialized = true

proc pollEvents*() =
  # Clear all per-frame data
  for window in windows:
    window.state.perFrame = PerFrame()

  autoreleasepool:
    while true:
      let event = NSApp.nextEventMatchingMask(
        NSEventMaskAny,
        NSDate.distantPast,
        NSDefaultRunLoopMode,
        YES
      )
      if event.int == 0:
        break
      NSApp.sendEvent(event)

proc makeContextCurrent*(window: Window) =
  window.inner.contentView.NSOpenGLView.openGLContext.makeCurrentContext()

proc swapBuffers*(window: Window) =
  window.inner.contentView.NSOpenGLView.openGLContext.flushBuffer()

proc close*(window: Window) =
  window.onCloseRequest = nil
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

proc closeIme*(window: Window) =
  discard

proc newWindow*(
  title: string,
  size: IVec2,
  visible = true,
  vsync = true,
  openglMajorVersion = 4,
  openglMinorVersion = 1,
  msaa = msaaDisabled,
  depthBits = 24,
  stencilBits = 8
): Window =
  result = Window()

  autoreleasepool:
    init()

    result.inner = WindyWindow.alloc().NSWindow
    result.inner.initWithContentRect(
      NSMakeRect(0, 0, 400, 400),
      decoratedResizableWindowMask,
      NSBackingStoreBuffered,
      NO
    )

    let
      pixelFormat = NSOpenGLPixelFormat.getClass().alloc().NSOpenGLPixelFormat
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
        NSOpenGLPFAOpenGLProfile, (
          case openglMajorVersion:
          of 4:
            NSOpenGLProfileVersion4_1Core
          of 3:
            NSOpenGLProfileVersion3_2Core
          else:
            NSOpenGLProfileVersionLegacy
        ),
        0
      ]
    pixelFormat.initWithAttributes(pixelFormatAttribs[0].unsafeAddr)

    let openglView = WindyView.alloc().NSOpenGLView
    openglView.initWithFrame(
      result.inner.contentView.frame,
      pixelFormat
    )
    openglView.setWantsBestResolutionOpenGLSurface(YES)

    openglView.openGLContext.makeCurrentContext()

    var swapInterval: GLint = if vsync: 1 else: 0
    openglView.openGLContext.setValues(
      swapInterval.addr,
      NSOpenGLContextParameterSwapInterval
    )

    result.inner.setDelegate(result.inner.ID)
    result.inner.setContentView(openglView.NSView)
    discard result.inner.makeFirstResponder(openglView.NSView)
    result.inner.setRestorable(NO)

    windows.add(result)

    result.title = title
    result.size = size
    result.pos = ivec2(0, 0)
    result.visible = visible

  pollEvents()

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
  window.state.perFrame.scrollDelta

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

proc getClipboardString*(): string =
  autoreleasepool:
    let
      pboard = NSPasteboard.generalPasteboard
      types = pboard.types

    if not pboard.types.containsObject(NSPasteboardTypeString.ID):
      return

    let value = pboard.stringForType(NSPasteboardTypeString)
    if value.int == 0:
      return

    result = $value

proc setClipboardString*(value: string) =
  autoreleasepool:
    let pboard = NSPasteboard.generalPasteboard
    pboard.clearContents()
    pboard.setString(@value, NSPasteboardTypeString)

proc getScreens*(): seq[Screen] =
  ## Queries and returns the currently connected screens.
  autoreleasepool:
    let screensArray = NSScreen.screens
    for i in 0 ..< screensArray.count:
      let
        screen = screensArray[i].NSScreen
        frame = screen.frame
      result.add(Screen(
        left: frame.origin.x.int,
        right: frame.origin.x.int + frame.size.width.int,
        top: frame.origin.y.int,
        bottom: frame.origin.y.int + frame.size.height.int,
        primary: i == 0
      ))
