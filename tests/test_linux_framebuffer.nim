include windy/platforms/linux/native/framebuffer

proc checkPixels(bits: int, red, green, blue, alpha: Bitfield, rotation: int) =
  ## Compare packed scanout bytes with the generic converter, including padding.
  let
    image = newImage(31, 17)
    physicalWidth = if rotation in [90, 270]: image.height else: image.width
    physicalHeight = if rotation in [90, 270]: image.width else: image.height
    bytes = bits div 8
    stride = ((physicalWidth * bytes + 3) div 4 + 1) * 4
  var
    memory = newSeq[byte](stride * physicalHeight + 8)
    expected = newSeq[byte](memory.len)
  for index in 0 ..< memory.len:
    memory[index] = 0xa5
    expected[index] = 0xa5
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let
        pixel = rgbx(uint8(x * 8), uint8(y * 15), uint8((x + y) * 5), 127)
        packed = packPixel(rgb(pixel), red, green, blue, alpha)
        point = rotatedPoint(x, y, image.width, image.height, rotation)
        offset = 4 + point.y * stride + point.x * bytes
      image.data[y * image.width + x] = pixel
      for index in 0 ..< bytes:
        expected[offset + index] = byte((packed shr (index * 8)) and 255)
  let fb = Framebuffer(memory: addr memory[4], width: image.width,
    height: image.height, rotation: rotation, activated: true,
    variable: VariableInfo(bits_per_pixel: uint32(bits), red: red,
      green: green, blue: blue, transp: alpha),
    fixed: FixedInfo(line_length: uint32(stride)))
  fb.present(image)
  doAssert memory == expected

for rotation in [0, 90, 180, 270]:
  for redOffset in [0'u32, 16]:
    for alphaBits in [0'u32, 8]:
      checkPixels(32, Bitfield(offset: redOffset, length: 8),
        Bitfield(offset: 8, length: 8), Bitfield(offset: 16 - redOffset, length: 8),
        Bitfield(offset: 24, length: alphaBits), rotation)
  checkPixels(24, Bitfield(offset: 16, length: 8), Bitfield(offset: 8, length: 8),
    Bitfield(length: 8), Bitfield(), rotation)
  checkPixels(16, Bitfield(offset: 11, length: 5), Bitfield(offset: 5, length: 6),
    Bitfield(length: 5), Bitfield(), rotation)
