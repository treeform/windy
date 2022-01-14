import common, pixie

const
  multiClickRadius = 4

type
  State* = object
    title*: string
    icon*: Image
    cursor*: Cursor
    closeRequested*, closed*: bool
    mousePos*: IVec2
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
    mousePrevPos*: IVec2
    mouseDelta*: IVec2
    scrollDelta*: Vec2
    buttonPressed*, buttonReleased*: set[Button]

var
  initialized*: bool
  platformDoubleClickInterval*: float64

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
