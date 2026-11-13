import pixie, std/strutils, std/unicode

type
  WindyError* = object of ValueError

  TouchPhase* = enum
    TouchBegin, TouchMove, TouchEnd, TouchCancel
  TouchContact* = object
    id*: int32
    position*: Vec2
  TouchEvent* = object
    contact*: TouchContact
    phase*: TouchPhase
  TouchCallback* = proc(event: TouchEvent)

  OpenGLVersion* = enum
    OpenGL3Dot0
    OpenGL3Dot1
    OpenGL3Dot2
    OpenGL3Dot3
    OpenGL4Dot0
    OpenGL4Dot1
    OpenGL4Dot2
    OpenGL4Dot3
    OpenGL4Dot4
    OpenGL4Dot5
    OpenGL4Dot6

  Screen* = object
    left*, right*, top*, bottom*: int
    primary*: bool

  CursorKind* = enum
    ArrowCursor
    PointerCursor
    IBeamCursor
    CrosshairCursor
    ClosedHandCursor
    OpenHandCursor
    ResizeLeftCursor
    ResizeRightCursor
    ResizeLeftRightCursor
    ResizeUpCursor
    ResizeDownCursor
    ResizeUpDownCursor
    OperationNotAllowedCursor
    WaitCursor
    CustomCursor

  Cursor* = object
    case kind*: CursorKind:
    of CustomCursor:
      image*: Image
      hotspot*: IVec2
    else:
      discard

  HttpHeader* = object
    key*, value*: string

  HttpRequestHandle* = distinct int
  WebSocketHandle* = distinct int

  HttpResponse* = ref object
    code*: int
    headers*: seq[HttpHeader]
    body*: string

  WebSocketMessageKind* = enum
    Utf8Message, BinaryMessage

  ClipboardContentKind* = enum
    TextContent, ImageContent

  FileDialogFilter* = object
    ## One named group of extensions for open/save dialogs.
    ## Use extensions like "*.vox;*.qb" or "vox,qb".
    name*: string
    extensions*: string

  ## Result of an unsaved-changes confirm dialog.
  ConfirmKind* = enum
    ConfirmCancel
    ConfirmNo
    ConfirmYes

  MSAA* = enum
    msaaDisabled = 0, msaa2x = 2, msaa4x = 4, msaa8x = 8

  WindowStyle* = enum
    DecoratedResizable, Decorated, Undecorated, Transparent

  Callback* = proc()
  TrayMenuEntryKind* = enum
    TrayMenuOption, TrayMenuSeparator

  TrayMenuEntry* = object
    ## A tray menu option or separator. Option labels are literal UTF-8 text.
    case kind*: TrayMenuEntryKind
    of TrayMenuOption:
      text*: string
      onClick*: Callback
    of TrayMenuSeparator:
      discard

  ButtonCallback* = proc(button: Button)
  RuneCallback* = proc(rune: Rune)
  TextInputCallback* = proc(text: string)
    ## Receives committed text as one edit, instead of individual onRune calls.
    ## Takes priority over onRune and requires runeInputEnabled.
    ## Native commits may contain multiple runes and line breaks.
  TextInputState* = object
    ## Describes the focused editor for native text services on macOS/Windows.
    ## Selection and visible ranges use half-open rune offsets.
    id*: string
      ## A nonempty field identity activates the editor; an empty one clears it.
    text*: string
    selectionStart*, selectionEnd*: int
    visibleStart*, visibleEnd*: int
    bounds*: Rect
      ## Bounds use framebuffer pixels measured from the window's top-left.
    multiline*, password*: bool

  TextInputEditKind* = enum
    ReplaceText, SelectText

  TextInputEdit* = object
    ## Requests an edit over a half-open range of rune offsets.
    kind*: TextInputEditKind
    text*: string
    start*, length*: int

  TextInputEditCallback* = proc(edit: TextInputEdit)
    ## Receives native selection or replacement requests on macOS/Windows.
    ## Apply the request to the editor, then publish its state again.
    ## Requires runeInputEnabled and an active, nonsecure TextInputState.
  HttpErrorCallback* = proc(msg: string)
  HttpResponseCallback* = proc(response: HttpResponse)
  HttpProgressCallback* = proc(completed, total: int)
  WebSocketMessageCallback* = proc(msg: string, kind: WebSocketMessageKind)
  FileDropCallback* = proc(fileName: string, fileData: string)

  Button* = enum
    ButtonUnknown
    MouseLeft
    MouseRight
    MouseMiddle
    MouseButton4
    MouseButton5
    DoubleClick
    TripleClick
    QuadrupleClick
    Key0
    Key1
    Key2
    Key3
    Key4
    Key5
    Key6
    Key7
    Key8
    Key9
    KeyA
    KeyB
    KeyC
    KeyD
    KeyE
    KeyF
    KeyG
    KeyH
    KeyI
    KeyJ
    KeyK
    KeyL
    KeyM
    KeyN
    KeyO
    KeyP
    KeyQ
    KeyR
    KeyS
    KeyT
    KeyU
    KeyV
    KeyW
    KeyX
    KeyY
    KeyZ
    KeyBacktick     # `
    KeyMinus        # -
    KeyEqual        # =
    KeyBackspace
    KeyTab
    KeyLeftBracket  # [
    KeyRightBracket # ]
    KeyBackslash    # \
    KeyCapsLock
    KeySemicolon    # :
    KeyApostrophe   # '
    KeyEnter
    KeyLeftShift
    KeyComma        # ,
    KeyPeriod       # .
    KeySlash        # /
    KeyRightShift
    KeyLeftControl
    KeyLeftSuper
    KeyLeftAlt
    KeySpace
    KeyRightAlt
    KeyRightSuper
    KeyMenu
    KeyRightControl
    KeyDelete
    KeyHome
    KeyEnd
    KeyInsert
    KeyPageUp
    KeyPageDown
    KeyEscape
    KeyUp
    KeyDown
    KeyLeft
    KeyRight
    KeyPrintScreen
    KeyScrollLock
    KeyPause
    KeyF1
    KeyF2
    KeyF3
    KeyF4
    KeyF5
    KeyF6
    KeyF7
    KeyF8
    KeyF9
    KeyF10
    KeyF11
    KeyF12
    KeyNumLock
    Numpad0
    Numpad1
    Numpad2
    Numpad3
    Numpad4
    Numpad5
    Numpad6
    Numpad7
    Numpad8
    Numpad9
    NumpadDecimal   # .
    NumpadEnter
    NumpadAdd       # +
    NumpadSubtract  # -
    NumpadMultiply  # *
    NumpadDivide    # /
    NumpadEqual     # =

  ButtonView* = distinct set[Button]

