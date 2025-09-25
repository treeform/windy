when defined(cpu64):
  type
    UINT_PTR* = int64
    LONG_PTR* = int64
    ULONG_PTR* = int64
else:
  type
    UINT_PTR* = int32
    LONG_PTR* = int32
    ULONG_PTR* = int32

type
  BYTE* = uint8
  PBYTE* = ptr BYTE
  SHORT* = int16
  BOOL* = int32
  LPBOOL* = ptr BOOL
  LONG* = int32
  USHORT* = uint16
  LANGID* = USHORT
  WORD* = uint16
  ATOM* = WORD
  DWORD* = int32
  LPDWORD* = ptr DWORD
  DWORD_PTR* = ULONG_PTR
  SIZE_T* = ULONG_PTR
  INTERNET_PORT* = WORD
  LPCSTR* = cstring
  LPSTR* = cstring
  WCHAR* = uint16
  LPCCH* = cstring
  LPCWSTR* = ptr WCHAR
  LPWSTR* = ptr WCHAR
  HRESULT* = LONG
  HANDLE* = int
  HWND* = HANDLE
  HMENU* = HANDLE
  HINSTANCE* = HANDLE
  HDC* = HANDLE
  HGLRC* = HANDLE
  HMONITOR* = HANDLE
  HICON* = HANDLE
  HCURSOR* = HICON
  HBRUSH* = HANDLE
  HMODULE* = HINSTANCE
  HGLOBAL* = HANDLE
  HIMC* = HANDLE
  HBITMAP* = HANDLE
  HINTERNET* = HANDLE
  HRGN* = HANDLE
  HGDIOBJ* = HANDLE
  LPVOID* = pointer
  LPCVOID* = pointer
  UINT* = uint32
  WPARAM* = UINT_PTR
  LPARAM* = LONG_PTR
  LRESULT* = LONG_PTR
  WNDPROC* = proc(
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
  LPPOINT* = ptr POINT
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
  RECT* {.pure.} = object
    left*: LONG
    top*: LONG
    right*: LONG
    bottom*: LONG
  LPRECT* = ptr RECT
  LPCRECT* = ptr RECT
  WINDOWPLACEMENT* {.pure.} = object
    length*: UINT
    flags*: UINT
    showCmd*: UINT
    ptMinPosition*: POINT
    ptMaxPosition*: POINT
    rcNormalPosition*: RECT
  TRACKMOUSEEVENTSTRUCT* {.pure.} = object
    cbSize*: DWORD
    dwFlags*: DWORD
    hWndTrack*: HWND
    dwHoverTime*: DWORD
  LPTRACKMOUSEEVENTSTRUCT* = ptr TRACKMOUSEEVENTSTRUCT
  MONITORINFO* {.pure.} = object
    cbSize*: DWORD
    rcMonitor*: RECT
    rcWork*: RECT
    dwFlags*: DWORD
  LPMONITORINFO* = ptr MONITORINFO
  COMPOSITIONFORM* {.pure.} = object
    dwStyle*: DWORD
    ptCurrentPos*: POINT
    rcArea*: RECT
  LPCOMPOSITIONFORM* = ptr COMPOSITIONFORM
  CANDIDATEFORM* {.pure.} = object
    dwIndex*: DWORD
    dwStyle*: DWORD
    ptCurrentPos*: POINT
    rcArea*: RECT
  LPCANDIDATEFORM* = ptr CANDIDATEFORM
  GUID* {.pure.} = object
    Data1*: int32
    Data2*: uint16
    Data3*: uint16
    Data4*: array[8, uint8]
  NOTIFYICONDATAW_UNION1* {.pure, union.} = object
    uTimeout*: UINT
    uVersion*: UINT
  NOTIFYICONDATAW* {.pure.} = object
    cbSize*: DWORD
    hWnd*: HWND
    uID*: UINT
    uFlags*: UINT
    uCallbackMessage*: UINT
    hIcon*: HICON
    szTip*: array[128, WCHAR]
    dwState*: DWORD
    dwStateMask*: DWORD
    szInfo*: array[256, WCHAR]
    union1*: NOTIFYICONDATAW_UNION1
    szInfoTitle*: array[64, WCHAR]
    dwInfoFlags*: DWORD
    guidItem*: GUID
    hBalloonIcon*: HICON
  PNOTIFYICONDATAW* = ptr NOTIFYICONDATAW
  WINHTTP_STATUS_CALLBACK* = proc(
    hInternet: HINTERNET,
    dwContext: DWORD_PTR,
    dwInternetStatus: DWORD,
    lpvStatusInformation: LPVOID,
    dwStatusInformationLength: DWORD
  ): void {.stdcall.}
  WINHTTP_WEB_SOCKET_BUFFER_TYPE* = enum
    WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE = 0,
    WINHTTP_WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE = 1,
    WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE = 2,
    WINHTTP_WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE = 3,
    WINHTTP_WEB_SOCKET_CLOSE_BUFFER_TYPE = 4
  WINHTTP_WEB_SOCKET_STATUS* {.pure.} = object
    dwBytesTransferred*: DWORD
    eBufferType*: WINHTTP_WEB_SOCKET_BUFFER_TYPE
  DWM_BLURBEHIND* {.pure.} = object
    dwFlags*: DWORD
    fEnable*: BOOL
    hRgnBlur*: HRGN
    fTransitionOnMaximized*: BOOL

type
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
  wglSwapIntervalEXT* = proc(interval: int32): BOOL {.stdcall, raises: [].}
  SetProcessDpiAwarenessContext* = proc(
    value: int
  ): BOOL {.stdcall, raises: [].}
  GetDpiForWindow* = proc(hWnd: HWND): UINT {.stdcall, raises: [].}
  AdjustWindowRectExForDpi* = proc(
    lpRect: LPRECT,
    dwStyle: DWORD,
    bMenu: BOOL,
    dwExStyle: DWORD,
    dpi: UINT
  ): BOOL {.stdcall, raises: [].}
  MONITORENUMPROC* = proc(
    P1: HMONITOR,
    P2: HDC,
    P3: LPRECT,
    P4: LPARAM
  ): BOOL {.stdcall, raises: [].}

template MAKEINTRESOURCE*(i: untyped): untyped = cast[LPWSTR](i and 0xffff)

const
  FALSE* = 0
  TRUE* = 1
  S_OK* = 0
  UNICODE_NOCHAR* = 0xFFFF
  CP_UTF8* = 65001
  CS_VREDRAW* = 0x0001
  CS_HREDRAW* = 0x0002
  CS_DBLCLKS* = 0x0008
  IDC_ARROW* = MAKEINTRESOURCE(32512)
  IDC_IBEAM* = MAKEINTRESOURCE(32513)
  IDC_WAIT* = MAKEINTRESOURCE(32514)
  IDC_CROSS* = MAKEINTRESOURCE(32515)
  IDC_UPARROW* = MAKEINTRESOURCE(32516)
  IDC_SIZE* = MAKEINTRESOURCE(32640)
  IDC_ICON* = MAKEINTRESOURCE(32641)
  IDC_SIZENWSE* = MAKEINTRESOURCE(32642)
  IDC_SIZENESW* = MAKEINTRESOURCE(32643)
  IDC_SIZEWE* = MAKEINTRESOURCE(32644)
  IDC_SIZENS* = MAKEINTRESOURCE(32645)
  IDC_SIZEALL* = MAKEINTRESOURCE(32646)
  IDC_NO* = MAKEINTRESOURCE(32648)
  IDC_HAND* = MAKEINTRESOURCE(32649)
  IDC_APPSTARTING* = MAKEINTRESOURCE(32650)
  IDC_HELP* = MAKEINTRESOURCE(32651)
  IDI_APPLICATION* = MAKEINTRESOURCE(32512)
  IMAGE_ICON* = 1
  LR_DEFAULTCOLOR* = 0x0000
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
  WS_OVERLAPPEDWINDOW* = WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or
      WS_THICKFRAME or WS_MINIMIZEBOX or WS_MAXIMIZEBOX
  WS_TILEDWINDOW* = WS_OVERLAPPEDWINDOW
  WS_POPUPWINDOW* = WS_POPUP or WS_BORDER or WS_SYSMENU
  WS_CHILDWINDOW* = WS_CHILD
  WS_EX_APPWINDOW* = 0x00040000
  WS_EX_TOPMOST* = 0x00000008
  WS_EX_LAYERED* = 0x00080000
  WS_EX_TRANSPARENT* = 0x00000020
  WM_NULL* = 0x0000
  WM_CREATE* = 0x0001
  WM_DESTROY* = 0x0002
  WM_MOVE* = 0x0003
  WM_SIZE* = 0x0005
  WM_ACTIVATE* = 0x0006
  WM_SETFOCUS* = 0x0007
  WM_KILLFOCUS* = 0x0008
  WM_ENABLE* = 0x000A
  WM_PAINT* = 0x000F
  WM_CLOSE* = 0x0010
  WM_QUIT* = 0x0012
  WM_ERASEBKGND* = 0x0014
  WM_SHOWWINDOW* = 0x0018
  WM_ACTIVATEAPP* = 0x001C
  WM_SETCURSOR* = 0x0020
  WM_GETMINMAXINFO* = 0x0024
  WM_WINDOWPOSCHANGING* = 0x0046
  WM_WINDOWPOSCHANGED* = 0x0047
  WM_GETICON* = 0x007F
  WM_SETICON* = 0x0080
  WM_NCCREATE* = 0x0081
  WM_NCCALCSIZE* = 0x0083
  WM_NCPAINT* = 0x0085
  WM_NCACTIVATE* = 0x0086
  WM_KEYDOWN* = 0x0100
  WM_KEYUP* = 0x0101
  WM_CHAR* = 0x0102
  WM_SYSKEYDOWN* = 0x0104
  WM_SYSKEYUP* = 0x0105
  WM_SYSCHAR* = 0x0106
  WM_UNICHAR* = 0x0109
  WM_IME_STARTCOMPOSITION* = 0x010D
  WM_IME_ENDCOMPOSITION* = 0x010E
  WM_IME_COMPOSITION* = 0x010F
  WM_QUERYUISTATE* = 0x0129
  WM_SYSCOMMAND* = 0x0112
  WM_MOUSEMOVE* = 0x0200
  WM_LBUTTONDOWN* = 0x0201
  WM_LBUTTONUP* = 0x0202
  WM_LBUTTONDBLCLK* = 0x0203
  WM_RBUTTONDOWN* = 0x0204
  WM_RBUTTONUP* = 0x0205
  WM_RBUTTONDBLCLK* = 0x0206
  WM_MBUTTONDOWN* = 0x0207
  WM_MBUTTONUP* = 0x0208
  WM_MBUTTONDBLCLK* = 0x0209
  WM_MOUSEWHEEL* = 0x020A
  WM_XBUTTONDOWN* = 0x020B
  WM_XBUTTONUP* = 0x020C
  WM_MOUSEHWHEEL* = 0x020E
  WM_IME_SETCONTEXT* = 0x0281
  WM_IME_NOTIFY* = 0x0282
  WM_IME_CONTROL* = 0x0283
  WM_IME_COMPOSITIONFULL* = 0x0284
  WM_IME_SELECT* = 0x0285
  WM_IME_CHAR* = 0x0286
  WM_IME_REQUEST* = 0x0288
  WM_IME_KEYDOWN* = 0x0290
  WM_IME_KEYUP* = 0x0291
  WM_MOUSELEAVE* = 0x02A3
  WM_DPICHANGED* = 0x02E0
  WM_DWMCOMPOSITIONCHANGED* = 0x031e
  WM_DWMNCRENDERINGCHANGED* = 0x031f
  WM_DWMCOLORIZATIONCOLORCHANGED* = 0x0320
  WM_DWMWINDOWMAXIMIZEDCHANGE* = 0x0321
  WM_DWMSENDICONICTHUMBNAIL* = 0x0323
  WM_DWMSENDICONICLIVEPREVIEWBITMAP* = 0x0326
  WM_USER* = 0x0400
  WM_APP* = 0x8000
  SC_RESTORE* = 0xF120
  SC_MINIMIZE* = 0xF020
  SC_MAXIMIZE* = 0xF030
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
  DPI_AWARENESS_CONTEXT_UNAWARE* = -1
  DPI_AWARENESS_CONTEXT_SYSTEM_AWARE* = -2
  DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE * = -3
  DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 * = -4
  DPI_AWARENESS_CONTEXT_UNAWARE_GDISCALED * = -5
  SWP_NOSIZE* = 0x0001
  SWP_NOMOVE* = 0x0002
  SWP_NOZORDER* = 0x0004
  SWP_NOREDRAW* = 0x0008
  SWP_NOACTIVATE* = 0x0010
  SWP_FRAMECHANGED* = 0x0020
  SWP_SHOWWINDOW* = 0x0040
  SWP_HIDEWINDOW* = 0x0080
  SWP_NOCOPYBITS* = 0x0100
  SWP_NOOWNERZORDER* = 0x0200
  SWP_NOSENDCHANGING* = 0x0400
  SWP_DRAWFRAME* = SWP_FRAMECHANGED
  SWP_NOREPOSITION* = SWP_NOOWNERZORDER
  SWP_DEFERERASE* = 0x2000
  SWP_ASYNCWINDOWPOS* = 0x4000
  HWND_TOP* = HWND 0
  HWND_BOTTOM* = HWND 1
  HWND_TOPMOST* = HWND(-1)
  HWND_NOTOPMOST* = HWND(-2)
  GWL_WNDPROC* = -4
  GWL_HINSTANCE* = -6
  GWL_HWNDPARENT* = -8
  GWL_STYLE* = -16
  GWL_EXSTYLE* = -20
  GWL_USERDATA* = -21
  GWL_ID* = -12
  MONITOR_DEFAULTTONULL* = 0x00000000
  MONITOR_DEFAULTTOPRIMARY* = 0x00000001
  MONITOR_DEFAULTTONEAREST* = 0x00000002
  TME_HOVER* = 0x00000001
  TME_LEAVE* = 0x00000002
  TME_NONCLIENT* = 0x00000010
  TME_QUERY* = 0x40000000
  TME_CANCEL* = 0x80000000'i32
  KF_EXTENDED* = 0x0100
  KF_UP* = 0x8000
  VK_CONTROL* = 0x11
  VK_SNAPSHOT* = 0x2C
  VK_LSHIFT* = 0xA0
  VK_RSHIFT* = 0xA1
  VK_PROCESSKEY* = 0xE5
  CF_UNICODETEXT* = 13
  CF_DIB* = 8
  CF_DIBV5* = 17
  GMEM_MOVEABLE* = 0x2
  XBUTTON1* = 0x0001
  XBUTTON2* = 0x0002
  CFS_DEFAULT* = 0x0000
  CFS_RECT* = 0x0001
  CFS_POINT* = 0x0002
  CFS_FORCE_POSITION* = 0x0020
  CFS_CANDIDATEPOS* = 0x0040
  CFS_EXCLUDE* = 0x0080
  GCS_COMPREADSTR* = 0x0001
  GCS_COMPREADATTR* = 0x0002
  GCS_COMPREADCLAUSE* = 0x0004
  GCS_COMPSTR* = 0x0008
  GCS_COMPATTR* = 0x0010
  GCS_COMPCLAUSE* = 0x0020
  GCS_CURSORPOS* = 0x0080
  GCS_DELTASTART* = 0x0100
  GCS_RESULTREADSTR* = 0x0200
  GCS_RESULTREADCLAUSE* = 0x0400
  GCS_RESULTSTR* = 0x0800
  GCS_RESULTCLAUSE* = 0x1000
  CPS_COMPLETE* = 0x0001
  CPS_CONVERT* = 0x0002
  CPS_REVERT* = 0x0003
  CPS_CANCEL* = 0x0004
  NI_COMPOSITIONSTR* = 0x0015
  IACE_CHILDREN* = 0x0001
  IACE_DEFAULT* = 0x0010
  IACE_IGNORENOCONTEXT* = 0x0020
  NOTIFYICON_VERSION_4* = 4
  NIM_ADD* = 0x00000000
  NIM_MODIFY* = 0x00000001
  NIM_DELETE* = 0x00000002
  NIM_SETFOCUS* = 0x00000003
  NIM_SETVERSION* = 0x00000004
  NIF_MESSAGE* = 0x00000001
  NIF_ICON* = 0x00000002
  NIF_TIP* = 0x00000004
  NIF_STATE* = 0x00000008
  NIF_INFO* = 0x00000010
  NIF_GUID* = 0x00000020
  NIF_REALTIME* = 0x00000040
  NIF_SHOWTIP* = 0x00000080
  MF_STRING* = 0x00000000
  MF_SEPARATOR* = 0x00000800
  TPM_RETURNCMD* = 0x0100
  HTCLIENT* = 1
  ICON_SMALL* = 0
  ICON_BIG* = 1
  MONITORINFOF_PRIMARY* = 0x00000001
  ERROR_INSUFFICIENT_BUFFER* = 122
  WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY* = 4
  WINHTTP_FLAG_ASYNC* = 0x10000000
  WINHTTP_CALLBACK_FLAG_ALL_NOTIFICATIONS* = 0xffffffff
  WINHTTP_INVALID_STATUS_CALLBACK* = cast[WINHTTP_STATUS_CALLBACK](-1)
  WINHTTP_FLAG_SECURE* = 0x00800000
  WINHTTP_ADDREQ_FLAG_ADD* = 0x20000000
  WINHTTP_ADDREQ_FLAG_REPLACE* = 0x80000000'i32
  WINHTTP_CALLBACK_STATUS_RESOLVING_NAME* = 0x00000001
  WINHTTP_CALLBACK_STATUS_NAME_RESOLVED* = 0x00000002
  WINHTTP_CALLBACK_STATUS_CONNECTING_TO_SERVER* = 0x00000004
  WINHTTP_CALLBACK_STATUS_CONNECTED_TO_SERVER* = 0x00000008
  WINHTTP_CALLBACK_STATUS_SENDING_REQUEST* = 0x00000010
  WINHTTP_CALLBACK_STATUS_REQUEST_SENT* = 0x00000020
  WINHTTP_CALLBACK_STATUS_RECEIVING_RESPONSE* = 0x00000040
  WINHTTP_CALLBACK_STATUS_RESPONSE_RECEIVED* = 0x00000080
  WINHTTP_CALLBACK_STATUS_CLOSING_CONNECTION* = 0x00000100
  WINHTTP_CALLBACK_STATUS_CONNECTION_CLOSED* = 0x00000200
  WINHTTP_CALLBACK_STATUS_HANDLE_CREATED* = 0x00000400
  WINHTTP_CALLBACK_STATUS_HANDLE_CLOSING* = 0x00000800
  WINHTTP_CALLBACK_STATUS_REDIRECT* = 0x00004000
  WINHTTP_CALLBACK_STATUS_INTERMEDIATE_RESPONSE* = 0x00008000
  WINHTTP_CALLBACK_STATUS_SECURE_FAILURE* = 0x00010000
  WINHTTP_CALLBACK_STATUS_HEADERS_AVAILABLE* = 0x00020000
  WINHTTP_CALLBACK_STATUS_DATA_AVAILABLE* = 0x00040000
  WINHTTP_CALLBACK_STATUS_READ_COMPLETE* = 0x00080000
  WINHTTP_CALLBACK_STATUS_WRITE_COMPLETE* = 0x00100000
  WINHTTP_CALLBACK_STATUS_REQUEST_ERROR* = 0x00200000
  WINHTTP_CALLBACK_STATUS_SENDREQUEST_COMPLETE* = 0x00400000
  WINHTTP_CALLBACK_STATUS_CLOSE_COMPLETE* = 0x02000000
  WINHTTP_CALLBACK_STATUS_SHUTDOWN_COMPLETE* = 0x04000000
  WINHTTP_QUERY_STATUS_CODE* = 19
  WINHTTP_QUERY_CONTENT_LENGTH* = 5
  WINHTTP_QUERY_FLAG_NUMBER* = 0x20000000
  WINHTTP_QUERY_RAW_HEADERS_CRLF* = 22
  WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET* = 114
  WINHTTP_ERROR_BASE* = 12000
  ERROR_WINHTTP_HEADER_NOT_FOUND* = WINHTTP_ERROR_BASE + 150
  DWM_BB_ENABLE* = 0x00000001
  DWM_BB_BLURREGION* = 0x00000002

{.push importc, stdcall.}

proc GetLastError*(): DWORD {.dynlib: "Kernel32".}

proc MultiByteToWideChar*(
  codePage: UINT,
  dwFlags: DWORD,
  lpMultiByteStr: LPCCH,
  cbMultiByte: int32,
  lpWideCharStr: LPWSTR,
  cchWideChar: int32
): int32 {.dynlib: "Kernel32".}

proc WideCharToMultiByte*(
  codePage: UINT,
  dwFlags: DWORD,
  lpWideCharStr: LPWSTR,
  ccWideChar: int32,
  lpMultiByteStr: LPSTR,
  cbMultiByte: int32,
  lpDefaultChar: LPCCH,
  lpUsedDefaultChar: LPBOOL
): int32 {.dynlib: "Kernel32".}

proc LoadLibraryA*(
  lpLibFileName: LPCSTR
): HMODULE {.dynlib: "Kernel32".}

proc FreeLibrary*(
  hLibModule: HMODULE
): BOOL {.dynlib: "Kernel32".}

proc GetProcAddress*(
  hModule: HMODULE,
  lpProcName: LPCSTR
): FARPROC {.dynlib: "Kernel32".}

proc GetModuleHandleW*(
  lpModuleName: LPCWSTR
): HMODULE {.dynlib: "Kernel32".}

proc GetCurrentProcess*(): HANDLE {.dynlib: "Kernel32".}

proc GetProcessId*(
  hProcess: HANDLE
): DWORD {.dynlib: "Kernel32".}

proc GlobalLock*(
  hMem: HGLOBAL
): LPVOID {.dynlib: "Kernel32".}

proc GlobalUnlock*(
  hMem: HGLOBAL
): BOOL {.dynlib: "Kernel32".}

proc GlobalAlloc*(
  uFlags: UINT,
  dwBytes: UINT_PTR
): HGLOBAL {.dynlib: "Kernel32".}

proc GlobalFree*(
  hMem: HGLOBAL
): HGLOBAL {.dynlib: "Kernel32".}

proc GlobalSize*(
  hMem: HGLOBAL
): SIZE_T {.dynlib: "Kernel32".}

proc GetUserDefaultUILanguage*(): LANGID {.dynlib: "Kernel32".}

proc LoadCursorW*(
  hInstance: HINSTANCE,
  lpCursorName: LPCWSTR
): HCURSOR {.dynlib: "User32".}

proc LoadImageW*(
  hInstance: HINSTANCE,
  name: LPCWSTR,
  `type`: UINT,
  cx: int32,
  cy: int32,
  fuLoad: UINT
): HANDLE {.dynlib: "User32".}

proc GetClassInfoExW*(
  hInstance: HINSTANCE,
  lpszClass: LPCWSTR,
  lpwcx: LPWNDCLASSEXW
): BOOL {.dynlib: "User32".}

proc RegisterClassExW*(
  P1: ptr WNDCLASSEXW
): ATOM {.dynlib: "User32".}

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
): HWND {.dynlib: "User32".}

