import ../../common, utils, vmath, windefs

const
  windowClassName = "WINDY0"
  defaultScreenDpi = 96
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

    hWnd: HWND
    hdc: HDC
    hglrc: HGLRC

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
  let windowClassName = windowClassName.wstr()

  var wc: WNDCLASSEXW
  wc.cbSize = sizeof(WNDCLASSEXW).UINT
  wc.style = CS_HREDRAW or CS_VREDRAW or CS_DBLCLKS
  wc.lpfnWndProc = wndProc
  wc.hInstance = GetModuleHandleW(nil)
  wc.hCursor = LoadCursorW(0, IDC_ARROW)
  wc.lpszClassName = cast[ptr WCHAR](windowClassName[0].unsafeAddr)
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
    windowClassName = windowClassName.wstr()
    title = title.wstr()

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
    cast[ptr WCHAR](windowClassName[0].unsafeAddr),
    cast[ptr WCHAR](title[0].unsafeAddr),
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

proc setWindowStyle(hWnd: HWND, style: LONG) =
  discard SetWindowLongW(hWnd, style, GWL_STYLE)

proc makeContextCurrent(hdc: HDC, hglrc: HGLRC) =
  if wglMakeCurrent(hdc, hglrc) == 0:
    raise newException(WindyError, "Error activating OpenGL rendering context")

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

proc callCallback(name: string, callback: Callback) {.raises: [].} =
  if callback == nil:
    return
  try:
    callback()
  except:
    quit("Exception during " & name & " callback: " & getCurrentExceptionMsg())

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
    callCallback("onCloseRequest", window.onCloseRequest)
    return 0
  of WM_MOVE:
    callCallback("onMove", window.onMove)
    return 0
  of WM_SIZE:
    callCallback("onResize", window.onResize)
    return 0
  of WM_SETFOCUS, WM_KILLFOCUS:
    callCallback("onFocusChange", window.onFocusChange)
    return 0
  else:
    discard

  DefWindowProcW(hWnd, uMsg, wParam, lParam)

proc init*() =
  if initialized:
    raise newException(WindyError, "Windy is already initialized")
  loadLibraries()
  discard SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)
  loadOpenGL()
  registerWindowClass(windowClassName, wndProc)
  initialized = true

proc pollEvents*() =
  var msg: MSG
  while PeekMessageW(msg.addr, 0, 0, 0, PM_REMOVE) > 0:
    if msg.message == WM_QUIT:
      for window in windows:
        discard wndProc(window.hwnd, WM_CLOSE, 0, 0)
      # app.quitRequested = true
    else:
      discard TranslateMessage(msg.addr)
      discard DispatchMessageW(msg.addr)

proc makeContextCurrent*(window: Window) =
  makeContextCurrent(window.hdc, window.hglrc)

proc swapBuffers*(window: Window) =
  if SwapBuffers(window.hdc) == 0:
    raise newException(WindyError, "Error swapping buffers")

proc close*(window: Window) =
  destroy window

proc newWindow*(
  title: string,
  size: IVec2,
  vsync = true,
  openglMajorVersion = 4,
  openglMinorVersion = 1,
  msaa = msaaDisabled,
  depthBits = 24,
  stencilBits = 8
): Window =
  result = Window()
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
  except WindyError as e:
    destroy result
    raise e

proc visible*(window: Window): bool =
  IsWindowVisible(window.hWnd) != 0

proc decorated*(window: Window): bool =
  let style = getWindowStyle(window.hWnd)
  (style and WS_BORDER) != 0

proc resizable*(window: Window): bool =
  let style = getWindowStyle(window.hWnd)
  (style and WS_THICKFRAME) != 0

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

proc focused*(window: Window): bool =
  window.hWnd == GetActiveWindow()

proc `decorated=`*(window: Window, decorated: bool) =
  var style: LONG
  if decorated:
    style = decoratedWindowStyle
  else:
    style = undecoratedWindowStyle

  if window.visible:
    style = style or WS_VISIBLE

  setWindowStyle(window.hWnd, style)

proc `visible=`*(window: Window, visible: bool) =
  if visible:
    discard ShowWindow(window.hWnd, SW_SHOW)
  else:
    discard ShowWindow(window.hWnd, SW_HIDE)

proc `resizable=`*(window: Window, resizable: bool) =
  if not window.decorated:
    return

  var style = decoratedWindowStyle.LONG
  if resizable:
    style = style or (WS_MAXIMIZEBOX or WS_THICKFRAME)
  else:
    style = style and not (WS_MAXIMIZEBOX or WS_THICKFRAME)

  if window.visible:
    style = style or WS_VISIBLE

  setWindowStyle(window.hWnd, style)

proc `size=`*(window: Window, size: IVec2) =
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
