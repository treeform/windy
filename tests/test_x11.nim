when defined(linux):
  import opengl
  include ../src/windy/platforms/linux/x11

  type
    CursorImage = object
      x, y: cshort
      width, height, xhot, yhot: cushort
      serial: culong
      pixels: ptr UncheckedArray[culong]
      atom: Atom
      name: cstring

  proc closeDisplay(d: Display): cint
    {.cdecl, dynlib: libX11, importc: "XCloseDisplay".}
    ## Closes the independent test connection.

  proc cursorImage(d: Display): ptr CursorImage
    {.cdecl, dynlib: "libXfixes.so.3", importc: "XFixesGetCursorImage".}
    ## Reads the cursor image currently displayed by the X server.

  proc movePointer(d: Display, x, y: cint, delay: culong): cint
    {.cdecl, dynlib: "libXtst.so.6",
      importc: "XTestFakeRelativeMotionEvent".}
    ## Injects relative pointer movement through the X server.

  proc syncEvents() =
    ## Processes queued events and finishes any resulting pointer warp.
    display.XSync()
    pollEvents()
    display.XSync()

  proc pointerVisible(d: Display): bool =
    ## Checks whether the server cursor has any opaque pixels.
    let image = d.cursorImage()
    doAssert image != nil
    defer:
      XFree(image)
    for i in 0 ..< image.width.int * image.height.int:
      if (image.pixels[i] shr 24 and 255) != 0:
        return true

  proc tryGrab(d: Display): cint =
    ## Tries to grab the pointer independently of Windy's state.
    d.XGrabPointer(
      d.defaultRootWindow,
      0,
      PointerMotionMask.cuint,
      GrabModeAsync,
      GrabModeAsync,
      0,
      0,
      CurrentTime
    )

  proc expectCaptureError(window: Window) =
    ## Ensures an unsuccessful capture raises without claiming ownership.
    var failed = false
    try:
      window.captureMouse()
    except WindyError:
      failed = true
    doAssert failed
    doAssert not window.mouseCaptured

  proc testContexts() =
    ## Checks actual OpenGL version, profile, and framebuffer attributes.
    let window = newWindow(
      "X11 context",
      ivec2(128, 128),
      visible = false,
      vsync = false,
      openglVersion = OpenGL3Dot3,
      depthBits = 24,
      stencilBits = 8
    )
    defer:
      window.close()
    loadExtensions()
    var major, minor, profile, depth, stencil: GLint
    glGetIntegerv(GL_MAJOR_VERSION, major.addr)
    glGetIntegerv(GL_MINOR_VERSION, minor.addr)
    glGetIntegerv(GL_CONTEXT_PROFILE_MASK, profile.addr)
    glGetFramebufferAttachmentParameteriv(
      GL_FRAMEBUFFER,
      GL_DEPTH,
      GL_FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE,
      depth.addr
    )
    glGetFramebufferAttachmentParameteriv(
      GL_FRAMEBUFFER,
      GL_STENCIL,
      GL_FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE,
      stencil.addr
    )
    doAssert major > 3 or (major == 3 and minor >= 3)
    doAssert (profile and GL_CONTEXT_CORE_PROFILE_BIT.GLint) != 0
    doAssert depth >= 24 and stencil >= 8
    echo "OpenGL: ", cast[cstring](glGetString(GL_VERSION))

  proc testUnsupportedVersion() =
    ## Checks rejection above the Mesa version cap used by this test run.
    var failed = false
    try:
      let window = newWindow(
        "Unsupported context",
        ivec2(32, 32),
        visible = false,
        vsync = false,
        openglVersion = OpenGL4Dot6
      )
      window.close()
    except WindyError:
      failed = true
    doAssert failed, "OpenGL 4.6 must fail with Mesa capped to 3.3"
    testContexts()

  proc testCapture() =
    ## Checks server capture, hidden cursor, relative movement, and cleanup.
    let
      window = newWindow(
        "X11 capture",
        ivec2(128, 128),
        visible = false,
        vsync = false,
        openglVersion = OpenGL3Dot3
      )
      peer = XOpenDisplay(nil)
    doAssert peer != nil
    defer:
      window.close()
      discard peer.closeDisplay()

    window.expectCaptureError()
    window.visible = true
    window.focus()
    syncEvents()
    window.captureMouse()
    syncEvents()
    doAssert window.mouseCaptured
    doAssert peer.tryGrab() == AlreadyGrabbed
    doAssert not peer.pointerVisible()
    window.cursor = common.Cursor(kind: CrosshairCursor)
    display.XSync()
    doAssert not peer.pointerVisible()

    var movement: IVec2
    for i in 0 ..< 12:
      for j in 0 ..< 2:
        doAssert peer.movePointer(13, -7, 0) != 0
      peer.XSync()
      syncEvents()
      doAssert window.mouseDelta == ivec2(26, -14)
      movement += window.mouseDelta
      syncEvents()
      doAssert window.mouseDelta == ivec2(0, 0)
    doAssert movement == ivec2(312, -168)

    window.releaseMouse()
    syncEvents()
    doAssert not window.mouseCaptured
    doAssert peer.pointerVisible()
    doAssert peer.tryGrab() == GrabSuccess
    window.expectCaptureError()
    peer.XUngrabPointer(CurrentTime)
    peer.XSync()

    window.captureMouse()
    syncEvents()
    peer.XSetInputFocus(peer.defaultRootWindow, rtNone)
    peer.XSync()
    syncEvents()
    doAssert not window.mouseCaptured
    doAssert peer.tryGrab() == GrabSuccess
    peer.XUngrabPointer(CurrentTime)
    peer.XSync()

    window.focus()
    syncEvents()
    window.captureMouse()
    window.visible = false
    syncEvents()
    doAssert not window.mouseCaptured
    doAssert peer.tryGrab() == GrabSuccess
    peer.XUngrabPointer(CurrentTime)
    peer.XSync()

    window.visible = true
    peer.XSetInputFocus(peer.defaultRootWindow, rtNone)
    peer.XSync()
    syncEvents()
    window.captureMouse()
    peer.XUnmapWindow(window.handle)
    peer.XSync()
    syncEvents()
    doAssert not window.mouseCaptured
    doAssert peer.tryGrab() == GrabSuccess
    peer.XUngrabPointer(CurrentTime)
    peer.XSync()

    window.visible = true
    window.focus()
    syncEvents()
    window.captureMouse()
    window.close()
    display.XSync()
    doAssert not window.mouseCaptured
    doAssert peer.tryGrab() == GrabSuccess
    peer.XUngrabPointer(CurrentTime)
    peer.XSync()
    window.expectCaptureError()

  proc counterValue(window: Window): XSyncValue =
    ## Reads the current resize sync counter from the X server.
    doAssert display.XSyncQueryCounter(window.xSyncCounter, result.addr) != 0

  proc sendSyncRequest(window: Window, lo: uint32, hi: int32) =
    ## Sends what a window manager sends right before resizing the window.
    let xaWMProtocols = display.XInternAtom("WM_PROTOCOLS", 0)
    let message = newClientMessage(
      window.handle,
      xaWMProtocols,
      [xaNetWMSyncRequest.clong, 0.clong, lo.clong, hi.clong]
    )
    window.handle.send(message)
    display.XSync()

  proc resize(window: Window, size: IVec2) =
    ## Resizes the window and waits for the server to queue ConfigureNotify.
    display.XResizeWindow(window.handle, size.x.uint32, size.y.uint32)
    display.XSync()

  proc testSyncRequestAck() =
    ## Plays the window manager side of the resize sync handshake under Xvfb.
    ## Checks that acknowledgements follow ConfigureNotify and a frame,
    ## and never happen without a request.
    let window = newWindow("Sync", ivec2(200, 100), visible = false)
    doAssert window.xSyncCounter.int != 0, "Xvfb lacks the SYNC extension"

    var resizes: seq[IVec2]
    window.onResize = proc() =
      resizes.add window.size

    doAssert window.counterValue.lo == 0
    doAssert window.syncState == SyncIdle

    # A resize without a request never touches the counter.
    window.resize(ivec2(210, 110))
    pollEvents()
    doAssert resizes == @[ivec2(210, 110)]
    doAssert window.counterValue.lo == 0
    doAssert window.syncState == SyncIdle

    # Request and ConfigureNotify in one poll: the ack waits for a frame.
    window.sendSyncRequest(1, 0)
    window.resize(ivec2(300, 200))
    pollEvents()
    doAssert resizes[^1] == ivec2(300, 200)
    doAssert window.syncState == SyncConfigured
    doAssert window.counterValue.lo == 0, "acked before the resized frame"
    pollEvents()
    doAssert window.syncState == SyncIdle
    doAssert window.counterValue.lo == 1

    # Request in one poll, ConfigureNotify in a later one. The poll that saw
    # the request must not ack, and must not wait longer than the timeout.
    window.sendSyncRequest(2, 0)
    let start = epochTime()
    pollEvents()
    doAssert epochTime() - start < 1.0, "poll did not give up waiting"
    doAssert window.syncState == SyncRequested
    doAssert window.counterValue.lo == 1, "acked without a ConfigureNotify"
    pollEvents()
    doAssert window.counterValue.lo == 1
    window.resize(ivec2(400, 300))
    pollEvents()
    doAssert resizes[^1] == ivec2(400, 300)
    doAssert window.syncState == SyncConfigured
    doAssert window.counterValue.lo == 1
    pollEvents()
    doAssert window.syncState == SyncIdle
    doAssert window.counterValue.lo == 2

    # The full 64-bit value round-trips and a newer request wins.
    window.sendSyncRequest(3, 0)
    window.sendSyncRequest(5, 1)
    window.resize(ivec2(500, 400))
    pollEvents()
    pollEvents()
    let value = window.counterValue
    doAssert value.lo == 5 and value.hi == 1

    # Once idle, polling leaves the counter alone.
    pollEvents()
    doAssert window.counterValue.lo == 5
    doAssert window.syncState == SyncIdle

    window.close()

  if paramCount() > 0 and paramStr(1) == "--unsupported-version":
    testUnsupportedVersion()
  else:
    testContexts()
    testCapture()
    testSyncRequestAck()
  echo "Windy X11 regression tests passed"
else:
  echo "Windy X11 regression tests skipped"