proc DefWindowProcW*(
  hWnd: HWND,
  uMsg: UINT,
  wParam: WPARAM,
  lParam: LPARAM
): LRESULT {.dynlib: "User32".}

proc ShowWindow*(
  hWnd: HWND,
  nCmdShow: int32
): BOOL {.dynlib: "User32".}

proc IsWindowVisible*(hWnd: HWND): BOOL {.dynlib: "User32".}

proc PeekMessageW*(
  lpMsg: LPMSG,
  hWnd: HWND,
  wMsgFilterMin: UINT,
  wMsgFilterMax: UINT,
  wRemoveMsg: UINT
): BOOL {.dynlib: "User32".}

proc TranslateMessage*(
  lpMsg: LPMSG
): BOOL {.dynlib: "User32".}

proc DispatchMessageW*(
  lpMsg: LPMSG
): LRESULT {.dynlib: "User32".}

proc GetActiveWindow*(): HWND {.dynlib: "User32".}

proc DestroyWindow*(hWnd: HWND): BOOL {.dynlib: "User32".}

proc GetDC*(hWnd: HWND): HDC {.dynlib: "User32".}

proc ReleaseDC*(
  hWnd: HWND,
  hdc: HDC
): BOOL {.dynlib: "User32".}

proc EnumDisplayMonitors*(
  hdc: HDC,
  lprcClip: LPCRECT,
  lpfnEnum: MONITORENUMPROC,
  dwData: LPARAM
): BOOL {.dynlib: "User32".}