const
  defaultHttpDeadline*: float32 = -1

proc `==`*(a, b: HttpRequestHandle): bool =
  a.int == b.int

proc `==`*(a, b: WebSocketHandle): bool =
  a.int == b.int

proc `[]`*(buttonView: ButtonView, button: Button): bool =
  button in set[Button](buttonView)

proc len*(buttonView: ButtonView): int =
  set[Button](buttonView).len

proc `[]`*(headers: seq[HttpHeader], key: string): string =
  ## Get a key out of headers. Not case sensitive.
  ## Use a for loop to get duplicate keys.
  for header in headers:
    if header.key.toLowerAscii() == key.toLowerAscii():
      return header.value

proc `[]=`*(headers: var seq[HttpHeader], key, value: string) =
  ## Sets a key in the headers. Not case sensitive.
  ## Overwrites the existing header for key if it exists else adds a new header.
  for header in headers.mitems:
    if header.key.toLowerAscii() == key.toLowerAscii():
      header.value = value
      return
  headers.add(HttpHeader(key: key, value: value))

proc size*(screen: Screen): IVec2 =
  ## Returns the size of the screen.
  ivec2(
    (screen.right - screen.left).int32,
    (screen.bottom - screen.top).int32
  )

proc warn*(message: string) =
  ## Warns about missing functionality.
  echo "Warning: ", message
