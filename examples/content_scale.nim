import opengl, windy

let window = newWindow("Windy Retina", ivec2(1280, 800))

# Windy uses physical pixels for window size units.
# This means this 1280 x 800 pixel window will look smaller than expected
# on high-dpi screens like a Macbook Retina display.

# To address this, scale the window size by the window's content scale.
window.size = (window.size.vec2 * window.contentScale).ivec2

# On a Retina display with a content scale of 2.0, this window will be resized
# to 2560 x 1600 physical pixels. This resized window will have approximately
# the same size-on-screen as a 1280 x 800 physical pixel window would with a
# content scale of 1.0.

window.makeContextCurrent()
loadExtensions()

window.onFrame = proc() =
  echo "content scale: ", window.contentScale
  glClear(GL_COLOR_BUFFER_BIT)
  # Your OpenGL display code here
  window.swapBuffers()

while not window.closeRequested:
  pollEvents()
