import x11/[x, xlib, xevent, glx]
import ../../common, os, vmath

type
  XWindow = x.Window

  Window* = ref object
    onCloseRequest*: Callback
    onMove*: Callback
    onResize*: Callback
    onFocusChange*: Callback

    handle: XWindow
    ctx: GlxContext
    gc: GC
    ic: XIC
    im: XIM

    closed: bool
    `"_visible"`: bool
    `"_decorated"`: bool

  WmForDecoratedKind {.pure.} = enum
    unsupported
    motiv
    kwm
    other


var
  initialized: bool
  windows: seq[Window]
  display: Display
  decoratedAtom: Atom
  wmForDecoratedKind: WmForDecoratedKind


proc atom[name: static string](): Atom =
  var a {.global.}: Atom
  if a == 0: a = display.XInternAtom(name, 0)
  a

template atom(name: static string): Atom = atom[name]()
proc atomIfExist(name: string): Atom = display.XInternAtom(name, 1)


proc handleXError(d: Display, event: ptr XErrorEvent): bool {.cdecl.} =
  raise WindyError.newException("Error dealing with X11: " & $event.errorCode.Status)

proc init* =
  if initialized: return # no need to raise error

  XSetErrorHandler handleXError

  display = XOpenDisplay(getEnv("DISPLAY"))
  if display == nil:
    raise WindyError.newException("Error opening X11 display, make sure the DISPLAY environment variable is set correctly")
  
  wmForDecoratedKind =
    if (decoratedAtom = atomIfExist"_MOTIF_WM_HINTS"; decoratedAtom != 0):
      WmForDecoratedKind.motiv
    elif (decoratedAtom = atomIfExist"KWM_WIN_DECORATION"; decoratedAtom != 0):
      WmForDecoratedKind.kwm
    elif (decoratedAtom = atomIfExist"_WIN_HINTS"; decoratedAtom != 0):
      WmForDecoratedKind.other
    else:
      WmForDecoratedKind.unsupported

  initialized = true

proc geometry(window: XWindow): tuple[root: XWindow; pos, size: IVec2; borderW: int, depth: int] =
  var
    root: XWindow
    x, y: int32
    w, h: uint32
    borderW: uint32
    depth: uint32
  display.XGetGeometry(window, root.addr, x.addr, y.addr, w.addr, h.addr, borderW.addr, depth.addr)
  (root, ivec2(x, y), ivec2(w.int32, h.int32), borderW.int, depth.int)

proc property(window: XWindow, property: Atom): tuple[kind: Atom, data: string] =
  var
    kind: Atom
    format: cint
    lenght: culong
    bytesAfter: culong
    data: cstring
  display.XGetWindowProperty(window, property, 0, 0, false, 0, kind.addr, format.addr, lenght.addr, bytesAfter.addr, data.addr)
  
  result.kind = kind
  
  let len = lenght.int * format.int div 8
  result.data = newString(len)
  if len != 0: copyMem(result.data[0].addr, data, len)

proc setProperty(window: XWindow, property: Atom, kind: Atom, format: cint, data: string) =
  display.XChangeProperty(window, property, kind, format, pmReplace, data, data.len.cint)

proc addProperty(window: XWindow, property: Atom, kind: Atom, format: cint, data: string) =
  display.XChangeProperty(window, property, kind, format, pmAppend, data, data.len.cint)

proc asSeq(s: string, T: type = uint8): seq[T] =
  result = newSeqOfCap[T](s.len div T.sizeof)
  for i in countup(0, s.len - T.sizeof, T.sizeof):
    var r: array[T.sizeof, char]
    copyMem(r.addr, s[i].unsafeAddr, T.sizeof)
    result.add cast[ptr T](r.addr)[]

proc asString[T](x: openarray[T]): string =
  result = newStringOfCap(x.len * T.sizeof)
  for v in x:
    for v in cast[ptr array[T.sizeof, char]](v.unsafeAddr)[]:
      result.add v

proc wmState(window: XWindow): seq[Atom] =
  window.property(atom"_NET_WM_STATE").data.asSeq(Atom)


proc destroy(window: Window) =
  if window.ic != nil:   XDestroyIC(window.ic)
  if window.im != nil:   XCloseIM(window.im)
  if window.gc != nil:   display.XFreeGC(window.gc)
  if window.handle != 0: display.XDestroyWindow(window.handle)
  wasMoved window[]

proc isOpen*(window: Window): bool = not window.closed

proc close*(window: Window) =
  destroy window


proc makeContextCurrent*(window: Window) =
  display.glXMakeCurrent(window.handle, window.ctx)

