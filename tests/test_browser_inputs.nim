include ../src/windy/platforms/emscripten/platform

type InputRecord = object
  name: string
  down: set[Button]

var
  testWindow: Window
  records: seq[InputRecord]

proc record(name: string) =
  ## Records callback order and the state visible to application code.
  records.add(InputRecord(name: name, down: testWindow.state.buttonDown))

proc reset() =
  ## Creates an input-only window using the actual WASM backend.
  records.setLen(0)
  testWindow = Window()
  testWindow.onButtonPress = proc(button: Button) =
    ## Records a normal application press callback.
    record("down " & $button)
  testWindow.onButtonRelease = proc(button: Button) =
    ## Records a normal application release callback.
    record("up " & $button)
  testWindow.onRune = proc(rune: Rune) =
    ## Records the rune supplied by the browser.
    record("text " & $rune)
  testWindow.onFocusChange = proc() =
    ## Records focus changes after key cleanup.
    record("focus")

proc keyboard(
  key, code: string,
  control = false,
  shift = false,
  alt = false,
  super = false,
  charCode = 0
): EmscriptenKeyboardEvent =
  ## Constructs the browser event fields used by the backend.
  doAssert key.len < result.key.len and code.len < result.code.len
  for i, character in key:
    result.key[i] = character
  for i, character in code:
    result.code[i] = character
  result.ctrlKey = control
  result.shiftKey = shift
  result.altKey = alt
  result.metaKey = super
  result.charCode = charCode.culong

proc down(event: var EmscriptenKeyboardEvent): EM_BOOL =
  ## Dispatches keydown and returns whether the browser should cancel it.
  onKeyDown(0, addr event, cast[pointer](testWindow))

proc up(event: var EmscriptenKeyboardEvent) =
  ## Dispatches a browser key release.
  discard onKeyUp(0, addr event, cast[pointer](testWindow))

proc text(event: var EmscriptenKeyboardEvent) =
  ## Dispatches the browser's text-producing keypress.
  doAssert onKeyPress(0, addr event, cast[pointer](testWindow)) == 1

proc names(): seq[string] =
  ## Returns callback names for compact order assertions.
  for entry in records:
    result.add(entry.name)

echo "Testing text enablement and keydown cancellation"
reset()
var character = keyboard("a", "KeyA", charCode = 'a'.ord)
doAssert character.down() == 1
character.text()
character.up()
doAssert names() == @["down KeyA", "up KeyA"]
testWindow.runeInputEnabled = true
records.setLen(0)
doAssert character.down() == 0
doAssert names() == @["down KeyA"]
character.text()
character.up()
doAssert names() == @["down KeyA", "text a", "up KeyA"]
doAssert KeyA in records[0].down and KeyA in records[1].down
doAssert KeyA notin records[2].down
doAssert testWindow.buttonPressed[KeyA]
doAssert testWindow.buttonReleased[KeyA]

echo "Testing Unicode, spaces, repeat callbacks, and physical keys"
reset()
testWindow.runeInputEnabled = true
for (key, code, rune) in [
  ("é", "KeyE", 0xe9), ("😀", "KeyQ", 0x1f600),
  (" ", "Space", 32), ("z", "KeyW", 'z'.ord)
]:
  var event = keyboard(key, code, charCode = rune)
  let button = keyEventToButton(addr event)
  doAssert event.down() == 0
  event.text()
  event.repeat = true
  doAssert event.down() == 0
  event.text()
  event.up()
  doAssert names()[^5 .. ^1] == @[
    "down " & $button, "text " & key,
    "down " & $button, "text " & key, "up " & $button
  ]

