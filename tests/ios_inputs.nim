when not defined(windyIosTesting):
  {.error: "Run with -d:windyIosTesting to use the native host mock.".}

include ../src/windy/platforms/ios/platform

const ShiftFlag = 1'u shl 17

var window: Window
runApplication(proc() =
  window = newWindow("Input test", ivec2(640, 480))
  doAssert window.metalView != nil
)
doAssert windyIosMain(0, nil) == 0
doAssert window != nil
doAssert window.pointerSource == MousePointer
doAssert window.metalView != nil
doAssert window.nativeViewController == cast[pointer](2)
doAssert window.contentScale == 2
doAssert window.focused
doAssert window.continuousRendering
window.continuousRendering = false
doAssert not native.continuousFrames
window.requestFrame(83)
doAssert native.frameDelay == 83
window.continuousRendering = true
doAssert window.continuousRendering
doAssert window.visible
doAssert not window.minimized
doAssert window.safeAreaInsets == (10'f, 20'f, 30'f, 40'f)
doAssert window.keyboardOcclusionHeight == 0
native.keyboardOcclusion = 280
doAssert window.keyboardOcclusionHeight == 280
wakeEvents()
doAssert native.eventWakeCount == 1

echo "Testing same-frame touch press and release"
var sawPress, sawRelease, sawFrame: bool
window.onButtonPress = proc(button: Button) =
  if button == MouseLeft:
    doAssert window.buttonDown[MouseLeft]
    doAssert window.pointerSource == TouchPointer
    sawPress = true
window.onButtonRelease = proc(button: Button) =
  if button == MouseLeft:
    doAssert not window.buttonDown[MouseLeft]
    doAssert window.pointerSource == TouchPointer
    sawRelease = true

let beforeTouchWake = native.frameRequestCount
native.callbacks.onTouch(10, NativeTouchBegan, 30, 40, TouchPointer)
doAssert native.frameRequestCount == beforeTouchWake + 1
native.callbacks.onTouch(10, NativeTouchEnded, 31, 41, TouchPointer)
doAssert native.frameRequestCount == beforeTouchWake + 2
window.onFrame = proc() =
  doAssert window.buttonPressed[MouseLeft]
  doAssert window.buttonReleased[MouseLeft]
  doAssert not window.buttonDown[MouseLeft]
  doAssert window.pointerSource == TouchPointer
  sawFrame = true
native.callbacks.onFrame()
doAssert sawPress and sawRelease and sawFrame
doAssert not window.buttonPressed[MouseLeft]
doAssert not window.buttonReleased[MouseLeft]
window.onFrame = nil

echo "Testing primary touch dragging across frames"
native.callbacks.onTouch(10, NativeTouchBegan, 30, 40, TouchPointer)
doAssert window.mouseDelta == ivec2(0, 0)
native.callbacks.onFrame()
doAssert window.buttonDown[MouseLeft]
doAssert not window.buttonPressed[MouseLeft]
doAssert window.pointerSource == TouchPointer
native.callbacks.onTouch(10, NativeTouchMoved, 35, 50, TouchPointer)
native.callbacks.onTouch(10, NativeTouchMoved, 40, 65, TouchPointer)
doAssert window.mouseDelta == ivec2(10, 25)
doAssert window.mousePos == ivec2(40, 65)
doAssert window.mousePrevPos == ivec2(35, 50)
doAssert window.scrollDelta == vec2(0, 0)
native.callbacks.onFrame()
doAssert window.buttonDown[MouseLeft]
doAssert window.mouseDelta == ivec2(0, 0)
doAssert window.pointerSource == TouchPointer
native.callbacks.onTouch(10, NativeTouchEnded, 42, 68, TouchPointer)
doAssert not window.buttonDown[MouseLeft]
doAssert window.buttonReleased[MouseLeft]
doAssert window.mousePos == ivec2(42, 68)
doAssert window.mouseDelta == ivec2(2, 3)
doAssert window.mouseInside
doAssert window.pointerSource == TouchPointer
native.callbacks.onFrame()
doAssert not window.buttonReleased[MouseLeft]
doAssert window.pointerSource == TouchPointer

