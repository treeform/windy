import unicode

type
  WindyError* = object of ValueError

  MSAA* = enum
    msaaDisabled = 0, msaa2x = 2, msaa4x = 4, msaa8x = 8

  Callback* = proc()
  ButtonCallback* = proc(button: Button)
  RuneCallback* = proc(rune: Rune)

  Button* = enum
    ButtonUnknown
    MouseLeft
    MouseRight
    MouseMiddle
    DoubleClick
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
    KeyBacktick
    KeyMinus
    KeyEqual
    KeyBackspace
    KeyTab
    KeyLeftBracket
    KeyRightBracket
    KeyBackslash
    KeyCapsLock
    KeySemicolon
    KeyApostrophe
    KeyEnter
    KeyLeftShift
    KeyComma
    KeyPeriod
    KeySlash
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
    NumpadDecimal
    NumpadEnter
    NumpadAdd
    NumpadSubtract
    NumpadMultiply
    NumpadDivide
    NumpadEqual
