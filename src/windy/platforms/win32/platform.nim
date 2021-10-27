import ../../common, ../../internal, times, unicode, utils, vmath, windefs

const
  windowClassName = "WINDY0"
  defaultScreenDpi = 96
  wheelDelta = 120
  multiClickRadius = 4
  decoratedWindowStyle = WS_OVERLAPPEDWINDOW
  undecoratedWindowStyle = WS_POPUP

  WGL_DRAW_TO_WINDOW_ARB = 0x2001
  WGL_ACCELERATION_ARB = 0x2003
  WGL_SUPPORT_OPENGL_ARB = 0x2010
  WGL_DOUBLE_BUFFER_ARB = 0x2011
  WGL_PIXEL_TYPE_ARB = 0x2013
  WGL_COLOR_BITS_ARB = 0x2014
  WGL_DEPTH_BITS_ARB = 0x2022
  WGL_STENCIL_BITS_ARB = 0x2023
  WGL_FULL_ACCELERATION_ARB = 0x2027
  WGL_TYPE_RGBA_ARB = 0x202B
  WGL_SAMPLES_ARB = 0x2042

  WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091
  WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092
  WGL_CONTEXT_PROFILE_MASK_ARB = 0x9126
  WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001
  # WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB = 0x00000002
  WGL_CONTEXT_FLAGS_ARB = 0x2094
  # WGL_CONTEXT_DEBUG_BIT_ARB = 0x0001
  WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB = 0x0002

type
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

    title: string
    closeRequested, closed: bool
    perFrame: PerFrame
    trackMouseEventRegistered: bool
    mousePos: IVec2
    buttonPressed, buttonDown, buttonReleased, buttonToggle: set[Button]
    exitFullscreenInfo: ExitFullscreenInfo
    doubleClickTime: float64
    tripleClickTimes: array[2, float64]
    quadrupleClickTimes: array[3, float64]
    multiClickPositions: array[3, IVec2]

    imePos*: IVec2
    imeCursorIndex: int
    imeCompositionString: string

    hWnd: HWND
    hdc: HDC
    hglrc: HGLRC

  ButtonView* = object
    states: set[Button]

  ExitFullscreenInfo = ref object
    maximized: bool
    style: LONG
    rect: RECT

var
  wglCreateContext: wglCreateContext
  wglDeleteContext: wglDeleteContext
  wglGetProcAddress: wglGetProcAddress
  wglGetCurrentDC: wglGetCurrentDC
  wglGetCurrentContext: wglGetCurrentContext
  wglMakeCurrent: wglMakeCurrent
  wglCreateContextAttribsARB: wglCreateContextAttribsARB
  wglChoosePixelFormatARB: wglChoosePixelFormatARB
  wglSwapIntervalEXT: wglSwapIntervalEXT
  SetProcessDpiAwarenessContext: SetProcessDpiAwarenessContext
  GetDpiForWindow: GetDpiForWindow
  AdjustWindowRectExForDpi: AdjustWindowRectExForDpi

var
  initialized: bool
  helperWindow: HWND
  platformDoubleClickInterval: float64
  windows: seq[Window]

proc indexForHandle(windows: seq[Window], hWnd: HWND): int =
  ## Returns the window for this handle, else -1
  for i, window in windows:
    if window.hWnd == hWnd:
      return i
  -1

proc forHandle(windows: seq[Window], hWnd: HWND): Window =
  ## Returns the window for this window handle, else nil
  let index = windows.indexForHandle(hWnd)
  if index == -1:
    return nil
  windows[index]

proc registerWindowClass(windowClassName: string, wndProc: WNDPROC) =
  let wideWindowClassName = windowClassName.wstr()

  var wc: WNDCLASSEXW
  wc.cbSize = sizeof(WNDCLASSEXW).UINT
  wc.style = CS_HREDRAW or CS_VREDRAW
  wc.lpfnWndProc = wndProc
  wc.hInstance = GetModuleHandleW(nil)
  wc.hCursor = LoadCursorW(0, IDC_ARROW)
  wc.lpszClassName = cast[ptr WCHAR](wideWindowClassName[0].unsafeAddr)
  wc.hIcon = LoadImageW(
    0,
    IDI_APPLICATION,
    IMAGE_ICON,
    0,
    0,
    LR_DEFAULTSIZE or LR_SHARED
  )

  if RegisterClassExW(wc.addr) == 0:
    raise newException(WindyError, "Error registering window class")

