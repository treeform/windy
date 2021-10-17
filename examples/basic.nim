import boxy, opengl, windy

init()

let
  windowSize = ivec2(1280, 800)
  window = newWindow("Windy + Boxy", windowSize)

window.makeContextCurrent()
loadExtensions()

window.visible = true

echo "GL_VERSION: ", cast[cstring](glGetString(GL_VERSION))
echo "GL_VENDOR: ", cast[cstring](glGetString(GL_VENDOR))
echo "GL_RENDERER: ", cast[cstring](glGetString(GL_RENDERER))
echo "GL_SHADING_LANGUAGE_VERSION: ", cast[cstring](glGetString(GL_SHADING_LANGUAGE_VERSION))

let bxy = newBoxy()

proc display() =
  bxy.beginFrame(windowSize)
  bxy.drawRect(rect(vec2(0, 0), windowSize.vec2), color(1, 1, 1, 1))
  bxy.drawRect(rect(vec2(100, 100), vec2(200, 200)), color(1, 0, 1, 1))
  bxy.endFrame()
  window.swapBuffers()

while true:
  pollEvents()
  display()
