when defined(cpu64):
  type
    UINT_PTR* = int64
    LONG_PTR* = int64
else:
  type
    UINT_PTR* = int32
    LONG_PTR* = int32

type
  BYTE* = uint8
  BOOL* = int32
  LONG* = int32
  WORD* = uint16
  ATOM* = WORD
  DWORD* = int32
  LPCSTR* = cstring
  WCHAR* = uint16
  LPCCH* = cstring
  LPCWSTR* = ptr WCHAR
  LPWSTR* = ptr WCHAR
  HANDLE* = int
  HWND* = HANDLE
  HMENU* = HANDLE
  HINSTANCE* = HANDLE
  HDC* = HANDLE
  HGLRC* = HANDLE
  HICON* = HANDLE
  HCURSOR* = HICON
  HBRUSH* = HANDLE
  HMODULE* = HINSTANCE
  LPVOID* = pointer
  UINT* = uint32
  WPARAM* = UINT_PTR
  LPARAM* = LONG_PTR
  LRESULT* = LONG_PTR
  WNDPROC* = proc (
    hWnd: HWND,
    uMsg: UINT,
    wParam: WPARAM,
    lParam: LPARAM
  ): LRESULT {.stdcall.}
  WNDCLASSEXW* {.pure.} = object
    cbSize*: UINT
    style*: UINT
    lpfnWndProc*: WNDPROC
    cbClsExtra*: int32
    cbWndExtra*: int32
    hInstance*: HINSTANCE
    hIcon*: HICON
    hCursor*: HCURSOR
    hbrBackground*: HBRUSH
    lpszMenuName*: LPCWSTR
    lpszClassName*: LPCWSTR
    hIconSm*: HICON
  LPWNDCLASSEXW* = ptr WNDCLASSEXW
  POINT* {.pure.} = object
    x*: LONG
    y*: LONG
  MSG* {.pure.} = object
    hwnd*: HWND
    message*: UINT
    wParam*: WPARAM
    lParam*: LPARAM
    time*: DWORD
    pt*: POINT
  LPMSG* = ptr MSG
  PROC* = pointer
  FARPROC* = pointer
  wglCreateContext* = proc(hdc: HDC): HGLRC {.stdcall, raises: [].}
  wglDeleteContext* = proc(hglrc: HGLRC): BOOL {.stdcall, raises: [].}
  wglGetProcAddress* = proc(lpProcName: LPCSTR): PROC {.stdcall, raises: [].}
  wglGetCurrentDC* = proc(): HDC {.stdcall, raises: [].}
  wglGetCurrentContext* = proc(): HGLRC {.stdcall, raises: [].}
  wglMakeCurrent* = proc(hdc: HDC, hglrc: HGLRC): BOOL {.stdcall, raises: [].}
  wglCreateContextAttribsARB* = proc(
    hdc: HDC,
    hShareContext: HGLRC,
    attribList: ptr int32
  ): HGLRC {.stdcall, raises: [].}
  wglChoosePixelFormatARB* = proc(
    hdc: HDC,
    piAttribIList: ptr int32,
    pfAttribFList: ptr float32,
    nMaxFormats: UINT,
    piFormats: ptr int32,
    nNumFormats: ptr UINT
  ): BOOL {.stdcall, raises: [].}
  PIXELFORMATDESCRIPTOR* {.pure.} = object
    nSize*: WORD
    nVersion*: WORD
    dwFlags*: DWORD
    iPixelType*: BYTE
    cColorBits*: BYTE
    cRedBits*: BYTE
    cRedShift*: BYTE
    cGreenBits*: BYTE
    cGreenShift*: BYTE
    cBlueBits*: BYTE
    cBlueShift*: BYTE
    cAlphaBits*: BYTE
    cAlphaShift*: BYTE
    cAccumBits*: BYTE
    cAccumRedBits*: BYTE
    cAccumGreenBits*: BYTE
    cAccumBlueBits*: BYTE
    cAccumAlphaBits*: BYTE
    cDepthBits*: BYTE
    cStencilBits*: BYTE
    cAuxBuffers*: BYTE
    iLayerType*: BYTE
    bReserved*: BYTE
    dwLayerMask*: DWORD
    dwVisibleMask*: DWORD
    dwDamageMask*: DWORD

