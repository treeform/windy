import opengl, windy, os

let window = newWindow("Windy Properties", ivec2(1280, 800))

window.makeContextCurrent()
loadExtensions()

proc display() =
  glClear(GL_COLOR_BUFFER_BIT)
  # Your OpenGL display code here
  window.swapBuffers()

while not window.closeRequested:
  display()

  sleep(100)

  pollEvents()

  # Window will block chaning size.
  window.size = ivec2(300, 300)
  doAssert window.size == ivec2(300, 300)

  # Not all sizes are valid, window try to go max it can.
  window.size = ivec2(300, 30000)
  doAssert window.size != ivec2(300, 300)

  # Change size back.
  window.size = ivec2(300, 300)
  doAssert window.size == ivec2(300, 300)

  # Window will block chaning size.
  window.pos = ivec2(200, 100)
  doAssert window.pos == ivec2(200, 100)

  window.pos = ivec2(-9000, 100)
  doAssert window.pos != ivec2(200, 100)

  window.maximized = false
  doAssert not window.maximized

  window.maximized = true
  doAssert window.maximized

  window.maximized = false
  doAssert not window.maximized

  window.minimized = false
  doAssert not window.minimized

  window.minimized = true
  doAssert window.minimized

  window.fullscreen = false
  doAssert not window.fullscreen

  window.fullscreen = true
  doAssert window.fullscreen

  window.fullscreen = false
  doAssert not window.fullscreen



  echo "SUCESS!"
  quit()