proc createWindow(windowClassName, title: string, size: IVec2): HWND =
  let
    wideWindowClassName = windowClassName.wstr()
    wideTitle = title.wstr()

  var size = size
  if size != ivec2(CW_USEDEFAULT, CW_USEDEFAULT):
    # Adjust the window creation size for window styles (border, etc)
    var rect = Rect(top: 0, left: 0, right: size.x, bottom: size.y)
    discard AdjustWindowRectExForDpi(
      rect.addr,
      decoratedWindowStyle,
      0,
      WS_EX_APPWINDOW,
      defaultScreenDpi
    )
    size.x = rect.right - rect.left
    size.y = rect.bottom - rect.top

  result = CreateWindowExW(
    WS_EX_APPWINDOW,
    cast[ptr WCHAR](wideWindowClassName[0].unsafeAddr),
    cast[ptr WCHAR](wideTitle[0].unsafeAddr),
    decoratedWindowStyle,
    CW_USEDEFAULT,
    CW_USEDEFAULT,
    size.x,
    size.y,
    0,
    0,
    GetModuleHandleW(nil),
    nil
  )
  if result == 0:
    raise newException(WindyError, "Creating native window failed")

  let key = "Windy".wstr()
  discard SetPropW(result, cast[ptr WCHAR](key[0].unsafeAddr), 1)

proc destroy(window: Window) =
  window.onCloseRequest = nil
  window.onMove = nil
  window.onResize = nil
  window.onFocusChange = nil

  if window.hglrc != 0:
    discard wglMakeCurrent(window.hdc, 0)
    discard wglDeleteContext(window.hglrc)
    window.hglrc = 0
  if window.hdc != 0:
    discard ReleaseDC(window.hWnd, window.hdc)
    window.hdc = 0
  if window.hWnd != 0:
    let key = "Windy".wstr()
    discard RemovePropW(window.hWnd, cast[ptr WCHAR](key[0].unsafeAddr))
    discard DestroyWindow(window.hWnd)
    let index = windows.indexForHandle(window.hWnd)
    if index != -1:
      windows.delete(index)
    window.hWnd = 0

proc getDC(hWnd: HWND): HDC =
  result = GetDC(hWnd)
  if result == 0:
    raise newException(WindyError, "Error getting window DC")

proc getWindowStyle(hWnd: HWND): LONG =
  GetWindowLongW(hWnd, GWL_STYLE)

proc updateWindowStyle(hWnd: HWND, style: LONG) =
  var rect: RECT
  discard GetClientRect(hWnd, rect.addr)
  discard AdjustWindowRectExForDpi(
    rect.addr,
    style,
    0,
    WS_EX_APPWINDOW,
    GetDpiForWindow(hWnd)
  )

  discard ClientToScreen(hWnd, cast[ptr POINT](rect.left.addr))
  discard ClientToScreen(hWnd, cast[ptr POINT](rect.right.addr))

  discard SetWindowLongW(hWnd, GWL_STYLE, style)

  echo SetWindowPos(
    hWnd,
    HWND_TOP,
    rect.left,
    rect.top,
    rect.right - rect.left,
    rect.bottom - rect.top,
    SWP_FRAMECHANGED or SWP_NOACTIVATE or SWP_NOZORDER
  )

proc makeContextCurrent(hdc: HDC, hglrc: HGLRC) =
  if wglMakeCurrent(hdc, hglrc) == 0:
    raise newException(WindyError, "Error activating OpenGL rendering context")

proc monitorInfo(window: Window): MONITORINFO =
  result.cbSize = sizeof(MONITORINFO).DWORD
  discard GetMonitorInfoW(
    MonitorFromWindow(window.hWnd, MONITOR_DEFAULTTONEAREST),
    result.addr
  )

proc title*(window: Window): string =
  window.title

proc closed*(window: Window): bool =
  window.closed

proc visible*(window: Window): bool =
  IsWindowVisible(window.hWnd) != 0

proc decorated*(window: Window): bool =
  let style = getWindowStyle(window.hWnd)
  (style and WS_BORDER) != 0

proc resizable*(window: Window): bool =
  let style = getWindowStyle(window.hWnd)
  (style and WS_THICKFRAME) != 0

proc fullscreen*(window: Window): bool =
  window.exitFullscreenInfo != nil

proc size*(window: Window): IVec2 =
  var rect: RECT
  discard GetClientRect(window.hWnd, rect.addr)
  ivec2(rect.right, rect.bottom)

proc pos*(window: Window): IVec2 =
  var pos: POINT
  discard ClientToScreen(window.hWnd, pos.addr)
  ivec2(pos.x, pos.y)

proc minimized*(window: Window): bool =
  IsIconic(window.hWnd) != 0

proc maximized*(window: Window): bool =
  IsZoomed(window.hWnd) != 0

proc framebufferSize*(window: Window): IVec2 =
  window.size

proc contentScale*(window: Window): float32 =
  let dpi = GetDpiForWindow(window.hWnd)
  result = dpi.float32 / defaultScreenDpi

proc focused*(window: Window): bool =
  window.hWnd == GetActiveWindow()