proc MonitorFromWindow*(
  hWnd: HWND,
  dwFlags: DWORD
): HMONITOR {.dynlib: "User32".}

proc GetMonitorInfoW*(
  hMonitor: HMONITOR,
  lpmi: LPMONITORINFO
): BOOL {.dynlib: "User32".}

proc GetWindowPlacement*(
  hWnd: HWND,
  lpwndpl: ptr WINDOWPLACEMENT
): BOOL {.dynlib: "User32".}

proc SetWindowPlacement*(
  hWnd: HWND,
  lpwndpl: ptr WINDOWPLACEMENT
): BOOL {.dynlib: "User32".}

proc SetWindowPos*(
  hWnd: HWND,
  hWndInsertAfter: HWND,
  x: int32,
  y: int32,
  cx: int32,
  cy: int32,
  uFlags: UINT
): BOOL {.dynlib: "User32".}

proc GetWindowLongW*(
  hWnd: HWND,
  index: int32
): LONG {.dynlib: "User32".}

proc SetWindowLongW*(
  hWnd: HWND,
  index: int32,
  dwNewLong: LONG
): LONG {.dynlib: "User32".}

proc GetWindowRect*(
  hWnd: HWND,
  lpRect: LPRECT
): BOOL {.dynlib: "User32".}

