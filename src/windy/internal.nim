import common, pixie, std/random

const
  multiClickRadius = 4
  CRLF* = "\r\n"

type
  GamepadState* = object
    numButtons*: int8
    numAxes*: int8
    buttons*: uint32 # One bit per button, 32 buttons max
    pressed*: uint32 # Buttons pressed this frame
    released*: uint32 # Buttons released this frame
    pressures*: array[GamepadButtonCount.int, float32]
    axes*: array[GamepadAxisCount.int, float32]

  WindowState* = object
    title*: string
    icon*: Image
    cursor*: Cursor
    closeRequested*, closed*: bool
    mousePos*, mousePrevPos*: IVec2
    buttonDown*, buttonToggle*: set[Button]
    perFrame*: PerFrame

    doubleClickTime*: float64
    tripleClickTimes*: array[2, float64]
    quadrupleClickTimes*: array[3, float64]
    multiClickPositions*: array[3, IVec2]

    runeInputEnabled*: bool
    imeCursorIndex*: int
    imeCompositionString*: string

  PerFrame* = object
    mouseDelta*: IVec2
    scrollDelta*: Vec2
    buttonPressed*, buttonReleased*: set[Button]

var
  initialized*: bool
  platformDoubleClickInterval*: float64
  windyRand* = initRand(2022)

proc next*(rand: Rand): int =
  windyRand.rand(int.high)

proc major*(openglVersion: OpenGLVersion): int =
  case openglVersion:
  of OpenGL3Dot0: 3
  of OpenGL3Dot1: 3
  of OpenGL3Dot2: 3
  of OpenGL3Dot3: 3
  of OpenGL4Dot0: 4
  of OpenGL4Dot1: 4
  of OpenGL4Dot2: 4
  of OpenGL4Dot3: 4
  of OpenGL4Dot4: 4
  of OpenGL4Dot5: 4
  of OpenGL4Dot6: 4

proc minor*(openglVersion: OpenGLVersion): int =
  case openglVersion:
  of OpenGL3Dot0: 0
  of OpenGL3Dot1: 1
  of OpenGL3Dot2: 2
  of OpenGL3Dot3: 3
  of OpenGL4Dot0: 0
  of OpenGL4Dot1: 1
  of OpenGL4Dot2: 2
  of OpenGL4Dot3: 3
  of OpenGL4Dot4: 4
  of OpenGL4Dot5: 5
  of OpenGL4Dot6: 6

