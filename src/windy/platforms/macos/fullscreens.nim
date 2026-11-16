const
  FullScreenPrimary = 1'u shl 7
  FullScreenAuxiliary = 1'u shl 8
  FullScreenNone = 1'u shl 9
  MainMenuWindowLevelKey = 8
  PresentationAutoReveal = (1'u shl 0) or (1'u shl 2) or (1'u shl 11)
  PresentationHiddenBars = (1'u shl 1) or (1'u shl 3)
  PresentationFullscreen = 1'u shl 10
  PresentationManaged = PresentationAutoReveal or PresentationHiddenBars or
    PresentationFullscreen

objc:
  proc collectionBehavior(self: NSWindow): uint
    ## Reads the window's participation in desktop Spaces.
  proc setCollectionBehavior(self: NSWindow, x: uint)
    ## Disables AppKit's separate fullscreen Space for Windy windows.
  proc hasShadow(self: NSWindow): bool
    ## Reads the shadow setting saved across fullscreen.
  proc setHasShadow(self: NSWindow, x: bool)
    ## Changes the shadow of the borderless fullscreen window.
  proc hidesOnDeactivate(self: NSWindow): bool
    ## Reads whether another application's activation hides this window.
  proc setHidesOnDeactivate(self: NSWindow, x: bool)
    ## Lets Cmd-Tab hide and restore fullscreen without minimizing it.
  proc acceptsMouseMovedEvents(self: NSWindow): bool
    ## Reads whether the window receives continuous pointer motion.
  proc setAcceptsMouseMovedEvents(self: NSWindow, x: bool)
    ## Keeps absolute pointer motion flowing in borderless fullscreen.
  proc makeMainWindow(self: NSWindow)
    ## Keeps the focused game as the application's main window.
  proc isOnActiveSpace(self: NSWindow): bool
    ## Checks whether the window belongs to the current desktop Space.
  proc presentationOptions(self: NSApplication): NSApplicationPresentationOptions
    ## Reads the application's requested menu-bar and Dock behavior.

proc applicationWindows(): NSArray =
  ## Finds native fullscreen windows before restoring presentation options.
  cast[proc(self: NSApplication, cmd: SEL): NSArray {.cdecl.}](objc_msgSend)(
    NSApp, s("windows")
  )

proc CGWindowLevelForKey(key: cint): int32 {.cdecl, importc.}
  ## Resolves the system menu's window level.

var
  fullscreenPresentationActive, updatingFullscreenPresentation: bool
  savedFullscreenPresentation, appliedFullscreenPresentation:
    NSApplicationPresentationOptions

proc restoredFullscreenPresentation(
    saved, applied, current: NSApplicationPresentationOptions
): NSApplicationPresentationOptions {.raises: [].} =
  ## Restores owned flags without replacing other components' option changes.
  if (current and PresentationManaged) != (applied and PresentationManaged):
    return current
  (current and not PresentationManaged) or (saved and PresentationManaged)

proc restorableFullscreenPresentation(
    options: NSApplicationPresentationOptions
): NSApplicationPresentationOptions =
  ## Removes Space-only options if no native fullscreen window remains visible.
  result = options
  let nativeWindows = applicationWindows()
  for i in 0 ..< nativeWindows.count.int:
    let native = nativeWindows.objectAtIndex(i.uint).NSWindow
    if native.isVisible and native.isOnActiveSpace and
      (native.styleMask and NSWindowStyleMaskFullScreen) != 0:
        return
  result = result and not (PresentationFullscreen or (1'u shl 11))

proc updateFullscreenPresentation() =
  ## Hides system bars only while a focused Windy fullscreen owns presentation.
  if updatingFullscreenPresentation:
    return
  updatingFullscreenPresentation = true
  defer: updatingFullscreenPresentation = false
  var owner: Window
  if NSApp.isActive:
    for window in windows:
      if window.fullscreenState and not window.fullscreenChanging and
        not window.state.closed and not window.state.closeRequested and
        window.focused and window.visible and window.inner.isOnActiveSpace:
          owner = window
          break
  let current = NSApp.presentationOptions
  if owner == nil:
    if fullscreenPresentationActive:
      let restored = restoredFullscreenPresentation(
        savedFullscreenPresentation, appliedFullscreenPresentation, current
      )
      if restored != current:
        NSApp.setPresentationOptions(
          restorableFullscreenPresentation(restored)
        )
      fullscreenPresentationActive = false
    return
  if not fullscreenPresentationActive:
    savedFullscreenPresentation = current
    fullscreenPresentationActive = true
  appliedFullscreenPresentation =
    (current and not (PresentationAutoReveal or PresentationFullscreen)) or
    PresentationHiddenBars
  if current != appliedFullscreenPresentation:
    NSApp.setPresentationOptions(appliedFullscreenPresentation)

proc flushFullscreenCallbacks(window: Window) =
  ## Delivers native geometry notifications only after a transition has settled.
  let
    moved = window.fullscreenMoved
    resized = window.fullscreenResized
  window.fullscreenMoved = false
  window.fullscreenResized = false
  if not window.state.closed and moved and window.onMove != nil:
    window.onMove()
  if not window.state.closed and resized and window.onResize != nil:
    window.onResize()
  if not window.state.closed and resized and window.onFrame != nil:
    window.onFrame()

proc updateFullscreen(window: Window) =
  ## Follows display changes and lowers inactive fullscreen windows for Cmd-Tab.
  if not window.fullscreenState or window.state.closed or
    window.fullscreenChanging or window.fullscreenUpdating:
      return
  window.fullscreenUpdating = true
  defer: window.fullscreenUpdating = false
  let native = window.inner
  native.ID.retain()
  defer: native.ID.release()
  let active = NSApp.isActive and window.focused and
    window.visible and not window.state.closeRequested
  let level =
    if active: CGWindowLevelForKey(MainMenuWindowLevelKey).int + 1
    else: window.fullscreenRestore.level
  if native.level != level:
    native.setLevel(level)
  if window.state.closed or not active:
    return
  let screen = native.screen
  if screen.int != 0 and native.frame != screen.frame:
    window.suspendMouseConfinement()
    window.fullscreenChanging = true
    try:
      native.setFrame(screen.frame, true)
    finally:
      window.fullscreenChanging = false
    window.flushFullscreenCallbacks()

proc updateFullscreenWindows() =
  ## Uses a stable snapshot because native resize callbacks can close windows.
  let pending = windows
  for window in pending:
    window.updateFullscreen()
  updateFullscreenPresentation()

proc setFullscreen(window: Window, enabled: bool) =
  ## Saves and restores native window state around borderless display coverage.
  if window.state.closed or window.fullscreenChanging or
    window.fullscreenState == enabled:
      return
  autoreleasepool:
    let native = window.inner
    native.ID.retain()
    defer: native.ID.release()
    window.fullscreenChanging = true
    defer:
      window.fullscreenChanging = false
      window.updateFullscreen()
      updateFullscreenPresentation()
      window.flushFullscreenCallbacks()
    window.suspendMouseConfinement()
    if window.state.closed:
      return
    if enabled:
      let screen = native.screen
      if screen.int == 0:
        raise newException(WindyError, "Fullscreen window has no display")
      window.fullscreenRestore = FullscreenRestore(
        frame: native.frame,
        style: native.styleMask,
        level: native.level,
        movable: native.isMovable,
        shadow: native.hasShadow,
        hides: native.hidesOnDeactivate,
        mouseMoved: native.acceptsMouseMovedEvents
      )
      window.fullscreenState = true
      native.setHidesOnDeactivate(true)
      native.setStyleMask(undecoratedWindowMask)
      if window.state.closed:
        return
      discard native.makeFirstResponder(native.contentView)
      native.setAcceptsMouseMovedEvents(true)
      if NSApp.isActive and window.focused:
        native.makeMainWindow()
      native.setMovable(false)
      native.setHasShadow(false)
      native.setFrame(screen.frame, true)
    else:
      window.fullscreenState = false
      let saved = window.fullscreenRestore
      native.setLevel(saved.level)
      if window.state.closed:
        return
      native.setStyleMask(saved.style)
      if window.state.closed:
        return
      native.setTitle(@(window.state.title))
      discard native.makeFirstResponder(native.contentView)
      native.setMovable(saved.movable)
      native.setHasShadow(saved.shadow)
      native.setHidesOnDeactivate(saved.hides)
      native.setAcceptsMouseMovedEvents(saved.mouseMoved)
      native.setFrame(saved.frame, true)
