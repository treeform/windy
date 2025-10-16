import boxy, opengl, windy

let window = newWindow("Windy Toggle Fullscreen", ivec2(1280, 800))

window.makeContextCurrent()
loadExtensions()

let bxy = newBoxy()

window.onFrame = proc() =
  bxy.beginFrame(window.size)
  bxy.drawRect(rect(vec2(0, 0), window.size.vec2), color(1, 1, 1, 1))
  bxy.drawRect(
    rect((window.size.vec2 / 2) - vec2(100, 100), vec2(200, 200)),
    color(1, 0, 1, 1)
  )
  bxy.endFrame()
  window.swapBuffers()

window.onButtonPress = proc(button: Button) =
  if button == MouseLeft:
    window.fullscreen = window.buttonToggle[MouseLeft]

while not window.closeRequested:
  pollEvents()