template handleButtonPressTemplate*() =
  window.state.buttonDown.incl button
  window.state.perFrame.buttonPressed.incl button
  if button in window.state.buttonToggle:
    window.state.buttonToggle.excl button
  else:
    window.state.buttonToggle.incl button
  if window.onButtonPress != nil:
    window.onButtonPress(button)

  if button == MouseLeft:
    let
      clickTime = epochTime()
      mousePos = window.state.mousePos
      scaledMultiClickRadius = multiClickRadius * window.contentScale

    let
      doubleClickInterval = clickTime - window.state.doubleClickTime
      doubleClickDistance =
        (mousePos - window.state.multiClickPositions[0]).vec2.length
    if doubleClickInterval <= platformDoubleClickInterval and
      doubleClickDistance <= scaledMultiClickRadius:
      window.handleButtonPress(DoubleClick)
      window.state.doubleClickTime = 0
    else:
      window.state.doubleClickTime = clickTime

    let
      tripleClickIntervals = [
        clickTime - window.state.tripleClickTimes[0],
        clickTime - window.state.tripleClickTimes[1]
      ]
      tripleClickInterval = tripleClickIntervals[0] + tripleClickIntervals[1]
      tripleClickDistance =
        (mousePos - window.state.multiClickPositions[1]).vec2.length

    if tripleClickInterval < 2 * platformDoubleClickInterval and
      tripleClickDistance <= scaledMultiClickRadius:
      window.handleButtonPress(TripleClick)
      window.state.tripleClickTimes = [0.float64, 0]
    else:
      window.state.tripleClickTimes[1] = window.state.tripleClickTimes[0]
      window.state.tripleClickTimes[0] = clickTime

    let
      quadrupleClickIntervals = [
        clickTime - window.state.quadrupleClickTimes[0],
        clickTime - window.state.quadrupleClickTimes[1],
        clickTime - window.state.quadrupleClickTimes[2]
      ]
      quadrupleClickInterval =
        quadrupleClickIntervals[0] +
        quadrupleClickIntervals[1] +
        quadrupleClickIntervals[2]
      quadrupleClickDistance =
        (mousePos - window.state.multiClickPositions[2]).vec2.length

    if quadrupleClickInterval < 3 * platformDoubleClickInterval and
      quadrupleClickDistance <= multiClickRadius:
      window.handleButtonPress(QuadrupleClick)
      window.state.quadrupleClickTimes = [0.float64, 0, 0]
    else:
      window.state.quadrupleClickTimes[2] = window.state.quadrupleClickTimes[1]
      window.state.quadrupleClickTimes[1] = window.state.quadrupleClickTimes[0]
      window.state.quadrupleClickTimes[0] = clickTime

    window.state.multiClickPositions[2] = window.state.multiClickPositions[1]
    window.state.multiClickPositions[1] = window.state.multiClickPositions[0]
    window.state.multiClickPositions[0] = mousePos

template handleButtonReleaseTemplate*() =
  if button == MouseLeft:
    if QuadrupleClick in window.state.buttonDown:
      window.handleButtonRelease(QuadrupleClick)
    if TripleClick in window.state.buttonDown:
      window.handleButtonRelease(TripleClick)
    if DoubleClick in window.state.buttonDown:
      window.handleButtonRelease(DoubleClick)

  window.state.buttonDown.excl button
  window.state.perFrame.buttonReleased.incl button
  if window.onButtonRelease != nil:
    window.onButtonRelease(button)

template handleRuneTemplate*() =
  if not window.state.runeInputEnabled:
    return
  if rune.uint32 < 32 or (rune.uint32 > 126 and rune.uint32 < 160):
    return
  if window.onRune != nil:
    window.onRune(rune)

proc addDefaultHeaders*(headers: var seq[HttpHeader]) =
  if headers["user-agent"].len == 0:
    headers["user-agent"] = "Windy"
  if headers["accept-encoding"].len == 0:
    # If there isn't a specific accept-encoding specified, enable gzip
    headers["accept-encoding"] = "gzip"

template handleGamepadTemplate*() =
  proc gamepadButton*(gamepadId: int, button: GamepadButton): bool =
    (gamepadStates[gamepadId].buttons and (1.uint32 shl button.int8)) != 0

  proc gamepadButtonPressed*(gamepadId: int, button: GamepadButton): bool =
    (gamepadStates[gamepadId].pressed and (1.uint32 shl button.int8)) != 0

  proc gamepadButtonReleased*(gamepadId: int, button: GamepadButton): bool =
    (gamepadStates[gamepadId].released and (1.uint32 shl button.int8)) != 0

  proc gamepadButtonPressure*(gamepadId: int, button: GamepadButton): float =
    gamepadStates[gamepadId].pressures[button.int8]

  proc gamepadAxis*(gamepadId: int, axis: GamepadAxis): float =
    gamepadStates[gamepadId].axes[axis.int8]

proc resetGamepadState*(state: var GamepadState) =
  state.numButtons = 0.int8
  state.numAxes = 0.int8
  state.buttons = 0.uint32
  state.pressed = 0.uint32
  state.released = 0.uint32
  for i in 0..<GamepadButtonCount.int:
    state.pressures[i] = 0.float32
  for i in 0..<GamepadAxisCount.int:
    state.axes[i] = 0.float32
