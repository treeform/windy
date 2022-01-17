import ../../common, ../../internal, os, sequtils, sets, strformat, times,
    unicode, vmath, x11/glx, x11/keysym, x11/x, x11/xevent, x11/xlib
type
  XWindow = x.Window

  Window* = ref object
    onCloseRequest*: Callback
    onMove*: Callback
    onResize*: Callback
    onFocusChange*: Callback
    onMouseMove*: Callback
    onScroll*: Callback
    onButtonPress*: ButtonCallback
    onButtonRelease*: ButtonCallback
    onRune*: RuneCallback
    onImeChange*: Callback

    mousePos, mousePrevPos: IVec2
    buttonClicking, buttonToggle: set[Button]

    perFrame: PerFrame
    buttonPressed, buttonDown, buttonReleased: set[Button]
    lastClickTime: times.Time
    lastClickPosition: IVec2
    clickSeqLen: int

    prevSize, prevPos: IVec2

    handle: XWindow
    ctx: GlxContext
    gc: GC
    ic: XIC
    im: XIM
    xSyncCounter: XSyncCounter
    lastSync: XSyncValue

    closeRequested, closed: bool
    runeInputEnabled: bool
    innerDecorated: bool
    innerFocused: bool

  WmForDecoratedKind {.pure.} = enum
    unsupported
    motiv
    kwm
    other

var
  quitRequested*: bool
  onQuitRequest*: Callback
  multiClickInterval*: Duration = initDuration(milliseconds = 200)
  multiClickRadius*: float = 4

  initialized: bool
  windows: seq[Window]

  display: Display
  decoratedAtom: Atom
  wmForDecoratedKind: WmForDecoratedKind
  clipboardWindow: XWindow
  clipboardContent: string

proc initConstants(display: Display) =
  xaNetWMState = display.XInternAtom("_NET_WM_STATE", 0)
  xaNetWMStateMaximizedHorz = display.XInternAtom("_NET_WM_STATE_MAXIMIZED_HORZ", 0)
  xaNetWMStateMaximizedVert = display.XInternAtom("_NET_WM_STATE_MAXIMIZED_VERT", 0)
  xaWMState = display.XInternAtom("WM_STATE", 0)
  xaNetWMStateHiden = display.XInternAtom("_NET_WM_STATE_HIDDEN", 0)
  xaNetWMStateFullscreen = display.XInternAtom("_NET_WM_STATE_FULLSCREEN", 0)
  xaNetWMName = display.XInternAtom("_NET_WM_NAME", 0)
  xaUTF8String = display.XInternAtom("UTF8_STRING", 0)
  xaNetWMIconName = display.XInternAtom("_NET_WM_ICON_NAME", 0)
  xaWMDeleteWindow = display.XInternAtom("WM_DELETE_WINDOW", 0)
  xaNetWMSyncRequest = display.XInternAtom("_NET_WM_SYNC_REQUEST", 0)
  xaNetWMSyncRequestCounter = display.XInternAtom("_NET_WM_SYNC_REQUEST_COUNTER", 0)
  xaClipboard = display.XInternAtom("CLIPBOARD", 0)
  xaWindyClipboardTargetProperty = display.XInternAtom("windy_clipboardTargetProperty", 0)
  xaTargets = display.XInternAtom("TARGETS", 0)
  xaText = display.XInternAtom("TEXT", 0)

proc atomIfExist(name: string): Atom =
  display.XInternAtom(name, 1)

proc handleXError(d: Display, event: ptr XErrorEvent): bool {.cdecl.} =
  raise WindyError.newException("Error dealing with X11: " &
      $event.errorCode.Status)

proc init =
  if initialized:
    return

  XSetErrorHandler handleXError

  display = XOpenDisplay(getEnv("DISPLAY"))
  if display == nil:
    raise WindyError.newException("Error opening X11 display, make sure the DISPLAY environment variable is set correctly")

  display.initConstants()

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

proc property(
  window: XWindow,
  property: Atom
): tuple[kind: Atom, data: string] =
  var
    kind: Atom
    format: cint
    length: culong
    bytesAfter: culong
    data: cstring
  display.XGetWindowProperty(
    window,
    property,
    0,
    -1,
    false,
    0,
    kind.addr,
    format.addr,
    length.addr,
    bytesAfter.addr,
    data.addr
  )

  result.kind = kind

  let len = length.int * format.int div 8
  result.data = newString(len)
  if len != 0:
    copyMem(result.data[0].addr, data, len)

