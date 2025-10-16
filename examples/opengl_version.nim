import opengl, os, windy

# https://en.wikipedia.org/wiki/OpenGL#Version_history

let window = newWindow(
  "Windy",
  ivec2(1280, 800),
  openglVersion = OpenGL3Dot3
)

window.makeContextCurrent()
loadExtensions()

echo "GL_VERSION: ", cast[cstring](glGetString(GL_VERSION))
echo "GL_VENDOR: ", cast[cstring](glGetString(GL_VENDOR))
echo "GL_RENDERER: ", cast[cstring](glGetString(GL_RENDERER))

while not window.closeRequested:
  pollEvents()
  sleep(10)