echo "Testing shortcut modifiers and complete between-frame chords"
for (key, code, modifier) in [
  ("Control", "ControlLeft", KeyLeftControl),
  ("Control", "ControlRight", KeyRightControl),
  ("Meta", "MetaLeft", KeyLeftSuper),
  ("Meta", "MetaRight", KeyRightSuper)
]:
  reset()
  testWindow.runeInputEnabled = true
  let super = modifier in {KeyLeftSuper, KeyRightSuper}
  var
    press = keyboard(key, code, control = not super, super = super)
    shortcut = keyboard(
      "a", "KeyA", control = not super, super = super, charCode = 'a'.ord
    )
    release = keyboard(key, code)
  doAssert press.down() == 1
  doAssert shortcut.down() == 1
  shortcut.text()
  shortcut.up()
  release.up()
  doAssert names() == @[
    "down " & $modifier, "down KeyA", "up KeyA", "up " & $modifier
  ]
  doAssert modifier in records[1].down
  doAssert modifier notin records[^1].down
  doAssert testWindow.state.buttonDown == {}

echo "Testing modifiers held before canvas focus and both Shift keys"
reset()
var shifted = keyboard("A", "KeyA", shift = true, super = true)
discard shifted.down()
doAssert records[^1].name == "down KeyA"
doAssert {KeyLeftShift, KeyLeftSuper, KeyA} <= records[^1].down
var plain = keyboard("a", "KeyA")
plain.up()
doAssert testWindow.state.buttonDown == {}
reset()
var
  leftShift = keyboard("Shift", "ShiftLeft", shift = true)
  rightShift = keyboard("Shift", "ShiftRight", shift = true)
discard leftShift.down()
discard rightShift.down()
leftShift.up()
doAssert testWindow.buttonDown[KeyRightShift]
doAssert not testWindow.buttonDown[KeyLeftShift]
rightShift.shiftKey = false
rightShift.up()
doAssert testWindow.state.buttonDown == {}

echo "Testing AltGr and dead keys without shortcut runes"
reset()
testWindow.runeInputEnabled = true
var
  altGraph = keyboard("@", "KeyQ", control = true, alt = true, charCode = 64)
  dead = keyboard("Dead", "Quote")
doAssert altGraph.down() == 0
altGraph.text()
doAssert records[^1].name == "text @"
doAssert dead.down() == 0
for (key, code) in [
  ("Enter", "Enter"), ("Tab", "Tab"), ("ArrowLeft", "ArrowLeft")
]:
  var event = keyboard(key, code)
  doAssert event.down() == 1

echo "Testing key mapping, unknown keys, and legacy modifiers"
for (code, expected) in [
  ("ShiftRight", KeyRightShift), ("AltRight", KeyRightAlt),
  ("ControlRight", KeyRightControl), ("MetaRight", KeyRightSuper),
  ("Numpad0", Numpad0), ("Numpad9", Numpad9),
  ("NumpadEnter", NumpadEnter), ("NumpadAdd", NumpadAdd),
  ("F1", KeyF1), ("F12", KeyF12), ("ContextMenu", KeyMenu)
]:
  var event = keyboard("", code)
  doAssert keyEventToButton(addr event) == expected
reset()
var unknown = keyboard("Unidentified", "Unidentified")
discard unknown.down()
unknown.up()
doAssert records.len == 0
unknown.keyCode = 17
unknown.location = 2
doAssert keyEventToButton(addr unknown) == KeyRightControl

echo "Testing missing Command releases and focus loss"
reset()
var
  command = keyboard("Meta", "MetaLeft", super = true)
  shortcut = keyboard("a", "KeyA", super = true)
discard command.down()
discard shortcut.down()
command.metaKey = false
command.up()
doAssert testWindow.state.buttonDown == {}
doAssert names() == @[
  "down KeyLeftSuper", "down KeyA", "up KeyLeftSuper", "up KeyA"
]
reset()
discard shifted.down()
discard onBlur(0, nil, cast[pointer](testWindow))
doAssert records[^1].name == "focus" and records[^1].down == {}
doAssert testWindow.state.buttonDown == {}
discard onBlur(0, nil, cast[pointer](testWindow))
doAssert records[^2].name == "focus"

echo "Windy browser input tests passed"
