import opengl, windy

let window = newWindow("Windy Basic", ivec2(1280, 800))

window.makeContextCurrent()
loadExtensions()

proc display() =
  glClear(GL_COLOR_BUFFER_BIT)
  # Your OpenGL display code here
  window.swapBuffers()

window.run(proc() =
  display()
  pollEvents())
