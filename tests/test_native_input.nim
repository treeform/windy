import
  pixie,
  windy/common,
  windy/platforms/linux/native/[touch, pixels, framebuffer, drm]

block:
  let reader = TouchReader(width: 1024, height: 768,
    minimumX: 100, maximumX: 1100, minimumY: 50, maximumY: 1050,
    pending: @[Slot(id: -1), Slot(id: -1)], previous: @[Slot(id: -1), Slot(id: -1)])
  reader.pending[0] = Slot(id: 7, x: 100, y: 50)
  reader.pending[1] = Slot(id: 9, x: 1100, y: 1050)
  let began = reader.report()
  doAssert began.len == 2
  doAssert began[0].phase == TouchBegin and began[0].contact.id == 7
  doAssert began[0].contact.position == vec2(0, 0)
  doAssert began[1].contact.position == vec2(1023, 767)
  doAssert reader.report().len == 0
  reader.pending[0].x = 600
  let moved = reader.report()
  doAssert moved.len == 1 and moved[0].phase == TouchMove
  doAssert moved[0].contact.id == 7 and moved[0].contact.position.x == 511
  reader.pending[0].id = 11
  let replaced = reader.report()
  doAssert replaced.len == 2
  doAssert replaced[0].phase == TouchEnd and replaced[0].contact.id == 7
  doAssert replaced[1].phase == TouchBegin and replaced[1].contact.id == 11
  let cancelled = reader.cancel()
  doAssert cancelled.len == 2
  for event in cancelled: doAssert event.phase == TouchCancel
  doAssert reader.cancel().len == 0
  doAssert reader.report().len == 0

block:
  for rotation in [0, 90, 180, 270]:
    let reader = TouchReader(width: 4, height: 3, maximumX: 100, maximumY: 100,
      rotation: rotation, pending: @[Slot(id: 1)], previous: @[Slot(id: -1)])
    let expected = case rotation
      of 0: vec2(0, 0)
      of 90: vec2(3, 0)
      of 180: vec2(3, 2)
      else: vec2(0, 2)
    doAssert reader.report()[0].contact.position == expected

block:
  doAssert rgb(rgbx(255, 0, 0, 255)) == 0xff0000'u32
  doAssert rgb(rgbx(0, 255, 0, 255)) == 0x00ff00'u32
  doAssert rgb(rgbx(0, 0, 255, 255)) == 0x0000ff'u32
  doAssert packPixel(0xffffff, Bitfield(offset: 11, length: 5),
    Bitfield(offset: 5, length: 6), Bitfield(length: 5), Bitfield()) == 0xffff
  doAssert chooseCrtc([90'u32, 110, 130], 130, 5, []) == 130
  doAssert chooseCrtc([90'u32, 110, 130], 0, 5, [90'u32]) == 130

block:
  var rejected = false
  try:
    discard openTouch("/dev/null", 20, 20, 0)
  except OSError:
    rejected = true
  doAssert rejected
