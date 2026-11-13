## Minimal custom editor used by the external Windows UI Automation regression.
## Compile with -d:useCpu to run without an OpenGL context or a widget toolkit.
when not defined(windows):
  {.error: "This fixture requires Windows.".}

import std/[os, monotimes, times, unicode], bumpy, windy

proc run() =
  let window = newWindow(
    "Windy text automation fixture", ivec2(600, 280), vsync = false
  )
  defer: window.close()
  var
    mode = "inactive"
    state = TextInputState(
      id: "native fixture", text: "Hello 🌍 world",
      selectionStart: 6, selectionEnd: 7,
      bounds: rect(20, 20, 560, 240), multiline: true
    )

  proc publish() =
    ## Mirrors the application model through the public native-text API.
    state.visibleEnd = state.text.runeLen
    if mode == "inactive" or mode == "disabled":
      window.setTextInputState(TextInputState())
    else:
      window.setTextInputState(state)

  proc apply(edit: TextInputEdit) =
    ## Implements replacement/selection as a toolkit would, using rune offsets.
    let
      runes = state.text.toRunes
      first = clamp(edit.start, 0, runes.len)
      last = first + clamp(edit.length, 0, runes.len - first)
    if edit.kind == SelectText:
      state.selectionStart = first
      state.selectionEnd = last
    else:
      var text = ""
      for i in 0 ..< first:
        text.add($runes[i])
      text.add(edit.text)
      for i in last ..< runes.len:
        text.add($runes[i])
      state.text = text
      state.selectionStart = first + edit.text.runeLen
      state.selectionEnd = state.selectionStart
    publish()

  proc commit(text: string) =
    ## Receives committed text as one application edit, including line breaks.
    let first = min(state.selectionStart, state.selectionEnd)
    apply(TextInputEdit(
      kind: ReplaceText, text: text, start: first,
      length: abs(state.selectionEnd - state.selectionStart)
    ))

  window.onTextEdit = apply
  window.onTextInput = commit
  window.onButtonPress = proc(button: Button) =
    ## Confirms synthesized modifiers reach the normal Windy shortcut callback.
    if window.runeInputEnabled and button == KeyV and
      (window.buttonDown[KeyLeftControl] or window.buttonDown[KeyRightControl]):
        commit(getClipboardString())

  let deadline = getMonoTime() + initDuration(seconds = 90)
  while not window.closeRequested and getMonoTime() < deadline:
    pollEvents()
    if paramCount() > 0 and fileExists(paramStr(1)):
      let requested = readFile(paramStr(1))
      if requested != mode:
        mode = requested
        state.password = mode == "password"
        state.multiline = mode != "single"
        window.runeInputEnabled = mode != "inactive" and mode != "disabled"
        publish()
    if paramCount() > 1:
      writeFile(paramStr(2), state.text)
    sleep(5)

run()
