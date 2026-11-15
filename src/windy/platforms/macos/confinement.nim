import std/math

{.emit: "#include <ApplicationServices/ApplicationServices.h>".}

const ConfinementWindowListIncludingWindow = 1'u32 shl 3

var
  kCGWindowBounds {.
    importc, header: "<ApplicationServices/ApplicationServices.h>"
  .}: pointer
  kCGWindowIsOnscreen {.
    importc, header: "<ApplicationServices/ApplicationServices.h>"
  .}: pointer

objc:
  proc respondsToSelector(self: NSWindow, x: SEL): bool
    ## Checks the native capability before calling an undocumented selector.
  proc setMouseConfinementRect(self: NSWindow, x: NSRect)
    ## Sets the visible pointer's native window-relative confinement rectangle.
  proc convertRect(self: NSView, x: NSRect, toView: NSView): NSRect
    ## Converts view points to the destination view or window coordinates.
  proc windowNumber(self: NSWindow): int
    ## Identifies this application's window in WindowServer metadata.
  proc objectForKey(self: NSDictionary, x: ID): ID
    ## Reads a value from the native window metadata dictionary.
  proc boolValue(self: ID): bool
    ## Reads whether WindowServer has placed the window onscreen.
  proc isMovable(self: NSWindow): bool
    ## Returns whether the native window can be dragged.
  proc setMovable(self: NSWindow, x: bool)
    ## Enables or disables native window dragging.

proc copyConfinementWindowInfo(options, window: uint32): pointer =
  ## Copies window metadata without capturing screen contents.
  {.emit: """
    `result` = (void *)CGWindowListCopyWindowInfo(`options`, `window`);
  """.}

proc readConfinementWindowBounds(
    dictionary: pointer, rect: var NSRect
): bool =
  ## Decodes native CGRect fields without aliasing Nim's separate rectangle type.
  var x, y, width, height: float64
  {.emit: """
    CGRect nativeBounds;
    `result` = CGRectMakeWithDictionaryRepresentation(
      (CFDictionaryRef)`dictionary`, &nativeBounds
    );
    if (`result`) {
      `x` = nativeBounds.origin.x;
      `y` = nativeBounds.origin.y;
      `width` = nativeBounds.size.width;
      `height` = nativeBounds.size.height;
    }
  """.}
  if result:
    rect = NSMakeRect(x, y, width, height)

proc releaseConfinementWindowInfo(value: pointer) =
  ## Releases copied Core Foundation metadata.
  {.emit: "CFRelease((CFTypeRef)`value`);".}

proc validMouseConfinementRegion(region: Rect): bool {.raises: [].} =
  ## Accepts finite framebuffer coordinates and positive rectangle dimensions.
  for value in [region.x, region.y, region.w, region.h]:
    if classify(value) in {fcNan, fcInf, fcNegInf}:
      return false
  region.w > 0 and region.h > 0

proc mouseConfinementViewRect(
    region: Rect, fullWindow: bool, bounds, backing: NSRect
): NSRect {.raises: [].} =
  ## Clips framebuffer pixels and converts to bottom-left content view points.
  if bounds.size.width <= 0 or bounds.size.height <= 0 or
    backing.size.width <= 0 or backing.size.height <= 0:
      return
  if fullWindow:
    return bounds
  let
    left = max(0.0, region.x.float64)
    top = max(0.0, region.y.float64)
    right = min(backing.size.width, region.x.float64 + region.w.float64)
    bottom = min(backing.size.height, region.y.float64 + region.h.float64)
  if right <= left or bottom <= top:
    return
  let
    scaleX = bounds.size.width / backing.size.width
    scaleY = bounds.size.height / backing.size.height
  NSMakeRect(
    bounds.origin.x + left * scaleX,
    bounds.origin.y + bounds.size.height - bottom * scaleY,
    (right - left) * scaleX,
    (bottom - top) * scaleY
  )

proc confinementFramesMatch(expected, actual: NSRect): bool {.raises: [].} =
  ## Allows server rounding while rejecting an old or intermediate window frame.
  expected.size.width > 0 and expected.size.height > 0 and
    actual.size.width > 0 and actual.size.height > 0 and
    abs(expected.origin.x - actual.origin.x) <= 1 and
    abs(expected.origin.y - actual.origin.y) <= 1 and
    abs(expected.size.width - actual.size.width) <= 1 and
    abs(expected.size.height - actual.size.height) <= 1