proc setProperty(
  window: XWindow, property: Atom, kind: Atom, format: cint, data: string
) =
  display.XChangeProperty(
    window,
    property,
    kind,
    format,
    pmReplace,
    data,
    data.len.cint div (format div 8)
  )

proc delProperty(window: XWindow, property: Atom) =
  display.XDeleteProperty(window, property)

proc asSeq(s: string, T: type = uint8): seq[T] =
  if s.len == 0:
    return
  result = newSeq[T]((s.len + T.sizeof - 1) div T.sizeof)
  copyMem(result[0].addr, s[0].unsafeaddr, s.len)

proc asString[T](x: seq[T]|HashSet[T]): string =
  result = newStringOfCap(x.len * T.sizeof)
  for v in x:
    for v in cast[array[T.sizeof, char]](v):
      result.add v

proc invert[T](x: var set[T], v: T) =
  if x.contains v:
    x.excl v
  else:
    x.incl v

proc send(a: XWindow, e: XEvent, mask: clong = NoEventMask, propagate = false) =
  display.XSendEvent(a, propagate, mask, e.unsafeAddr)

proc newClientMessage[T](
  window: XWindow,
  messageKind: Atom,
  data: openarray[T],
  serial: int = 0,
  sendEvent: bool = false
): XEvent =
  result.kind = xeClientMessage
  result.client.messageType = messageKind
  if data.len * T.sizeof > XClientMessageData.sizeof:
    raise WindyError.newException(&"To much data in client message (>{XClientMessageData.sizeof} bytes)")
  if data.len > 0:
    copyMem(result.client.data.addr, data[0].unsafeaddr, data.len * T.sizeof)
  result.client.format = case T.sizeof
    of 1: 8
    of 2: 16
    of 4: 32
    of 8: 32
    else: 8
  result.client.window = window
  result.client.display = display
  result.client.serial = serial.culong
  result.client.sendEvent = sendEvent

proc wmState(window: XWindow): HashSet[Atom] =
  window.property(xaNetWMState).data.asSeq(Atom).toHashSet

proc wmStateSend(window: XWindow, op: int, atom: Atom) =
  # op: 2 - switch, 1 - set true, 0 - set false
  display.defaultRootWindow.send(
    window.newClientMessage(xaNetWMState, [Atom op, atom]),
    SubstructureNotifyMask or SubstructureRedirectMask
  )

