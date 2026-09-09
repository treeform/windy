import
  std/[os, times, unicode],
  opengl, windy

const Modifiers = {
  KeyLeftControl, KeyRightControl, KeyLeftShift, KeyRightShift,
  KeyLeftAlt, KeyRightAlt, KeyLeftSuper, KeyRightSuper
}

let window = newWindow("Windy Inputs", ivec2(1000, 600))

var
  text: seq[Rune]
  lastRuneTime: float64

proc updateTitle() =
  ## Shows text and the current held keys without needing a font asset.
  let mode =
    if window.runeInputEnabled:
      "on"
    else:
      "off"
  window.title = "F2 text=" & mode & ", Esc clears | " & $text &
    " | held: " & $set[Button](window.buttonDown)

window.runeInputEnabled = true
window.makeContextCurrent()
loadExtensions()
updateTitle()

window.onButtonPress = proc(button: Button) =
  ## Logs the key and modifiers as seen by a normal application callback.
  echo "press ", button, " held: ", set[Button](window.buttonDown)
  case button
  of KeyF2:
    window.runeInputEnabled = not window.runeInputEnabled
  of KeyEscape:
    text.setLen(0)
  else:
    discard
  updateTitle()

window.onButtonRelease = proc(button: Button) =
  ## Logs releases and updates the displayed held state.
  echo "release ", button, " held: ", set[Button](window.buttonDown)
  updateTitle()

window.onRune = proc(rune: Rune) =
  ## Displays each received rune and flashes the window green.
  echo "rune ", rune, " held: ", set[Button](window.buttonDown)
  text.add(rune)
  if text.len > 80:
    text.delete(0)
  lastRuneTime = epochTime()
  updateTitle()

window.onFocusChange = proc() =
  ## Makes stuck input visible after switching away and returning.
  echo "focus ", window.focused, " held: ", set[Button](window.buttonDown)
  updateTitle()

window.onFrame = proc() =
  ## Shows modifiers in red, received text in green, and other keys in blue.
  let held = set[Button](window.buttonDown)
  if (held * Modifiers) != {}:
    glClearColor(0.35f, 0.08f, 0.08f, 1.0f)
  elif epochTime() - lastRuneTime < 0.2:
    glClearColor(0.08f, 0.35f, 0.12f, 1.0f)
  elif (held * {Key0 .. Button.high}) != {}:
    glClearColor(0.08f, 0.15f, 0.35f, 1.0f)
  else:
    glClearColor(0.08f, 0.08f, 0.08f, 1.0f)
  glClear(GL_COLOR_BUFFER_BIT)
  window.swapBuffers()

while not window.closeRequested:
  if window.minimized or not window.visible:
    sleep(10)
  pollEvents()
