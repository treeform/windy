import pixie, std/strutils, std/unicode

type
  WindyError* = object of ValueError

  Screen* = object
    left*, right*, top*, bottom*: int
    primary*: bool

  CursorKind* = enum
    DefaultCursor, CustomCursor

  Cursor* = object
    case kind*: CursorKind:
    of DefaultCursor:
      discard
    of CustomCursor:
      image*: Image
      hotspot*: IVec2

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

  MSAA* = enum
    msaaDisabled = 0, msaa2x = 2, msaa4x = 4, msaa8x = 8

  WindowStyle* = enum
    DecoratedResizable, Decorated, Undecorated

  Callback* = proc()
  ButtonCallback* = proc(button: Button)
  RuneCallback* = proc(rune: Rune)
  HttpErrorCallback* = proc(msg: string)
  HttpResponseCallback* = proc(response: HttpResponse)
  HttpProgressCallback* = proc(completed, total: int)
  WebSocketMessageCallback* = proc(msg: string, kind: WebSocketMessageKind)

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