proc confinementGeometryChanged(
    confinement: MouseConfinement, frame, bounds, backing: NSRect
): bool {.raises: [].} =
  ## Includes the clip and backing scale when invalidating native geometry.
  not confinement.active or
    confinement.cachedFrame != frame or
    confinement.cachedBounds != bounds or
    confinement.cachedBacking != backing

proc nativeConfinementGeometryCommitted(native: NSWindow): bool =
  ## Waits for WindowServer rather than AppKit's eagerly updated frame.
  if not native.isVisible:
    return false
  let screens = NSScreen.screens
  if screens.count == 0:
    return false
  let
    primary = screens.objectAtIndex(0).NSScreen.frame
    frame = native.frame
    expected = NSMakeRect(
      frame.origin.x,
      primary.origin.y + primary.size.height -
        frame.origin.y - frame.size.height,
      frame.size.width,
      frame.size.height
    )
    info = copyConfinementWindowInfo(
      ConfinementWindowListIncludingWindow,
      native.windowNumber.uint32
    )
  if info == nil:
    return false
  defer:
    releaseConfinementWindowInfo(info)
  let windows = cast[NSArray](info)
  if windows.count != 1:
    return false
  let metadata = windows.objectAtIndex(0).NSDictionary
  if not metadata.objectForKey(cast[ID](kCGWindowIsOnscreen)).boolValue:
    return false
  let bounds = metadata.objectForKey(cast[ID](kCGWindowBounds))
  var actual: NSRect
  if bounds.int == 0 or
    not readConfinementWindowBounds(cast[pointer](bounds), actual):
      return false
  confinementFramesMatch(expected, actual)

proc mouseConfinementSupported*(window: Window): bool =
  ## Returns whether the live window supports native visible cursor confinement.
  window != nil and not window.state.closed and window.inner.int != 0 and
    window.inner.respondsToSelector(s("setMouseConfinementRect:"))

proc clearMouseConfinementClip(window: Window) =
  ## Removes the old native clip before any geometry or control changes.
  let wasActive = window.confinement.active
  window.confinement.active = false
  window.confinement.cachedFrame = NSRect()
  window.confinement.cachedBounds = NSRect()
  window.confinement.cachedBacking = NSRect()
  if wasActive and window.mouseConfinementSupported:
    window.inner.setMouseConfinementRect(NSRect())

proc restoreMouseConfinementControls(window: Window) =
  ## Restores only the movable flag and resizable bit owned by confinement.
  if not window.confinement.controlsLocked:
    return
  if window.state.closed or window.inner.int == 0:
    window.confinement.controlsLocked = false
    return
  let
    native = window.inner
    mask = native.styleMask
  if (mask and NSWindowStyleMaskFullScreen) != 0:
    return
  native.ID.retain()
  defer:
    native.ID.release()
  window.confinement.controlsLocked = false
  native.setMovable(window.confinement.savedMovable)
  let restoredMask =
    if window.confinement.savedResizable:
      mask or NSWindowStyleMaskResizable
    else:
      mask and not NSWindowStyleMaskResizable
  if mask != restoredMask:
    native.setStyleMask(restoredMask)
    if not window.state.closed and window.inner.int == native.int:
      discard native.makeFirstResponder(native.contentView)

proc suspendMouseConfinement(window: Window) =
  ## Clears clipping and restores controls while retaining the user's request.
  if window == nil:
    return
  let wasUpdating = window.confinement.updating
  window.confinement.updating = true
  defer:
    window.confinement.updating = wasUpdating
  window.clearMouseConfinementClip()
  window.restoreMouseConfinementControls()

proc releaseMouseConfinement*(window: Window) =
  ## Cancels confinement and restores pointer movement and window controls.
  if window == nil:
    return
  window.confinement.requested = false
  window.suspendMouseConfinement()

proc lockMouseConfinementControls(window: Window) =
  ## Disables native drag and resize handles while confined in windowed mode.
  let native = window.inner
  if window.fullscreen or
    (native.styleMask and NSWindowStyleMaskFullScreen) != 0:
      return
  native.ID.retain()
  defer:
    native.ID.release()
  if not window.confinement.controlsLocked:
    window.confinement.savedMovable = native.isMovable
    window.confinement.savedResizable =
      (native.styleMask and NSWindowStyleMaskResizable) != 0
    window.confinement.controlsLocked = true
  native.setMovable(false)
  let mask = native.styleMask
  if (mask and NSWindowStyleMaskResizable) != 0:
    native.setStyleMask(mask and not NSWindowStyleMaskResizable)
    if not window.state.closed and window.inner.int == native.int:
      discard native.makeFirstResponder(native.contentView)

