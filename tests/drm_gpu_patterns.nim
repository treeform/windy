type
  PixelLayout* = enum
    xbgrPixels, xrgbPixels
  Viewport* = object
    x*, y*, width*, height*: int
  PairedFlip* = object
    crtcs*: array[2, uint32]
    completed*: set[range[0..1]]
    timestamps*: array[2, uint64]

const
  SourceWidth* = 256

proc fit*(width, height, panelWidth, panelHeight: int): Viewport =
  ## Center an image inside a panel using an integer scale.
  if min(width, height) <= 0 or min(panelWidth, panelHeight) <= 0:
    raise newException(ValueError, "Dimensions must be positive")
  let scale = min(panelWidth div width, panelHeight div height)
  if scale < 1:
    raise newException(ValueError, "Source does not fit the panel")
  result.width = width * scale
  result.height = height * scale
  result.x = (panelWidth - result.width) div 2
  result.y = (panelHeight - result.height) div 2

proc pixel*(x, y, frame, panelHeight: int): uint32 =
  ## Generate opaque colour bars, single-pixel checks and a moving white seam.
  let
    panel = y div panelHeight
    localY = y mod panelHeight
    bars = [0xff0000ff'u32, 0xff00ff00'u32, 0xffff0000'u32, 0xffffffff'u32]
  if x == frame mod SourceWidth or localY == frame mod panelHeight:
    return 0xffffffff'u32
  if localY < panelHeight div 3:
    return bars[(x div 64 + panel) mod bars.len]
  if localY < panelHeight * 2 div 3:
    return if (x + localY) mod 2 == 0: 0xffffffff'u32 else: 0xff000000'u32
  if panel == 0: 0xff00ffff'u32 else: 0xffffff00'u32

proc pack*(rgba: uint32, layout: PixelLayout): uint32 =
  ## Preserve XBGR bytes or exchange red and blue for a standard XRGB source.
  if layout == xbgrPixels: rgba
  else: (rgba and 0xff00ff00'u32) or (rgba and 255) shl 16 or (rgba shr 16 and 255)

proc generate*(data: var seq[uint32], panelHeight, frame: int, layout: PixelLayout) =
  ## Fill one combined frame with an identical animation for both benchmarks.
  data.setLen(SourceWidth * panelHeight * 2)
  for y in 0 ..< panelHeight * 2:
    for x in 0 ..< SourceWidth:
      data[y * SourceWidth + x] = pack(pixel(x, y, frame, panelHeight), layout)

proc complete*(pair: var PairedFlip, crtc: uint32, timestamp: uint64) =
  ## Record exactly one completion per output before its buffer can be retired.
  for index in 0..1:
    if pair.crtcs[index] == crtc:
      if index in pair.completed:
        raise newException(ValueError, "Duplicate flip completion")
      pair.completed.incl index
      pair.timestamps[index] = timestamp
      return
  raise newException(ValueError, "Completion from an unexpected CRTC")

proc ready*(pair: PairedFlip): bool =
  ## Return whether both consumers have finished the paired update.
  pair.completed == {0, 1}

proc scalePanel*[T](source: seq[uint32], panel, sourceHeight: int, layout: PixelLayout,
    output: var seq[T], width, height: int) =
  ## Match the player's CPU row expansion, row copies and border-only clears.
  let
    view = fit(SourceWidth, sourceHeight, width, height)
    scale = view.width div SourceWidth
  static: doAssert sizeof(T) == sizeof(uint32)
  output.setLen(width * height)
  for y in 0 ..< height:
    if y < view.y or y >= view.y + view.height:
      for x in 0 ..< width: output[y * width + x] = cast[T](0xff000000'u32)
    else:
      for x in 0 ..< view.x: output[y * width + x] = cast[T](0xff000000'u32)
      for x in view.x + view.width ..< width: output[y * width + x] = cast[T](0xff000000'u32)
  for sourceY in 0 ..< sourceHeight:
    let target = (view.y + sourceY * scale) * width + view.x
    template expandRow(factor: int) =
      for sourceX in 0 ..< SourceWidth:
        let colour = pack(source[(panel * sourceHeight + sourceY) * SourceWidth + sourceX], layout)
        for repeat in 0 ..< factor: output[target + sourceX * factor + repeat] = cast[T](colour)
    case scale
    of 2: expandRow(2)
    of 3: expandRow(3)
    of 4: expandRow(4)
    else: expandRow(scale)
    for repeat in 1 ..< scale:
      copyMem(addr output[target + repeat * width], addr output[target], view.width * sizeof(uint32))
