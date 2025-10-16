import opengl, windy

let window = newWindow("Windy Fixed Size", ivec2(500, 500))
window.style = Decorated

window.makeContextCurrent()
loadExtensions()

window.onFrame = proc() =
  glClear(GL_COLOR_BUFFER_BIT)
  # Your OpenGL display code here
  window.swapBuffers()

while not window.closeRequested:
  pollEvents()