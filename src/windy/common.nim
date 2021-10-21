import vmath

type
  WindyError* = object of ValueError

  MSAA* = enum
    msaaDisabled = 0, msaa2x = 2, msaa4x = 4, msaa8x = 8

  Callback* = proc()

  PerFrame* = object
    mousePrevPos*: IVec2
    mouseDelta*: IVec2
    scrollDelta*: Vec2
