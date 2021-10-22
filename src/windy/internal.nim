import vmath

type
  PerFrame* = object
    mousePrevPos*: IVec2
    mouseDelta*: IVec2
    scrollDelta*: Vec2
