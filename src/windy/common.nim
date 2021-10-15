type
  WindyError* = object of ValueError

  MSAA* = enum
    msaaDisabled = 0, msaa2x = 2, msaa4x = 4, msaa8x = 8