proc mousePos*(window: Window): IVec2 =
  window.mousePos

proc mousePrevPos*(window: Window): IVec2 =
  window.perFrame.mousePrevPos

proc mouseDelta*(window: Window): IVec2 =
  window.perFrame.mouseDelta

proc scrollDelta*(window: Window): Vec2 =
  window.perFrame.scrollDelta

proc closeRequested*(window: Window): bool =
  window.closeRequested

proc imeCursorIndex*(window: Window): int =
  window.imeCursorIndex

proc imeCompositionString*(window: Window): string =
  window.imeCompositionString

proc `title=`*(window: Window, title: string) =
  window.title = title
  var wideTitle = title.wstr()
  discard SetWindowTextW(window.hWnd, cast[ptr WCHAR](wideTitle[0].addr))

proc `visible=`*(window: Window, visible: bool) =
  if visible:
    discard ShowWindow(window.hWnd, SW_SHOW)
  else:
    discard ShowWindow(window.hWnd, SW_HIDE)

proc `decorated=`*(window: Window, decorated: bool) =
  if window.fullscreen:
    return

  var style: LONG
  if decorated:
    style = decoratedWindowStyle
  else:
    style = undecoratedWindowStyle

  if window.visible:
    style = style or WS_VISIBLE

  updateWindowStyle(window.hWnd, style)

proc `resizable=`*(window: Window, resizable: bool) =
  if window.fullscreen:
    return
  if not window.decorated:
    return

  var style = decoratedWindowStyle.LONG
  if resizable:
    style = style or (WS_MAXIMIZEBOX or WS_THICKFRAME)
  else:
    style = style and not (WS_MAXIMIZEBOX or WS_THICKFRAME)

  if window.visible:
    style = style or WS_VISIBLE

  updateWindowStyle(window.hWnd, style)

proc `fullscreen=`*(window: Window, fullscreen: bool) =
  if window.fullscreen == fullscreen:
    return

  if fullscreen:
    # Save some window info for restoring when exiting fullscreen
    window.exitFullscreenInfo = ExitFullscreenInfo()
    window.exitFullscreenInfo.maximized = window.maximized
    if window.maximized:
      discard SendMessageW(window.hWnd, WM_SYSCOMMAND, SC_RESTORE, 0)
    window.exitFullscreenInfo.style = getWindowStyle(window.hWnd)
    discard GetWindowRect(window.hWnd, window.exitFullscreenInfo.rect.addr)

    var style = undecoratedWindowStyle

    if window.visible:
      style = style or WS_VISIBLE

    discard SetWindowLongW(window.hWnd, GWL_STYLE, style)

    let mi = window.monitorInfo
    discard SetWindowPos(
      window.hWnd,
      HWND_TOPMOST,
      mi.rcMonitor.left,
      mi.rcMonitor.top,
      mi.rcMonitor.right - mi.rcMonitor.left,
      mi.rcMonitor.bottom - mi.rcMonitor.top,
      SWP_NOZORDER or SWP_NOACTIVATE or SWP_FRAMECHANGED
    )
  else:
    var style = window.exitFullscreenInfo.style

    if window.visible:
      style = style or WS_VISIBLE
    else:
      style = style and (not WS_VISIBLE)

    discard SetWindowLongW(window.hWnd, GWL_STYLE, style)

    let
      maximized = window.exitFullscreenInfo.maximized
      rect = window.exitFullscreenInfo.rect

    # Make sure window.fullscreen returns false in the resize callbacks
    # that get triggered after this.
    window.exitFullscreenInfo = nil

    discard SetWindowPos(
      window.hWnd,
      HWND_TOP,
      rect.left,
      rect.top,
      rect.right - rect.left,
      rect.bottom - rect.top,
      SWP_NOZORDER or SWP_NOACTIVATE or SWP_FRAMECHANGED
    )

    if maximized:
      discard SendMessageW(window.hWnd, WM_SYSCOMMAND, SC_MAXIMIZE, 0)

proc `size=`*(window: Window, size: IVec2) =
  if window.fullscreen:
    return

  var rect = RECT(top: 0, left: 0, right: size.x, bottom: size.y)
  discard AdjustWindowRectExForDpi(
    rect.addr,
    getWindowStyle(window.hWnd),
    0,
    WS_EX_APPWINDOW,
    GetDpiForWindow(window.hWnd)
  )
  discard SetWindowPos(
    window.hWnd,
    HWND_TOP,
    0,
    0,
    rect.right - rect.left,
    rect.bottom - rect.top,
    SWP_NOACTIVATE or SWP_NOZORDER or SWP_NOMOVE
  )

