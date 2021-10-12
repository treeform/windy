import ../../common, x11, os

type
  PlatformApp* = ref object
    windows*: seq[PlatformWindow]
    display: Display

  PlatformWindow* = ref PlatformWindowObj
  PlatformWindowObj = object
    display: Display
    handle: Window
    ctx: GlxContext
    gc: GC
    ic: XIC
    im: XIM

    opened: bool


proc newPlatformApp*(): PlatformApp =
  new result
  result.display = XOpenDisplay(getEnv("DISPLAY"))
  if result.display == nil:
    raise WindyError.newException("Error opening X11 display, make sure the DISPLAY environment variable is set correctly")


proc `=destroy`(window: var PlatformWindowObj) =
  if window.ic != nil:   XDestroyIC(window.ic)
  if window.im != nil:   discard XCloseIM(window.im)
  if window.gc != nil:   discard window.display.XFreeGC(window.gc)
  if window.handle != 0: discard window.display.XDestroyWindow(window.handle)

proc show*(window: PlatformWindow) =
  window.display.XRaiseWindow(window.handle)

proc hide*(window: PlatformWindow) =
  window.display.XLowerWindow(window.handle)

proc makeContextCurrent*(window: PlatformWindow) =
  discard window.display.glXMakeCurrent(window.handle, window.ctx)

proc swapBuffers*(window: PlatformWindow) =
  window.display.glXSwapBuffers(window.handle)

proc newWindow*(
  app: PlatformApp,
  windowTitle: string,
  x, y, w, h: int
): PlatformWindow =
  new result
  result.display = app.display

  let root = app.display.defaultRootWindow
  
  var attribList = [GlxRgba, GlxDepthSize, 24, GlxDoublebuffer]
  let vi = app.display.glXChooseVisual(0, attribList[0].addr)

  let cmap = app.display.XCreateColormap(root, vi.visual, AllocNone)
  var swa = XSetWindowAttributes(colormap: cmap)

  result.handle = app.display.XCreateWindow(
    root,
    x.cint, y.cint,
    w.cuint, h.cuint,
    0,
    vi.depth.cuint,
    InputOutput,
    vi.visual,
    CwColormap or CwEventMask,
    swa.addr
  )

  discard app.display.XMapWindow(result.handle)
  var wmProtocols = [app.display.atom "WM_DELETE_WINDOW"]
  discard app.display.XSetWMProtocols(result.handle, wmProtocols[0].addr, cint wmProtocols.len)

  result.im = app.display.XOpenIM(nil, nil, nil)
  result.ic = result.im.XCreateIC(
    XNClientWindow,
    result.handle,
    XNFocusWindow,
    result.handle,
    XnInputStyle,
    XimPreeditNothing or XimStatusNothing,
    nil
  )

  var gcv: XGCValues
  result.gc = app.display.XCreateGC(result.handle, GCForeground or GCBackground, gcv.addr)

  result.ctx = app.display.glXCreateContext(vi, nil, 1)

  if result.ctx == nil:
    raise newException(WindyError, "Error creating OpenGL context")

  hide result
  makeContextCurrent result

  app.windows.add result

proc newWindow*(
  app: PlatformApp,
  windowTitle: string,
  width, height: int
): PlatformWindow =
  app.newWindow(windowTitle, 0, 0, width, height)

proc mainLoop*(window: PlatformWindow) =
  var ev: XEvent

  while window.opened:
    var xevents: seq[XEvent]

    proc checkEvent(d: Display, event: ptr XEvent, userData: pointer): cint {.cdecl.} =
      if cast[int](event.xany.window) == cast[int](userData): 1 else: 0
    
    while window.display.XCheckIfEvent(ev.addr, checkEvent, cast[pointer](window)) == 1:
      xevents.add ev
    
    for ev in xevents.mitems:
      case ev.theType
      
      of ClientMessage:
        if ev.xclient.data.l[0] == clong window.display.atom "WM_DELETE_WINDOW":
          window.opened = false

      else: discard
