import opengl, windy

let window = newWindow("Drag and Drop Example", ivec2(800, 600))

window.makeContextCurrent()
loadExtensions()

window.onFileDrop = proc(fileName: string, fileData: string) =
  echo "File dropped: ", fileName, " (", fileData.len, " bytes)"
  echo "Content preview: ", fileData[0..min(100, fileData.len-1)]

window.onFrame = proc() =
  # Clear screen with a light color.
  # just something to let the user drop a file onto the window.
  glClearColor(0.9, 0.9, 0.9, 1.0)
  glClear(GL_COLOR_BUFFER_BIT)

window.onCloseRequest = proc() =
  echo "Window close requested"

echo "Drag and drop files onto the window to test file drop functionality"
echo "Close the window to exit"

while not window.closeRequested:
  pollEvents()
  if window.onFrame != nil:
    window.onFrame()
  window.swapBuffers()