proc `pos=`*(window: Window, pos: IVec2) =
  if window.fullscreen:
    return

  var rect = RECT(top: pos.x, left: pos.y, bottom: pos.x, right: pos.y)
  discard AdjustWindowRectExForDpi(
    rect.addr,
    getWindowStyle(window.hWnd),
    0,
    WS_EX_APPWINDOW,
    GetDpiForWindow(window.hWnd)
  )
  discard SetWindowPos(
    window.hWnd,
    HWND_TOP,
    rect.left,
    rect.top,
    0,
    0,
    SWP_NOACTIVATE or SWP_NOZORDER or SWP_NOSIZE
  )

proc `minimized=`*(window: Window, minimized: bool) =
  var cmd: int32
  if minimized:
    cmd = SW_MINIMIZE
  else:
    cmd = SW_RESTORE
  discard ShowWindow(window.hWnd, cmd)

proc `maximized=`*(window: Window, maximized: bool) =
  var cmd: int32
  if maximized:
    cmd = SW_MAXIMIZE
  else:
    cmd = SW_RESTORE
  discard ShowWindow(window.hWnd, cmd)

proc `closeRequested=`*(window: Window, closeRequested: bool) =
  window.closeRequested = closeRequested
  if closeRequested:
    if window.onCloseRequest != nil:
      window.onCloseRequest()

proc loadOpenGL() =
  let opengl = LoadLibraryA("opengl32.dll")
  if opengl == 0:
    raise newException(WindyError, "Loading opengl32.dll failed")

  wglCreateContext =
    cast[wglCreateContext](GetProcAddress(opengl, "wglCreateContext"))
  wglDeleteContext =
    cast[wglDeleteContext](GetProcAddress(opengl, "wglDeleteContext"))
  wglGetProcAddress =
    cast[wglGetProcAddress](GetProcAddress(opengl, "wglGetProcAddress"))
  wglGetCurrentDC =
    cast[wglGetCurrentDC](GetProcAddress(opengl, "wglGetCurrentDC"))
  wglGetCurrentContext =
    cast[wglGetCurrentContext](GetProcAddress(opengl, "wglGetCurrentContext"))
  wglMakeCurrent =
    cast[wglMakeCurrent](GetProcAddress(opengl, "wglMakeCurrent"))

  # Before we can load extensions, we need a dummy OpenGL context, created using
  # a dummy window. We use a dummy window because you can only set the pixel
  # format for a window once. For the real window, we want to use
  # wglChoosePixelFormatARB (so we can potentially specify options that aren't
  # available in PIXELFORMATDESCRIPTOR), but we can't load and use that before
  # we have a context.

  let dummyWindowClassName = "WindyDummy"

  proc dummyWndProc(
    hWnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM
  ): LRESULT {.stdcall.} =
    DefWindowProcW(hWnd, uMsg, wParam, lParam)

  registerWindowClass(dummyWindowClassName, dummyWndProc)

  let
    hWnd = createWindow(
      dummyWindowClassName,
      dummyWindowClassName,
      ivec2(CW_USEDEFAULT, CW_USEDEFAULT)
    )
    hdc = getDC(hWnd)

  var pfd: PIXELFORMATDESCRIPTOR
  pfd.nSize = sizeof(PIXELFORMATDESCRIPTOR).WORD
  pfd.nVersion = 1
  pfd.dwFlags = PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER
  pfd.iPixelType = PFD_TYPE_RGBA
  pfd.cColorBits = 32
  pfd.cAlphaBits = 8
  pfd.cDepthBits = 24
  pfd.cStencilBits = 8

  let pixelFormat = ChoosePixelFormat(hdc, pfd.addr)
  if pixelFormat == 0:
    raise newException(WindyError, "Error choosing pixel format")

  if SetPixelFormat(hdc, pixelFormat, pfd.addr) == 0:
    raise newException(WindyError, "Error setting pixel format")

  let hglrc = wglCreateContext(hdc)
  if hglrc == 0:
    raise newException(WindyError, "Error creating rendering context")

  makeContextCurrent(hdc, hglrc)

  wglCreateContextAttribsARB =
    cast[wglCreateContextAttribsARB](
      wglGetProcAddress("wglCreateContextAttribsARB")
    )
  wglChoosePixelFormatARB =
    cast[wglChoosePixelFormatARB](
      wglGetProcAddress("wglChoosePixelFormatARB")
    )
  wglSwapIntervalEXT =
    cast[wglSwapIntervalEXT](
      wglGetProcAddress("wglSwapIntervalEXT")
    )

  discard wglMakeCurrent(hdc, 0)
  discard wglDeleteContext(hglrc)
  discard ReleaseDC(hWnd, hdc)
  discard DestroyWindow(hWnd)