proc GetClientRect*(
  hWnd: HWND,
  lpRect: LPRECT
): BOOL {.dynlib: "User32".}

proc ClientToScreen*(
  hWnd: HWND,
  lpPoint: LPPOINT
): BOOL {.dynlib: "User32".}

proc ScreenToClient*(
  hWnd: HWND,
  lpPoint: LPPOINT
): BOOL {.dynlib: "User32".}

proc SetPropW*(
  hWnd: HWND,
  lpString: LPCWSTR,
  hData: HANDLE
): BOOL {.dynlib: "User32".}

proc GetPropW*(
  hWnd: HWND,
  lpString: LPCWSTR
): BOOL {.dynlib: "User32".}

proc RemovePropW*(
  hWnd: HWND,
  lpString: LPCWSTR
): HANDLE {.dynlib: "User32".}

proc IsIconic*(hWnd: HWND): BOOL {.dynlib: "User32".}

proc IsZoomed*(hWnd: HWND): BOOL {.dynlib: "User32".}

proc GetCursorPos*(
  lpPoint: LPPOINT
): BOOL {.dynlib: "User32".}

proc TrackMouseEvent*(
  lpEventTrack: LPTRACKMOUSEEVENTSTRUCT
): BOOL {.dynlib: "User32".}

proc SetCapture*(hWnd: HWND): HWND {.dynlib: "User32".}

