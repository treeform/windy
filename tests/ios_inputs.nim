when not defined(windyIosTesting):
  {.error: "Run with -d:windyIosTesting to use the native host mock.".}

include ../src/windy/platforms/ios/platform

const ShiftFlag = 1'u shl 17

var window: Window
runApplication(proc() =
  window = newWindow("Input test", ivec2(640, 480))
  doAssert window.metalView == nil
)
doAssert windyIosMain(0, nil) == 0
doAssert window != nil
doAssert window.metalView != nil
doAssert window.nativeViewController == cast[pointer](2)
doAssert window.contentScale == 2
doAssert window.focused
doAssert window.safeAreaInsets == (10'f, 20'f, 30'f, 40'f)

echo "Testing same-frame touch press and release"
var sawPress, sawRelease, sawFrame: bool
window.onButtonPress = proc(button: Button) =
  if button == MouseLeft:
    doAssert window.buttonDown[MouseLeft]
    sawPress = true
window.onButtonRelease = proc(button: Button) =
  if button == MouseLeft:
    doAssert not window.buttonDown[MouseLeft]
    sawRelease = true

native.callbacks.onTouch(10, NativeTouchBegan, 30, 40)
native.callbacks.onTouch(10, NativeTouchEnded, 31, 41)
window.onFrame = proc() =
  doAssert window.buttonPressed[MouseLeft]
  doAssert window.buttonReleased[MouseLeft]
  doAssert not window.buttonDown[MouseLeft]
  sawFrame = true
native.callbacks.onFrame()
doAssert sawPress and sawRelease and sawFrame
doAssert not window.buttonPressed[MouseLeft]
doAssert not window.buttonReleased[MouseLeft]
window.onFrame = nil

echo "Testing primary touch ownership and cancellation"
native.callbacks.onTouch(10, NativeTouchBegan, 30, 40)
native.callbacks.onTouch(11, NativeTouchBegan, 80, 90)
native.callbacks.onTouch(11, NativeTouchMoved, 90, 100)
doAssert window.mousePos == ivec2(30, 40)
native.callbacks.onTouch(10, NativeTouchCancelled, 30, 40)
doAssert not window.buttonDown[MouseLeft]
doAssert not window.buttonPressed[MouseLeft]
doAssert window.buttonReleased[MouseLeft]
doAssert not window.mouseInside
doAssert window.mousePos == ivec2(-1, -1)
native.callbacks.onTouch(11, NativeTouchMoved, 110, 120)
doAssert not window.buttonDown[MouseLeft]
doAssert window.mousePos == ivec2(-1, -1)
native.callbacks.onTouch(11, NativeTouchEnded, 110, 120)
native.callbacks.onFrame()

echo "Testing hardware modifier sides and software Shift-Tab"
window.runeInputEnabled = true
doAssert native.keyboardVisible
native.callbacks.onKey(0xe5, NativeKeyPressed, 0)
doAssert window.buttonDown[KeyRightShift]
doAssert not window.buttonDown[KeyLeftShift]
native.callbacks.onKey(0xe1, NativeKeyPressed, ShiftFlag)
doAssert window.buttonDown[KeyLeftShift]
doAssert window.buttonDown[KeyRightShift]
native.callbacks.onKey(0xe5, NativeKeyReleased, ShiftFlag)
doAssert window.buttonDown[KeyLeftShift]
doAssert not window.buttonDown[KeyRightShift]
var sawShiftTab = false
window.onButtonPress = proc(button: Button) =
  if button == KeyTab:
    doAssert window.buttonDown[KeyLeftShift]
    sawShiftTab = true
native.callbacks.onKey(0x2b, NativeKeyPressed, uint.high)
native.callbacks.onKey(0x2b, NativeKeyReleased, uint.high)
doAssert sawShiftTab
doAssert window.buttonDown[KeyLeftShift]
doAssert window.buttonPressed[KeyTab]
doAssert window.buttonReleased[KeyTab]
doAssert not window.buttonReleased[KeyLeftShift]
native.callbacks.onKey(0xe1, NativeKeyReleased, 0)
doAssert not window.buttonDown[KeyLeftShift]

window.onButtonPress = nil
echo "Testing HID keys and repeat edges"
for pair in [
  (0x04, KeyA), (0x1d, KeyZ), (0x1e, Key1), (0x26, Key9), (0x27, Key0),
  (0x3a, KeyF1), (0x43, KeyF10), (0x45, KeyF12),
  (0x59, Numpad1), (0x61, Numpad9), (0x62, Numpad0),
  (0x4a, KeyHome), (0x4f, KeyRight), (0x52, KeyUp)
]:
  native.callbacks.onKey(pair[0], NativeKeyPressed, 0)
  doAssert window.buttonDown[pair[1]]
  native.callbacks.onFrame()
  doAssert not window.buttonPressed[pair[1]]
  native.callbacks.onKey(pair[0], NativeKeyRepeated, 0)
  doAssert window.buttonDown[pair[1]]
  doAssert window.buttonPressed[pair[1]]
  native.callbacks.onKey(pair[0], NativeKeyReleased, 0)
  doAssert not window.buttonDown[pair[1]]

native.callbacks.onKey(0x04, NativeKeyPressed, 1'u shl 16)
doAssert not window.buttonDown[KeyCapsLock]
native.callbacks.onKey(0x04, NativeKeyReleased, 0)

echo "Testing committed Unicode input and native clipboard"
var receivedRunes: seq[Rune]
window.onRune = proc(rune: Rune) =
  receivedRunes.add(rune)
native.callbacks.onText("a界")
doAssert receivedRunes == @[Rune(97), Rune(0x754c)]
window.runeInputEnabled = false
doAssert not native.keyboardVisible
native.callbacks.onText("ignored")
doAssert receivedRunes.len == 2
setClipboardString("Windy native iOS")
doAssert getClipboardString() == "Windy native iOS"
doAssert getClipboardContentKinds() == {TextContent}

echo "Testing focus, resize, scrolling and callback failure"
native.callbacks.onTouch(10, NativeTouchBegan, 30, 40)
native.callbacks.onKey(0x04, NativeKeyPressed, 0)
native.callbacks.onFocus(false)
doAssert not window.focused
doAssert window.buttonDown.len == 0
doAssert window.buttonPressed.len == 0
doAssert not window.mouseInside
doAssert window.mousePos == ivec2(-1, -1)
var frameCount = 0
window.onFrame = proc() =
  inc frameCount
native.callbacks.onFrame()
doAssert frameCount == 0
native.callbacks.onTouch(12, NativeTouchBegan, 50, 60)
native.callbacks.onKey(0x04, NativeKeyPressed, 0)
doAssert window.buttonDown.len == 0
native.callbacks.onFocus(true)
doAssert window.focused
doAssert window.buttonDown.len == 0
native.callbacks.onResize(1200, 600, 3)
doAssert window.size == ivec2(1200, 600)
doAssert window.contentScale == 3
native.callbacks.onScroll(15, 24, 2, 3)
doAssert window.mousePos == ivec2(15, 24)
doAssert window.scrollDelta == vec2(2, -3)
native.callbacks.onFrame()
doAssert frameCount == 1
doAssert window.scrollDelta == vec2(0, 0)

window.onFrame = proc() =
  raise newException(ValueError, "Expected input-test callback failure")
native.callbacks.onFrame()
doAssert window.closed and window.closeRequested
doAssert native.renderingStopped

echo "Native iOS input and lifecycle checks passed."