proc loadLibraries() =
  let user32 = LoadLibraryA("user32.dll")
  if user32 == 0:
    raise newException(WindyError, "Error loading user32.dll")

  SetProcessDpiAwarenessContext = cast[SetProcessDpiAwarenessContext](
    GetProcAddress(user32, "SetProcessDpiAwarenessContext")
  )
  GetDpiForWindow = cast[GetDpiForWindow](
    GetProcAddress(user32, "GetDpiForWindow")
  )
  AdjustWindowRectExForDpi = cast[AdjustWindowRectExForDpi](
    GetProcAddress(user32, "AdjustWindowRectExForDpi")
  )

proc createHelperWindow(): HWND =
  let helperWindowClassName = "WindyHelper"

  proc helperWndProc(
    hWnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM
  ): LRESULT {.stdcall.} =
    DefWindowProcW(hWnd, uMsg, wParam, lParam)

  registerWindowClass(helperWindowClassName, helperWndProc)

  result = createWindow(
    helperWindowClassName,
    helperWindowClassName,
    ivec2(CW_USEDEFAULT, CW_USEDEFAULT)
  )

proc handleButtonPress(window: Window, button: Button) =
  window.buttonDown.incl button
  window.buttonPressed.incl button
  if button in window.buttonToggle:
    window.buttonToggle.excl button
  else:
    window.buttonToggle.incl button
  if window.onButtonPress != nil:
    window.onButtonPress(button)

  if button == MouseLeft:
    let
      clickTime = epochTime()
      scaledMultiClickRadius = multiClickRadius * window.contentScale

    let
      doubleClickInterval = clickTime - window.doubleClickTime
      doubleClickDistance =
        (window.mousePos - window.multiClickPositions[0]).vec2.length
    if doubleClickInterval <= platformDoubleClickInterval and
      doubleClickDistance <= scaledMultiClickRadius:
      window.handleButtonPress(DoubleClick)
      window.doubleClickTime = 0
    else:
      window.doubleClickTime = clickTime

    let
      tripleClickIntervals = [
        clickTime - window.tripleClickTimes[0],
        clickTime - window.tripleClickTimes[1]
      ]
      tripleClickInterval = tripleClickIntervals[0] + tripleClickIntervals[1]
      tripleClickDistance =
        (window.mousePos - window.multiClickPositions[1]).vec2.length

    if tripleClickInterval < 2 * platformDoubleClickInterval and
      tripleClickDistance <= scaledMultiClickRadius:
      window.handleButtonPress(TripleClick)
      window.tripleClickTimes = [0.float64, 0]
    else:
      window.tripleClickTimes[1] = window.tripleClickTimes[0]
      window.tripleClickTimes[0] = clickTime

    let
      quadrupleClickIntervals = [
        clickTime - window.quadrupleClickTimes[0],
        clickTime - window.quadrupleClickTimes[1],
        clickTime - window.quadrupleClickTimes[2]
      ]
      quadrupleClickInterval =
        quadrupleClickIntervals[0] +
        quadrupleClickIntervals[1] +
        quadrupleClickIntervals[2]
      quadrupleClickDistance =
        (window.mousePos - window.multiClickPositions[2]).vec2.length

    if quadrupleClickInterval < 3 * platformDoubleClickInterval and
      quadrupleClickDistance <= multiClickRadius:
      window.handleButtonPress(QuadrupleClick)
      window.quadrupleClickTimes = [0.float64, 0, 0]
    else:
      window.quadrupleClickTimes[2] = window.quadrupleClickTimes[1]
      window.quadrupleClickTimes[1] = window.quadrupleClickTimes[0]
      window.quadrupleClickTimes[0] = clickTime

    window.multiClickPositions[2] = window.multiClickPositions[1]
    window.multiClickPositions[1] = window.multiClickPositions[0]
    window.multiClickPositions[0] = window.mousePos

proc handleButtonRelease(window: Window, button: Button) =
  if button == MouseLeft:
    if QuadrupleClick in window.buttonDown:
      window.handleButtonRelease(QuadrupleClick)
    if TripleClick in window.buttonDown:
      window.handleButtonRelease(TripleClick)
    if DoubleClick in window.buttonDown:
      window.handleButtonRelease(DoubleClick)

  window.buttonDown.excl button
  window.buttonReleased.incl button
  if window.onButtonRelease != nil:
    window.onButtonRelease(button)

proc handleRune(window: Window, rune: Rune) =
  if rune.uint32 < 32 or (rune.uint32 > 126 and rune.uint32 < 160):
      return
  if window.onRune != nil:
    window.onRune(rune)

