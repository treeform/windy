import
  ./drm_gpu_patterns

proc main() =
  ## Check layout, colour contracts and both possible completion orders.
  for height in [192, 224]:
    let view = fit(SourceWidth, height, 1024, 768)
    if height == 192:
      doAssert view == Viewport(x: 0, y: 0, width: 1024, height: 768)
    else:
      doAssert view == Viewport(x: 128, y: 48, width: 768, height: 672)
    var xbgr, xrgb: seq[uint32]
    generate(xbgr, height, 7, xbgrPixels)
    generate(xrgb, height, 7, xrgbPixels)
    doAssert xbgr.len == SourceWidth * height * 2
    for index, colour in xbgr:
      doAssert colour shr 24 == 255
      doAssert pack(xrgb[index], xrgbPixels) == colour
    doAssert pixel(1, height - 1, 7, height) != pixel(1, height * 2 - 1, 7, height)
    var output: seq[uint32]
    for layout in [xbgrPixels, xrgbPixels]:
      for panel in 0..1:
        scalePanel((if layout == xbgrPixels: xbgr else: xrgb), panel, height, layout,
          output, 1024, 768)
        for y in 0..<768:
          for x in 0..<1024:
            var expected = 0xff000000'u32
            if x >= view.x and x < view.x + view.width and y >= view.y and y < view.y + view.height:
              expected = pixel((x - view.x) div (view.width div SourceWidth),
                (y - view.y) div (view.width div SourceWidth) + panel * height, 7, height)
            doAssert output[y * 1024 + x] == expected
  for order in [[0, 1], [1, 0]]:
    var pair = PairedFlip(crtcs: [69'u32, 70])
    pair.complete(pair.crtcs[order[0]], 100)
    doAssert not pair.ready
    pair.complete(pair.crtcs[order[1]], 105)
    doAssert pair.ready
    doAssert pair.timestamps[order[0]] == 100
    doAssert pair.timestamps[order[1]] == 105
    for crtc in [pair.crtcs[0], 999'u32]:
      var rejected = false
      try: pair.complete(crtc, 110)
      except ValueError: rejected = true
      doAssert rejected
  var rejected = false
  try: discard fit(2048, 768, 1024, 768)
  except ValueError: rejected = true
  doAssert rejected

main()
