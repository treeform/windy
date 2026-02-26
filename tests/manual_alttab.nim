import opengl, os, windy

let window = newWindow("Windy Callbacks", ivec2(1280, 800))
window.runeInputEnabled = true

window.makeContextCurrent()
loadExtensions()

window.onFrame = proc() =
  glClear(GL_COLOR_BUFFER_BIT)

  # Print if alt is down, when mouse is down:
  if window.buttonDown[KeyLeftSuper] or
    window.buttonDown[KeyRightSuper] or
    window.buttonDown[KeyLeftAlt] or
    window.buttonDown[KeyRightAlt] or
    window.buttonDown[KeyLeftControl] or
    window.buttonDown[KeyRightControl]:
      glClearColor(1.0f, 0.0f, 0.0f, 1.0f)
  else:
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f)

  window.swapBuffers()

while not window.closeRequested:

  if window.minimized or not window.visible:
    sleep(10)
  pollEvents()
