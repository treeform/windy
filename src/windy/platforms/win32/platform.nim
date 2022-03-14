import ../../common, ../../internal, flatty/binny, pixie/fileformats/png,
    pixie/fileformats/bmp, pixie/images, std/tables, std/random,
    std/strutils, std/times, std/unicode, urlly, utils, vmath, windefs, zippy

const
  windowClassName = "WINDY0"
  trayIconId = 2022
  defaultScreenDpi = 96
  wheelDelta = 120
  decoratedWindowStyle = WS_OVERLAPPEDWINDOW
  undecoratedWindowStyle = WS_POPUP

  WGL_DRAW_TO_WINDOW_ARB = 0x2001
  WGL_ACCELERATION_ARB = 0x2003
  WGL_SUPPORT_OPENGL_ARB = 0x2010
  WGL_DOUBLE_BUFFER_ARB = 0x2011
  WGL_PIXEL_TYPE_ARB = 0x2013
  WGL_COLOR_BITS_ARB = 0x2014
  WGL_ALPHA_BITS_ARB = 0x201B
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

  WM_TRAY_ICON = WM_APP + 0
  WM_HTTP = WM_APP + 1

  HTTP_REQUEST_START = 10
  HTTP_REQUEST_ERROR = 11
  HTTP_SECURE_ERROR = 12
  HTTP_SENDREQUEST_COMPLETE = 13
  HTTP_HEADERS_AVAILABLE = 14
  HTTP_READ_COMPLETE = 15
  HTTP_WRITE_COMPLETE = 16
  HTTP_REQUEST_CANCEL = 17
  HTTP_HANDLE_CLOSING = 18
  HTTP_WEBSOCKET_CLOSE = 19

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
    imePos*: IVec2

    state: WindowState
    trackMouseEventRegistered: bool
    exitFullscreenInfo: ExitFullscreenInfo
    isFloating: bool

    hWnd: HWND
    hdc: HDC
    hglrc: HGLRC
    iconHandle: HICON
    customCursor: HCURSOR

  ExitFullscreenInfo = ref object
    maximized: bool
    style: LONG
    rect: RECT

  TrayMenyEntryKind* = enum
    TrayMenuOption, TrayMenuSeparator

  TrayMenuEntry* = object
    case kind*: TrayMenyEntryKind
    of TrayMenuOption:
      text*: string
      onClick*: Callback
    of TrayMenuSeparator:
      discard

  HttpRequestState = object
    url, verb: string
    headers: seq[HttpHeader]
    requestBodyLen: int
    requestBody: pointer
    deadline: float64

    canceled, closed: bool

    onError: HttpErrorCallback
    onResponse: HttpResponseCallback
    onUploadProgress: HttpProgressCallback
    onDownloadProgress: HttpProgressCallback

    onWebSocketUpgrade: proc()

    hOpen, hConnect, hRequest: HINTERNET

    requestBodyBytesWritten: int
    responseCode: DWORD
    responseHeaders: string
    responseContentLength: int # From Content-Length header, if present
    responseBodyCap, responseBodyLen: int
    responseBody: pointer

  WebSocketState = object
    httpRequest: HttpRequestHandle
    hWebSocket: HINTERNET

    onOpenCalled: bool
    closed: bool

    onError: HttpErrorCallback
    onOpen, onClose: Callback
    onMessage: WebSocketMessageCallback

    buffer: pointer
    bufferCap, bufferLen: int

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
  windowPropKey: string
  helperWindow: HWND
  windows: seq[Window]
  onTrayIconClick: Callback
  trayIconHandle: HICON
  trayMenuHandle: HMENU
  trayMenuEntries: seq[TrayMenuEntry]
  httpRequests: Table[HttpRequestHandle, ptr HttpRequestState]
  webSockets: Table[WebSocketHandle, ptr WebSocketState]

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

proc createWindow(windowClassName, title: string): HWND =
  let
    wideWindowClassName = windowClassName.wstr()
    wideTitle = title.wstr()

  result = CreateWindowExW(
    WS_EX_APPWINDOW,
    cast[ptr WCHAR](wideWindowClassName[0].unsafeAddr),
    cast[ptr WCHAR](wideTitle[0].unsafeAddr),
    decoratedWindowStyle,
    CW_USEDEFAULT,
    CW_USEDEFAULT,
    CW_USEDEFAULT,
    CW_USEDEFAULT,
    0,
    0,
    GetModuleHandleW(nil),
    nil
  )
  if result == 0:
    raise newException(WindyError, "Creating native window failed")

proc destroy(window: Window) =
  window.onCloseRequest = nil
  window.onMove = nil
  window.onResize = nil
  window.onFocusChange = nil
  window.onMouseMove = nil
  window.onScroll = nil
  window.onButtonPress = nil
  window.onButtonRelease = nil
  window.onRune = nil
  window.onImeChange = nil

  if window.hglrc != 0:
    discard wglMakeCurrent(window.hdc, 0)
    discard wglDeleteContext(window.hglrc)
    window.hglrc = 0
  if window.hdc != 0:
    discard ReleaseDC(window.hWnd, window.hdc)
    window.hdc = 0
  if window.hWnd != 0:
    discard RemovePropW(window.hWnd, cast[ptr WCHAR](windowPropKey[0].addr))
    discard DestroyWindow(window.hWnd)
    let index = windows.indexForHandle(window.hWnd)
    if index != -1:
      windows.delete(index)
    window.hWnd = 0

proc createIconHandle(image: Image): HICON =
  let encoded = image.encodePng()
  result = CreateIconFromResourceEx(
    cast[PBYTE](encoded[0].unsafeAddr),
    encoded.len.DWORD,
    TRUE,
    0x00030000,
    0,
    0,
    0
  )

  if result == 0:
    raise newException(WindyError, "Error creating icon")

