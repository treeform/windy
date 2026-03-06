import opengl, os, windy

let window = newWindow("Windy Properties", ivec2(1280, 800))

window.makeContextCurrent()
loadExtensions()

window.onFrame = proc() =
  glClear(GL_COLOR_BUFFER_BIT)
  # Your OpenGL display code here
  window.swapBuffers()

template waitFor(condition: untyped, maxTries: int) =
  ## Waits for an asynchronous window state transition.
  when defined(macosx):
    var tries = 0
    while not (condition) and tries < maxTries:
      pollEvents()
      sleep(16)
      inc tries

while not window.closeRequested:
  sleep(100)

  pollEvents()

  # Initial window open size
  doAssert window.size == ivec2(1280, 800)

  # Window will block changing size.
  window.size = ivec2(300, 400)
  doAssert window.size == ivec2(300, 400)

  # Not all sizes are valid, window try to go max it can.
  window.size = ivec2(300, 30000)
  doAssert window.size.y != 30000 # You can't get height 30000 even if you ask.
  doAssert window.size != ivec2(300, 400)

  # Change size back.
  window.size = ivec2(300, 400)
  doAssert window.size == ivec2(300, 400)

  window.pos = ivec2(200, 100)
  doAssert window.pos == ivec2(200, 100)

  window.pos = ivec2(-9000, 100)
  when defined(windows):
    # On Windows it is possible to set window to invalid locations.
    doAssert window.pos.x == -9000
  else:
    doAssert window.pos.x != -9000
  doAssert window.pos != ivec2(200, 100)

  window.visible = false
  doAssert not window.visible

  window.visible = true
  doAssert window.visible

  window.maximized = false
  doAssert not window.maximized

  window.maximized = true
  doAssert window.maximized

  window.maximized = false
  doAssert not window.maximized

  window.minimized = false
  doAssert not window.minimized

  window.minimized = true
  waitFor(window.minimized, 30)
  doAssert window.minimized

  window.minimized = false
  waitFor(not window.minimized, 30)
  doAssert not window.minimized

  window.fullscreen = false
  waitFor(not window.fullscreen, 60)
  doAssert not window.fullscreen

  window.fullscreen = true
  waitFor(window.fullscreen, 600)
  doAssert window.fullscreen

  window.fullscreen = false
  waitFor(not window.fullscreen, 600)
  doAssert not window.fullscreen

  echo "SUCCESS!"
  quit()