echo "Testing coalesced drag origin after earlier pointer movement"
native.callbacks.onTouch(0, NativeTouchHover, 800, 900, MousePointer)
doAssert window.mouseDelta != ivec2(0, 0)
native.callbacks.onTouch(20, NativeTouchBegan, 200, 300, TouchPointer)
doAssert window.mouseDelta == ivec2(0, 0)
native.callbacks.onTouch(20, NativeTouchMoved, 210, 320, TouchPointer)
native.callbacks.onTouch(20, NativeTouchEnded, 220, 340, TouchPointer)
doAssert window.mouseDelta == ivec2(20, 40)
native.callbacks.onTouch(0, NativeTouchHover, 900, 800, MousePointer)
native.callbacks.onTouch(21, NativeTouchBegan, 100, 500, TouchPointer)
native.callbacks.onTouch(21, NativeTouchMoved, 105, 490, TouchPointer)
native.callbacks.onTouch(21, NativeTouchMoved, 120, 460, TouchPointer)
native.callbacks.onTouch(21, NativeTouchEnded, 130, 440, TouchPointer)
window.onFrame = proc() =
  doAssert window.mousePos == ivec2(130, 440)
  doAssert window.mouseDelta == ivec2(30, -60)
  doAssert window.mousePos - window.mouseDelta == ivec2(100, 500)
  doAssert window.pointerSource == TouchPointer
  doAssert window.buttonPressed[MouseLeft]
  doAssert window.buttonReleased[MouseLeft]
  doAssert not window.buttonDown[MouseLeft]
native.callbacks.onFrame()
window.onFrame = nil
doAssert window.mouseDelta == ivec2(0, 0)