proc createCursorHandle(cursor: Cursor): HCURSOR =
  var encoded: string
  encoded.addUint16(cursor.hotspot.x.uint16)
  encoded.addUint16(cursor.hotspot.y.uint16)
  encoded &= cursor.image.encodePng()

  result = CreateIconFromResourceEx(
    cast[PBYTE](encoded[0].unsafeAddr),
    encoded.len.DWORD,
    FALSE,
    0x00030000,
    0,
    0,
    0
  )

  if result == 0:
    raise newException(WindyError, "Error creating cursor")

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

  discard SetWindowPos(
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

proc visible*(window: Window): bool =
  IsWindowVisible(window.hWnd) != 0

proc style*(window: Window): WindowStyle =
  let style = getWindowStyle(window.hWnd)
  if (style and WS_THICKFRAME) != 0:
    return DecoratedResizable
  if (style and WS_BORDER) != 0:
    return Decorated
  Undecorated

proc fullscreen*(window: Window): bool =
  window.exitFullscreenInfo != nil

proc floating*(window: Window): bool =
  window.isFloating

proc contentScale*(window: Window): float32 =
  let dpi = GetDpiForWindow(window.hWnd)
  result = dpi.float32 / defaultScreenDpi

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

proc focused*(window: Window): bool =
  window.hWnd == GetActiveWindow()

proc closeIme*(window: Window) =
  let hIMC = ImmGetContext(window.hWnd)
  if hIMC != 0:
    discard ImmNotifyIME(hIMC, NI_COMPOSITIONSTR, CPS_CANCEL, 0)
    discard ImmReleaseContext(window.hWnd, hIMC)
    window.state.imeCursorIndex = 0
    window.state.imeCompositionString = ""
    if window.onImeChange != nil:
      window.onImeChange()

proc `title=`*(window: Window, title: string) =
  window.state.title = title
  var wideTitle = title.wstr()
  discard SetWindowTextW(window.hWnd, cast[ptr WCHAR](wideTitle[0].addr))

proc `icon=`*(window: Window, icon: Image) =
  let prevIconHandle = window.iconHandle
  window.iconHandle = icon.createIconHandle()
  discard SendMessageW(
    window.hWnd,
    WM_SETICON,
    ICON_SMALL,
    window.iconHandle.LPARAM
  )
  discard SendMessageW(
    window.hWnd,
    WM_SETICON,
    ICON_BIG,
    window.iconHandle.LPARAM
  )
  discard DestroyIcon(prevIconHandle)
  window.state.icon = icon

proc `visible=`*(window: Window, visible: bool) =
  if visible:
    discard ShowWindow(window.hWnd, SW_SHOW)
  else:
    discard ShowWindow(window.hWnd, SW_HIDE)

proc `style=`*(window: Window, windowStyle: WindowStyle) =
  if window.fullscreen:
    return

  var style: Long

  case windowStyle:
  of DecoratedResizable:
    style = decoratedWindowStyle or (WS_MAXIMIZEBOX or WS_THICKFRAME)
  of Decorated:
    style = decoratedWindowStyle and not (WS_MAXIMIZEBOX or WS_THICKFRAME)
  of Undecorated:
    style = undecoratedWindowStyle

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
      HWND_TOP,
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

proc `floating=`*(window: Window, floating: bool) =
  if window.floating == floating:
    return

  window.isFloating = floating

  discard SetWindowPos(
    window.hWnd,
    if floating: HWND_TOPMOST else: HWND_TOP,
    0,
    0,
    0,
    0,
    SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE
  )

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

  var rect = RECT(top: pos.y, left: pos.x, bottom: pos.y, right: pos.x)
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
  window.state.closeRequested = closeRequested
  if closeRequested:
    if window.onCloseRequest != nil:
      window.onCloseRequest()

proc `runeInputEnabled=`*(window: Window, runeInputEnabled: bool) =
  window.state.runeInputEnabled = runeInputEnabled
  if runeInputEnabled:
    discard ImmAssociateContextEx(window.hWnd, 0, IACE_DEFAULT)
  else:
    window.closeIme()
    discard ImmAssociateContextEx(window.hWnd, 0, 0)

proc `cursor=`*(window: Window, cursor: Cursor) =
  if window.customCursor != 0:
    discard DestroyCursor(window.customCursor)

  window.state.cursor = cursor

  case cursor.kind:
  of DefaultCursor:
    window.customCursor = 0
  else:
    window.customCursor = cursor.createCursorHandle()
    discard SetCursor(window.customCursor)

proc loadOpenGL() =
  let opengl = LoadLibraryA("opengl32.dll")
  if opengl == 0:
    quit("Loading opengl32.dll failed")

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

  try:
    registerWindowClass(dummyWindowClassName, dummyWndProc)
  except:
    quit("Error registering dummy window class")

  let
    hWnd =
      try:
        createWindow(dummyWindowClassName, dummyWindowClassName)
      except:
        quit("Error creating dummy window")
    hdc =
      try:
        getDC(hWnd)
      except:
        quit("Error getting dummy window DC")

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
    quit("Error choosing dummy window pixel format")

  if SetPixelFormat(hdc, pixelFormat, pfd.addr) == 0:
    quit("Error setting dummy window pixel format")

  let hglrc = wglCreateContext(hdc)
  if hglrc == 0:
    quit("Error creating dummy window rendering context")

  try:
    makeContextCurrent(hdc, hglrc)
  except:
    quit("Error making dummy window context current")

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
    quit("Error loading user32.dll")

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
    hWnd: HWND,
    uMsg: UINT,
    wParam: WPARAM,
    lParam: LPARAM
  ): LRESULT {.stdcall.} =
    case uMsg:
    of WM_TRAY_ICON:
      let innerMsg = LOWORD(lParam)
      case innerMsg:
      of WM_LBUTTONUP:
        if onTrayIconClick != nil:
          onTrayIconClick()
      of WM_RBUTTONUP:
        if trayMenuHandle > 0:
          var pos: POINT
          discard GetCursorPos(pos.addr)
          let clicked = TrackPopupMenu(
            trayMenuHandle,
            TPM_RETURNCMD,
            pos.x,
            pos.y,
            0,
            helperWindow,
            nil
          ).int
          if clicked > 0:
            if trayMenuEntries[clicked - 1].onClick != nil:
              trayMenuEntries[clicked - 1].onClick()
      else:
        discard
      return 0
    else:
      DefWindowProcW(hWnd, uMsg, wParam, lParam)

  registerWindowClass(helperWindowClassName, helperWndProc)

  result = createWindow(helperWindowClassName, helperWindowClassName)

proc handleButtonPress(window: Window, button: Button) =
  handleButtonPressTemplate()

proc handleButtonRelease(window: Window, button: Button) =
  handleButtonReleaseTemplate()

proc handleRune(window: Window, rune: Rune) =
  handleRuneTemplate()

