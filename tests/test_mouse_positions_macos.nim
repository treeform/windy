when defined(macosx):
  include ../src/windy/platforms/macos/platform

  objc:
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
    proc CGEvent(self: NSEvent): pointer
    proc eventWithCGEvent(class: typedesc[NSEvent], x: pointer): NSEvent

  proc CGEventCreateCopy(event: pointer): pointer {.importc, nodecl.}
  proc CGEventSetIntegerValueField(
    event: pointer, field: uint32, value: int64
  ) {.importc, nodecl.}
  proc CFRelease(value: pointer) {.importc, nodecl.}

  proc withButton(event: NSEvent, button: int): NSEvent =
    ## AppKit's event constructor defaults other mouse events to button zero.
    let native = CGEventCreateCopy(event.CGEvent())
    defer: CFRelease(native)
    CGEventSetIntegerValueField(native, 3, button.int64)
    NSEvent.eventWithCGEvent(native)

  proc testClickLocations() =
    ## Checks button positions without adding movement events or capture drift.
    let
      window = newWindow("Mouse positions", ivec2(200, 160), visible = false)
      view = window.inner.contentView.ID
      bounds = window.inner.contentView.bounds
      scale = window.contentScale
      preservedPosition = ivec2(-100, -100)
      previousPosition = ivec2(300, 400)
      movement = ivec2(7, -9)
    defer:
      window.state.mouseCaptured = false
      window.close()
    var
      expected: IVec2
      presses, releases: seq[Button]
      moves: int
    window.onMouseMove = proc() =
      ## Counts movement callbacks separately from native button events.
      inc moves
    window.onButtonPress = proc(button: Button) =
      ## Checks the button callback observes the same event's position.
      doAssert window.mousePos == expected
      presses.add(button)
    window.onButtonRelease = proc(button: Button) =
      ## Checks release positions update even without an intervening move.
      doAssert window.mousePos == expected
      releases.add(button)
    autoreleasepool:
      for captured in [false, true]:
        window.state.mouseCaptured = captured
        presses.setLen(0)
        releases.setLen(0)
        for index, mouseEvent in [
          (1.uint, 0), (2.uint, 0), (3.uint, 1), (4.uint, 1),
          (25.uint, 2), (26.uint, 2), (25.uint, 3), (26.uint, 3),
          (25.uint, 4), (26.uint, 4)
        ]:
          let
            (eventType, button) = mouseEvent
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
            ).withButton(button)
            location = event.locationInWindow()
          expected =
            if captured:
              preservedPosition
            else:
              ivec2(
                (round(location.x).float32 * scale).int32,
                (round(bounds.size.height - location.y).float32 * scale).int32
              )
          window.state.mousePos = preservedPosition
          window.state.mousePrevPos = previousPosition
          window.state.perFrame.mouseDelta = movement
          window.state.mouseInside = false
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
          doAssert window.mousePos == expected,
            "Event " & $eventType & " button " & $event.buttonNumber &
            " captured " & $captured & ": " & $window.mousePos &
            " != " & $expected
          doAssert window.mousePrevPos == previousPosition
          doAssert window.mouseDelta == movement
          doAssert not window.mouseInside
          doAssert moves == 0
        doAssert presses == @[
          MouseLeft, MouseRight, MouseMiddle, MouseButton4, MouseButton5
        ]
        doAssert releases == presses

  proc testBackingScalePositions() =
    ## Preserves logical pointer state and pending deltas across display scales.
    let window = Window()
    var moves = 0
    window.onMouseMove = proc() =
      ## Rejects synthesized movement during a backing-scale change.
      inc moves
    window.state.contentScale = 2
    window.state.mousePos = ivec2(80, 84)
    window.state.mousePrevPos = ivec2(74, 94)
    window.state.perFrame.mouseDelta = ivec2(6, -10)
    window.state.multiClickPositions = [
      ivec2(20, 24), ivec2(30, 34), ivec2(40, 44)
    ]
    window.state.hasPrevMouse = true
    window.state.mouseInside = true
    for captured in [false, true]:
      window.state.mouseCaptured = captured
      window.updateBackingScale(1)
      doAssert window.state.contentScale == 1
      doAssert window.mousePos == ivec2(40, 42)
      doAssert window.mousePrevPos == ivec2(37, 47)
      doAssert window.mouseDelta == ivec2(3, -5)
      doAssert window.state.multiClickPositions == [
        ivec2(10, 12), ivec2(15, 17), ivec2(20, 22)
      ]
      window.updateBackingScale(1)
      doAssert window.mousePos == ivec2(40, 42)
      doAssert window.mouseDelta == ivec2(3, -5)
      window.updateBackingScale(2)
      doAssert window.mousePos == ivec2(80, 84)
      doAssert window.mousePrevPos == ivec2(74, 94)
      doAssert window.mouseDelta == ivec2(6, -10)
      doAssert window.state.hasPrevMouse and window.mouseInside
      doAssert moves == 0

  proc testBackingBeforeMouseEvent() =
    ## Converts cached pixels before a new native event measures its delta.
    let
      window = newWindow("Backing mouse pixels", ivec2(200, 160), visible = false)
      scale = window.contentScale
    defer:
      window.close()
    window.state.contentScale = scale * 2
    window.state.mousePos = (vec2(40, 42) * scale * 2).ivec2
    window.state.mousePrevPos = (vec2(37, 47) * scale * 2).ivec2
    window.state.perFrame.mouseDelta = (vec2(3, -5) * scale * 2).ivec2
    window.state.hasPrevMouse = true
    var moves = 0
    window.onMouseMove = proc() =
      ## Sees the real event's delta expressed only in the new scale.
      inc moves
      doAssert window.mousePos == (vec2(41, 43) * scale).ivec2
      doAssert window.mousePrevPos == (vec2(40, 42) * scale).ivec2
      doAssert window.mouseDelta == (vec2(4, -4) * scale).ivec2
    handleMouseMove(window, NSMakePoint(
      41, window.inner.contentView.bounds.size.height - 43
    ))
    doAssert moves == 1

  proc testBackingBeforeCallbacks() =
    ## Publishes rescaled pointer state before resize and render callbacks run.
    let
      window = newWindow("Backing callbacks", ivec2(200, 160), visible = false)
      scale = window.contentScale
    defer:
      window.close()
    window.state.contentScale = scale * 2
    window.state.mousePos = (vec2(40, 42) * scale * 2).ivec2
    window.state.mousePrevPos = (vec2(37, 47) * scale * 2).ivec2
    window.state.perFrame.mouseDelta = (vec2(3, -5) * scale * 2).ivec2
    window.state.hasPrevMouse = true
    var frames, resizes, moves = 0
    proc check() =
      ## Checks callbacks never observe a mixture of old and new pixel units.
      doAssert window.mousePos == (vec2(40, 42) * scale).ivec2
      doAssert window.mousePrevPos == (vec2(37, 47) * scale).ivec2
      doAssert window.mouseDelta == (vec2(3, -5) * scale).ivec2
      doAssert window.state.hasPrevMouse
    window.onResize = proc() =
      ## Validates the first public notification of a backing change.
      check()
      inc resizes
    window.onFrame = proc() =
      ## Validates the draw dispatched directly from the backing notification.
      check()
      inc frames
    window.onMouseMove = proc() =
      ## Counts only genuine movement, never backing-coordinate conversions.
      inc moves
    for _ in 0 ..< 2:
      discard viewDidChangeBackingProperties(
        window.inner.contentView.ID,
        s"viewDidChangeBackingProperties"
      )
    doAssert frames == 2 and resizes == 2 and moves == 0

  testClickLocations()
  testBackingScalePositions()
  testBackingBeforeMouseEvent()
  testBackingBeforeCallbacks()
  echo "Native mouse button positions passed."
