import ../../common, x11, os

type
  PlatformWindow* = ref PlatformWindowObj
  PlatformWindowObj = object
    handle: Window
    ctx: GlxContext
    gc: GC
    ic: XIC
    im: XIM

    closed*: bool


var
  initialized*: bool
  windows*: seq[PlatformWindow]
  display: Display


proc platformInit* =
  if initialized:
    raise newException(WindyError, "Windy is already initialized")

  display = XOpenDisplay(getEnv("DISPLAY"))
  if display == nil:
    raise WindyError.newException("Error opening X11 display, make sure the DISPLAY environment variable is set correctly")
  
  initialized = true


proc `=destroy`(window: var PlatformWindowObj) =
  if window.ic != nil:   XDestroyIC(window.ic)
  if window.im != nil:   discard XCloseIM(window.im)
  if window.gc != nil:   discard display.XFreeGC(window.gc)
  if window.handle != 0: discard display.XDestroyWindow(window.handle)

proc show*(window: PlatformWindow) =
  display.XRaiseWindow(window.handle)

proc hide*(window: PlatformWindow) =
  display.XLowerWindow(window.handle)

proc makeContextCurrent*(window: PlatformWindow) =
  discard display.glXMakeCurrent(window.handle, window.ctx)

proc swapBuffers*(window: PlatformWindow) =
  display.glXSwapBuffers(window.handle)

proc newPlatformWindow*(
  title: string,
  x, y, w, h: int
): PlatformWindow =
  new result
  let root = display.defaultRootWindow
  
  var attribList = [GlxRgba, GlxDepthSize, 24, GlxDoublebuffer]
  let vi = display.glXChooseVisual(0, attribList[0].addr)

  let cmap = display.XCreateColormap(root, vi.visual, AllocNone)
  var swa = XSetWindowAttributes(colormap: cmap)

  result.handle = display.XCreateWindow(
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

  discard display.XSelectInput(result.handle,
    ExposureMask or KeyPressMask or KeyReleaseMask or PointerMotionMask or ButtonPressMask or
    ButtonReleaseMask or StructureNotifyMask or EnterWindowMask or LeaveWindowMask or FocusChangeMask
  )

  discard display.XMapWindow(result.handle)
  var wmProtocols = [display.atom "WM_DELETE_WINDOW"]
  discard display.XSetWMProtocols(result.handle, wmProtocols[0].addr, cint wmProtocols.len)

  result.im = display.XOpenIM
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
  result.gc = display.XCreateGC(result.handle, GCForeground or GCBackground, gcv.addr)

  result.ctx = display.glXCreateContext(vi, nil, 1)

  if result.ctx == nil:
    raise newException(WindyError, "Error creating OpenGL context")

  hide result
  makeContextCurrent result

  windows.add result

proc newPlatformWindow*(
  title: string,
  width, height: int
): PlatformWindow =
  newPlatformWindow(title, 0, 0, width, height)

proc isOpen*(window: PlatformWindow): bool = not window.closed

proc pollEvents*(window: PlatformWindow) =
  var ev: XEvent
  
  proc checkEvent(d: Display, event: ptr XEvent, userData: pointer): cint {.cdecl.} =
    if event.xany.window == cast[PlatformWindow](userData).handle: 1 else: 0
  
  while display.XCheckIfEvent(ev.addr, checkEvent, cast[pointer](window)) == 1:
    case ev.theType
    
    of ClientMessage:
      if ev.xclient.data.l[0] == clong display.atom "WM_DELETE_WINDOW":
        window.closed = true

    else: discard