proc wndProc(
  hWnd: HWND,
  uMsg: UINT,
  wParam: WPARAM,
  lParam: LPARAM
): LRESULT {.stdcall.} =
  # echo wmEventName(uMsg)
  let data = GetPropW(hWnd, cast[ptr WCHAR](windowPropKey[0].addr))
  if data == 0:
    # This event is for a window being created (CreateWindowExW has not returned)
    return DefWindowProcW(hWnd, uMsg, wParam, lParam)

  let window = windows.forHandle(hWnd)
  if window == nil:
    raise newException(WindyError, "Received message for missing window")

  case uMsg:
  of WM_CLOSE:
    window.closeRequested = true
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
    window.state.mousePrevPos = window.state.mousePos
    var pos: POINT
    discard GetCursorPos(pos.addr)
    discard ScreenToClient(window.hWnd, pos.addr)
    window.state.mousePos = ivec2(pos.x, pos.y)
    window.state.perFrame.mouseDelta +=
      window.state.mousePos - window.state.mousePrevPos
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
  of WM_SETCURSOR:
    if window.customCursor != 0 and LOWORD(lParam) == HTCLIENT:
      discard SetCursor(window.customCursor)
      return TRUE
  of WM_MOUSEWHEEL:
    let hiword = HIWORD(wParam)
    window.state.perFrame.scrollDelta += vec2(0, hiword.float32 / wheelDelta)
    if window.onScroll != nil:
      window.onScroll()
    return 0
  of WM_MOUSEHWHEEL:
    let hiword = HIWORD(wParam)
    window.state.perFrame.scrollDelta += vec2(hiword.float32 / wheelDelta, 0)
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
      window.state.imeCursorIndex = ImmGetCompositionStringW(
        hIMC, GCS_CURSORPOS, nil, 0
      )

    if (lParam and GCS_COMPSTR) != 0:
      let len = ImmGetCompositionStringW(
        hIMC, GCS_COMPSTR, nil, 0
      )
      if len > 0:
        var buf = newString(len + 1) # Include 1 extra byte for WCHAR null terminator
        discard ImmGetCompositionStringW(hIMC, GCS_COMPSTR, buf[0].addr, len)
        window.state.imeCompositionString = $cast[ptr WCHAR](buf[0].addr)
      else:
        window.state.imeCompositionString = ""

    if (lParam and GCS_RESULTSTR) != 0:
      # The input runes will come in through WM_CHAR events
      window.state.imeCursorIndex = 0
      window.state.imeCompositionString = ""

    if (lParam and (GCS_CURSORPOS or GCS_COMPSTR or GCS_RESULTSTR)) != 0:
      # If we received a message that updates IME state, trigger the callback
      if window.onImeChange != nil:
        window.onImeChange()

    discard ImmReleaseContext(window.hWnd, hIMC)
    # Do not return 0 here
  else:
    discard

  DefWindowProcW(hWnd, uMsg, wParam, lParam)

proc init() {.raises: [].} =
  if initialized:
    return
  windowPropKey = "Windy".wstr()
  loadLibraries()
  discard SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
  loadOpenGL()
  try:
    helperWindow = createHelperWindow()
    registerWindowClass(windowClassName, wndProc)
  except:
    quit("Error creating helper window")
  platformDoubleClickInterval = GetDoubleClickTime().float64 / 1000
  initialized = true

proc makeContextCurrent*(window: Window) =
  makeContextCurrent(window.hdc, window.hglrc)

proc swapBuffers*(window: Window) =
  if SwapBuffers(window.hdc) == 0:
    raise newException(WindyError, "Error swapping buffers")

proc close*(window: Window) =
  destroy window
  window.state.closed = true

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
  init()

  result = Window()
  result.title = title
  result.hWnd = createWindow(windowClassName, title)
  result.size = size

  discard SetPropW(result.hWnd, cast[ptr WCHAR](windowPropKey[0].addr), 1)

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
      WGL_ALPHA_BITS_ARB,
      8,
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

    if wglSwapIntervalEXT(if vsync: 1 else: 0) == 0:
      raise newException(WindyError, "Error setting swap interval")

    windows.add(result)

    result.visible = visible
  except WindyError as e:
    destroy result
    raise e

proc title*(window: Window): string =
  window.state.title

proc icon*(window: Window): Image =
  window.state.icon

proc mousePos*(window: Window): IVec2 =
  window.state.mousePos

proc mousePrevPos*(window: Window): IVec2 =
  window.state.mousePrevPos

proc mouseDelta*(window: Window): IVec2 =
  window.state.perFrame.mouseDelta

proc scrollDelta*(window: Window): Vec2 =
  window.state.perFrame.scrollDelta

proc runeInputEnabled*(window: Window): bool =
  window.state.runeInputEnabled

proc cursor*(window: Window): Cursor =
  window.state.cursor

proc imeCursorIndex*(window: Window): int =
  window.state.imeCursorIndex

proc imeCompositionString*(window: Window): string =
  window.state.imeCompositionString

proc closeRequested*(window: Window): bool =
  window.state.closeRequested

proc closed*(window: Window): bool =
  window.state.closed

proc buttonDown*(window: Window): ButtonView =
  window.state.buttonDown.ButtonView

proc buttonPressed*(window: Window): ButtonView =
  window.state.perFrame.buttonPressed.ButtonView

proc buttonReleased*(window: Window): ButtonView =
  window.state.perFrame.buttonReleased.ButtonView

proc buttonToggle*(window: Window): ButtonView =
  window.state.buttonToggle.ButtonView

proc getAvailableClipboardFormats(): seq[UINT] =
  var format = 0.UINT
  while true:
    format = EnumClipboardFormats(format)
    if format == 0:
      break
    result.add(format)

proc getClipboardContentKinds*(): set[ClipboardContentKind] =
  init()

  let availableFormats = getAvailableClipboardFormats()
  if CF_UNICODETEXT in availableFormats:
    result.incl TextContent
  if CF_DIBV5 in availableFormats or CF_DIB in availableFormats:
    result.incl ImageContent

proc getClipboardImage*(): Image =
  init()

  if OpenClipboard(helperWindow) == 0:
    return

  proc decodeClipboardImage(format: UINT): Image =
    let dataHandle = GetClipboardData(format)
    if dataHandle == 0:
      return

    let p = GlobalLock(dataHandle)
    if p != nil:
      try:
        let size = GlobalSize(dataHandle).int
        result = decodeDib(p, size, true)
      except:
        discard
      finally:
        discard GlobalUnlock(dataHandle)

  let availableFormats = getAvailableClipboardFormats()

  try:
    if CF_DIBV5 in availableFormats:
      result = decodeClipboardImage(CF_DIBV5)
    elif CF_DIB in availableFormats:
      result = decodeClipboardImage(CF_DIB)
  finally:
    discard CloseClipboard()