proc swapBuffers*(window: Window) =
  display.glXSwapBuffers(window.handle)


proc visible*(window: Window): bool =
  window.`"_visible"`

proc `visible=`*(window: Window, v: bool) =
  if v: display.XMapWindow(window.handle)
  else: display.XUnmapWindow(window.handle)


proc size*(window: Window): IVec2 =
  window.handle.geometry.size

proc `size=`*(window: Window, v: IVec2) =
  display.XResizeWindow(window.handle, v.x.uint32, v.y.uint32)


proc framebufferSize*(window: Window): IVec2 =
  window.size


proc pos*(window: Window): IVec2 =
  window.handle.geometry.pos

proc `pos=`*(window: Window, v: IVec2) =
  display.XMoveWindow(window.handle, v.x, v.y)


proc decorated*(window: Window): bool =
  window.`"_decorated"`

proc `decorated=`*(window: Window, v: bool) =
  window.`"_decorated"` = v

  let size = window.size # save current window size

  case wmForDecoratedKind
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

  window.size = size # restore window size


proc resizable*(window: Window): bool =
  let size = window.size
  var hints: XSizeHints
  display.XGetNormalHints(window.handle, hints.addr)
  hints.minSize == size and hints.maxSize == size

proc `resizable=`*(window: Window, v: bool) =
  let size = window.size
  var hints = XSizeHints(
    flags: (1 shl 4) or (1 shl 5),
    minSize: size,
    maxSize: size
  )
  display.XSetNormalHints(window.handle, hints.addr)


proc fullscreen*(window: Window): bool =
  atom"_NET_WM_STATE_FULLSCREEN" in window.handle.wmState

proc `fullscreen=`*(window: Window, v: bool) =
  if window.fullscreen == v: return
  if v:
    window.handle.addProperty(atom"_NET_WM_STATE", xaAtom, 32, [atom"_NET_WM_STATE_FULLSCREEN"].asString)
  else:
    var wmState = window.handle.wmState
    wmState.del wmState.find(atom"_NET_WM_STATE_FULLSCREEN")
    window.handle.setProperty(atom"_NET_WM_STATE", xaAtom, 32, wmState.asString)


proc title*(window: Window): string =
  window.handle.property(atom"_NET_WM_ICON_NAME").data

proc `title=`*(window: Window, v: string) =
  window.handle.setProperty(atom"_NET_WM_NAME", atom"UTF8_STRING", 8, v)
  window.handle.setProperty(atom"_NET_WM_ICON_NAME", atom"UTF8_STRING", 8, v)
  display.Xutf8SetWMProperties(window.handle, v, v, nil, 0, nil, nil, nil)


proc newWindow*(
  title: string,
  size: IVec2,
  vsync = true,

  # window constructor can't set opengl version, msaa and stencilBits
  # args mustn't set depthBits directly
  openglMajorVersion = 4,
  openglMinorVersion = 1,
  msaa = msaaDisabled,
  depthBits = 24,
  stencilBits = 8,
  
  transparent = false, # note that transparency CANNOT be changed after window was created
): Window =
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
    size.x.cuint, size.y.cuint,
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

proc pollEvents(window: Window) =
  template pushEvent(e) =
    try:
      if window.e != nil: window.e()
    except:
      raise CatchableError.newException("Exception during " & astToStr(name) & " callback: " & getCurrentExceptionMsg())
      # it is always bad to quit immediately

  var ev: XEvent
  
  proc checkEvent(d: Display, event: ptr XEvent, userData: pointer): bool {.cdecl.} =
    event.xany.window == cast[Window](userData).handle
  
  while display.XCheckIfEvent(ev.addr, checkEvent, cast[pointer](window)):
    case ev.kind
    
    of xeClientMessage:
      pushEvent onCloseRequest
      return

    of xeFocusIn:
      if window.ic != nil: XSetICFocus window.ic
      #TODO: press currently pressed keys
      pushEvent onFocusChange
    
    of xeFocusOut:
      if window.ic != nil: XUnsetICFocus window.ic
      #TODO: release currently pressed keys
      pushEvent onFocusChange
    
    of xeMap: window.`"_visible"` = true
    of xeUnmap: window.`"_visible"` = false

    of xeConfigure:
      # Configure means resize and move at the same time
      #TODO: check is it resize or move
      pushEvent onResize
      pushEvent onMove

    of xeMotion:
      #TODO: push event
      discard ev.xmotion.pos
    
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

proc pollEvents* =
  let ws = windows
  windows = @[]

  for window in ws:
    if window.isOpen:
      windows.add window
    else:
      destroy window

  for window in windows:
    pollEvents window