proc wndProc(
  hWnd: HWND,
  uMsg: UINT,
  wParam: WPARAM,
  lParam: LPARAM
): LRESULT {.stdcall.} =
  # echo wmEventName(uMsg)
  let
    key = "Windy".wstr()
    data = GetPropW(hWnd, cast[ptr WCHAR](key[0].unsafeAddr))
  if data == 0:
    # This event is for a window being created (CreateWindowExW has not returned)
    return DefWindowProcW(hWnd, uMsg, wParam, lParam)

  let window = windows.forHandle(hWnd)
  if window == nil:
    return

  case uMsg:
  of WM_CLOSE:
    window.closeRequested = true
    if window.onCloseRequest != nil:
      window.onCloseRequest()
    return 0
  of WM_MOVE:
    if window.onMove != nil:
      window.onMove()
    return 0
  of WM_SIZE:
    if window.onResize != nil:
      window.onResize()
    return 0
  of WM_SETFOCUS, WM_KILLFOCUS:
    if window.onFocusChange != nil:
      window.onFocusChange()
    return 0
  of WM_DPICHANGED:
    # Resize to the suggested size (this triggers WM_SIZE)
    let suggested = cast[ptr RECT](lParam)
    discard SetWindowPos(
      window.hWnd,
      HWND_TOP,
      suggested.left,
      suggested.top,
      suggested.right - suggested.left,
      suggested.bottom - suggested.top,
      SWP_NOACTIVATE or SWP_NOZORDER
    )
    return 0
  of WM_MOUSEMOVE:
    window.perFrame.mousePrevPos = window.mousePos
    var pos: POINT
    discard GetCursorPos(pos.addr)
    discard ScreenToClient(window.hWnd, pos.addr)
    window.mousePos = ivec2(pos.x, pos.y)
    window.perFrame.mouseDelta = window.mousePos - window.perFrame.mousePrevPos
    if window.onMouseMove != nil:
      window.onMouseMove()
    if not window.trackMouseEventRegistered:
      var tme: TRACKMOUSEEVENTSTRUCT
      tme.cbSize = sizeof(TRACKMOUSEEVENTSTRUCT).DWORD
      tme.dwFlags = TME_LEAVE
      tme.hWndTrack = window.hWnd
      discard TrackMouseEvent(tme.addr)
      window.trackMouseEventRegistered = true
    return 0
  of WM_MOUSELEAVE:
    window.trackMouseEventRegistered = false
    return 0
  of WM_MOUSEWHEEL:
    let hiword = HIWORD(wParam)
    window.perFrame.scrollDelta = vec2(0, hiword.float32 / wheelDelta)
    if window.onScroll != nil:
      window.onScroll()
    return 0
  of WM_MOUSEHWHEEL:
    let hiword = HIWORD(wParam)
    window.perFrame.scrollDelta = vec2(hiword.float32 / wheelDelta, 0)
    if window.onScroll != nil:
      window.onScroll()
    return 0
  of WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN, WM_XBUTTONDOWN,
    WM_LBUTTONUP, WM_RBUTTONUP, WM_MBUTTONUP, WM_XBUTTONUP:
    let button =
      case uMsg:
      of WM_LBUTTONDOWN, WM_LBUTTONUP:
        MouseLeft
      of WM_RBUTTONDOWN, WM_RBUTTONUP:
        MouseRight
      of WM_XBUTTONDOWN, WM_XBUTTONUP:
        if HIWORD(wParam) == XBUTTON1:
          MouseButton4
        else:
          MouseButton5
      else:
        MouseMiddle
    if uMsg in {WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN}:
      window.handleButtonPress(button)
      if button == MouseLeft:
        discard SetCapture(window.hWnd)
    else:
      window.handleButtonRelease(button)
      if button == MouseLeft:
        discard ReleaseCapture()
    return 0
  of WM_KEYDOWN, WM_SYSKEYDOWN, WM_KEYUP, WM_SYSKEYUP:
    if wParam == VK_PROCESSKEY:
      # IME
      discard
    elif wParam == VK_SNAPSHOT:
      window.handleButtonPress(KeyPrintScreen)
      window.handleButtonRelease(KeyPrintScreen)
    else:
      let
        scancode = (HIWORD(lParam) and (KF_EXTENDED or 0xff))
        button = scancodeToButton[scancode]
      if button != ButtonUnknown:
        if (HIWORD(lParam) and KF_UP) == 0:
          window.handleButtonPress(button)
        else:
          window.handleButtonRelease(button)
      return 0
  of WM_CHAR, WM_SYSCHAR, WM_UNICHAR:
    if uMsg == WM_UNICHAR and wParam == UNICODE_NOCHAR:
      return TRUE
    let codepoint = wParam.uint32
    window.handleRune(Rune(codepoint))
    return 0
  of WM_IME_STARTCOMPOSITION:
    let hIMC = ImmGetContext(window.hWnd)

    var compositionPos: COMPOSITIONFORM
    compositionPos.dwStyle = CFS_POINT
    compositionPos.ptCurrentPos = POINT(x: window.imePos.x, y: window.imePos.y)
    discard ImmSetCompositionWindow(hIMC, compositionPos.addr)

    var candidatePos: CANDIDATEFORM
    candidatePos.dwIndex = 0
    candidatePos.dwStyle = CFS_CANDIDATEPOS
    candidatePos.ptCurrentPos = POINT(x: window.imePos.x, y: window.imePos.y)
    discard ImmSetCandidateWindow(hIMC, candidatePos.addr)

    var exclude: CANDIDATEFORM
    exclude.dwIndex = 0
    exclude.dwStyle = CFS_EXCLUDE
    exclude.ptCurrentPos = POINT(x: window.imePos.x, y: window.imePos.y)
    exclude.rcArea = RECT(
      left: window.imePos.x,
      top: window.imePos.y,
      right: window.imePos.x + 1,
      bottom: window.imePos.x + 1
    )
    discard ImmSetCandidateWindow(hIMC, exclude.addr)

    discard ImmReleaseContext(window.hWnd, hIMC)
    return 0
  of WM_IME_COMPOSITION:
    let hIMC = ImmGetContext(window.hWnd)

    if (lParam and GCS_CURSORPOS) != 0:
      window.imeCursorIndex = ImmGetCompositionStringW(
        hIMC, GCS_CURSORPOS, nil, 0
      )

    if (lParam and GCS_COMPSTR) != 0:
      let len = ImmGetCompositionStringW(
        hIMC, GCS_COMPSTR, nil, 0
      )
      if len > 0:
        var buf = newString(len + 1) # Include 1 extra byte for WCHAR null terminator
        discard ImmGetCompositionStringW(
          hIMC, GCS_COMPSTR, buf[0].addr, len
        )
        window.imeCompositionString = $cast[ptr WCHAR](buf[0].addr)
      else:
        window.imeCompositionString = ""

    if (lParam and GCS_RESULTSTR) != 0:
      # The input runes will come in through WM_CHAR events
      window.imeCursorIndex = 0
      window.imeCompositionString = ""

    if (lParam and (GCS_CURSORPOS or GCS_COMPSTR or GCS_RESULTSTR)) != 0:
      # If we received a message that updates IME state, trigger the callback
      if window.onImeChange != nil:
        window.onImeChange()

    discard ImmReleaseContext(window.hWnd, hIMC)
    # Do not return 0 here
  else:
    discard

  DefWindowProcW(hWnd, uMsg, wParam, lParam)