proc ReleaseCapture*(): BOOL {.dynlib: "User32".}

proc GetKeyState*(nVirtKey: int32): SHORT {.dynlib: "User32".}

proc SetWindowTextW*(
  hWnd: HWND,
  lpString: LPWSTR
): BOOL {.dynlib: "User32".}

proc SendMessageW*(
  hWnd: HWND,
  uMsg: UINT,
  wParam: WPARAM,
  lParam: LPARAM
): LRESULT {.dynlib: "User32".}

proc GetDoubleClickTime*(): UINT {.dynlib: "User32".}

proc MessageBoxW*(hWnd: HWND, lpText: LPCSTR, lpCaption: LPCSTR, uType: UINT): UINT {.dynlib: "User32".}

proc OpenClipboard*(
  hWndNewOwner: HWND
): BOOL {.dynlib: "User32".}

proc CloseClipboard*(): BOOL {.dynlib: "User32".}

proc EmptyClipboard*(): BOOL {.dynlib: "User32".}

proc SetClipboardData*(
  uFormat: UINT,
  hMem: HANDLE
): HANDLE {.dynlib: "User32".}

proc GetClipboardData*(
  uFormat: UINT
): HANDLE {.dynlib: "User32".}

proc IsClipboardFormatAvailable*(
  format: UINT
): BOOL {.dynlib: "User32".}

