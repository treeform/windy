import
  windy, vmath, boxy, opengl

let window = newWindow("Basic Boxy", ivec2(1280, 800))
window.makeContextCurrent()
loadExtensions()
let bxy = newBoxy()
bxy.addImage("testTexture", readImage("examples/data/testTexture.png"))

window.onFrame = proc() =
  bxy.beginFrame(window.size)

  bxy.drawImage(
    "testTexture",
    center = window.size.vec2 / 2,
    angle = 0
  )

  bxy.endFrame()
  window.swapBuffers()

while not window.closeRequested:
  pollEvents()
