import windy

when defined(emscripten):
  const sample = "Windy clipboard: café 🚀\nSecond line"
  let window = newWindow("Press C to copy, then paste", ivec2(640, 480))
  window.runeInputEnabled = true

  window.onButtonPress = proc(button: Button) =
    if button == KeyC:
      setClipboardString(sample)
    elif button == KeyV and window.buttonDown[KeyLeftControl]:
      echo getClipboardString()

  while not window.closeRequested:
    pollEvents()
else:
  setClipboardString("Windy")
  echo getClipboardString()