template MAKEINTRESOURCE*(i: untyped): untyped = cast[LPWSTR](i and 0xffff)

const
  CP_UTF8* = 65001
  CS_VREDRAW* = 0x0001
  CS_HREDRAW* = 0x0002
  CS_DBLCLKS* = 0x0008
  IDC_ARROW* = MAKEINTRESOURCE(32512)
  IDI_APPLICATION* = MAKEINTRESOURCE(32512)
  IMAGE_ICON* = 1
  LR_DEFAULTSIZE* = 0x0040
  LR_SHARED* = 0x8000
  CW_USEDEFAULT* = 0x80000000'i32
  WS_OVERLAPPED* = 0x00000000
  WS_POPUP* = 0x80000000'i32
  WS_CHILD* = 0x40000000
  WS_MINIMIZE* = 0x20000000
  WS_VISIBLE* = 0x10000000
  WS_DISABLED* = 0x08000000
  WS_CLIPSIBLINGS* = 0x04000000
  WS_CLIPCHILDREN* = 0x02000000
  WS_MAXIMIZE* = 0x01000000
  WS_CAPTION* = 0x00C00000
  WS_BORDER* = 0x00800000
  WS_DLGFRAME* = 0x00400000
  WS_VSCROLL* = 0x00200000
  WS_HSCROLL* = 0x00100000
  WS_SYSMENU* = 0x00080000
  WS_THICKFRAME* = 0x00040000
  WS_GROUP* = 0x00020000
  WS_TABSTOP* = 0x00010000
  WS_MINIMIZEBOX* = 0x00020000
  WS_MAXIMIZEBOX* = 0x00010000
  WS_TILED* = WS_OVERLAPPED
  WS_ICONIC* = WS_MINIMIZE
  WS_SIZEBOX* = WS_THICKFRAME
  WS_OVERLAPPEDWINDOW* = WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_THICKFRAME or WS_MINIMIZEBOX or WS_MAXIMIZEBOX
  WS_TILEDWINDOW* = WS_OVERLAPPEDWINDOW
  WS_POPUPWINDOW* = WS_POPUP or WS_BORDER or WS_SYSMENU
  WS_CHILDWINDOW* = WS_CHILD
  WS_EX_APPWINDOW* = 0x00040000
  WM_NULL* = 0x0000
  WM_CREATE* = 0x0001
  WM_DESTROY* = 0x0002
  WM_CLOSE* = 0x0010
  WM_QUIT* = 0x0012
  WM_NCCREATE* = 0x0081
  WM_NCCALCSIZE* = 0x0083
  SW_HIDE* = 0
  SW_SHOWNORMAL* = 1
  SW_NORMAL* = 1
  SW_SHOWMINIMIZED* = 2
  SW_SHOWMAXIMIZED* = 3
  SW_MAXIMIZE* = 3
  SW_SHOWNOACTIVATE* = 4
  SW_SHOW* = 5
  SW_MINIMIZE* = 6
  SW_SHOWMINNOACTIVE* = 7
  SW_SHOWNA* = 8
  SW_RESTORE* = 9
  SW_SHOWDEFAULT* = 10
  SW_FORCEMINIMIZE* = 11
  PM_NOREMOVE* = 0x0000
  PM_REMOVE* = 0x0001
  PM_NOYIELD* = 0x0002
  PFD_DRAW_TO_WINDOW* = 0x00000004
  PFD_SUPPORT_OPENGL* = 0x00000020
  PFD_DOUBLEBUFFER* = 0x00000001
  PFD_TYPE_RGBA* = 0

proc GetLastError*(): DWORD {.importc, stdcall, dynlib: "Kernel32".}

proc MultiByteToWideChar*(
  codePage: UINT,
  dwFlags: DWORD,
  lpMultiByteStr: LPCCH,
  cbMultiByte: int32,
  lpWideCharStr: LPWSTR,
  cchWideChar: int32
): int32 {.importc, stdcall, dynlib: "Kernel32".}

