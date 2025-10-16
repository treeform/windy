import opengl, os, windy

let window = newWindow("Windy Callbacks", ivec2(1280, 800))
window.runeInputEnabled = true

window.makeContextCurrent()
loadExtensions()

window.onFrame = proc() =
  glClear(GL_COLOR_BUFFER_BIT)
  # Your OpenGL display code here
  window.swapBuffers()

window.onCloseRequest = proc() =
  echo "onCloseRequest"

window.onMove = proc() =
  echo "onMove ", window.pos

window.onResize = proc() =
  echo "onResize ", window.size, " content scale = ", window.contentScale
  if window.minimized:
    echo "(minimized)"
  if window.maximized:
    echo "(maximized)"

window.onFocusChange = proc() =
  echo "onFocusChange ", window.focused

window.onMouseMove = proc() =
  echo "onMouseMove from ",
    window.mousePrevPos, " to ", window.mousePos,
    " delta = ", window.mouseDelta

window.onScroll = proc() =
  echo "onScroll ", window.scrollDelta

window.onButtonPress = proc(button: Button) =
  echo "onButtonPress ", button
  echo "down: ", window.buttonDown[button]
  echo "pressed: ", window.buttonPressed[button]
  echo "released: ", window.buttonReleased[button]
  echo "toggle: ", window.buttonToggle[button]

window.onButtonRelease = proc(button: Button) =
  echo "onButtonRelease ", button
  echo "down: ", window.buttonDown[button]
  echo "pressed: ", window.buttonPressed[button]
  echo "released: ", window.buttonReleased[button]
  echo "toggle: ", window.buttonToggle[button]

window.onRune = proc(rune: Rune) =
  echo "onRune ", rune

while not window.closeRequested:
  if window.minimized or not window.visible:
    sleep(10)
  pollEvents()
