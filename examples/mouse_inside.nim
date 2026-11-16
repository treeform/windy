import opengl, os, windy

let window = newWindow("Windy Mouse Inside", ivec2(1280, 800))

window.makeContextCurrent()
loadExtensions()

var wasInside = window.mouseInside

echo "Move the mouse in and out of the window."
echo "Red means inside, black means outside."
echo "mouseInside ", wasInside

window.onFrame = proc() =
  let inside = window.mouseInside
  if inside != wasInside:
    echo "mouseInside ", inside
    wasInside = inside
  if inside:
    glClearColor(1.0f, 0.0f, 0.0f, 1.0f)
  else:
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
  glClear(GL_COLOR_BUFFER_BIT)
  window.swapBuffers()

while not window.closeRequested:
  if window.minimized or not window.visible:
    sleep(10)
  pollEvents()
