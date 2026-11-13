## Run manually on Windows: nim r -d:useCpu tests/manual_text_input.nim
## Focus the window and dictate with Wispr Flow. Received input is displayed
## in the window and printed to the terminal. This is not run by CI.
when not defined(windows) or not defined(useCpu):
  {.error: "Run on Windows with nim r -d:useCpu tests/manual_text_input.nim".}

import std/[os, strutils, unicode], pixie, windy

let
  window = newWindow("Windy dictation — speak or type here", ivec2(800, 360))
  font = readFont(getEnv("WINDIR", "C:\\Windows") / "Fonts" / "segoeui.ttf")

font.size = 20
font.paint.color = color(0.1, 0.1, 0.1)
window.runeInputEnabled = true

var
  state = TextInputState(id: "dictation", multiline: true)
  redraw = true

proc publish() =
  state.bounds = rect(20, 90, max(1, window.size.x - 40).float32,
    max(1, window.size.y - 110).float32)
  state.visibleEnd = state.text.runeLen
  window.setTextInputState(if window.focused: state else: TextInputState())
  redraw = true

proc apply(edit: TextInputEdit) =
  let
    runes = state.text.toRunes
    first = clamp(edit.start, 0, runes.len)
    last = first + clamp(edit.length, 0, runes.len - first)
  if edit.kind == SelectText:
    state.selectionStart = first
    state.selectionEnd = last
    echo "Selection: ", first, "..", last
  else:
    state.text = $runes[0 ..< first] & edit.text & $runes[last ..< runes.len]
    state.selectionStart = first + edit.text.runeLen
    state.selectionEnd = state.selectionStart
    echo "Text: ", state.text.escape
  publish()

proc insert(text: string) =
  apply(TextInputEdit(kind: ReplaceText, text: text,
    start: min(state.selectionStart, state.selectionEnd),
    length: abs(state.selectionEnd - state.selectionStart)))

window.onTextEdit = proc(edit: TextInputEdit) =
  echo "Native edit: ", edit.kind, " at ", edit.start, " length ", edit.length,
    " text ", edit.text.escape
  apply(edit)

window.onTextInput = proc(text: string) =
  echo "Committed text: ", text.escape
  insert(text)

window.onButtonPress = proc(button: Button) =
  let control = window.buttonDown[KeyLeftControl] or window.buttonDown[KeyRightControl]
  case button
  of KeyA:
    if control:
      apply(TextInputEdit(kind: SelectText, length: state.text.runeLen))
  of KeyV:
    if control:
      echo "Paste shortcut"
      insert(getClipboardString())
  of KeyBackspace:
    if state.selectionStart == state.selectionEnd:
      state.selectionStart = max(0, state.selectionStart - 1)
    insert("")
  of KeyEnter:
    insert("\n")
  of KeyEscape:
    apply(TextInputEdit(kind: ReplaceText, length: state.text.runeLen))
  else:
    discard

window.onFocusChange = publish
window.onResize = publish
window.onFrame = proc() =
  if not redraw or window.size.x <= 0 or window.size.y <= 0:
    return
  let image = newImage(window.size.x, window.size.y)
  image.fill(rgba(248, 248, 248, 255))
  image.fillText(font, "Speak with Wispr Flow, or type here.\n" &
    "Ctrl+A: select all    Ctrl+V: paste    Esc: clear",
    translate(vec2(20, 16)), vec2((window.size.x - 40).float32, 64))
  image.fillText(font, (if state.text.len == 0: "Waiting for text…" else: state.text),
    translate(state.bounds.xy), state.bounds.wh)
  window.presentPixels(image)
  redraw = false

echo "Focus the Windy window and dictate. Input events will appear here."
publish()
while not window.closeRequested:
  pollEvents()
  sleep(10)
window.close()
