import opengl, windy

# Global event handlers must be registered before the first window is created,
# this enables them to receive events from gamepads that are already connected
onGamepadConnected = proc(gamepadId: int) =
  echo "Gamepad ", gamepadId, " connected: ", gamepadName(gamepadId)
onGamepadDisconnected = proc(gamepadId: int) =
  echo "Gamepad ", gamepadId, " disconnected"

let window = newWindow("Windy Gamepad", ivec2(1280, 800))
var color = vec4(0, 0, 0, 1)

window.makeContextCurrent()
loadExtensions()

proc gamepad() =
  for i in 0..<maxGamepads:
    for btn in 0.GamepadButton..<GamepadButtonCount:
      if gamepadButtonPressed(i, btn):
        echo "Gamepad ", i, " button ", btn, " pressed"
      if gamepadButtonReleased(i, btn):
        echo "Gamepad ", i, " button ", btn, " released"
      if gamepadButtonPressure(i, btn) > 0 and gamepadButtonPressure(i, btn) < 1:
        echo "Gamepad ", i, " button ", btn, " pressure ", gamepadButtonPressure(i, btn)
    for axis in 0.GamepadAxis..<GamepadAxisCount:
      if gamepadAxis(i, axis) != 0:
        echo "Gamepad ", i, " axis ", axis, " value ", gamepadAxis(i, axis)

proc display() =
  glClearColor(color.x, color.y, color.z, color.w)
  glClear(GL_COLOR_BUFFER_BIT)
  window.swapBuffers()

window.run(proc() =
  gamepad()
  display()
  pollEvents())