proc EnumClipboardFormats*(
  format: UINT
): UINT {.dynlib: "User32".}

proc CreateCaret*(
  hWnd: HWND,
  hBitamp: HBITMAP,
  nWidth: int32,
  nHeight: int32
): BOOL {.dynlib: "User32".}

proc DestroyCaret*(): BOOL {.dynlib: "User32".}

proc SetCaretPos*(
  x: int32,
  y: int32
): BOOL {.dynlib: "User32".}

proc CreateIconFromResourceEx*(
  presbits: PBYTE,
  dwResSize: DWORD,
  fIcon: BOOL,
  dwVer: DWORD,
  cxDesired: int32,
  cyDesired: int32,
  Flags: UINT
): HICON {.dynlib: "User32".}

proc DestroyIcon*(hIcon: HICON): BOOL {.dynlib: "User32".}

proc CreatePopupMenu*(): HMENU {.dynlib: "User32".}

proc DestroyMenu*(hMenu: HMENU): BOOL {.dynlib: "User32".}

proc AppendMenuW*(
  hMenu: HMENU,
  uFlags: UINT,
  uIDNewItem: UINT_PTR,
  lpNewItem: LPCWSTR
): BOOL {.dynlib: "User32".}

proc TrackPopupMenu*(
  hMenu: HMENU,
  uFlags: UINT,
  x: int32,
  y: int32,
  nReserved: int32,
  hWnd: HWND,
  prcRect: ptr RECT
): BOOL {.dynlib: "User32".}