proc keysymToButton(sym: KeySym): Button =
  case sym
  of xk_shiftL: KeyLeftShift
  of xk_shiftR: KeyRightShift
  of xk_controlL: KeyLeftControl
  of xk_controlR: KeyRightControl
  of xk_bracketLeft: KeyLeftBracket
  of xk_bracketRight: KeyRightBracket
  of xk_altL: KeyLeftAlt
  of xk_altR: KeyRightAlt
  of xk_superL: KeyLeftSuper
  of xk_superR: KeyRightSuper
  of xk_menu: KeyMenu
  of xk_escape: KeyEscape
  of xk_semicolon: KeySemicolon
  of xk_slash: KeySlash
  of xk_equal: KeyEqual
  of xk_minus: KeyMinus
  of xk_comma: KeyComma
  of xk_period: KeyPeriod
  of xk_apostrophe: KeyApostrophe
  of xk_backslash: KeyBackslash
  of xk_grave: KeyBacktick
  of xk_space: KeySpace
  of xk_return: KeyEnter
  of xk_kpEnter: KeyEnter
  of xk_backspace: KeyBackspace
  of xk_tab: KeyTab
  of xk_prior: KeyPage_up
  of xk_next: KeyPage_down
  of xk_end: KeyEnd
  of xk_home: KeyHome
  of xk_insert: KeyInsert
  of xk_delete: KeyDelete
  of xk_kpAdd: NumpadAdd
  of xk_kpSubtract: NumpadSubtract
  of xk_kpMultiply: NumpadMultiply
  of xk_kpDivide: NumpadDivide
  of xk_capsLock: KeyCapsLock
  of xk_numLock: KeyNumLock
  of xk_scrollLock: KeyScrollLock
  of xk_print: KeyPrintScreen
  of xk_kpSeparator: NumpadDecimal
  of xk_pause: KeyPause
  of xk_f1: KeyF1
  of xk_f2: KeyF2
  of xk_f3: KeyF3
  of xk_f4: KeyF4
  of xk_f5: KeyF5
  of xk_f6: KeyF6
  of xk_f7: KeyF7
  of xk_f8: KeyF8
  of xk_f9: KeyF9
  of xk_f10: KeyF10
  of xk_f11: KeyF11
  of xk_f12: KeyF12
  of xk_left: KeyLeft
  of xk_right: KeyRight
  of xk_up: KeyUp
  of xk_down: KeyDown
  of xk_kpInsert: Numpad0
  of xk_kpEnd: Numpad1
  of xk_kpDown: Numpad2
  of xk_kpPagedown: Numpad3
  of xk_kpLeft: Numpad4
  of xk_kpBegin: Numpad5
  of xk_kpRight: Numpad6
  of xk_kpHome: Numpad7
  of xk_kpUp: Numpad8
  of xk_kpPageup: Numpad9
  of xk_a: KeyA
  of xk_b: KeyB
  of xk_c: KeyC
  of xk_d: KeyD
  of xk_e: KeyR
  of xk_f: KeyF
  of xk_g: KeyG
  of xk_h: KeyH
  of xk_i: KeyI
  of xk_j: KeyJ
  of xk_k: KeyK
  of xk_l: KeyL
  of xk_m: KeyM
  of xk_n: KeyN
  of xk_o: KeyO
  of xk_p: KeyP
  of xk_q: KeyQ
  of xk_r: KeyR
  of xk_s: KeyS
  of xk_t: KeyT
  of xk_u: KeyU
  of xk_v: KeyV
  of xk_w: KeyW
  of xk_x: KeyX
  of xk_y: KeyY
  of xk_z: KeyZ
  of xk_0: Key0
  of xk_1: Key1
  of xk_2: Key2
  of xk_3: Key3
  of xk_4: Key4
  of xk_5: Key5
  of xk_6: Key6
  of xk_7: Key7
  of xk_8: Key8
  of xk_9: Key9
  else: ButtonUnknown

proc queryKeyboardState(): set[0..255] =
  var r: array[32, char]
  display.XQueryKeymap(r)
  return cast[ptr set[0..255]](r.addr)[]

proc destroy(window: Window) =
  if window.ic != nil:
    XDestroyIC(window.ic)
  if window.im != nil:
    XCloseIM(window.im)
  if window.gc != nil:
    display.XFreeGC(window.gc)
  if window.handle != 0:
    display.XDestroyWindow(window.handle)
  if window.xSyncCounter.int != 0:
    display.XSyncDestroyCounter(window.xSyncCounter)
  wasMoved window[]
  window.closed = true

proc closed*(window: Window): bool = window.closed

proc close*(window: Window) =
  destroy window

proc makeContextCurrent*(window: Window) =
  display.glXMakeCurrent(window.handle, window.ctx)

proc swapBuffers*(window: Window) =
  display.glXSwapBuffers(window.handle)

template blockUntil(expression: untyped) {.dirty.} =
  ## In X11 many properties are async, you change them and then it takes
  ## time for them to take effect. This is different from Win/Mac. This
  ## waits till property changes before continueing to mach behavior.
  ## It will stop waiting eventually though and just return.
  let start = epochTime()
  while true:
    if expression:
      break
    if epochTime() - start > 0.500:
      # We could throw exception here, Chrome + GLFW do not though,
      # and just let it slide, giving it kind of best effort.
      break
    sleep(1)

proc visible*(window: Window): bool =
  var
    attributes: XWindowAttributes
  display.XGetWindowAttributes(window.handle, attributes.addr)
  return attributes.map_state == IsViewable

proc `visible=`*(window: Window, v: bool) =
  if v:
    display.XMapWindow(window.handle)
  else:
    display.XUnmapWindow(window.handle)
  blockUntil(window.visible == v)

proc pos*(window: Window): IVec2 =
  var
    child: XWindow
  display.XTranslateCoordinates(
    window.handle,
    display.defaultRootWindow,
    0,
    0,
    result.x.addr,
    result.y.addr,
    child.addr
  )

proc borderSize(window: Window): IVec2 =
  # Figure out the chrome size of the window.
  let originalValue = window.pos
  display.XMoveWindow(window.handle, 100, 100)
  blockUntil(originalValue != window.pos)
  return window.pos - ivec2(100, 100)

