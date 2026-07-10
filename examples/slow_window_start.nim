import
  std/[os, strformat],
  windy, vmath, boxy, opengl

const
  SlowStartMs = 3500

var
  window: Window
  bxy: Boxy
  squareSize = 28.0
  clicked = false
  moveCount = 0

proc drawFrame() =
  ## Draws the cursor-following square and crosshair.
  bxy.beginFrame(window.size)
  bxy.saveTransform()

  let
    scale = window.contentScale
    logicalSize = window.size.vec2 / scale
    cursorPos = window.mousePos.vec2 / scale
    halfSize = squareSize / 2.0
    squareColor =
      if clicked:
        color(0.2, 0.7, 1.0, 0.9)
      else:
        color(1.0, 0.3, 0.3, 0.8)

  bxy.scale(scale)
  bxy.drawRect(
    rect(0, 0, logicalSize.x, logicalSize.y),
    color(0.1, 0.1, 0.1, 1.0)
  )
  bxy.drawRect(
    rect(
      cursorPos.x - halfSize,
      cursorPos.y - halfSize,
      squareSize,
      squareSize
    ),
    squareColor
  )
  bxy.drawRect(
    rect(cursorPos.x - 1, 0, 2, logicalSize.y),
    color(0.3, 1.0, 0.3, 0.5)
  )
  bxy.drawRect(
    rect(0, cursorPos.y - 1, logicalSize.x, 2),
    color(0.3, 1.0, 0.3, 0.5)
  )

  bxy.restoreTransform()
  bxy.endFrame()
  window.swapBuffers()

window = newWindow("Slow Window Start", ivec2(1280, 800))
window.makeContextCurrent()
loadExtensions()
bxy = newBoxy()

window.onMouseMove = proc() =
  moveCount += 1

window.onButtonPress = proc(button: Button) =
  case button:
  of MouseLeft:
    clicked = not clicked
    echo &"Left click toggled color. Mouse moves seen: {moveCount}"
  else:
    discard

window.onFrame = proc() =
  drawFrame()

echo "Slow window start repro."
echo "The window is visible before the event loop is allowed to run."
echo "After the delay, move the mouse and click the square."

drawFrame()
echo "Delaying for 3,500 ms."
sleep(SlowStartMs)
echo "Delay done."

while not window.closeRequested:
  pollEvents()
