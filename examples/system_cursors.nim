import windy, vmath, boxy, opengl

# Test all cursor types
let cursors = [
  Cursor(kind: ArrowCursor),
  Cursor(kind: PointingHandCursor),
  Cursor(kind: IBeamCursor),
  Cursor(kind: CrosshairCursor),
  Cursor(kind: ClosedHandCursor),
  Cursor(kind: OpenHandCursor),
  Cursor(kind: ResizeLeftCursor),
  Cursor(kind: ResizeRightCursor),
  Cursor(kind: ResizeLeftRightCursor),
  Cursor(kind: ResizeUpCursor),
  Cursor(kind: ResizeDownCursor),
  Cursor(kind: ResizeUpDownCursor),
  Cursor(kind: OperationNotAllowedCursor),
  Cursor(kind: WaitCursor)
]

var
  currentCursor = 0
  window: Window
  bxy: Boxy

window = newWindow("SystemCursors Test", ivec2(800, 600))
window.makeContextCurrent()
loadExtensions()
bxy = newBoxy()

echo "Press SPACE or click to cycle through cursor types"
echo "Press ESC to exit"
echo "Current cursor: ", cursors[currentCursor].kind

proc nextCursor() =
  currentCursor = (currentCursor + 1) mod cursors.len
  window.cursor = cursors[currentCursor]
  echo "Current cursor: ", cursors[currentCursor].kind

window.onButtonPress = proc(button: Button) =
  case button:
  of KeySpace:
    nextCursor()
  of MouseLeft:
    nextCursor()
  of KeyEscape:
    window.closeRequested = true
  else:
    discard

window.onFrame = proc() =
  bxy.beginFrame(window.size)

  # Draw different colored rectangles for each cursor zone
  let numCursors = cursors.len
  let rectHeight = window.size.y.float / numCursors.float

  for i in 0 ..< numCursors:
    let
      y = i.float * rectHeight
      hue = i.float / numCursors.float
      # Simple HSV to RGB conversion
      c = hue * 6.0
      x = 1.0 - abs((c mod 2.0) - 1.0)
      rgb = if c < 1: (1.0, x, 0.0)
        elif c < 2: (x, 1.0, 0.0)
        elif c < 3: (0.0, 1.0, x)
        elif c < 4: (0.0, x, 1.0)
        elif c < 5: (x, 0.0, 1.0)
        else: (1.0, 0.0, x)

    let color = if i == currentCursor:
      color(rgb[0], rgb[1], rgb[2], 1.0)
    else:
      color(rgb[0] * 0.3, rgb[1] * 0.3, rgb[2] * 0.3, 1.0)

    bxy.drawRect(rect(0, y, window.size.x.float, rectHeight), color)

  bxy.endFrame()
  window.swapBuffers()

while not window.closeRequested:
  pollEvents()