proc `pos=`*(window: Window, v: IVec2) =
  let v = v - window.borderSize()
  let originalValue = window.pos
  if originalValue == v:
    return
  display.XMoveWindow(window.handle, v.x, v.y)
  blockUntil(originalValue != window.pos)

proc size*(window: Window): IVec2 =
  var
    attributes: XWindowAttributes
  display.XGetWindowAttributes(window.handle, attributes.addr)
  return attributes.size

proc framebufferSize*(window: Window): IVec2 =
  window.size

proc `size=`*(window: Window, v: IVec2) =
  let originalValue = window.size
  if originalValue == v:
    return

  # Its important to swap buffers so that openGL viewport updates.
  window.swapBuffers()
  # TODO: for some reason Chrome GLFW just do display.XFlush() and its enough?
  display.XResizeWindow(window.handle, v.x.uint32, v.y.uint32)

  blockUntil(originalValue != window.size)

proc maximized*(window: Window): bool =
  let wmState = window.handle.wmState
  return xaNetWMStateMaximizedHorz in wmState and
    xaNetWMStateMaximizedVert in wmState

proc `maximized=`*(window: Window, v: bool) =
  window.handle.wmStateSend(v.int, xaNetWMStateMaximizedHorz)
  window.handle.wmStateSend(v.int, xaNetWMStateMaximizedVert)
  blockUntil(window.maximized == v)

proc minimized*(window: Window): bool =
  let wState = window.handle.property(xaWMState).data.asSeq(int32)
  return wState.len >= 1 and wState[0] == 3 or
    xaNetWMStateHiden in window.handle.wmState

proc `minimized=`*(window: Window, v: bool) =
  if v:
    display.XIconifyWindow(window.handle, display.defaultScreen)
  else:
    display.XRaiseWindow(window.handle)
  blockUntil(window.minimized == v)

proc focused*(window: Window): bool =
  return window.innerFocused

proc focus*(window: Window) =
  display.XSetInputFocus(window.handle, rtNone)

proc fullscreen*(window: Window): bool =
  xaNetWMStateFullscreen in window.handle.wmState

proc `fullscreen=`*(window: Window, v: bool) =
  window.handle.wmStateSend(v.int, xaNetWMStateFullscreen)
  blockUntil(window.fullscreen == v)

proc style*(window: Window): WindowStyle =
  if window.innerDecorated:
    var hints: XSizeHints
    display.XGetNormalHints(window.handle, hints.addr)
    if (hints.flags and 0b110000) == 0b110000:
      WindowStyle.Decorated
    else:
      WindowStyle.DecoratedResizable
  else:
    WindowStyle.Undecorated

