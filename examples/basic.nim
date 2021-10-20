import boxy, opengl, windy

init()

let window = newWindow("Windy Basic", ivec2(1280, 800))

window.makeContextCurrent()
loadExtensions()

let bxy = newBoxy()

proc display() =
  bxy.beginFrame(window.size)
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(1, 1, 1, 1))
  bxy.drawRect(rect(vec2(100, 100), vec2(200, 200)), color(1, 0, 1, 1))
  bxy.endFrame()
  window.swapBuffers()

var running = true

window.onCloseRequest = proc() =
  running = false
  window.close()

window.visible = true

while running:
  display()
  pollEvents()