proc getClipboardString*(): string =
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

proc showTrayIcon*(
  icon: Image,
  tooltip: string,
  onClick: Callback,
  menu: seq[TrayMenuEntry] = @[]
) =
  if trayMenuHandle != 0:
    discard DestroyMenu(trayMenuHandle)
    trayMenuHandle = 0
    trayMenuEntries = @[]

  if menu.len > 0:
    trayMenuEntries = menu
    trayMenuHandle = CreatePopupMenu()
    for i, entry in menu:
      case entry.kind:
      of TrayMenuOption:
        let wstr = entry.text.wstr()
        discard AppendMenuW(
          trayMenuHandle,
          MF_STRING,
          (i + 1).UINT_PTR,
          cast[ptr WCHAR](wstr[0].unsafeAddr)
        )
      of TrayMenuSeparator:
        discard AppendMenuW(trayMenuHandle, MF_SEPARATOR, 0, nil)

  if trayIconHandle != 0:
    discard DestroyIcon(trayIconHandle)

  trayIconHandle = icon.createIconHandle()

  onTrayIconClick = onClick

  var nid: NOTIFYICONDATAW
  nid.cbSize = sizeof(NOTIFYICONDATAW).DWORD
  nid.hWnd = helperWindow
  nid.uID = trayIconId
  nid.uFlags = NIF_MESSAGE or NIF_ICON
  nid.uCallbackMessage = WM_TRAY_ICON
  nid.hIcon = trayIconHandle
  nid.union1.uVersion = NOTIFYICON_VERSION_4

  if tooltip != "":
    nid.uFlags = nid.uFlags or NIF_TIP or NIF_SHOWTIP

    let wstr = tooltip.wstr()
    copyMem(
      nid.szTip[0].addr,
      wstr[0].unsafeAddr,
      min(nid.szTip.high, wstr.high) * 2 # Leave room for null terminator
    )

  discard Shell_NotifyIconW(NIM_ADD, nid.addr)

proc hideTrayIcon*() =
  var nid: NOTIFYICONDATAW
  nid.cbSize = sizeof(NOTIFYICONDATAW).DWORD
  nid.hWnd = helperWindow
  nid.uID = trayIconId

  discard Shell_NotifyIconW(NIM_DELETE, nid.addr)

  onTrayIconClick = nil

  if trayMenuHandle != 0:
    discard DestroyMenu(trayMenuHandle)
    trayMenuHandle = 0
    trayMenuEntries = @[]

  if trayIconHandle != 0:
    discard DestroyIcon(trayIconHandle)
    trayIconHandle = 0

proc getScreens*(): seq[Screen] =
  ## Queries and returns the currently connected screens.

  type Holder = object
    screens: seq[Screen]

  var h = Holder()

  proc callback(
    hMonitor: HMONITOR,
    hdc: HDC,
    screenCoords: LPRECT,
    extra: LPARAM
  ): BOOL {.stdcall, raises: [].} =
    var mi: MONITORINFO
    mi.cbSize = sizeof(MONITORINFO).DWORD

    discard GetMonitorInfoW(hMonitor, mi.addr)

    cast[ptr Holder](extra).screens.add(Screen(
      left: screenCoords.left,
      right: screenCoords.right,
      top: screenCoords.top,
      bottom: screenCoords.bottom,
      primary: (mi.dwFlags and MONITORINFOF_PRIMARY) != 0
    ))

    return TRUE

  discard EnumDisplayMonitors(0, nil, callback, cast[LPARAM](h.addr))

  h.screens

proc close(handle: HttpRequestHandle) =
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil:
    return

  state.closed = true

  discard WinHttpCloseHandle(state.hRequest)
  discard WinHttpCloseHandle(state.hConnect)
  discard WinHttpCloseHandle(state.hOpen)

proc destroy(handle: HttpRequestHandle) =
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil:
    return

  httpRequests.del(handle)

  if state.responseBody != nil:
    deallocShared(state.responseBody)
  deallocShared(state)

proc onHttpError(handle: HttpRequestHandle, msg: string) =
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil:
    return

  handle.close()

  if not state.canceled and state.onError != nil:
    state.onError(msg)

proc onDeadlineExceeded(handle: HttpRequestHandle) =
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil:
    return

  let
    now = epochTime()
    msg = "Deadline of " & $state.deadline & " exceeded, time is " & $now
  handle.onHttpError(msg)

when defined(windyUseStdHttp):
  # For debugging, use Nim's std/httpclient on Windows
  import ../../http
  export http

