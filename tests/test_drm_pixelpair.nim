import
  std/unittest,
  windy,
  windy/platforms/linux/drm,
  windy/platforms/linux/native/pixels

suite "GPU pixel pairs":
  test "DS and EarthBound preserve integer pixels and borders":
    check pixelViewport(PixelRegion(width: 256, height: 192), 1024, 768) ==
      PixelRegion(width: 1024, height: 768)
    check pixelViewport(PixelRegion(width: 256, height: 224), 1024, 768) ==
      PixelRegion(x: 128, y: 48, width: 768, height: 672)
    check pixelViewport(PixelRegion(width: 100, height: 80), 60, 50) ==
      PixelRegion(x: -20, y: -15, width: 100, height: 80)
  test "source crops and black outputs validate before rendering":
    validateRegions(0, 0, [PixelRegion(), PixelRegion()])
    validateRegions(256, 448, [PixelRegion(width: 256, height: 224),
      PixelRegion(y: 224, width: 256, height: 224)])
    for region in [PixelRegion(width: 0, height: 1),
        PixelRegion(x: -1, width: 1, height: 1),
        PixelRegion(x: high(int), width: 1, height: 1),
        PixelRegion(width: 257, height: 1)]:
      expect ValueError: validateRegions(256, 448, [region, PixelRegion()])
  test "texture crops retain top and bottom orientation":
    let vertices = pixelVertices(256, 448, [PixelRegion(width: 256, height: 224),
      PixelRegion(y: 224, width: 256, height: 224)])
    check vertices[3] == 0.5
    check vertices[11] == 0
    check vertices[27] == 1
    check vertices[35] == 0.5
  test "invalid window ownership fails without opening GPU libraries":
    expect WindyError: discard newDrmPixelPair(nil, nil)
    expect WindyError: discard newDrmPixelPair(Window(nil), Window(nil))
    expect WindyError: discard newDrmPixelPair(Window(), Window())
    close(DrmPixelPair(nil))
