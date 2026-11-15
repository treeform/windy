import ../../common

type
  NativeTouchPhase* = enum
    NativeTouchBegan
    NativeTouchMoved
    NativeTouchEnded
    NativeTouchCancelled
    NativeTouchHover

  NativeKeyAction* = enum
    NativeKeyPressed
    NativeKeyRepeated
    NativeKeyReleased

  NativeCallbacks* = object
    ## Main-thread events delivered by Windy's UIKit host.
    onInitialize*: proc()
    onFrame*: proc()
    onResize*: proc(width, height: int32, scale: float32)
    onFocus*: proc(focused: bool)
    onTouch*: proc(id: int, phase: NativeTouchPhase, x, y: float64)
    # Keys use UIKit USB HID usages and UIKeyModifierFlags.
    # uint.high means a software keyboard event has no modifier snapshot.
    onKey*: proc(usage: int, action: NativeKeyAction, modifiers: uint)
    onText*: proc(text: string)
    onTextEdit*: proc(edit: TextInputEdit)
    onScroll*: proc(x, y, deltaX, deltaY: float64)
    onError*: proc(message: string)