elif compileOption("threads"):
  # --threads:on is required by the callback procs provided to WinHttp

  proc startHttpRequest*(
    url: string,
    verb = "GET",
    headers = newSeq[HttpHeader](),
    body = "",
    deadline = defaultHttpDeadline
  ): HttpRequestHandle {.raises: [].} =
    init()

    var headers = headers
    headers.addDefaultHeaders()

    let state = cast[ptr HttpRequestState](allocShared0(sizeof(HttpRequestState)))
    state.url = url
    state.verb = verb
    state.headers = headers

    if body.len > 0:
      state.requestBody = allocShared0(body.len)
      state.requestBodyLen = body.len
      copyMem(state.requestBody, body[0].unsafeAddr, body.len)

    if deadline >= 0:
      state.deadline = deadline
    else:
      state.deadline = epochTime() + 60 # Default deadline

    while true:
      result = windyRand.rand(int.high).HttpRequestHandle
      if result notin httpRequests and result.WebSocketHandle notin webSockets:
        httpRequests[result] = state
        break

    discard PostMessageW(helperWindow, WM_HTTP, HTTP_REQUEST_START, result.LPARAM)

  proc deadline*(handle: HttpRequestHandle): float64 =
    let state = httpRequests.getOrDefault(handle, nil)
    if state == nil:
      return
    state.deadline

  proc `deadline=`*(handle: HttpRequestHandle, deadline: float64) =
    let state = httpRequests.getOrDefault(handle, nil)
    if state == nil:
      return
    state.deadline = deadline

  proc `onError=`*(
    handle: HttpRequestHandle,
    callback: HttpErrorCallback
  ) =
    let state = httpRequests.getOrDefault(handle, nil)
    if state == nil:
      return
    state.onError = callback

  proc `onResponse=`*(
    handle: HttpRequestHandle,
    callback: HttpResponseCallback
  ) =
    let state = httpRequests.getOrDefault(handle, nil)
    if state == nil:
      return
    state.onResponse = callback

  proc `onUploadProgress=`*(
    handle: HttpRequestHandle,
    callback: HttpProgressCallback
  ) =
    let state = httpRequests.getOrDefault(handle, nil)
    if state == nil:
      return
    state.onUploadProgress = callback

  proc `onDownloadProgress=`*(
    handle: HttpRequestHandle,
    callback: HttpProgressCallback
  ) =
    let state = httpRequests.getOrDefault(handle, nil)
    if state == nil:
      return
    state.onDownloadProgress = callback

  proc cancel*(handle: HttpRequestHandle) {.raises: [].} =
    let state = httpRequests.getOrDefault(handle, nil)
    if state == nil:
      return

    state.canceled = true

    discard PostMessageW(
      helperWindow,
      WM_HTTP,
      HTTP_REQUEST_CANCEL,
      handle.LPARAM
    )

  proc httpCallback(
    hInternet: HINTERNET,
    dwContext: DWORD_PTR,
    dwInternetStatus: DWORD,
    lpvStatusInformation: LPVOID,
    dwStatusInformationLength: DWORD
  ): void {.stdcall, raises: [].} =
    {.push stackTrace: off.}

    var wParam: WPARAM

    case dwInternetStatus:
    of WINHTTP_CALLBACK_STATUS_REQUEST_ERROR:
      wParam = HTTP_REQUEST_ERROR
    of WINHTTP_CALLBACK_STATUS_SECURE_FAILURE:
      wParam = HTTP_SECURE_ERROR
    of WINHTTP_CALLBACK_STATUS_WRITE_COMPLETE:
      let bytesWritten = cast[ptr DWORD](lpvStatusInformation)[]
      wParam = bytesWritten shl 16 # HIWORD
      wParam = wParam or HTTP_WRITE_COMPLETE
    of WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE:
      wParam = HTTP_SENDREQUEST_COMPLETE
    of WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE:
      wParam = HTTP_HEADERS_AVAILABLE
    of WINHTTP_CALLBACK_STATUS_READ_COMPLETE:
      wParam = dwStatusInformationLength shl 16 # HIWORD
      wParam = wParam or HTTP_READ_COMPLETE
    of WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING:
      wParam = HTTP_HANDLE_CLOSING
    else:
      discard

    if wParam > 0:
      discard PostMessageW(
        helperWindow,
        WM_HTTP,
        wParam,
        dwContext.LPARAM
      )

    {.pop.}

  proc webSocketCallback(
    hWebSocket: HINTERNET,
    dwContext: DWORD_PTR,
    dwInternetStatus: DWORD,
    lpvStatusInformation: LPVOID,
    dwStatusInformationLength: DWORD
  ): void {.stdcall, raises: [].} =
    {.push stackTrace: off.}

    var wParam: WPARAM

    case dwInternetStatus:
    of WINHTTP_CALLBACK_STATUS_REQUEST_ERROR:
      wParam = HTTP_REQUEST_ERROR
    of WINHTTP_CALLBACK_STATUS_SECURE_FAILURE:
      wParam = HTTP_SECURE_ERROR
    of WINHTTP_CALLBACK_STATUS_READ_COMPLETE:
      let socketStatus =
        cast[ptr WINHTTP_WEB_SOCKET_STATUS](lpvStatusInformation)[]
      wParam = socketStatus.dwBytesTransferred shl 16
      wParam = wParam or (socketStatus.eBufferType.DWORD shl 8)
      wparam = wparam or HTTP_READ_COMPLETE
    of WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING:
      wParam = HTTP_HANDLE_CLOSING
    else:
      discard

    if wParam > 0:
      discard PostMessageW(
        helperWindow,
        WM_HTTP,
        wParam,
        dwContext.LPARAM
      )

    {.pop.}

  proc onStartRequest(handle: HttpRequestHandle) =
    let state = httpRequests.getOrDefault(handle, nil)
    if state == nil:
      return

    if state.canceled:
      return

    if state.deadline > 0 and state.deadline <= epochTime():
      handle.onDeadlineExceeded()
      return

    let url =
      try:
        parseUrl(state.url)
      except:
        handle.onHttpError("Parsing URL failed: " & getCurrentExceptionMsg())
        return

    if state.onWebSocketUpgrade != nil: # WebSocket request
      # WinHttp does not like ws:// or wss:// so convert internally
      let scheme = url.scheme.toLowerAscii()
      if scheme == "ws":
        url.scheme = "http"
      elif scheme == "wss":
        url.scheme = "https"
      else:
        handle.onHttpError("Invalid URL scheme: " & url.scheme)
        return
    else:
      if url.scheme.toLowerAscii() notin ["http", "https"]:
        handle.onHttpError("Invalid URL scheme: " & url.scheme)
        return

    var port: INTERNET_PORT
    if url.port == "":
      case url.scheme.toLowerAscii():
      of "http":
        port = 80
      of "https":
        port = 443
      else:
        discard # Scheme is validated above
    else:
      try:
        let parsedPort = parseInt(url.port)
        if parsedPort < 0 or parsedPort > uint16.high.int:
          handle.onHttpError("Invalid port: " & url.port)
          return
        port = parsedPort.uint16
      except:
        handle.onHttpError("Parsing port failed")
        return

    var wideUserAgent = state.headers["user-agent"].wstr()

    state.hOpen = WinHttpOpen(
      cast[ptr WCHAR](wideUserAgent[0].addr),
      WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
      nil,
      nil,
      WINHTTP_FLAG_ASYNC
    )
    if state.hOpen == 0:
      handle.onHttpError("WinHttpOpen error: " & $GetLastError())
      return

    # Set timeouts to 0, we handle deadline ourselves
    if WinHttpSetTimeouts(state.hOpen, 0, 0, 0, 0) == 0:
      handle.onHttpError("WinHttpSetTimeouts error: " & $GetLastError())
      return

    let prevCallback = WinHttpSetStatusCallback(
      state.hOpen,
      httpCallback,
      cast[DWORD](WINHTTP_CALLBACK_FLAG_ALL_NOTIFICATIONS),
      0
    )

    if prevCallback == WINHTTP_INVALID_STATUS_CALLBACK:
      handle.onHttpError("WinHttpSetStatusCallback error")
      return

    var wideHostname = url.hostname.wstr()

    state.hConnect = WinHttpConnect(
      state.hOpen,
      cast[ptr WCHAR](wideHostname[0].addr),
      port,
      0
    )
    if state.hConnect == 0:
      handle.onHttpError("WinHttpConnect error: " & $GetLastError())
      return

    var wideVerb = state.verb.toUpperAscii().wstr()

    var objectName = url.path
    if url.search != "":
      objectName &= "?" & url.search

    var wideObjectName = objectName.wstr()

    var
      wideDefaultAcceptType = "*/*".wstr()
      defaultAcceptTypes = [
        cast[ptr WCHAR](wideDefaultAcceptType[0].addr),
        nil
      ]

    state.hRequest = WinHttpOpenRequest(
      state.hConnect,
      cast[ptr WCHAR](wideVerb[0].addr),
      cast[ptr WCHAR](wideObjectName[0].addr),
      nil,
      nil,
      cast[ptr ptr WCHAR](defaultAcceptTypes.addr),
      if url.scheme.toLowerAscii() == "https": WINHTTP_FLAG_SECURE.DWORD else: 0
    )
    if state.hRequest == 0:
      handle.onHttpError("WinHttpOpenRequest error: " & $GetLastError())
      return

    if state.requestBodyLen > 0:
      state.headers["Content-Length"] = $state.requestBodyLen

    var requestHeaders: string
    for header in state.headers:
      requestHeaders &= header.key & ": " & header.value & CRLF

    var wideRequestHeaders = requestHeaders.wstr()

    if WinHttpAddRequestHeaders(
      state.hRequest,
      cast[ptr WCHAR](wideRequestHeaders[0].addr),
      -1,
      (WINHTTP_ADDREQ_FLAG_ADD or WINHTTP_ADDREQ_FLAG_REPLACE).DWORD
    ) == 0:
      handle.onHttpError("WinHttpAddRequestHeaders error: " & $GetLastError())
      return

    if state.onWebSocketUpgrade != nil: # WebSocket request
      if WinHttpSetOption(
        state.hRequest,
        WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET,
        nil,
        0
      ) == 0:
        handle.onHttpError("WinHttpSetOption error: " & $GetLastError())
        return

    # WinHttpSendRequest starts triggering callbacks

    if WinHttpSendRequest(
      state.hRequest,
      nil,
      0,
      nil,
      0,
      0,
      cast[DWORD_PTR](handle)
    ) == 0:
      handle.onHttpError("WinHttpSendRequest error: " & $GetLastError())
      return

  proc onSendRequestComplete(handle: HttpRequestHandle) =
    let state = httpRequests.getOrDefault(handle, nil)
    if state == nil:
      return

    if state.canceled or state.closed:
      return

    if state.deadline > 0 and state.deadline <= epochTime():
      handle.onDeadlineExceeded()
      return

    if state.requestBodyLen > 0:
      if WinHttpWriteData(
        state.hRequest,
        state.requestBody,
        min(
          state.requestBodyLen,
          int16.high # Never read more than HIWORD
        ).DWORD,
        nil
      ) == 0:
        handle.onHttpError("WinHttpWriteData error " & $GetLastError())
    else:
      if WinHttpReceiveResponse(state.hRequest, nil) == 0:
        handle.onHttpError("WinHttpReceiveResponse error " & $GetLastError())

  proc onHeadersAvailable(handle: HttpRequestHandle) =
    let state = httpRequests.getOrDefault(handle, nil)
    if state == nil:
      return

    if state.canceled or state.closed:
      return

    if state.deadline > 0 and state.deadline <= epochTime():
      handle.onDeadlineExceeded()
      return

    if state.onWebSocketUpgrade != nil: # WebSocket request
      state.onWebSocketUpgrade()
      return

    var dwSize = sizeof(DWORD).DWORD
    if WinHttpQueryHeaders(
      state.hRequest,
      WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER,
      nil,
      state.responseCode.addr,
      dwSize.addr,
      nil
    ) == 0:
      handle.onHttpError("WinHttpQueryHeaders error: " & $GetLastError())
      return

    block: # Read Content-Length if present
      var
        buf = newString(32)
        bufLen = buf.len.DWORD
      if WinHttpQueryHeaders(
        state.hRequest,
        WINHTTP_QUERY_CONTENT_LENGTH,
        nil,
        buf[0].addr,
        bufLen.addr,
        nil
      ) == 0:
        if GetLastError() != ERROR_WINHTTP_HEADER_NOT_FOUND:
          handle.onHttpError("WinHttpQueryHeaders error: " & $GetLastError())
          return

      state.responseContentLength = -1 # Unkonwn length

      try:
        state.responseContentLength = parseInt($cast[ptr WCHAR](buf[0].addr))
      except:
        discard

    var
      responseHeadersLen: DWORD
      responseHeadersBuf: string

    # Determine how big the header buffer needs to be
    discard WinHttpQueryHeaders(
      state.hRequest,
      WINHTTP_QUERY_RAW_HEADERS_CRLF,
      nil,
      nil,
      responseHeadersLen.addr,
      nil
    )
    if GetLastError() == ERROR_INSUFFICIENT_BUFFER: # Expected!
      # Set the header buffer to the correct size and inclue a null terminator
      responseHeadersBuf.setLen(responseHeadersLen)
    else:
      handle.onHttpError("WinHttpQueryHeaders error: " & $GetLastError())
      return

    # Read the headers into the buffer
    if WinHttpQueryHeaders(
      state.hRequest,
      WINHTTP_QUERY_RAW_HEADERS_CRLF,
      nil,
      responseHeadersBuf[0].addr,
      responseHeadersLen.addr,
      nil
    ) == 0:
      handle.onHttpError("WinHttpQueryHeaders error: " & $GetLastError())
      return

    state.responseHeaders = $cast[ptr WCHAR](responseHeadersBuf[0].addr)

    if state.responseHeaders.len == 0:
      handle.onHttpError("Error parsing response headers")
      return

    state.responseBodyCap = 16384
    state.responseBody = allocShared0(state.responseBodyCap)

    if WinHttpReadData(
      state.hRequest,
      state.responseBody,
      state.responseBodyCap.DWORD,
      nil
    ) == 0:
      handle.onHttpError("WinHttpReadData error: " & $GetLastError())
      return

  proc onWriteComplete(handle: HttpRequestHandle, bytesWritten: int) =
    let state = httpRequests.getOrDefault(handle, nil)
    if state == nil:
      return

    if state.canceled or state.closed:
      return

    if state.deadline > 0 and state.deadline <= epochTime():
      handle.onDeadlineExceeded()
      return

    state.requestBodyBytesWritten += bytesWritten

    try:
      if state.onUploadProgress != nil:
        state.onUploadProgress(
          state.requestBodyBytesWritten,
          state.requestBodyLen
        )
    except:
      handle.onHttpError(getCurrentExceptionMsg())
      return

    if state.requestBodyBytesWritten == state.requestBodyLen:
      if WinHttpReceiveResponse(state.hRequest, nil) == 0:
        handle.onHttpError("WinHttpReceiveResponse error " & $GetLastError())
    else:
      let requestBody = cast[ptr UncheckedArray[uint8]](state.requestBody)
      if WinHttpWriteData(
        state.hRequest,
        requestBody[state.requestBodyBytesWritten].addr,
        min(
          state.requestBodyLen - state.requestBodyBytesWritten,
          int16.high # Never read more than HIWORD
        ).DWORD,
        nil
      ) == 0:
        handle.onHttpError("WinHttpWriteData error " & $GetLastError())

  proc onReadComplete(handle: HttpRequestHandle, bytesRead: int) =
    let state = httpRequests.getOrDefault(handle, nil)
    if state == nil:
      return

    if state.canceled or state.closed:
      return

    if state.deadline > 0 and state.deadline <= epochTime():
      handle.onDeadlineExceeded()
      return

    if bytesRead == 0: # This request is complete
      let response = HttpResponse()
      response.code = state.responseCode

      let responseHeaders = state.responseHeaders.split(CRLF)
      for i, line in responseHeaders:
        if i == 0: # HTTP/1.1 200 OK
          continue
        if line != "":
          let parts = line.split(":", 1)
          if parts.len == 2:
            response.headers.add(HttpHeader(
              key: strutils.strip(parts[0]),
              value: strutils.strip(parts[1])
            ))

      if state.responseBodyLen > 0:
        let contentEncoding = response.headers["content-encoding"]
        if contentEncoding.toLowerAscii() == "gzip":
          try:
            response.body = uncompress(
              state.responseBody,
              state.responseBodyLen
            )
          except:
            handle.onHttpError("Error uncompressing response")
            return
        else:
          response.body.setLen(state.responseBodyLen)
          copyMem(
            response.body[0].addr,
            state.responseBody,
            state.responseBodyLen
          )

      handle.close()

      try:
        if state.onResponse != nil:
          state.onResponse(response)
      except:
        handle.onHttpError(getCurrentExceptionMsg())
        return

    else: # Continue reading
      state.responseBodyLen += bytesRead

      try:
        if state.onDownloadProgress != nil:
          state.onDownloadProgress(
            state.responseBodyLen,
            state.responseContentLength
          )
      except:
        handle.onHttpError(getCurrentExceptionMsg())
        return

      if state.responseBodyCap - state.responseBodyLen < 8192:
        let newCap = state.responseBodyCap * 2
        state.responseBody =
          reallocShared0(state.responseBody, state.responseBodyCap, newCap)
        state.responseBodyCap = newCap

      let responseBody = cast[ptr UncheckedArray[uint8]](state.responseBody)
      if WinHttpReadData(
        state.hRequest,
        responseBody[state.responseBodyLen].addr,
        min(
          state.responseBodyCap - state.responseBodyLen,
          int16.high # Never read more than HIWORD
        ).DWORD,
        nil
      ) == 0:
        handle.onHttpError("WinHttpReadData error: " & $GetLastError())
        return

  proc close*(handle: WebSocketHandle) {.raises: [].} =
    let state = webSockets.getOrDefault(handle, nil)
    if state == nil:
      return

    state.closed = true

    state.httpRequest.cancel()

    discard PostMessageW(
      helperWindow,
      WM_HTTP,
      HTTP_WEBSOCKET_CLOSE,
      handle.LPARAM
    )

  proc destroy(handle: WebSocketHandle) =
    let state = webSockets.getOrDefault(handle, nil)
    if state == nil:
      return

    webSockets.del(handle)

    if state.buffer != nil:
      deallocShared(state.buffer)
    deallocShared(state)

  proc onWebSocketError(handle: WebSocketHandle, msg: string) =
    let state = webSockets.getOrDefault(handle, nil)
    if state == nil:
      return

    if state.closed:
      return

    handle.close()

    if state.onError != nil:
      state.onError(msg)

  proc openWebSocket*(
    url: string,
    deadline = defaultHttpDeadline
  ): WebSocketHandle {.raises: [].} =
    init()

    let state = cast[ptr WebSocketState](allocShared0(sizeof(WebSocketState)))
    state.httpRequest = startHttpRequest(
      url,
      "GET",
      deadline = deadline
    )

    var handle: WebSocketHandle
    while true:
      handle = windyRand.rand(int.high).WebSocketHandle
      if handle.HttpRequestHandle notin httpRequests and handle notin webSockets:
        webSockets[handle] = state
        break

    let requestState = httpRequests.getOrDefault(state.httpRequest)

    requestState.onWebSocketUpgrade = proc() =
      if state.closed:
        return

      state.hWebSocket = WinHttpWebSocketCompleteUpgrade(
        requestState.hRequest,
        cast[DWORD_PTR](handle)
      )
      if state.hWebSocket == 0:
        state.httpRequest.onHttpError(
          "WinHttpWebSocketCompleteUpgrade error: " & $GetLastError()
        )
        return

      requestState.deadline = 0
      requestState.onError = nil

      state.httpRequest.close()

      let prevCallback = WinHttpSetStatusCallback(
        state.hWebSocket,
        webSocketCallback,
        cast[DWORD](WINHTTP_CALLBACK_FLAG_ALL_NOTIFICATIONS),
        0
      )

      if prevCallback == WINHTTP_INVALID_STATUS_CALLBACK:
        handle.onWebSocketError("WinHttpSetStatusCallback error")
        return

      state.onOpenCalled = true

      try:
        if state.onOpen != nil:
          state.onOpen()
      except:
        handle.onWebSocketError(getCurrentExceptionMsg())
        return

      state.bufferCap = 16384
      state.buffer = allocShared0(state.bufferCap)

      discard WinHttpWebSocketReceive(
        state.hWebSocket,
        state.buffer,
        state.bufferCap.DWORD,
        nil,
        nil
      )

    requestState.onError = proc(msg: string) =
      if state.onError != nil:
        state.onError(msg)

    handle

  proc `onError=`*(
    handle: WebSocketHandle,
    callback: HttpErrorCallback
  ) =
    let state = webSockets.getOrDefault(handle, nil)
    if state == nil:
      return
    state.onError = callback

  proc `onOpen=`*(
    handle: WebSocketHandle,
    callback: Callback
  ) =
    let state = webSockets.getOrDefault(handle, nil)
    if state == nil:
      return
    state.onOpen = callback

  proc `onClose=`*(
    handle: WebSocketHandle,
    callback: Callback
  ) =
    let state = webSockets.getOrDefault(handle, nil)
    if state == nil:
      return
    state.onClose = callback

  proc `onMessage=`*(
    handle: WebSocketHandle,
    callback: WebSocketMessageCallback
  ) =
    let state = webSockets.getOrDefault(handle, nil)
    if state == nil:
      return
    state.onMessage = callback

  proc send*(msg: string, kind = Utf8Message) =
    discard

  proc onReadComplete(
    handle: WebSocketHandle,
    bytesRead: int,
    bufferKind: WINHTTP_WEB_SOCKET_BUFFER_TYPE
  ) =
    let state = webSockets.getOrDefault(handle, nil)
    if state == nil:
      return

    if state.closed:
      return

    state.bufferLen += bytesRead

    proc resetBuffer() =
      zeroMem(state.buffer, state.bufferCap)
      state.bufferLen = 0

    proc webSocketReceive() =
      if state.bufferCap - state.bufferLen < 8192:
        let newCap = state.bufferCap * 2
        state.buffer =
          reallocShared0(state.buffer, state.bufferCap, newCap)
        state.bufferCap = newCap

      let buffer = cast[ptr UncheckedArray[uint8]](state.buffer)
      discard WinHttpWebSocketReceive(
        state.hWebSocket,
        buffer[state.bufferLen].addr,
        min(
          state.bufferCap - state.bufferLen,
          int16.high # Never read more than HIWORD
        ).DWORD,
        nil,
        nil
      )

    case bufferKind:
    of WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE:
      if state.onMessage != nil:
        var msg = newString(state.bufferLen)
        copyMem(msg[0].addr, state.buffer, state.bufferLen)
        try:
          state.onMessage(msg, BinaryMessage)
        except:
          handle.onWebSocketError(getCurrentExceptionMsg())
          return

      resetBuffer()
      webSocketReceive()

    of WINHTTP_WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE:
      webSocketReceive()

    of WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE:
      if state.onMessage != nil:
        var msg = newString(state.bufferLen)
        copyMem(msg[0].addr, state.buffer, state.bufferLen)
        try:
          state.onMessage(msg, Utf8Message)
        except:
          handle.onWebSocketError(getCurrentExceptionMsg())
          return

      resetBuffer()
      webSocketReceive()

    of WINHTTP_WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE:
      webSocketReceive()

    of WINHTTP_WEB_SOCKET_CLOSE_BUFFER_TYPE:
      handle.close()

  proc onWebSocketClose(handle: WebSocketHandle) =
    let state = webSockets.getOrDefault(handle, nil)
    if state == nil:
      return

    state.closed = true

    discard WinHttpCloseHandle(state.hWebSocket)

    if state.onOpenCalled and state.onClose != nil:
      state.onClose()

