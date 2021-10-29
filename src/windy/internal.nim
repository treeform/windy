import vmath

type
  State* = object
    closeRequested*, closed*: bool
    mousePos*: IVec2
    buttonPressed*, buttonDown*, buttonReleased*, buttonToggle*: set[Button]
    perFrame*: PerFrame

  PerFrame* = object
    mousePrevPos*: IVec2
    mouseDelta*: IVec2
    scrollDelta*: Vec2
