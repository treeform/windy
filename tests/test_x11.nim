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
    glGetIntegerv(GL_DEPTH_BITS, depth.addr)
    glGetIntegerv(GL_STENCIL_BITS, stencil.addr)
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

  if paramCount() > 0 and paramStr(1) == "--unsupported-version":
    testUnsupportedVersion()
  else:
    testContexts()
    testCapture()
  echo "Windy X11 regression tests passed"
else:
  echo "Windy X11 regression tests skipped"
