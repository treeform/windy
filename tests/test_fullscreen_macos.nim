when defined(macosx):
  from pixie import rect

  include ../src/windy/platforms/macos/platform

  type NativeWindowState = object
    frame: NSRect
    style: NSWindowStyleMask
    level: NSWindowLevel
    collection: uint
    movable, shadow, hides, mouseMoved: bool

  objc:
    proc title(self: NSWindow): NSString
      ## Reads the native title after restoring window decorations.

  proc nativeState(window: Window): NativeWindowState =
    ## Records native window properties that fullscreen must preserve.
    let native = window.inner
    NativeWindowState(
      frame: native.frame,
      style: native.styleMask,
      level: native.level,
      collection: native.collectionBehavior,
      movable: native.isMovable,
      shadow: native.hasShadow,
      hides: native.hidesOnDeactivate,
      mouseMoved: native.acceptsMouseMovedEvents
    )

  proc testFullscreenRestoration() =
    ## Checks synchronous fullscreen and exact restoration of native state.
    for style in [DecoratedResizable, Decorated, Undecorated]:
      for customFlags in [false, true]:
        let window = newWindow(
          "Hidden fullscreen restoration",
          ivec2(360, 240),
          style = style,
          visible = false
        )
        defer:
          window.close()
        if customFlags:
          window.inner.setLevel(NSFloatingWindowLevel)
          window.inner.setMovable(false)
          window.inner.setHasShadow(false)
          window.inner.setHidesOnDeactivate(true)
          window.inner.setAcceptsMouseMovedEvents(true)
        let
          saved = window.nativeState()
          nativeClass = object_getClass(window.inner.ID).int
          presentation = NSApp.presentationOptions
        for i in 0 ..< 3:
          window.fullscreen = true
          doAssert window.fullscreen
          doAssert not window.visible
          doAssert window.inner.frame == window.inner.screen.frame
          doAssert (window.inner.styleMask and
            (NSWindowStyleMaskTitled or NSWindowStyleMaskResizable or
            NSWindowStyleMaskFullScreen)) == 0
          doAssert window.inner.hidesOnDeactivate
          doAssert not window.inner.isMovable
          doAssert not window.inner.hasShadow
          doAssert window.inner.acceptsMouseMovedEvents
          doAssert window.inner.level == saved.level
          doAssert object_getClass(window.inner.ID).int == nativeClass
          doAssert NSApp.presentationOptions == presentation
          doAssert not fullscreenPresentationActive
          window.fullscreen = true
          window.fullscreen = false
          doAssert not window.fullscreen
          doAssert window.nativeState() == saved
          doAssert object_getClass(window.inner.ID).int == nativeClass
          doAssert not window.visible
          doAssert NSApp.presentationOptions == presentation
          window.fullscreen = false
          doAssert window.nativeState() == saved

  proc testIndependentFullscreens() =
    ## Checks that closing one fullscreen leaves another window's state intact.
    let
      first = newWindow("Hidden first", ivec2(310, 210), visible = false)
      second = newWindow("Hidden second", ivec2(420, 280), visible = false)
      secondSaved = second.nativeState()
      presentation = NSApp.presentationOptions
    defer:
      first.close()
      second.close()
    first.fullscreen = true
    doAssert first.fullscreen and not second.fullscreen
    second.fullscreen = true
    first.fullscreen = false
    doAssert not first.fullscreen and second.fullscreen
    first.fullscreen = true
    first.close()
    doAssert first.closed and first.inner.int == 0
    doAssert second.fullscreen and not second.closed
    doAssert NSApp.presentationOptions == presentation
    second.fullscreen = false
    doAssert second.nativeState() == secondSaved
    doAssert NSApp.presentationOptions == presentation

  proc testFullscreenSetters() =
    ## Checks that windowed geometry survives setters during fullscreen.
    let window = newWindow("Original title", ivec2(360, 240), visible = false)
    defer:
      window.close()
    let saved = window.nativeState()
    window.fullscreen = true
    let covered = window.nativeState()
    window.size = ivec2(100, 100)
    window.pos = ivec2(10, 20)
    window.style = Decorated
    doAssert window.nativeState() == covered
    window.title = "Title changed during fullscreen"
    window.fullscreen = false
    doAssert window.nativeState() == saved
    doAssert $window.inner.title == "Title changed during fullscreen"

  proc testPresentationRestoration() =
    ## Checks fullscreen restores only presentation options that it owns.
    const
      ExistingOption = 1'u shl 5
      NewOption = 1'u shl 6
      SavedBars = (1'u shl 0) or (1'u shl 2)
      Saved = SavedBars or ExistingOption
      Applied = PresentationHiddenBars or ExistingOption
    doAssert restoredFullscreenPresentation(
      Saved, Applied, Applied or NewOption
    ) == (Saved or NewOption)
    doAssert restoredFullscreenPresentation(
      Saved, Applied, Applied and not ExistingOption
    ) == SavedBars
    let changedBars = SavedBars or ExistingOption or NewOption
    doAssert restoredFullscreenPresentation(
      Saved, Applied, changedBars
    ) == changedBars

  proc testFullscreenCallbackClose() =
    ## Checks both transition directions when native callbacks close a window.
    for closingOnResize in [false, true]:
      for entering in [false, true]:
        let window = newWindow(
          "Hidden callback close",
          ivec2(320, 220),
          visible = false
        )
        defer:
          window.close()
        if not entering:
          window.fullscreen = true
        let
          native = window.inner.ID
          presentation = NSApp.presentationOptions
          expectedFullscreen = bool(entering)
        var callbacks = 0
        let closeInCallback = proc() =
          ## Closes immediately and rejects frame callbacks after disposal.
          inc callbacks
          doAssert window.fullscreen == expectedFullscreen
          window.close()
          window.onFrame = proc() =
            ## Rejects frame callbacks on the now closed window.
            doAssert false, "Fullscreen rendered a closed window"
        if closingOnResize:
          window.onResize = closeInCallback
        else:
          window.onMove = closeInCallback
        # Hidden windows can suppress native move notifications.
        # Queue the delegate event that a visible transition would deliver.
        window.fullscreenChanging = true
        if closingOnResize:
          discard windowDidResize(
            native, s"windowDidResize:", 0.NSNotification
          )
        else:
          discard windowDidMove(native, s"windowDidMove:", 0.NSNotification)
        window.fullscreenChanging = false
        window.fullscreen = entering
        doAssert callbacks == 1,
          "Callback close failed: resize=" & $closingOnResize &
          ", entering=" & $entering & ", callbacks=" & $callbacks
        doAssert window.closed and window.inner.int == 0
        doAssert not window.confinement.requested
        doAssert not window.mouseConfined
        doAssert NSApp.presentationOptions == presentation
        # Queued notifications must not resolve the disposed native handle.
        discard windowDidResize(native, s"windowDidResize:", 0.NSNotification)
        discard windowDidMove(native, s"windowDidMove:", 0.NSNotification)
        window.fullscreen = not entering
        window.close()

  proc testConfinementCoordinates() =
    ## Checks top-left pixel regions and whole bounds on 1x and Retina displays.
    let
      bounds = NSMakeRect(10, 20, 400, 300)
      normal = NSMakeRect(0, 0, 400, 300)
      retina = NSMakeRect(0, 0, 800, 600)
      region = rect(40, 60, 120, 80)
    doAssert mouseConfinementViewRect(region, false, bounds, normal) ==
      NSMakeRect(50, 180, 120, 80)
    doAssert mouseConfinementViewRect(region, false, bounds, retina) ==
      NSMakeRect(30, 250, 60, 40)
    doAssert mouseConfinementViewRect(
      rect(-20, -10, 100, 80), false, bounds, normal
    ) == NSMakeRect(10, 250, 80, 70)
    doAssert mouseConfinementViewRect(
      rect(390, 290, 100, 100), false, bounds, normal
    ) == NSMakeRect(400, 20, 10, 10)
    let outside = mouseConfinementViewRect(
      rect(401, 0, 20, 20), false, bounds, normal
    )
    doAssert outside.size.width == 0 or outside.size.height == 0
    doAssert mouseConfinementViewRect(region, true, bounds, retina) == bounds
    let
      resized = NSMakeRect(0, 0, 960, 540)
      resizedBacking = NSMakeRect(0, 0, 1920, 1080)
    doAssert mouseConfinementViewRect(
      region, true, resized, resizedBacking
    ) == resized
    doAssert mouseConfinementViewRect(
      region, false, resized, resizedBacking
    ) == NSMakeRect(20, 470, 60, 40)

  proc testStaleConfinementGeometry() =
    ## Checks that moves, resizes, and scale changes invalidate clipping.
    let
      frame = NSMakeRect(100, 200, 400, 300)
      bounds = NSMakeRect(0, 0, 400, 300)
      backing = NSMakeRect(0, 0, 800, 600)
      confinement = MouseConfinement(
        active: true,
        cachedFrame: frame,
        cachedBounds: bounds,
        cachedBacking: backing
      )
    doAssert not confinementGeometryChanged(confinement, frame, bounds, backing)
    doAssert confinementGeometryChanged(
      confinement, NSMakeRect(101, 200, 400, 300), bounds, backing
    )
    doAssert confinementGeometryChanged(
      confinement, NSMakeRect(100, 200, 450, 300), bounds, backing
    )
    doAssert confinementGeometryChanged(
      confinement, frame, NSMakeRect(0, 0, 450, 300), backing
    )
    doAssert confinementGeometryChanged(
      confinement, frame, bounds, NSMakeRect(0, 0, 400, 300)
    )
    doAssert confinementGeometryChanged(
      confinement, frame, NSMakeRect(30, 40, 100, 80), backing
    )
    doAssert confinementFramesMatch(frame, NSMakeRect(100, 200, 400, 300))
    doAssert not confinementFramesMatch(
      frame, NSMakeRect(100, 200, 800, 600)
    )
    doAssert not confinementFramesMatch(frame, NSMakeRect(100, 220, 400, 300))
    doAssert not confinementFramesMatch(frame, NSRect())

  proc testInvalidConfinementRegions() =
    ## Checks that empty and non-finite rectangles cannot reach AppKit.
    doAssert validMouseConfinementRegion(rect(-10, -20, 30, 40))
    for region in [
      rect(0, 0, 0, 10),
      rect(0, 0, 10, 0),
      rect(0, 0, -1, 10),
      rect(0, 0, 10, -1),
      rect(NaN.float32, 0, 10, 10),
      rect(0, Inf.float32, 10, 10),
      rect(0, 0, Inf.float32, 10),
      rect(0, 0, 10, NaN.float32)
    ]:
      doAssert not validMouseConfinementRegion(region)

  proc testHiddenConfinement() =
    ## Checks inactive requests, relative conflicts, and window close cleanup.
    let window = newWindow(
      "Hidden confinement lifecycle",
      ivec2(300, 200),
      visible = false
    )
    defer:
      window.state.mouseCaptured = false
      window.close()
    doAssert not window.mouseConfined
    window.releaseMouseConfinement()
    if not window.mouseConfinementSupported:
      var rejected = false
      try:
        window.confineMouse()
      except WindyError:
        rejected = true
      doAssert rejected
      return
    let
      saved = window.nativeState()
      nativeClass = object_getClass(window.inner.ID).int
    doAssert not window.inner.nativeConfinementGeometryCommitted()
    window.confineMouse()
    pollEvents()
    doAssert window.confinement.requested and window.confinement.fullWindow
    doAssert not window.mouseConfined
    doAssert window.nativeState() == saved
    var rejectedInvalid = false
    try:
      window.confineMouse(rect(0, 0, 0, 20))
    except WindyError:
      rejectedInvalid = true
    doAssert rejectedInvalid
    doAssert window.confinement.requested and window.confinement.fullWindow
    discard windowDidResignKey(
      window.inner.ID, s"windowDidResignKey:", 0.NSNotification
    )
    doAssert window.confinement.requested
    doAssert not window.mouseConfined
    doAssert object_getClass(window.inner.ID).int == nativeClass
    window.confineMouse(rect(30, 40, 100, 80))
    pollEvents()
    doAssert window.confinement.requested and not window.confinement.fullWindow
    doAssert window.confinement.region == rect(30, 40, 100, 80)
    window.releaseMouseConfinement()
    window.releaseMouseConfinement()
    doAssert not window.confinement.requested and not window.mouseConfined
    window.confineMouse()
    # Avoid hiding or warping the user's cursor in this hidden native test.
    window.state.mouseCaptured = true
    window.captureMouse()
    doAssert not window.confinement.requested and not window.mouseConfined
    for fullWindow in [false, true]:
      var rejected = false
      try:
        if fullWindow:
          window.confineMouse()
        else:
          window.confineMouse(rect(0, 0, 20, 20))
      except WindyError:
        rejected = true
      doAssert rejected
      doAssert not window.confinement.requested
    window.state.mouseCaptured = false
    window.confineMouse()
    window.close()
    doAssert window.closed and window.inner.int == 0
    doAssert not window.confinement.requested and not window.mouseConfined
    doAssert not window.confinement.controlsLocked
    doAssert not window.mouseConfinementSupported
    window.releaseMouseConfinement()
    window.close()

  proc testConfinementControls() =
    ## Checks drag and resize flags survive native lock and restore callbacks.
    for style in [DecoratedResizable, Decorated, Undecorated]:
      for movable in [false, true]:
        let window = newWindow(
          "Hidden confinement controls",
          ivec2(300, 200),
          style = style,
          visible = false
        )
        defer:
          window.close()
        window.inner.setMovable(movable)
        let
          saved = window.nativeState()
          nativeClass = object_getClass(window.inner.ID).int
        window.confinement.updating = true
        window.lockMouseConfinementControls()
        doAssert window.confinement.controlsLocked
        doAssert not window.inner.isMovable
        doAssert (window.inner.styleMask and NSWindowStyleMaskResizable) == 0
        doAssert (window.inner.styleMask and not NSWindowStyleMaskResizable) ==
          (saved.style and not NSWindowStyleMaskResizable)
        window.confinement.updating = false
        window.releaseMouseConfinement()
        doAssert not window.confinement.controlsLocked
        doAssert window.nativeState() == saved
        doAssert object_getClass(window.inner.ID).int == nativeClass

  testFullscreenRestoration()
  testIndependentFullscreens()
  testFullscreenSetters()
  testPresentationRestoration()
  testFullscreenCallbackClose()
  testConfinementCoordinates()
  testStaleConfinementGeometry()
  testInvalidConfinementRegions()
  testHiddenConfinement()
  testConfinementControls()
  echo "Windy fullscreen and confinement regression tests passed"
else:
  echo "Windy macOS fullscreen regression tests skipped"
