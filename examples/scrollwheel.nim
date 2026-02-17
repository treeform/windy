import
  std/[strformat, times],
  windy, vmath, boxy, opengl

var
  window: Window
  bxy: Boxy
  rectCenter: Vec2
  lastScrollAt = epochTime()
  hasLastScroll = false

const ScrollMoveScale = 1.0

window = newWindow("Wheel Rectangle Boxy", ivec2(1280, 800))
window.makeContextCurrent()
loadExtensions()
bxy = newBoxy()

rectCenter = window.size.vec2 / 2

echo "Use mouse wheel to move the white rectangle."
echo "Each scroll prints delta, position, and delta per second."

proc handleScrollDelta() =
  let
    delta = window.scrollDelta
    deltaVec = vec2(delta.x.float, delta.y.float)
    now = epochTime()
  if delta.x == 0 and delta.y == 0:
    return

  let dt =
    if hasLastScroll:
      max(0.000001, now - lastScrollAt)
    else:
      0.0

  lastScrollAt = now
  hasLastScroll = true
  rectCenter += deltaVec * ScrollMoveScale

  let deltaPerSecond =
    if dt > 0.0:
      deltaVec / dt.float32
    else:
      vec2(0'f32, 0'f32)
  echo &"scroll delta=({deltaVec.x:.2f}, {deltaVec.y:.2f}) " &
    &"delta/s=({deltaPerSecond.x:.2f}, {deltaPerSecond.y:.2f}) " &
    &"position=({rectCenter.x:.2f}, {rectCenter.y:.2f})"

window.onFrame = proc() =
  bxy.beginFrame(window.size)

  let
    halfSize = window.size.vec2 * 0.5
    topLeft = rectCenter - halfSize / 2

  bxy.drawRect(rect(0, 0, window.size.x.float, window.size.y.float), color(0.08, 0.08, 0.08, 1.0))
  bxy.drawRect(rect(topLeft.x, topLeft.y, halfSize.x, halfSize.y), color(1.0, 1.0, 1.0, 1.0))

  bxy.endFrame()
  window.swapBuffers()

while not window.closeRequested:
  pollEvents()
  handleScrollDelta()
