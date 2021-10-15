import ../../common, x11, os, sequtils

type
  PlatformWindow* = ref object
    handle: Window
    ctx: GlxContext
    gc: GC
    ic: XIC
    im: XIM

    closed*: bool

  WmForDecoratedKind {.pure.} = enum
    unsupported
    motiv
    kwm
    other


var
  initialized*: bool
  windows*: seq[PlatformWindow]
  display: Display
  decoratedAtom: Atom
  wmForFramelessKind: WmForDecoratedKind


proc atom[name: static string](): Atom =
  var a {.global.}: Atom
  if a == 0: a = display.XInternAtom(name, 0)
  a

template atom(name: static string): Atom = atom[name]()
proc atomIfExist(name: string): Atom = display.XInternAtom(name, 1)


proc handleXError(d: Display, event: ptr XErrorEvent): bool {.cdecl.} =
  raise WindyError.newException("Error dealing with X11: " & $event.errorCode.Status)

proc platformInit* =
  if initialized: return # no need to raise error

  XSetErrorHandler handleXError

  display = XOpenDisplay(getEnv("DISPLAY"))
  if display == nil:
    raise WindyError.newException("Error opening X11 display, make sure the DISPLAY environment variable is set correctly")
  
  wmForFramelessKind =
    if (decoratedAtom = atomIfExist"_MOTIF_WM_HINTS"; decoratedAtom != 0):
      WmForDecoratedKind.motiv
    elif (decoratedAtom = atomIfExist"KWM_WIN_DECORATION"; decoratedAtom != 0):
      WmForDecoratedKind.kwm
    elif (decoratedAtom = atomIfExist"_WIN_HINTS"; decoratedAtom != 0):
      WmForDecoratedKind.other
    else:
      WmForDecoratedKind.unsupported

  initialized = true

proc newXClientMessageEvent[T](
  window: Window,
  messageKind: Atom,
  data: openarray[T],
  serial: int = 0,
  sendEvent: bool = false
  ): XEvent =
  if data.len * T.sizeof > XClientMessageData.sizeof:
    raise WindyError.newException("To much data in client message")

  result = XEvent(xclient: XClientMessageEvent(
    kind: xeClientMessage,
    messageType: messageKind,
    window: window,
    display: display,
    serial: serial.culong,
    sendEvent: sendEvent,
    format: case T.sizeof
      of 1: 8
      of 2: 16
      of 4: 32
      of 8: 32
      else: 8
  ))

  if data.len != 0:
    copyMem(result.xclient.data.addr, data[0].unsafeAddr, data.len * T.sizeof)


proc destroy(window: PlatformWindow) =
  if window.ic != nil:   XDestroyIC(window.ic)
  if window.im != nil:   XCloseIM(window.im)
  if window.gc != nil:   display.XFreeGC(window.gc)
  if window.handle != 0: display.XDestroyWindow(window.handle)

proc show*(window: PlatformWindow) =
  display.XRaiseWindow(window.handle)

proc hide*(window: PlatformWindow) =
  display.XLowerWindow(window.handle)

proc makeContextCurrent*(window: PlatformWindow) =
  display.glXMakeCurrent(window.handle, window.ctx)

proc swapBuffers*(window: PlatformWindow) =
  display.glXSwapBuffers(window.handle)

proc close*(window: PlatformWindow) =
  if window.closed: return
  var e = newXClientMessageEvent(window.handle, atom"WM_PROTOCOLS", [atom"WM_DELETE_WINDOW", CurrentTime])
  display.XSendEvent(window.handle, 0, NoEventMask, e.addr)

proc isOpen*(window: PlatformWindow): bool = not window.closed

proc `title=`*(window: PlatformWindow, v: string) =
  display.XChangeProperty(window.handle, atom"_NET_WM_NAME", atom"UTF8_STRING", 8, pmReplace, v, v.len.cint)
  display.XChangeProperty(window.handle, atom"_NET_WM_ICON_NAME", atom"UTF8_STRING", 8, pmReplace, v, v.len.cint)
  display.Xutf8SetWMProperties(window.handle, v, v, nil, 0, nil, nil, nil)

proc `decorated=`*(window: PlatformWindow, v: bool) =
  #TOFIX: size of window changes
  case wmForFramelessKind
  of WmForDecoratedKind.motiv:
    type MWMHints = object
      flags: culong
      functions: culong
      decorations: culong
      input_mode: culong
      status: culong
    
    var hints = MWMHints(flags: culong (if v: 0 else: 1) shl 1)
    display.XChangeProperty(
      window.handle, decoratedAtom, decoratedAtom, 32, pmReplace,
      cast[ptr cuchar](hints.addr), MWMHints.sizeof div 4
    )

  of WmForDecoratedKind.kwm, WmForDecoratedKind.other:
    var hints: clong = if v: 1 else: 0
    display.XChangeProperty(
      window.handle, decoratedAtom, decoratedAtom, 32, pmReplace,
      cast[ptr cuchar](hints.addr), clong.sizeof div 4
    )

  else: display.XSetTransientForHint(window.handle, display.defaultRootWindow)

proc `fullscreen=`*(window: PlatformWindow, v: bool) =
  var e = newXClientMessageEvent(
    window.handle,
    atom"_NET_WM_STATE",
    [Atom (if v: 1 else: 0), atom"_NET_WM_STATE_FULLSCREEN", CurrentTime] # 2 - switch, 1 - set true, 0 - set false
  )
  display.XSendEvent(window.handle, 0, SubstructureNotifyMask or SubstructureRedirectMask, e.addr)

