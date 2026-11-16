## Browser mouse regression fixture. Inspect window.windyMouseEvents from CDP.
import windy, vmath

{.emit: """
#include <emscripten.h>
EM_JS(void, recordMouse, (int kind, int x, int y, int dx, int dy, int down), {
  (window.windyMouseEvents ||= []).push({kind, x, y, dx, dy, down});
});
""".}
proc recordMouse(kind, x, y, dx, dy, down: cint) {.importc, nodecl.}
let window = newWindow("Windy mouse regression", ivec2(800, 600))
proc snapshot(kind: cint) =
  let position = window.mousePos.vec2 / window.contentScale
  let delta = window.mouseDelta.vec2 / window.contentScale
  recordMouse(kind, position.x.cint, position.y.cint,
    delta.x.cint, delta.y.cint, cint(window.buttonDown[MouseLeft]))
window.onButtonPress = proc(button: Button) =
  if button == MouseLeft: snapshot(1)
window.onButtonRelease = proc(button: Button) =
  if button == MouseLeft: snapshot(2)
window.onMouseMove = proc() = snapshot(3)
window.onFrame = proc() = discard
while not window.closeRequested:
  pollEvents()
