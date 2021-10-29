import common, vmath

type
  State* = object
    title*: string
    closeRequested*, closed*: bool
    mousePos*: IVec2
    buttonPressed*, buttonDown*, buttonReleased*, buttonToggle*: set[Button]
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
