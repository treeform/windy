import boxy, opengl, windy

init()

let window = newWindow("Windy Callbacks", ivec2(1280, 800))

window.makeContextCurrent()
loadExtensions()

let bxy = newBoxy()

proc display() =
  bxy.beginFrame(window.size)
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(1, 1, 1, 1))
  bxy.drawRect(rect(vec2(100, 100), vec2(200, 200)), color(1, 0, 1, 1))
  bxy.endFrame()
  window.swapBuffers()

window.visible = true

var running = true

window.onCloseRequest = proc() =
  echo "onCloseRequest"
  running = false
  window.close()

window.onMove = proc() =
  echo "onMove ", window.pos

window.onResize = proc() =
  echo "onResize ", window.size
  if window.minimized:
    echo "(minimized)"
  if window.maximized:
    echo "(maximized)"
  display()

window.onFocusChange = proc() =
  echo "onFocusChange ", window.focused

while running:
  display()
  pollEvents()