proc `style=`*(window: Window, v: WindowStyle) =
  if window.fullscreen:
    return

  let currentStyle = window.style
  if currentStyle == v:
    return

  template addDecorations() {.dirty.} =
    window.innerDecorated = true
    case wmForDecoratedKind
    of WmForDecoratedKind.motiv,
        WmForDecoratedKind.kwm,
        WmForDecoratedKind.other:
      window.handle.delProperty(decoratedAtom)

      display.XSetTransientForHint(window.handle, 0)
      if window.visible:
        # "reopen" window
        display.XUnmapWindow(window.handle)
        display.XMapWindow(window.handle)

      window.size = size # restore window size
    else:
      discard

  case v
  of WindowStyle.Undecorated:
    window.innerDecorated = false
    let size = window.size # save current window size

    case wmForDecoratedKind
    of WmForDecoratedKind.motiv:
      window.handle.setProperty(
        decoratedAtom, decoratedAtom, 32, @[1 shl 1, 0, 0, 0, 0].asString
      )
    of WmForDecoratedKind.kwm, WmForDecoratedKind.other:
      window.handle.setProperty(
        decoratedAtom, decoratedAtom, 32, @[0'i32].asString
      )
    else:
      return

    display.XSetTransientForHint(window.handle, display.defaultRootWindow)
    if window.visible:
      # "reopen" window
      display.XUnmapWindow(window.handle)
      display.XMapWindow(window.handle)

    window.size = size # restore window size

  of WindowStyle.Decorated:
    let size = window.size

    if currentStyle == WindowStyle.Undecorated:
      addDecorations()

    # make window unresizable
    var hints = XSizeHints(
      flags: 0b110000,
      minSize: size,
      maxSize: size
    )
    display.XSetNormalHints(window.handle, hints.addr)

  of WindowStyle.DecoratedResizable:
    let size = window.size

    if currentStyle == WindowStyle.Undecorated:
      addDecorations()

    # make window resizable
    var hints = XSizeHints(flags: 0)
    display.XSetNormalHints(window.handle, hints.addr)

proc title*(window: Window): string =
  window.handle.property(xaNetWMName).data

proc `title=`*(window: Window, v: string) =
  window.handle.setProperty(xaNetWMName, xaUTF8String, 8, v)
  window.handle.setProperty(xaNetWMIconName, xaUTF8String, 8, v)
  display.Xutf8SetWMProperties(window.handle, v, v, nil, 0, nil, nil, nil)

proc contentScale*(window: Window): float32 =
  const pixelsPerMillimeter = 25.4
  const defaultScreenDpi = 96
  let s = display.screen(display.defaultScreen)
  (s.size.vec2 * pixelsPerMillimeter / s.msize.vec2 / defaultScreenDpi).x

proc runeInputEnabled*(window: Window): bool =
  window.runeInputEnabled

proc `runeInputEnabled=`*(window: Window, v: bool) =
  window.runeInputEnabled = v

proc newWindow*(
  title: string,
  size: IVec2,
  visible = true,
  vsync = true,

  openglMajorVersion = 4,
  openglMinorVersion = 1,
  msaa = msaaDisabled,
  depthBits = 24,
  stencilBits = 8,

  transparent = false,
): Window =
  ## Creates a new window. Intitializes Windy if needed.
  init()
  result = Window()
  result.innerDecorated = true
  result.runeInputEnabled = true

  let root = display.defaultRootWindow

  var vi: XVisualInfo
  if transparent:
    display.XMatchVisualInfo(display.defaultScreen, 32, TrueColor, vi.addr)
  else:
    display.XMatchVisualInfo(display.defaultScreen, 24, TrueColor, vi.addr)
    # strangely, glx returns nil when -d:danger
    # var attribList = [GlxRgba, GlxDepthSize, 24, GlxDoublebuffer]
    # vi = display.glXChooseVisual(display.defaultScreen, attribList[0].addr)[]

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
    CwColormap or CwEventMask or CwBorderPixel,
    swa.addr
  )

  display.XSelectInput(
    result.handle,
    ExposureMask or
    KeyPressMask or
    KeyReleaseMask or
    PointerMotionMask or
    ButtonPressMask or
    ButtonReleaseMask or
    StructureNotifyMask or
    EnterWindowMask or
    LeaveWindowMask or
    FocusChangeMask
  )

  var wmProtocols = [xaWMDeleteWindow, xaNetWMSyncRequest]
  display.XSetWMProtocols(
    result.handle, wmProtocols[0].addr, cint wmProtocols.len
  )

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
    raise WindyError.newException("Error creating OpenGL context")

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
      raise WindyError.newException("VSync is not supported")

  if visible:
    result.visible = true

  block xsync:
    var vEv, vEr: cint
    if display.XSyncQueryExtension(vEv.addr, vEr.addr):
      var vMaj, vMin: cint
      display.XSyncInitialize(vMaj.addr, vMin.addr)
      result.xSyncCounter = display.XSyncCreateCounter(XSyncValue())
      result.handle.setProperty(
        xaNetWMSyncRequestCounter,
        xaCardinal,
        32,
        @[result.xSyncCounter].asString
      )

  windows.add result