proc pollEvents*() =
  # Clear all per-frame data
  for window in windows:
    window.state.perFrame = PerFrame()

  var msg: MSG
  while PeekMessageW(msg.addr, 0, 0, 0, PM_REMOVE) > 0:
    case msg.message:
    of WM_QUIT:
      for window in windows:
        discard wndProc(window.hwnd, WM_CLOSE, 0, 0)
    of WM_HTTP:
      when compileOption("threads"):
        let handle = msg.lParam
        if handle.WebSocketHandle in webSockets:
          case msg.wParam.uint8.int:
          of HTTP_REQUEST_ERROR:
            handle.WebSocketHandle.onWebSocketError("WinHttp request error")
          of HTTP_SECURE_ERROR:
            handle.WebSocketHandle.onWebSocketError("WinHttp secure error")
          of HTTP_READ_COMPLETE:
            let
              bytesRead = HIWORD(msg.wParam)
              bufferKind = (cast[uint](msg.wParam shr 8) and uint8.high).int
            handle.WebSocketHandle.onReadComplete(
              bytesRead,
              bufferKind.WINHTTP_WEB_SOCKET_BUFFER_TYPE
            )
          of HTTP_WEBSOCKET_CLOSE:
            handle.WebSocketHandle.onWebSocketClose()
          of HTTP_HANDLE_CLOSING:
            handle.WebSocketHandle.destroy()
          else:
            discard
        else:
          case LOWORD(msg.wParam):
          of HTTP_REQUEST_START:
            handle.HttpRequestHandle.onStartRequest()
          of HTTP_REQUEST_ERROR:
            handle.HttpRequestHandle.onHttpError("WinHttp request error")
          of HTTP_SECURE_ERROR:
            handle.HttpRequestHandle.onHttpError("WinHttp secure error")
          of HTTP_SENDREQUEST_COMPLETE:
            handle.HttpRequestHandle.onSendRequestComplete()
          of HTTP_HEADERS_AVAILABLE:
            handle.HttpRequestHandle.onHeadersAvailable()
          of HTTP_READ_COMPLETE:
            handle.HttpRequestHandle.onReadComplete(HIWORD(msg.wParam))
          of HTTP_WRITE_COMPLETE:
            handle.HttpRequestHandle.onWriteComplete(HIWORD(msg.wParam))
          of HTTP_REQUEST_CANCEL:
            handle.HttpRequestHandle.close()
          of HTTP_HANDLE_CLOSING:
            handle.HttpRequestHandle.destroy()
          else:
            discard
    else:
      discard TranslateMessage(msg.addr)
      discard DispatchMessageW(msg.addr)

  let now = epochTime()
  for handle, state in httpRequests:
    if state.deadline > 0 and state.deadline <= now:
      handle.onDeadlineExceeded()

  let activeWindow = windows.forHandle(GetActiveWindow())
  if activeWindow != nil:
    # When both shift keys are down the first one released does not trigger a
    # key up event so we fake it here.
    if KeyLeftShift in activeWindow.state.buttonDown:
      if (GetKeyState(VK_LSHIFT) and KF_UP) == 0:
        activeWindow.handleButtonRelease(KeyLeftShift)
    if KeyRightShift in activeWindow.state.buttonDown:
      if (GetKeyState(VK_RSHIFT) and KF_UP) == 0:
        activeWindow.handleButtonRelease(KeyRightShift)

  when defined(windyUseStdHttp):
    pollHttp()
