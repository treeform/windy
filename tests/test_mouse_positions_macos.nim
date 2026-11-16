when defined(macosx):
  include ../src/windy/platforms/macos/platform

  objc:
    proc windowNumber(self: NSWindow): int
    proc mouseEventWithType(
      class: typedesc[NSEvent],
      x: uint,
      location: NSPoint,
      modifierFlags: uint,
      timestamp: float64,
      windowNumber: int,
      context: ID,
      eventNumber: int,
      clickCount: int,
      pressure: float32
    ): NSEvent

  proc testClickLocations() =
    ## Checks button callbacks receive fresh positions without move events.
    let
      window = newWindow("Mouse positions", ivec2(200, 160), visible = false)
      view = window.inner.contentView.ID
      bounds = window.inner.contentView.bounds
      scale = window.contentScale
    defer:
      window.close()
    var
      expected: IVec2
      presses, releases: seq[Button]
    window.onButtonPress = proc(button: Button) =
      ## Checks the button callback observes the same event's position.
      doAssert window.mousePos == expected
      presses.add(button)
    window.onButtonRelease = proc(button: Button) =
      ## Checks release positions update even without an intervening move.
      doAssert window.mousePos == expected
      releases.add(button)
    autoreleasepool:
      for index, eventType in [1.uint, 2, 3, 4, 25, 26]:
        let
          point = NSMakePoint(12 + index.float64 * 4, 15 + index.float64 * 3)
          event = NSEvent.mouseEventWithType(
            eventType,
            point,
            0,
            0,
            window.inner.windowNumber(),
            0.ID,
            index,
            1,
            0
          )
        expected = ivec2(
          (round(point.x).float32 * scale).int32,
          (round(bounds.size.height - point.y).float32 * scale).int32
        )
        window.state.mousePos = ivec2(-100, -100)
        case eventType
        of 1:
          discard mouseDown(view, s"mouseDown:", event)
        of 2:
          discard mouseUp(view, s"mouseUp:", event)
        of 3:
          discard rightMouseDown(view, s"rightMouseDown:", event)
        of 4:
          discard rightMouseUp(view, s"rightMouseUp:", event)
        of 25:
          discard otherMouseDown(view, s"otherMouseDown:", event)
        of 26:
          discard otherMouseUp(view, s"otherMouseUp:", event)
        else:
          doAssert false
        doAssert window.mousePos == expected
        doAssert window.mouseInside
    doAssert presses.len >= 2
    doAssert presses[0 .. 1] == @[MouseLeft, MouseRight]
    doAssert releases == presses

  testClickLocations()
  echo "Native mouse button positions passed."
