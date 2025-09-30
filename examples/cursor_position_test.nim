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

window.onButtonPress = proc(button: Button) =
  case button:
  of KeyEqual, NumpadAdd:
    squareSize += 5.0
    echo &"Square size: {squareSize}"
  of KeyMinus, NumpadSubtract:
    squareSize = max(5.0, squareSize - 5.0)
    echo &"Square size: {squareSize}"
  of KeyEscape:
    window.closeRequested = true
  else:
    discard

window.onFrame = proc() =
  bxy.beginFrame(window.size)
  
  # Clear background.
  bxy.drawRect(rect(0, 0, window.size.x.float, window.size.y.float), color(0.1, 0.1, 0.1, 1.0))
  
  # Draw crosshair at cursor position.
  let cursorPos = window.mousePos.vec2
  
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
  bxy.drawRect(rect(cursorPos.x - 1, 0, 2, window.size.y.float), color(0.3, 1.0, 0.3, 0.5))
  bxy.drawRect(rect(0, cursorPos.y - 1, window.size.x.float, 2), color(0.3, 1.0, 0.3, 0.5))
  
  bxy.endFrame()
  window.swapBuffers()

while not window.closeRequested:
  pollEvents()