proc LoadLibraryA*(
  lpLibFileName: LPCSTR
): HMODULE {.importc, stdcall, dynlib: "Kernel32".}

proc FreeLibrary*(
  hLibModule: HMODULE
): BOOL {.importc, stdcall, dynlib: "Kernel32".}

proc GetProcAddress*(
  hModule: HMODULE,
  lpProcName: LPCSTR
): FARPROC {.importc, stdcall, dynlib: "Kernel32".}

proc GetModuleHandleW*(
  lpModuleName: LPCWSTR
): HMODULE {.importc, stdcall, dynlib: "Kernel32".}

proc LoadCursorW*(
  hInstance: HINSTANCE,
  lpCursorName: LPCWSTR
): HCURSOR {.importc, stdcall, dynlib: "User32".}

proc LoadImageW*(
  hInstance: HINSTANCE,
  name: LPCWSTR,
  `type`: UINT,
  cx: int32,
  cy: int32,
  fuLoad: UINT
): HANDLE {.importc, stdcall, dynlib: "User32".}

proc GetClassInfoExW*(
  hInstance: HINSTANCE,
  lpszClass: LPCWSTR,
  lpwcx: LPWNDCLASSEXW
): BOOL {.importc, stdcall, dynlib: "User32".}

proc RegisterClassExW*(
  P1: ptr WNDCLASSEXW
): ATOM {.importc, stdcall, dynlib: "User32".}

proc CreateWindowExW*(
  dwExStyle: DWORD,
  lpClassName: LPCWSTR,
  lpWindowName: LPCWSTR,
  dwStyle: DWORD,
  X: int32,
  Y: int32,
  nWidth: int32,
  nHeight: int32,
  hWndParent: HWND,
  hMenu: HMENU,
  hInstance: HINSTANCE,
  lpParam: LPVOID
): HWND {.importc, stdcall, dynlib: "User32".}

proc DefWindowProcW*(
  hWnd: HWND,
  uMsg: UINT,
  wParam: WPARAM,
  lParam: LPARAM
): LRESULT {.importc, stdcall, dynlib: "User32".}

proc ShowWindow*(
  hWnd: HWND,
  nCmdShow: int32
): BOOL {.importc, stdcall, dynlib: "User32".}

proc PeekMessageW*(
  lpMsg: LPMSG,
  hWnd: HWND,
  wMsgFilterMin: UINT,
  wMsgFilterMax: UINT,
  wRemoveMsg: UINT
): BOOL {.importc, stdcall, dynlib: "User32".}

proc TranslateMessage*(
  lpMsg: LPMSG
): BOOL {.importc, stdcall, dynlib: "User32".}

proc DispatchMessageW*(
  lpMsg: LPMSG
): LRESULT {.importc, stdcall, dynlib: "User32".}

proc GetActiveWindow*(): HWND {.importc, stdcall, dynlib: "User32".}

proc DestroyWindow*(hWnd: HWND): BOOL {.importc, stdcall, dynlib: "User32".}

proc GetDC*(hWnd: HWND): HDC {.importc, stdcall, dynlib: "User32".}

proc ReleaseDC*(
  hWnd: HWND,
  hdc: HDC
): BOOL {.importc, stdcall, dynlib: "User32".}

proc ChoosePixelFormat*(
  hdc: HDC,
  ppfd: ptr PIXELFORMATDESCRIPTOR
): int32 {.importc, stdcall, dynlib: "Gdi32".}

proc SetPixelFormat*(
  hdc: HDC,
  format: int32,
  ppfd: ptr PIXELFORMATDESCRIPTOR
): BOOL {.importc, stdcall, dynlib: "Gdi32".}

proc GetPixelFormat*(hdc: HDC): int32 {.importc, stdcall, dynlib: "Gdi32".}

proc DescribePixelFormat*(
  hdc: HDC,
  iPixelFormat: int32,
  nBytes: UINT,
  ppfd: ptr PIXELFORMATDESCRIPTOR
): int32 {.importc, stdcall, dynlib: "Gdi32".}

proc SwapBuffers*(hdc: HDC): BOOL {.importc, stdcall, dynlib: "Gdi32".}
