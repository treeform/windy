include windy/platforms/linux/drm

proc pattern(width, height: int): Image =
  ## Generate asymmetric pixel colours without loading game data.
  result = newImage(width, height)
  for y in 0 ..< height:
    for x in 0 ..< width:
      result.data[y * width + x] = rgbx(uint8(x mod 256), uint8(y mod 256),
        uint8((x xor y) mod 256), 255)

proc verify(pair: GpuDisplay, image: Image, regions: array[2, PixelRegion]) =
  ## Read every GPU pixel against source crops, integer scaling and black borders.
  pair.gpuUpload(image, regions)
  pair.gpuDraw()
  let
    width = pair.panelWidth
    height = pair.panelHeight
  var pixels = newSeq[uint32](width * height * 2)
  pair.gpu.glReadPixels(0, 0, cint(width), cint(height * 2), GpuGlRgba, GpuGlByte, addr pixels[0])
  gpuChecked(pair.gpu.glGetError() == 0, "Reading pixel pair")
  for index, crop in regions:
    let
      scale = if crop.width == 0: 1 else: max(1, min(width div crop.width, height div crop.height))
      left = (width - crop.width * scale) div 2
      top = (height - crop.height * scale) div 2
    for y in 0 ..< height:
      for x in 0 ..< width:
        var expected = 0xff000000'u32
        if crop.width > 0 and x >= left and y >= top and
            x < left + crop.width * scale and y < top + crop.height * scale:
          let
            sourceX = crop.x + (x - left) div scale
            sourceY = crop.y + (y - top) div scale
          expected = cast[uint32](image.data[sourceY * image.width + sourceX])
        let actual = pixels[(height * 2 - 1 - index * height - y) * width + x] or 0xff000000'u32
        if actual != expected:
          raise newException(IOError, &"Pair pixel mismatch on output {index} at {x},{y}: {actual} != {expected}")
  pair.presentGpuPixels(image, regions)

proc main() =
  ## Run bounded silent pixel/flip checks against the production GPU implementation.
  if paramCount() != 3:
    raise newException(ValueError, "Usage: manual_drm_pixelpair CARD TOP BOTTOM")
  let display = openDrm(paramStr(1))
  defer: display.close()
  display.openOutput(@[paramStr(2), paramStr(3)], 0, true)
  let pair = newGpuDisplay(display, [display.screens[0], display.screens[1]])
  defer: pair.close()
  for panelHeight in [192, 224]:
    pair.verify(pattern(256, panelHeight * 2), [PixelRegion(width: 256, height: panelHeight),
      PixelRegion(y: panelHeight, width: 256, height: panelHeight)])
  let single = pattern(240, 160)
  pair.verify(single, [PixelRegion(width: 240, height: 160), PixelRegion()])
  pair.verify(single, [PixelRegion(), PixelRegion(width: 240, height: 160)])
  pair.verify(pattern(19, 26), [PixelRegion(width: 19, height: 13),
    PixelRegion(y: 13, width: 19, height: 13)])
  pair.verify(pattern(pair.panelWidth + 16, pair.panelHeight + 8),
    [PixelRegion(width: pair.panelWidth + 16, height: pair.panelHeight + 8), PixelRegion()])
  pair.verify(pattern(320, 240), [PixelRegion(), PixelRegion(width: 320, height: 240)])
  pair.verify(nil, [PixelRegion(), PixelRegion()])
  echo "GPU pixel pair: all pixels, crops, resize, blank/swap, clipping and paired flips passed"

when isMainModule:
  main()
