import pixie

type PixelRegion* = object
  x*, y*, width*, height*: int

proc rgb*(pixel: ColorRGBX): uint32 {.inline.} =
  uint32(pixel.r) shl 16 or uint32(pixel.g) shl 8 or uint32(pixel.b)

proc rotatedPoint*(x, y, width, height, rotation: int): tuple[x, y: int] {.inline.} =
  case rotation
  of 0: (x, y)
  of 90: (height - 1 - y, x)
  of 180: (width - 1 - x, height - 1 - y)
  of 270: (y, width - 1 - x)
  else: raise newException(ValueError, "Rotation must be 0, 90, 180 or 270")

proc validateRegions*(width, height: int, regions: array[2, PixelRegion]) =
  ## Validate source crops; an empty region leaves its output black.
  for region in regions:
    if region == PixelRegion(): continue
    if width <= 0 or height <= 0 or region.x < 0 or region.y < 0 or
        region.width <= 0 or region.height <= 0 or region.x > width or
        region.y > height or region.width > width - region.x or
        region.height > height - region.y:
      raise newException(ValueError, "Invalid pixel source region")

proc pixelViewport*(region: PixelRegion, width, height: int): PixelRegion =
  ## Center whole-number scaling, clipping at native size when necessary.
  if min(region.width, region.height) <= 0 or min(width, height) <= 0:
    raise newException(ValueError, "Invalid pixel viewport dimensions")
  let scale = max(1, min(width div region.width, height div region.height))
  result.width = region.width * scale
  result.height = region.height * scale
  result.x = (width - result.width) div 2
  result.y = (height - result.height) div 2

proc pixelVertices*(width, height: int, regions: array[2, PixelRegion]): array[48, cfloat] =
  ## Address top-left source crops with OpenGL's bottom-left vertex convention.
  validateRegions(width, height, regions)
  if width <= 0 or height <= 0: return
  for index, region in regions:
    let
      left = cfloat(region.x) / cfloat(width)
      right = cfloat(region.x + region.width) / cfloat(width)
      top = cfloat(region.y) / cfloat(height)
      bottom = cfloat(region.y + region.height) / cfloat(height)
      vertices = [-1.cfloat, -1, left, bottom, 1, -1, right, bottom,
        -1, 1, left, top, -1, 1, left, top, 1, -1, right, bottom, 1, 1, right, top]
    for offset, value in vertices: result[index * vertices.len + offset] = value