proc SetCursor*(hCursor: HCURSOR): HCURSOR {.dynlib: "User32".}

proc DestroyCursor*(hCursor: HCURSOR): BOOL {.dynlib: "User32".}

proc PostMessageW*(
  hWnd: HWND,
  uMsg: UINT,
  wParam: WPARAM,
  lParam: LPARAM
): BOOL {. dynlib: "User32".}

proc ChoosePixelFormat*(
  hdc: HDC,
  ppfd: ptr PIXELFORMATDESCRIPTOR
): int32 {.dynlib: "Gdi32".}

proc SetPixelFormat*(
  hdc: HDC,
  format: int32,
  ppfd: ptr PIXELFORMATDESCRIPTOR
): BOOL {.dynlib: "Gdi32".}

proc GetPixelFormat*(hdc: HDC): int32 {.dynlib: "Gdi32".}

proc DescribePixelFormat*(
  hdc: HDC,
  iPixelFormat: int32,
  nBytes: UINT,
  ppfd: ptr PIXELFORMATDESCRIPTOR
): int32 {.dynlib: "Gdi32".}

proc SwapBuffers*(hdc: HDC): BOOL {.dynlib: "Gdi32".}

proc CreateRectRgn*(
  x1: int32,
  y1: int32,
  x2: int32,
  y2: int32
): HRGN {.dynlib: "Gdi32".}

proc DeleteObject*(ho: HGDIOBJ): BOOL {.dynlib: "Gdi32".}

proc DwmEnableBlurBehindWindow*(
  hWnd: HWND,
  pBlurBehind: ptr DWM_BLURBEHIND
): HRESULT {.dynlib: "Dwmapi"}

proc ImmGetContext*(
  hWnd: HWND
): HIMC {.dynlib: "imm32".}

proc ImmReleaseContext*(
  hWnd: HWND,
  hIMC: HIMC
): BOOL {.dynlib: "imm32".}

proc ImmSetCompositionWindow*(
  hIMC: HIMC,
  lpCompForm: LPCOMPOSITIONFORM
): BOOL {.dynlib: "imm32".}

proc ImmSetCandidateWindow*(
  hIMC: HIMC,
  lpCandidate: LPCANDIDATEFORM
): BOOL {.dynlib: "imm32".}

proc ImmGetCompositionStringW*(
  hIMC: HIMC,
  gcsValue: DWORD,
  lpBuf: LPVOID,
  dwBufLen: DWORD
): LONG {.dynlib: "imm32".}

