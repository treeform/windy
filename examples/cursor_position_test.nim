import
  std/[strformat],
  windy, vmath, boxy, opengl

var
  window: Window
  bxy: Boxy
  squareSize = 20.0

window = newWindow("Cursor Position Test", ivec2(1280, 800))
window.makeContextCurrent()
loadExtensions()
bxy = newBoxy()

echo "Move your mouse to test cursor position accuracy"
echo "Press +/- to adjust square size"
echo "Press ESC to exit"
echo &"Content scale: {window.contentScale}"
echo &"Window size: {window.size}"
echo &"Logical size: {window.size.vec2 / window.contentScale}"

window.onButtonPress = proc(button: Button) =
  case button:
  of KeyEqual, NumpadAdd:
    squareSize += 5.0
    echo &"Square size: {squareSize}"
  of KeyMinus, NumpadSubtract:
    squareSize = max(5.0, squareSize - 5.0)
    echo &"Square size: {squareSize}"
  else:
    discard

window.onFrame = proc() =
  bxy.beginFrame(window.size)

  bxy.saveTransform()

  # Scale by contentScale to work in logical coordinates.
  let scale = window.contentScale
  bxy.scale(scale)

  # Now we work in logical coordinates.
  let logicalSize = window.size.vec2 / scale

  # Clear background.
  bxy.drawRect(rect(0, 0, logicalSize.x, logicalSize.y), color(0.1, 0.1, 0.1, 1.0))

  # Convert cursor position from physical to logical coordinates.
  let cursorPos = window.mousePos.vec2 / scale

  # Draw a square centered at cursor position.
  let halfSize = squareSize / 2.0
  bxy.drawRect(
    rect(
      cursorPos.x - halfSize,
      cursorPos.y - halfSize,
      squareSize,
      squareSize
    ),
    color(1.0, 0.3, 0.3, 0.8)
  )

  # Draw crosshair lines.
  bxy.drawRect(rect(cursorPos.x - 1, 0, 2, logicalSize.y), color(0.3, 1.0, 0.3, 0.5))
  bxy.drawRect(rect(0, cursorPos.y - 1, logicalSize.x, 2), color(0.3, 1.0, 0.3, 0.5))

  bxy.restoreTransform()

  bxy.endFrame()
  window.swapBuffers()

while not window.closeRequested:
  pollEvents()