proc pollEvents(window: Window) =

  # Clear all per-frame data
  window.perFrame = PerFrame()
  window.buttonPressed = {}
  window.buttonReleased = {}

  # signal that frame was drawn
  display.XSyncSetCounter(window.xSyncCounter, window.lastSync)

  var ev: XEvent

  proc checkEvent(
    d: Display,
    event: ptr XEvent,
    userData: pointer
  ): bool {.cdecl.} =
    event.any.window == cast[Window](userData).handle

  template pushButtonEvent(
    button: Button,
    press: bool = ev.kind == xeButtonPress
  ) =
    if press:
      window.buttonDown.incl button
      window.buttonPressed.incl button
      window.buttonClicking.incl button
      window.buttonToggle.invert button
      if window.onButtonPress != nil:
        window.onButtonPress(button)
    else:
      window.buttonDown.excl button
      window.buttonReleased.incl button
      if window.onButtonRelease != nil:
        window.onButtonRelease(button)

  while display.XCheckIfEvent(ev.addr, checkEvent, cast[pointer](window)):
    case ev.kind

    of xeClientMessage:
      if ev.client.data.l[0] == xaWMDeleteWindow.clong:
        window.closeRequested = true
        if window.onCloseRequest != nil:
          window.onCloseRequest()
        return # end polling events immediently

      elif ev.client.data.l[0] == xaNetWMSyncRequest.clong:
        window.lastSync = XSyncValue(
          lo: cast[uint32](ev.client.data.l[2]),
          hi: cast[int32](ev.client.data.l[3])
        )

    of xeFocusIn:
      if window.innerFocused:
        return # was duplicated
      window.innerFocused = true

      if window.ic != nil:
        XSetICFocus window.ic

      # press currently pressed keys
      for k in queryKeyboardState().mapit(
          keysymToButton display.XKeycodeToKeysym(it.cuchar, 0
        )):
        if k == ButtonUnknown:
          continue
        pushButtonEvent(k, true)

      if window.onFocusChange != nil:
        window.onFocusChange()

    of xeFocusOut:
      if not window.innerFocused:
        return # was duplicated
      window.innerFocused = false

      if window.ic != nil:
        XUnsetICFocus window.ic

      # release currently pressed keys
      let bd = window.buttonDown
      window.buttonDown = {}
      for k in bd:
        pushButtonEvent(k.Button, false)

      if window.onFocusChange != nil:
        window.onFocusChange()

    of xeConfigure:
      let pos = window.pos
      if pos != window.prevPos:
        window.prevPos = pos
        if window.onMove != nil:
          window.onMove()

      if ev.configure.size != window.prevSize:
        window.prevSize = ev.configure.size
        if window.onResize != nil:
          window.onResize()

    of xeMotion:
      window.mousePrevPos = window.mousePos
      window.mousePos = ev.motion.pos
      window.perFrame.mouseDelta += window.mousePos - window.mousePrevPos
      if (window.mousePos - window.lastClickPosition).vec2.length > multiClickRadius:
        window.buttonClicking = {}
        window.clickSeqLen = 0
      if window.onMouseMove != nil:
        window.onMouseMove()

    of xeButtonPress, xeButtonRelease:

      template pushScrollEvent(delta: Vec2) =
        window.perFrame.scrollDelta = delta
        if window.onScroll != nil:
          window.onScroll()

      let
        now = getTime()
        isDblclk = now - window.lastClickTime <= multiClickInterval
      window.lastClickTime = now
      window.lastClickPosition = window.mousePos

      case ev.button.button
      of 1:
        pushButtonEvent(MouseLeft)

        if ev.kind == xeButtonRelease and MouseLeft in window.buttonClicking and isDblclk:
          inc window.clickSeqLen
          if window.clickSeqLen >= 2:
            pushButtonEvent(DoubleClick)
          if window.clickSeqLen >= 3:
            pushButtonEvent(TripleClick)
          if window.clickSeqLen >= 4:
            pushButtonEvent(QuadrupleClick)

      of 2: pushButtonEvent(MouseMiddle)
      of 3: pushButtonEvent(MouseRight)
      of 8: pushButtonEvent(MouseButton4)
      of 9: pushButtonEvent(MouseButton5)

      of 4: pushScrollEvent(vec2(0, 1)) # scroll up
      of 5: pushScrollEvent(vec2(0, -1)) # scroll down
      of 6: pushScrollEvent(vec2(-1, 0)) # scroll left?
      of 7: pushScrollEvent(vec2(1, 0)) # scroll right?
      else: discard

      if not isDblclk:
        window.clickSeqLen = 0

    of xeKeyPress, xeKeyRelease:
      var key = ButtonUnknown
      var i = 0
      while i < 4 and key == ButtonUnknown:
        key = keysymToButton(XLookupKeysym(ev.key.addr, i.cint))
        inc i
      if key != ButtonUnknown:
        pushButtonEvent(key, ev.kind == xeKeyPress)

      # handle text input
      if window.runeInputEnabled and
        ev.kind == xeKeyPress and
        window.ic != nil and
        (ev.key.state and ControlMask) == 0:
          var
            status: cint
            s = newString(16)
          s.setLen(window.ic.Xutf8LookupString(
            ev.key.addr, s.cstring, 16, nil, status.addr
          ))
          if s != "\u001B": # Ignore ESC.
            for rune in s.runes:
              if window.onRune != nil:
                window.onRune(rune)
    else:
      discard