proc mouseConfinementEligible(window: Window): bool =
  ## Requires a visible focused window outside close or fullscreen transitions.
  window != nil and not window.state.closed and
    not window.state.closeRequested and not window.fullscreenChanging and
    not window.state.mouseCaptured and window.inner.int != 0 and
    window.inner.isVisible and not window.inner.isMiniaturized and
    window.focused and NSApp.isActive

proc mouseConfined*(window: Window): bool =
  ## Reports active native clipping while focus and visibility allow it.
  window.mouseConfinementEligible and window.confinement.active

proc updateMouseConfinement(window: Window) =
  ## Applies requested clipping only after the event drain and server commit.
  if window == nil or window.confinement.updating:
    return
  window.confinement.updating = true
  defer:
    window.confinement.updating = false
  if not window.confinement.requested or
    not window.mouseConfinementEligible or
    not window.mouseConfinementSupported:
      window.suspendMouseConfinement()
      return
  let
    native = window.inner
    view = native.contentView
  native.ID.retain()
  view.ID.retain()
  defer:
    view.ID.release()
    native.ID.release()
  let
    previousFrame = native.frame
    previousBounds = view.bounds
    previousBacking = view.convertRectToBacking(previousBounds)
    previousClip = mouseConfinementViewRect(
      window.confinement.region,
      window.confinement.fullWindow,
      previousBounds,
      previousBacking
    )
  if previousClip.size.width <= 0 or previousClip.size.height <= 0:
    window.suspendMouseConfinement()
    return
  window.lockMouseConfinementControls()
  if not window.confinement.requested or not window.mouseConfinementEligible:
    window.suspendMouseConfinement()
    return
  if not window.fullscreen and not window.confinement.controlsLocked:
    return
  let
    frame = native.frame
    bounds = view.bounds
    backing = view.convertRectToBacking(bounds)
    viewClip = mouseConfinementViewRect(
      window.confinement.region,
      window.confinement.fullWindow,
      bounds,
      backing
    )
    clip = view.convertRect(viewClip, NSView(0))
  if viewClip.size.width <= 0 or viewClip.size.height <= 0:
    window.suspendMouseConfinement()
    return
  if not confinementGeometryChanged(window.confinement, frame, clip, backing):
    return
  window.clearMouseConfinementClip()
  if previousFrame != frame or previousBounds != bounds or
    previousBacking != backing or not native.nativeConfinementGeometryCommitted:
      return
  # Clearing before reapplying prevents AppKit from retaining the old boundary.
  native.setMouseConfinementRect(NSRect())
  native.setMouseConfinementRect(clip)
  window.confinement.cachedFrame = frame
  window.confinement.cachedBounds = clip
  window.confinement.cachedBacking = backing
  window.confinement.active = true

proc validateMouseConfinementRequest(window: Window) =
  ## Rejects unavailable or relative-capture requests without changing state.
  if not window.mouseConfinementSupported:
    raise newException(WindyError,
      "Native mouse confinement is unavailable for this window")
  if window.state.mouseCaptured:
    raise newException(WindyError,
      "Release relative mouse capture before confining the visible cursor")

proc confineMouse*(window: Window) =
  ## Confines the visible cursor to the full content after the next event poll.
  ## The request follows content size and resumes when focus returns.
  window.validateMouseConfinementRequest()
  if window.confinement.requested and window.confinement.fullWindow:
    return
  window.confinement.fullWindow = true
  window.confinement.requested = true
  window.suspendMouseConfinement()

proc confineMouse*(window: Window, region: Rect) =
  ## Confines to framebuffer pixels from the content's top-left after a poll.
  ## Clips to content and suspends confinement when the intersection is empty.
  if not validMouseConfinementRegion(region):
    raise newException(WindyError,
      "Mouse confinement requires a finite rectangle with positive dimensions")
  window.validateMouseConfinementRequest()
  if window.confinement.requested and not window.confinement.fullWindow and
    window.confinement.region == region:
      return
  window.confinement.region = region
  window.confinement.fullWindow = false
  window.confinement.requested = true
  window.suspendMouseConfinement()
