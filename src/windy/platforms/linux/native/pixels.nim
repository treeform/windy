import pixie

proc rgb*(pixel: ColorRGBX): uint32 {.inline.} =
  uint32(pixel.r) shl 16 or uint32(pixel.g) shl 8 or uint32(pixel.b)

proc rotatedPoint*(x, y, width, height, rotation: int): tuple[x, y: int] {.inline.} =
  case rotation
  of 0: (x, y)
  of 90: (height - 1 - y, x)
  of 180: (width - 1 - x, height - 1 - y)
  of 270: (y, width - 1 - x)
  else: raise newException(ValueError, "Rotation must be 0, 90, 180 or 270")