proc mousePos*(window: Window): IVec2 =
  window.mousePos

proc mousePrevPos*(window: Window): IVec2 =
  window.mousePrevPos

proc mouseDelta*(window: Window): IVec2 =
  window.perFrame.mouseDelta

proc scrollDelta*(window: Window): Vec2 =
  window.perFrame.scrollDelta

proc buttonDown*(window: Window): ButtonView =
  ButtonView window.buttonDown

proc buttonPressed*(window: Window): ButtonView =
  ButtonView window.buttonPressed

proc buttonReleased*(window: Window): ButtonView =
  ButtonView window.buttonReleased

proc buttonToggle*(window: Window): ButtonView =
  ButtonView window.buttonToggle

proc closeRequested*(window: Window): bool =
  window.closeRequested

proc `closeRequested=`*(window: Window, v: bool) =
  window.closeRequested = v
  if v:
    if window.onCloseRequest != nil:
      window.onCloseRequest()

proc initClipboard =
  if clipboardWindow != 0:
    return
  clipboardWindow = display.XCreateSimpleWindow(
    display.defaultRootWindow, 0, 0, 1, 1, 0, 0, 0
  )

proc processClipboardEvents: bool =
  var ev: XEvent

  proc checkEvent(
    d: Display,
    event: ptr XEvent,
    userData: pointer
  ): bool {.cdecl.} =
    event.any.window == cast[Window](userData).handle

  while display.XCheckIfEvent(
    ev.addr, checkEvent, cast[pointer](clipboardWindow)
  ):
    case ev.kind
    of xeSelection:
      template e: untyped = ev.selection

      if e.property == 0 or e.selection != xaClipboard:
        continue

      clipboardContent = clipboardWindow.property(
        xaWindyClipboardTargetProperty
      ).data
      clipboardWindow.delProperty(xaWindyClipboardTargetProperty)

      return true

    of xeSelectionRequest:
      template e: untyped = ev.selectionRequest

      var resp = XSelectionEvent(
        kind: xeSelection,
        requestor: e.requestor,
        selection: e.selection,
        property: e.property,
        target: e.target,
        time: e.time
      )

      if e.selection == xaClipboard:
        if e.target == xaTargets:
          # request requests that we can handle
          e.requestor.setProperty(e.property, xaAtom, 32, @[
            xaTargets,
            xaText,
            xaString,
            xaUTF8String
          ].asString)
          e.requestor.send(XEvent(selection: resp), propagate = true)
          continue

        elif e.target in {xaString, xaText, xaUTF8String}:
          # request clipboard data
          e.requestor.setProperty(e.property, xaAtom, 8, clipboardContent)
          e.requestor.send(XEvent(selection: resp), propagate = true)
          continue

      # we can't handle this request
      resp.property = 0
      e.requestor.send(XEvent(selection: resp), propagate = true)

    else:
      discard

proc getClipboardString*: string =
  initClipboard()
  if display.XGetSelectionOwner(xaClipboard) == 0:
    return ""

  if display.XGetSelectionOwner(xaClipboard) == clipboardWindow:
    return clipboardContent

  display.XConvertSelection(
    xaClipboard,
    xaUTF8String,
    xaWindyClipboardTargetProperty,
    clipboardWindow
  )

  while not processClipboardEvents(): discard
  result = clipboardContent
  clipboardContent = ""

proc setClipboardString*(s: string) =
  initClipboard()
  clipboardContent = s
  display.XSetSelectionOwner(xaClipboard, clipboardWindow)

proc pollEvents* =
  let ws = windows
  windows = @[]

  for window in ws:
    if window.closed:
      destroy window
    else:
      windows.add window

  if clipboardWindow != 0:
    discard processClipboardEvents()
  for window in windows:
    pollEvents window

proc closeIme*(window: Window) =
  discard

proc imeCursorIndex*(window: Window): int =
  discard

proc imeCompositionString*(window: Window): string =
  discard
