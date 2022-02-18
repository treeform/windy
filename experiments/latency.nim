import boxy, opengl, windy

let window = newWindow("Toggle Fullscreen", ivec2(1280, 800), vsync=true)

window.makeContextCurrent()
loadExtensions()

let bxy = newBoxy()

proc display() =
  bxy.beginFrame(window.size)
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(1, 1, 1, 1))
  let mousePos = window.mousePos.vec2 #+ window.mouseDelta.vec2
  bxy.drawRect(rect(mousePos, vec2(20, 20)), color(0, 0, 0, 1))
  bxy.endFrame()
  window.swapBuffers()

while true:
  pollEvents()
  if window.closeRequested:
    break
  display()