proc init*() =
  if initialized:
    raise newException(WindyError, "Windy is already initialized")
  loadLibraries()
  discard SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
  loadOpenGL()
  helperWindow = createHelperWindow()
  registerWindowClass(windowClassName, wndProc)
  platformDoubleClickInterval = GetDoubleClickTime().float64 / 1000
  initialized = true

proc pollEvents*() =
  # Clear all per-frame data
  for window in windows:
    window.perFrame = PerFrame()
    window.buttonPressed = {}
    window.buttonReleased = {}

  var msg: MSG
  while PeekMessageW(msg.addr, 0, 0, 0, PM_REMOVE) > 0:
    if msg.message == WM_QUIT:
      for window in windows:
        discard wndProc(window.hwnd, WM_CLOSE, 0, 0)
    else:
      discard TranslateMessage(msg.addr)
      discard DispatchMessageW(msg.addr)

  let activeWindow = windows.forHandle(GetActiveWindow())
  if activeWindow != nil:
    # When both shift keys are down the first one released does not trigger a
    # key up event so we fake it here.
    if KeyLeftShift in activeWindow.buttonDown:
      if (GetKeyState(VK_LSHIFT) and KF_UP) == 0:
        activeWindow.handleButtonRelease(KeyLeftShift)
    if KeyRightShift in activeWindow.buttonDown:
      if (GetKeyState(VK_RSHIFT) and KF_UP) == 0:
        activeWindow.handleButtonRelease(KeyRightShift)

proc makeContextCurrent*(window: Window) =
  makeContextCurrent(window.hdc, window.hglrc)

proc swapBuffers*(window: Window) =
  if SwapBuffers(window.hdc) == 0:
    raise newException(WindyError, "Error swapping buffers")

proc close*(window: Window) =
  destroy window
  window.closed = true

proc closeIme*(window: Window) =
  let hIMC = ImmGetContext(window.hWnd)
  discard ImmNotifyIME(hIMC, NI_COMPOSITIONSTR, CPS_CANCEL, 0)
  discard ImmReleaseContext(window.hWnd, hIMC)
  window.imeCursorIndex = 0
  window.imeCompositionString = ""