proc ImmNotifyIME*(
  hIMC: HIMC,
  dwAction: DWORD,
  dwIndex: DWORD,
  dwValue: DWORD
): BOOL {.dynlib: "imm32".}

proc ImmAssociateContextEx*(
  hWnd: HWND,
  hIMC: HIMC,
  dwFlags: DWORD
): BOOL {.dynlib: "imm32".}

proc Shell_NotifyIconW*(
  dwMessage: DWORD,
  lpData: PNOTIFYICONDATAW
): BOOL {.dynlib: "shell32".}

proc WinHttpOpen*(
  lpszAgent: LPCWSTR,
  dwAccessType: DWORD,
  lpszProxy: LPCWSTR,
  lpszProxyBypass: LPCWSTR,
  dwFlags: DWORD
): HINTERNET {.dynlib: "winhttp".}

proc WinHttpSetTimeouts*(
  hSession: HINTERNET,
  nResolveTimeout, nConnectTimeout, nSendTimeout, nReceiveTimeout: int32
): BOOL {.dynlib: "winhttp".}

proc WinHttpConnect*(
  hSession: HINTERNET,
  lpszServerName: LPCWSTR,
  nServerPort: INTERNET_PORT,
  dwFlags: DWORD
): HINTERNET {.dynlib: "winhttp".}

proc WinHttpOpenRequest*(
  hConnect: HINTERNET,
  lpszVerb: LPCWSTR,
  lpszObjectName: LPCWSTR,
  lpszVersion: LPCWSTR,
  lpszReferrer: LPCWSTR,
  lplpszAcceptTypes: ptr LPCWSTR,
  dwFlags: DWORD
): HINTERNET {.dynlib: "winhttp".}

proc WinHttpAddRequestHeaders*(
  hRequest: HINTERNET,
  lpszHeaders: LPCWSTR,
  dwHeadersLength: DWORD,
  dwModifiers: DWORD
): BOOL {.dynlib: "winhttp".}

proc WinHttpSendRequest*(
  hRequest: HINTERNET,
  lpszHeaders: LPCWSTR,
  dwHeadersLength: DWORD,
  lpOptional: LPVOID,
  dwOptionalLength: DWORD,
  dwTotalLength: DWORD,
  dwContext: DWORD_PTR
): BOOL {.dynlib: "winhttp".}

proc WinHttpReceiveResponse*(
  hRequest: HINTERNET,
  lpReserved: LPVOID
): BOOL {.dynlib: "winhttp".}

proc WinHttpQueryHeaders*(
  hRequest: HINTERNET,
  dwInfoLevel: DWORD,
  pwszName: LPCWSTR,
  lpBuffer: LPVOID,
  lpdwBufferLength: LPDWORD,
  lpdwIndex: LPDWORD
): BOOL {.dynlib: "winhttp".}

proc WinHttpReadData*(
  hFile: HINTERNET,
  lpBuffer: LPVOID,
  dwNumberOfBytesToRead: DWORD,
  lpdwNumberOfBytesRead: LPDWORD
): BOOL {.dynlib: "winhttp".}

proc WinHttpCloseHandle*(hInternet: HINTERNET): BOOL {.dynlib: "winhttp".}

proc WinHttpSetStatusCallback*(
  hInternet: HINTERNET,
  lpfnInternetCallback: WINHTTP_STATUS_CALLBACK,
  dwNotificationFlags: DWORD,
  dwReserved: DWORD_PTR
): WINHTTP_STATUS_CALLBACK {.dynlib: "winhttp".}

proc WinHttpWriteData*(
  hInternet: HINTERNET,
  lpBuffer: LPCVOID,
  dwNumberOfBytesToWrite: DWORD,
  lpdwNumberOfBytesWritten: LPDWORD
): BOOL {.dynlib: "winhttp".}

proc WinHttpWebSocketCompleteUpgrade*(
  hRequest: HINTERNET,
  pContext: DWORD_PTR
): HINTERNET {.dynlib: "winhttp".}

proc WinHttpSetOption*(
  hInternet: HINTERNET,
  dwOption: DWORD,
  lpBuffer: LPVOID,
  dwBufferLength: DWORD
): BOOL {.dynlib: "winhttp".}

proc WinHttpWebSocketReceive*(
  hWebSocket: HINTERNET,
  pvBuffer: pointer,
  dwBufferLength: DWORD,
  pdwBytesRead: ptr DWORD,
  peBufferType: ptr WINHTTP_WEB_SOCKET_BUFFER_TYPE
): DWORD {.dynlib: "winhttp".}

proc WinHttpWebSocketClose*(
  hWebSocket: HINTERNET,
  usStatus: USHORT,
  pvReason: pointer,
  dwReasonLength: DWORD
): DWORD {.dynlib: "winhttp".}

{.pop.}
