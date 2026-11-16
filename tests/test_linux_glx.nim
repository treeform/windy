import opengl, windy

let window = newWindow("Windy GLX regression", ivec2(64, 48), vsync = false)
window.makeContextCurrent()
loadExtensions()
doAssert glGetString(GL_VERSION) != nil
for frame in 0 ..< 3:
  glClearColor(0.2, 0.4, 0.8, 1)
  glClear(GL_COLOR_BUFFER_BIT)
  window.swapBuffers()
  pollEvents()
window.close()
doAssert window.closed