echo "Testing event-timed touch velocity independent of rendered frames"
for rate in [30, 60, 120]:
  let
    start = 10_000_000.0
    velocity = vec2(600, -900)
    origin = vec2(100, 2000)
  native.callbacks.onTouch(
    30, NativeTouchBegan, origin.x, origin.y, TouchPointer, start
  )
  doAssert window.pointerVelocity == vec2(0)
  for i in 1 .. 24:
    let
      elapsed = i.float64 / rate.float64
      position = origin + velocity * elapsed.float32
    native.callbacks.onTouch(
      30, NativeTouchMoved, position.x, position.y, TouchPointer,
      start + elapsed
    )
    if i mod 3 == 0:
      native.callbacks.onFrame()
  let position = origin + velocity * (24.0'f / rate.float32)
  native.callbacks.onTouch(
    30, NativeTouchEnded, position.x, position.y, TouchPointer,
    start + 24.0 / rate.float64
  )
  doAssert (window.pointerVelocity - velocity).length < 0.02
  native.callbacks.onFrame()
  doAssert (window.pointerVelocity - velocity).length < 0.02

echo "Testing a complete timed flick before one render frame"
native.callbacks.onTouch(31, NativeTouchBegan, 100, 100, TouchPointer, 1.0)
native.callbacks.onTouch(31, NativeTouchMoved, 120, 160, TouchPointer, 1.02)
native.callbacks.onTouch(31, NativeTouchEnded, 140, 220, TouchPointer, 1.04)
doAssert (window.pointerVelocity - vec2(1000, 3000)).length < 0.02
doAssert window.buttonPressed[MouseLeft]
doAssert window.buttonReleased[MouseLeft]
native.callbacks.onFrame()
doAssert (window.pointerVelocity - vec2(1000, 3000)).length < 0.02

echo "Testing sparse touch timing retains velocity at the sample boundary"
native.callbacks.onTouch(32, NativeTouchBegan, 100, 100, TouchPointer, 2.0)
native.callbacks.onTouch(32, NativeTouchEnded, 400, 700, TouchPointer, 2.3)
doAssert (window.pointerVelocity - vec2(1000, 2000)).length < 0.02
native.callbacks.onFrame()

echo "Testing pause before lift slows or cancels momentum"
native.callbacks.onTouch(33, NativeTouchBegan, 100, 100, TouchPointer, 3.0)
native.callbacks.onTouch(33, NativeTouchMoved, 100, 130, TouchPointer, 3.03)
native.callbacks.onTouch(33, NativeTouchEnded, 100, 130, TouchPointer, 3.08)
doAssert abs(window.pointerVelocity.y - 375) < 0.02
native.callbacks.onTouch(34, NativeTouchBegan, 100, 100, TouchPointer, 4.0)
native.callbacks.onTouch(34, NativeTouchMoved, 100, 130, TouchPointer, 4.03)
native.callbacks.onTouch(34, NativeTouchEnded, 100, 130, TouchPointer, 4.15)
doAssert window.pointerVelocity == vec2(0)
native.callbacks.onFrame()

echo "Testing quick reversal uses the new direction"
native.callbacks.onTouch(35, NativeTouchBegan, 100, 100, TouchPointer, 5.0)
native.callbacks.onTouch(35, NativeTouchMoved, 100, 180, TouchPointer, 5.04)
native.callbacks.onTouch(35, NativeTouchMoved, 100, 200, TouchPointer, 5.05)
native.callbacks.onTouch(35, NativeTouchMoved, 100, 180, TouchPointer, 5.06)
native.callbacks.onTouch(35, NativeTouchEnded, 100, 170, TouchPointer, 5.07)
doAssert abs(window.pointerVelocity.y + 1500) < 0.02
native.callbacks.onFrame()

echo "Testing velocity bounds, primary ownership and cancellation"
native.callbacks.onTouch(36, NativeTouchBegan, 100, 100, TouchPointer, 6.0)
native.callbacks.onTouch(36, NativeTouchMoved, 100, 1000, TouchPointer, 6.002)
doAssert window.pointerVelocity.length <= MaxTouchSpeed * window.contentScale
let primaryVelocity = window.pointerVelocity
native.callbacks.onTouch(37, NativeTouchBegan, 30, 30, TouchPointer, 6.003)
native.callbacks.onTouch(37, NativeTouchMoved, 30, 300, TouchPointer, 6.004)
doAssert window.pointerVelocity == primaryVelocity
native.callbacks.onTouch(36, NativeTouchCancelled, 100, 1000, TouchPointer, 6.005)
doAssert window.pointerVelocity == vec2(0)
native.callbacks.onTouch(38, NativeTouchBegan, 100, 100, TouchPointer, 7.0)
native.callbacks.onTouch(38, NativeTouchMoved, 100, 200, TouchPointer, 7.05)
doAssert window.pointerVelocity.y > 0
native.callbacks.onFocus(false)
doAssert window.pointerVelocity == vec2(0)
native.callbacks.onFocus(true)
native.callbacks.onTouch(39, NativeTouchBegan, 100, 100, TouchPointer, 8.0)
native.callbacks.onTouch(39, NativeTouchMoved, 100, 200, TouchPointer, 8.05)
native.callbacks.onTouch(39, NativeTouchEnded, 100, 200, TouchPointer, 8.05)
doAssert window.pointerVelocity.y > 0
native.callbacks.onScroll(100, 200, 0, 1)
doAssert window.pointerVelocity == vec2(0)
native.callbacks.onFrame()

echo "Testing primary touch ownership and cancellation"
native.callbacks.onTouch(10, NativeTouchBegan, 30, 40, TouchPointer)
native.callbacks.onTouch(11, NativeTouchBegan, 80, 90, TouchPointer)
native.callbacks.onTouch(11, NativeTouchMoved, 90, 100, TouchPointer)
doAssert window.mousePos == ivec2(30, 40)
doAssert window.pointerSource == TouchPointer
native.callbacks.onTouch(0, NativeTouchHover, 100, 120, MousePointer)
doAssert window.mousePos == ivec2(30, 40)
doAssert window.pointerSource == TouchPointer
native.callbacks.onTouch(10, NativeTouchCancelled, 30, 40, TouchPointer)
doAssert not window.buttonDown[MouseLeft]
doAssert not window.buttonPressed[MouseLeft]
doAssert window.buttonReleased[MouseLeft]
doAssert not window.mouseInside
doAssert window.mousePos == ivec2(-1, -1)
doAssert window.pointerSource == TouchPointer
native.callbacks.onTouch(11, NativeTouchMoved, 110, 120, TouchPointer)
doAssert not window.buttonDown[MouseLeft]
doAssert window.mousePos == ivec2(-1, -1)
native.callbacks.onTouch(11, NativeTouchEnded, 110, 120, TouchPointer)
native.callbacks.onFrame()

window.onButtonPress = nil
window.onButtonRelease = nil

echo "Testing Pencil drawing with a resting palm"
var palmCancelled, pencilPressed: bool
window.onButtonRelease = proc(button: Button) =
  if button == MouseLeft and window.pointerSource == TouchPointer:
    doAssert not window.mouseInside
    doAssert window.mousePos == ivec2(-1, -1)
    doAssert not window.buttonDown[MouseLeft]
    palmCancelled = true
window.onButtonPress = proc(button: Button) =
  if button == MouseLeft and window.pointerSource == PenPointer:
    doAssert palmCancelled
    doAssert window.mousePos == ivec2(200, 300)
    doAssert window.buttonDown[MouseLeft]
    pencilPressed = true
native.callbacks.onTouch(40, NativeTouchBegan, 60, 70, TouchPointer, 9.0)
native.callbacks.onTouch(40, NativeTouchMoved, 60, 90, TouchPointer, 9.02)
doAssert window.pointerVelocity.y > 0
native.callbacks.onFrame()
native.callbacks.onTouch(41, NativeTouchBegan, 200, 300, PenPointer, 9.03)
doAssert palmCancelled and pencilPressed
doAssert window.pointerSource == PenPointer
doAssert window.pointerVelocity == vec2(0)
doAssert window.mouseDelta == ivec2(0)
doAssert window.buttonPressed[MouseLeft]
doAssert not window.buttonReleased[MouseLeft]
native.callbacks.onFrame()
for phase in [NativeTouchMoved, NativeTouchCancelled, NativeTouchEnded]:
  native.callbacks.onTouch(40, phase, 500, 600, TouchPointer, 9.04)
  doAssert window.mousePos == ivec2(200, 300)
  doAssert window.pointerSource == PenPointer
  doAssert window.buttonDown[MouseLeft]
native.callbacks.onTouch(42, NativeTouchBegan, 700, 800, TouchPointer, 9.05)
native.callbacks.onTouch(42, NativeTouchMoved, 800, 900, TouchPointer, 9.06)
native.callbacks.onTouch(41, NativeTouchMoved, 220, 340, PenPointer, 9.06)
doAssert window.mousePos == ivec2(220, 340)
doAssert window.pointerVelocity == vec2(0)
native.callbacks.onTouch(41, NativeTouchEnded, 230, 350, PenPointer, 9.07)
doAssert not window.buttonDown[MouseLeft]
doAssert window.buttonReleased[MouseLeft]
doAssert window.mousePos == ivec2(230, 350)
native.callbacks.onFrame()
native.callbacks.onTouch(42, NativeTouchMoved, 900, 1000, TouchPointer, 9.08)
native.callbacks.onTouch(42, NativeTouchEnded, 900, 1000, TouchPointer, 9.09)
doAssert window.mousePos == ivec2(230, 350)
doAssert not window.buttonDown[MouseLeft]
window.onButtonPress = nil
window.onButtonRelease = nil

echo "Testing Pencil cancellation and same-frame strokes"
native.callbacks.onTouch(43, NativeTouchBegan, 100, 200, PenPointer, 10.0)
native.callbacks.onTouch(43, NativeTouchMoved, 120, 240, PenPointer, 10.01)
native.callbacks.onTouch(43, NativeTouchCancelled, 120, 240, PenPointer, 10.02)
doAssert not window.buttonDown[MouseLeft]
doAssert not window.buttonPressed[MouseLeft]
doAssert not window.mouseInside
native.callbacks.onFrame()
native.callbacks.onTouch(46, NativeTouchBegan, 50, 60, TouchPointer, 10.9)
native.callbacks.onTouch(44, NativeTouchBegan, 100, 200, PenPointer, 11.0)
doAssert not window.buttonReleased[MouseLeft]
native.callbacks.onTouch(44, NativeTouchMoved, 120, 240, PenPointer, 11.01)
native.callbacks.onTouch(44, NativeTouchEnded, 130, 250, PenPointer, 11.02)
doAssert window.pointerSource == PenPointer
doAssert window.buttonPressed[MouseLeft]
doAssert window.buttonReleased[MouseLeft]
doAssert not window.buttonDown[MouseLeft]
doAssert window.mousePos - window.mouseDelta == ivec2(100, 200)
doAssert window.pointerVelocity == vec2(0)
native.callbacks.onFrame()

echo "Testing a fresh finger gesture after Pencil drawing"
native.callbacks.onTouch(45, NativeTouchBegan, 50, 60, TouchPointer, 12.0)
native.callbacks.onTouch(45, NativeTouchMoved, 50, 80, TouchPointer, 12.02)
doAssert window.buttonDown[MouseLeft]
doAssert window.pointerSource == TouchPointer
doAssert window.pointerVelocity.y > 0
native.callbacks.onTouch(45, NativeTouchEnded, 50, 90, TouchPointer, 12.03)
native.callbacks.onFrame()

echo "Testing pointer source changes after touch cancellation"
native.callbacks.onTouch(0, NativeTouchHover, 50, 60, MousePointer)
doAssert window.pointerSource == MousePointer
doAssert window.mousePos == ivec2(50, 60)
native.callbacks.onTouch(20, NativeTouchBegan, 60, 70, PenPointer)
doAssert window.pointerSource == PenPointer
native.callbacks.onTouch(20, NativeTouchEnded, 61, 71, PenPointer)
doAssert window.pointerSource == PenPointer
native.callbacks.onTouch(21, NativeTouchBegan, 70, 80, MousePointer)
doAssert window.pointerSource == MousePointer
native.callbacks.onTouch(21, NativeTouchEnded, 71, 81, MousePointer)
doAssert window.pointerSource == MousePointer
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

let beforeKeyWake = native.frameRequestCount
native.callbacks.onKey(0x04, NativeKeyPressed, 1'u shl 16)
doAssert native.frameRequestCount == beforeKeyWake + 1
doAssert not window.buttonDown[KeyCapsLock]
native.callbacks.onKey(0x04, NativeKeyReleased, 0)

echo "Testing committed Unicode input and native clipboard"
var receivedRunes: seq[Rune]
window.onRune = proc(rune: Rune) =
  receivedRunes.add(rune)
let beforeTextWake = native.frameRequestCount
native.callbacks.onText("a界")
doAssert native.frameRequestCount == beforeTextWake + 1
doAssert receivedRunes == @[Rune(97), Rune(0x754c)]
window.runeInputEnabled = false
doAssert not native.keyboardVisible
native.callbacks.onText("ignored")
doAssert receivedRunes.len == 2
setClipboardString("Windy native iOS")
doAssert getClipboardString() == "Windy native iOS"
doAssert getClipboardContentKinds() == {TextContent}

echo "Testing atomic native commits and rune-based editing ranges"
var receivedText: seq[string]
window.onTextInput = proc(text: string) =
  receivedText.add(text)
window.runeInputEnabled = true
native.callbacks.onText("a界\n👩🏽‍💻")
doAssert receivedText == @["a界\n👩🏽‍💻"]
doAssert receivedRunes.len == 2
window.setTextInputState(TextInputState(
  id: "composer", text: "a界🙂z", selectionStart: -1, selectionEnd: 20,
  visibleStart: -4, visibleEnd: 18, multiline: true,
  bounds: rect(5, 10, 200, 100)
))
doAssert native.textInput.selectionStart == 0
doAssert native.textInput.selectionEnd == 4
doAssert native.textInput.visibleStart == 0
doAssert native.textInput.visibleEnd == 4
var edits: seq[TextInputEdit]
window.onTextEdit = proc(edit: TextInputEdit) =
  edits.add(edit)
let beforeEditWake = native.frameRequestCount
native.callbacks.onTextEdit(TextInputEdit(
  kind: ReplaceText, start: 1, length: 2, text: "👩🏽‍💻"
))
doAssert native.frameRequestCount == beforeEditWake + 1
doAssert window.textInput.text == "a👩🏽‍💻z"
doAssert edits.len == 1
doAssert edits[0].start == 1 and edits[0].length == 2
native.callbacks.onTextEdit(TextInputEdit(
  kind: SelectText, start: 3, length: int.high
))
doAssert edits[1].start == 3 and edits[1].length == 3
doAssert window.textInput.selectionStart == 3
doAssert window.textInput.selectionEnd == 6
native.callbacks.onTextEdit(TextInputEdit(
  kind: ReplaceText, start: int.high, length: int.high, text: "!"
))
doAssert edits[2].start == 6 and edits[2].length == 0
doAssert window.textInput.text == "a👩🏽‍💻z!"
window.setTextInputState(TextInputState(
  id: "password", text: "秘密", password: true
))
native.callbacks.onTextEdit(TextInputEdit(
  kind: ReplaceText, start: 1, length: 1, text: "🙂"
))
doAssert window.textInput.text == "秘🙂"
doAssert native.textInput.password
window.runeInputEnabled = false
native.callbacks.onTextEdit(TextInputEdit(kind: ReplaceText, text: "ignored"))
doAssert edits.len == 4
window.runeInputEnabled = true
window.setTextInputState(TextInputState())
native.callbacks.onTextEdit(TextInputEdit(kind: ReplaceText, text: "ignored"))
doAssert edits.len == 4
window.runeInputEnabled = false

echo "Testing image clipboard and text replacement"
let clipboardImage = newImage(2, 2)
clipboardImage.fill(rgba(24, 68, 110, 255))
setClipboardImage(clipboardImage)
doAssert getClipboardContentKinds() == {ImageContent}
doAssert getClipboardImage().data == clipboardImage.data
setClipboardString("Replaces image")
doAssert getClipboardContentKinds() == {TextContent}
doAssert getClipboardImage() == nil

echo "Testing native edit menus without keyboard ownership changes"
var menuActions: seq[TextEditAction]
let collectMenuAction = proc(action: TextEditAction) =
  ## Records a user menu choice without changing the published editor.
  menuActions.add(action)
let menuBounds = rect(20, 40, 60, 80)
doAssert window.showTextEditMenu(
  menuBounds, {CopyTextAction, SelectAllTextAction}, collectMenuAction
)
doAssert native.textMenuBounds == menuBounds
doAssert native.textMenuActions == {CopyTextAction, SelectAllTextAction}
doAssert not native.keyboardVisible
doAssert not window.runeInputEnabled
let firstMenu = native.textMenuCallback
firstMenu(PasteTextAction)
doAssert menuActions.len == 0
firstMenu(CopyTextAction)
firstMenu(CopyTextAction)
doAssert menuActions == @[CopyTextAction]
doAssert not native.keyboardVisible
window.runeInputEnabled = true
doAssert window.showTextEditMenu(
  menuBounds, {PasteTextAction}, collectMenuAction
)
let dismissedMenu = native.textMenuCallback
window.dismissTextEditMenu()
doAssert native.textMenuCallback == nil
dismissedMenu(PasteTextAction)
doAssert menuActions.len == 1
doAssert native.keyboardVisible
doAssert window.showTextEditMenu(
  menuBounds, {CutTextAction}, collectMenuAction
)
let replacedMenu = native.textMenuCallback
doAssert window.showTextEditMenu(
  menuBounds, {SelectAllTextAction}, collectMenuAction
)
replacedMenu(CutTextAction)
doAssert menuActions.len == 1
native.textMenuCallback(SelectAllTextAction)
doAssert menuActions == @[CopyTextAction, SelectAllTextAction]
doAssert window.showTextEditMenu(
  menuBounds, {CopyTextAction}, collectMenuAction
)
let suspendedMenu = native.textMenuCallback
native.callbacks.onFocus(false)
suspendedMenu(CopyTextAction)
doAssert native.textMenuCallback == nil
doAssert menuActions.len == 2
doAssert not window.showTextEditMenu(
  menuBounds, {CopyTextAction}, collectMenuAction
)
native.callbacks.onFocus(true)
doAssert not window.showTextEditMenu(menuBounds, {}, collectMenuAction)
window.runeInputEnabled = false

echo "Testing focus, resize, scrolling and callback failure"
native.callbacks.onTouch(10, NativeTouchBegan, 30, 40, TouchPointer)
native.callbacks.onKey(0x04, NativeKeyPressed, 0)
native.callbacks.onFocus(false)
doAssert not window.focused
doAssert not window.visible
doAssert window.minimized
doAssert window.buttonDown.len == 0
doAssert window.buttonPressed.len == 0
doAssert not window.mouseInside
doAssert window.mousePos == ivec2(-1, -1)
var frameCount = 0
window.onFrame = proc() =
  inc frameCount
native.callbacks.onFrame()
doAssert frameCount == 0
native.callbacks.onTouch(12, NativeTouchBegan, 50, 60, TouchPointer)
native.callbacks.onKey(0x04, NativeKeyPressed, 0)
doAssert window.buttonDown.len == 0
let beforeFocusWake = native.frameRequestCount
native.callbacks.onFocus(true)
doAssert native.frameRequestCount == beforeFocusWake + 1
doAssert window.focused
doAssert window.visible
doAssert not window.minimized
doAssert window.buttonDown.len == 0
let beforeResizeWake = native.frameRequestCount
native.callbacks.onResize(1200, 600, 3)
doAssert native.frameRequestCount == beforeResizeWake + 1
doAssert window.size == ivec2(1200, 600)
doAssert window.contentScale == 3
doAssert window.pointerSource == TouchPointer
let beforeScrollWake = native.frameRequestCount
native.callbacks.onScroll(15, 24, 2, 3)
doAssert native.frameRequestCount == beforeScrollWake + 1
doAssert window.pointerSource == MousePointer
doAssert window.mousePos == ivec2(15, 24)
doAssert window.scrollDelta == vec2(2, -3)
native.callbacks.onFrame()
doAssert frameCount == 1
doAssert window.scrollDelta == vec2(0, 0)

window.onFrame = proc() =
  raise newException(ValueError, "Expected input-test callback failure")
doAssert window.showTextEditMenu(
  menuBounds, {CopyTextAction}, collectMenuAction
)
let closedMenu = native.textMenuCallback
native.callbacks.onFrame()
doAssert window.closed and window.closeRequested
doAssert native.renderingStopped
doAssert native.textMenuCallback == nil
closedMenu(CopyTextAction)
doAssert menuActions.len == 2

echo "Native iOS input and lifecycle checks passed."
