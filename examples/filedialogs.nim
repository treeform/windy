## Demonstrates windy open/save file dialogs.
import windy

let window = newWindow("File Dialogs", ivec2(640, 360))
window.makeContextCurrent()

window.onFrame = proc() =
  if window.buttonPressed[KeyO]:
    let path = openFileDialog(
      "Open File",
      @[FileDialogFilter(name: "Text", extensions: "*.txt;*.md")],
      ""
    )
    echo "open: ", path
  if window.buttonPressed[KeyS]:
    let path = saveFileDialog(
      "Save File",
      @[FileDialogFilter(name: "Text", extensions: "*.txt")],
      "",
      "untitled.txt"
    )
    echo "save: ", path
  if window.buttonPressed[KeyEscape]:
    window.closeRequested = true

while not window.closeRequested:
  pollEvents()