proc newPlatformWindow*(
  title: string,
  w, h: int,
  vsync: bool,
  # window constructor can't set opengl version, msaa and stencilBits
  # args mustn't set depthBits directly
  resizable: bool,
  fullscreen: bool,
  transparent: bool,
  decorated: bool,
  # what means "floating"?
): PlatformWindow =
  new result
  let root = display.defaultRootWindow
  
  var vi: XVisualInfo
  if transparent:
    display.XMatchVisualInfo(display.defaultScreen, 32, TrueColor, vi.addr)
  else:
    var attribList = [GlxRgba, GlxDepthSize, 24, GlxDoublebuffer]
    vi = display.glXChooseVisual(display.defaultScreen, attribList[0].addr)[]

  let cmap = display.XCreateColormap(root, vi.visual, AllocNone)
  var swa = XSetWindowAttributes(colormap: cmap)

  result.handle = display.XCreateWindow(
    root,
    0, 0,
    w.cuint, h.cuint,
    0,
    vi.depth.cuint,
    InputOutput,
    vi.visual,
    CwColormap or CwEventMask or CwBorderPixel or CwBackPixel,
    swa.addr
  )

  display.XSelectInput(result.handle,
    ExposureMask or KeyPressMask or KeyReleaseMask or PointerMotionMask or ButtonPressMask or
    ButtonReleaseMask or StructureNotifyMask or EnterWindowMask or LeaveWindowMask or FocusChangeMask
  )

  if fullscreen:
    var v = [atom"_NET_WM_STATE_FULLSCREEN"]
    display.XChangeProperty(result.handle, atom"_NET_WM_STATE", xaAtom, 32, pmAppend, cast[cstring](v[0].addr), v.len.cint)

  display.XMapWindow(result.handle)
  var wmProtocols = [atom"WM_DELETE_WINDOW"]
  display.XSetWMProtocols(result.handle, wmProtocols[0].addr, cint wmProtocols.len)

  result.im = display.XOpenIM
  result.ic = result.im.XCreateIC(
    "clientWindow",
    result.handle,
    "focusWindow",
    result.handle,
    "inputStyle",
    XimPreeditNothing or XimStatusNothing,
    nil
  )

  var gcv: XGCValues
  result.gc = display.XCreateGC(result.handle, GCForeground or GCBackground, gcv.addr)

  result.ctx = display.glXCreateContext(vi.addr, nil, 1)

  if result.ctx == nil:
    raise newException(WindyError, "Error creating OpenGL context")

  result.title = title
  if not decorated:
    result.decorated = false
  if not resizable:
    var hints = XSizeHints(
      flags: (1 shl 4) or (1 shl 5),
      minWidth: w.cint, maxWidth: w.cint,
      minHeight: h.cint, maxHeight: h.cint
    )
    display.XSetNormalHints(result.handle, hints.addr)

  hide result
  makeContextCurrent result

  if vsync:
    if glXSwapIntervalEXT != nil:
      display.glXSwapIntervalEXT(result.handle, 1)
    elif glXSwapIntervalMESA != nil:
      glXSwapIntervalMESA(1)
    elif glXSwapIntervalSGI != nil:
      glXSwapIntervalSGI(1)
    else:
      raise newException(WindyError, "VSync is not supported")

  windows.add result

proc pollEvents(window: PlatformWindow) =
  var ev: XEvent
  
  proc checkEvent(d: Display, event: ptr XEvent, userData: pointer): bool {.cdecl.} =
    event.xany.window == cast[PlatformWindow](userData).handle
  
  while display.XCheckIfEvent(ev.addr, checkEvent, cast[pointer](window)):
    case ev.kind
    
    of xeClientMessage:
      if ev.xclient.data.l[0] == clong atom"WM_DELETE_WINDOW":
        window.closed = true
        return

    of xeMotion:
      #TODO: push event
      discard (ev.xmotion.x.int, ev.xmotion.y.int)
    
    of xeButtonPress, xeButtonRelease:
      #TODO: push event
      case ev.xbutton.button
      of 1: discard # left
      of 2: discard # middle
      of 3: discard # right
      of 8: discard # backward
      of 9: discard # forward
      
      of 4: discard # scroll up
      of 5: discard # scroll down
      
      else: discard

    of xeFocusIn:
      if window.ic != nil: XSetICFocus window.ic
      #TODO: press currently pressed keys
    
    of xeFocusOut:
      if window.ic != nil: XUnsetICFocus window.ic
      #TODO: release currently pressed keys
        
    of xeKeyPress:
      #TODO: handle key press

      # handle text input
      if window.ic != nil and (ev.xkey.state and ControlMask) == 0:
        var
          status: cint
          s = newString(16)
        s.setLen window.ic.Xutf8LookupString(ev.xkey.addr, s, 16, nil, status.addr)

        if s != "\u001B":
          #TODO: push event
          discard
        
    of xeKeyRelease:
      #TODO: handle key release
      discard

    else: discard

proc platformPollEvents* =
  let ws = windows
  windows = @[]

  for window in ws:
    if window.isOpen:
      windows.add window
    else:
      destroy window

  for window in windows:
    pollEvents window