proc newWindow*(
  title: string,
  size: IVec2,
  visible = true,
  vsync = true,
  openglMajorVersion = 4,
  openglMinorVersion = 1,
  msaa = msaaDisabled,
  depthBits = 24,
  stencilBits = 8
): Window =
  ## Creates a new window. Intitializes Windy if needed.
  if not initialized:
    init()

  result = Window()
  result.title = title
  result.hWnd = createWindow(
    windowClassName,
    title,
    size
  )

  try:
    result.hdc = getDC(result.hWnd)

    let pixelFormatAttribs = [
      WGL_DRAW_TO_WINDOW_ARB.int32,
      1,
      WGL_SUPPORT_OPENGL_ARB,
      1,
      WGL_DOUBLE_BUFFER_ARB,
      1,
      WGL_ACCELERATION_ARB,
      WGL_FULL_ACCELERATION_ARB,
      WGL_PIXEL_TYPE_ARB,
      WGL_TYPE_RGBA_ARB,
      WGL_COLOR_BITS_ARB,
      32,
      WGL_DEPTH_BITS_ARB,
      depthBits.int32,
      WGL_STENCIL_BITS_ARB,
      stencilBits.int32,
      WGL_SAMPLES_ARB,
      msaa.int32,
      0
    ]

    var
      pixelFormat: int32
      numFormats: UINT
    if wglChoosePixelFormatARB(
      result.hdc,
      pixelFormatAttribs[0].unsafeAddr,
      nil,
      1,
      pixelFormat.addr,
      numFormats.addr
    ) == 0:
      raise newException(WindyError, "Error choosing pixel format")
    if numFormats == 0:
      raise newException(WindyError, "No pixel format chosen")

    var pfd: PIXELFORMATDESCRIPTOR
    if DescribePixelFormat(
      result.hdc,
      pixelFormat,
      sizeof(PIXELFORMATDESCRIPTOR).UINT,
      pfd.addr
    ) == 0:
      raise newException(WindyError, "Error describing pixel format")

    if SetPixelFormat(result.hdc, pixelFormat, pfd.addr) == 0:
      raise newException(WindyError, "Error setting pixel format")

    let contextAttribs = [
      WGL_CONTEXT_MAJOR_VERSION_ARB.int32,
      openglMajorVersion.int32,
      WGL_CONTEXT_MINOR_VERSION_ARB,
      openglMinorVersion.int32,
      WGL_CONTEXT_PROFILE_MASK_ARB,
      WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
      WGL_CONTEXT_FLAGS_ARB,
      WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB,
      0
    ]

    result.hglrc = wglCreateContextAttribsARB(
      result.hdc,
      0,
      contextAttribs[0].unsafeAddr
    )
    if result.hglrc == 0:
      raise newException(WindyError, "Error creating OpenGL context")

    # The first call to ShowWindow may ignore the parameter so do an initial
    # call to clear that behavior.
    discard ShowWindow(result.hWnd, SW_HIDE)

    result.makeContextCurrent()

    if wglSwapIntervalEXT(if vsync: 1 else : 0) == 0:
      raise newException(WindyError, "Error setting swap interval")

    windows.add(result)

    if visible:
      result.visible = true
  except WindyError as e:
    destroy result
    raise e

proc buttonDown*(window: Window): ButtonView =
  ButtonView(states: window.buttonDown)

proc buttonPressed*(window: Window): ButtonView =
  ButtonView(states: window.buttonPressed)

proc buttonReleased*(window: Window): ButtonView =
  ButtonView(states: window.buttonReleased)

proc buttonToggle*(window: Window): ButtonView =
  ButtonView(states: window.buttonToggle)

proc `[]`*(buttonView: ButtonView, button: Button): bool =
  button in buttonView.states

proc getClipboardString*(): string =
  if not initialized:
    init()

  if IsClipboardFormatAvailable(CF_UNICODETEXT) == FALSE:
    return ""

  if OpenClipboard(helperWindow) == 0:
    return ""

  let dataHandle = GetClipboardData(CF_UNICODETEXT)
  if dataHandle != 0:
    let p = cast[ptr WCHAR](GlobalLock(dataHandle))
    if p != nil:
      result = $p
      discard GlobalUnlock(dataHandle)

  discard CloseClipboard()

proc setClipboardString*(value: string) =
  if not initialized:
    init()

  var wideValue = value.wstr()

  let dataHandle = GlobalAlloc(
    GMEM_MOVEABLE,
    wideValue.len + 2 # Include uint16 null terminator
  )
  if dataHandle == 0:
    return

  let p = GlobalLock(dataHandle)
  if p == nil:
    discard GlobalFree(dataHandle)
    return

  copyMem(p, wideValue[0].addr, wideValue.len)

  discard GlobalUnlock(dataHandle)

  if OpenClipboard(helperWindow) == 0:
    discard GlobalFree(dataHandle)
    return

  discard EmptyClipboard()
  discard SetClipboardData(CF_UNICODETEXT, dataHandle)
  discard CloseClipboard()
