import
  std/[os, posix, strformat],
  pixie,
  ./pixels

type
  Bitfield* {.importc: "struct fb_bitfield", header: "<linux/fb.h>", bycopy.} = object
    offset*, length*, msb_right*: uint32
  VariableInfo {.importc: "struct fb_var_screeninfo", header: "<linux/fb.h>", bycopy.} = object
    xres, yres, xres_virtual, yres_virtual, xoffset, yoffset: uint32
    bits_per_pixel, grayscale: uint32
    red, green, blue, transp: Bitfield
    nonstd, activate, height, width, accel_flags: uint32
    pixclock, left_margin, right_margin, upper_margin, lower_margin: uint32
    hsync_len, vsync_len, sync, vmode, rotate, colorspace: uint32
    reserved: array[4, uint32]
  FixedInfo {.importc: "struct fb_fix_screeninfo", header: "<linux/fb.h>", bycopy.} = object
    id: array[16, char]
    smem_start: culong
    smem_len, `type`, type_aux, visual: uint32
    xpanstep, ypanstep, ywrapstep: uint16
    line_length: uint32
    mmio_start: culong
    mmio_len, accel: uint32
    capabilities: uint16
    reserved: array[2, uint16]
  Framebuffer* = ref object
    fd: cint
    variable, original: VariableInfo
    fixed: FixedInfo
    memory: pointer
    saved: seq[byte]
    length: int
    activated, touched: bool
    rotation*: int
    width*, height*: int

const
  GetVariable = 0x4600.culong
  PutVariable = 0x4601.culong
  GetFixed = 0x4602.culong
  PanDisplay = 0x4606.culong
  Blank = 0x4611.culong
  ActivateForce = 128'u32

proc deviceIoctl*(fd: cint, request: culong, argument: pointer): cint {.importc: "ioctl", header: "<sys/ioctl.h>".}

proc packPixel*(color: uint32, red, green, blue, alpha: Bitfield): uint32 =
  for (value, channel) in [(color shr 16 and 255, red),
      (color shr 8 and 255, green), (color and 255, blue), (255'u32, alpha)]:
    if channel.length > 0:
      if channel.length > 8 or channel.offset + channel.length > 32 or channel.msb_right != 0:
        raise newException(ValueError, "Unsupported framebuffer channel layout")
      let maximum = (1'u32 shl channel.length) - 1
      result = result or ((value * maximum + 127) div 255 shl channel.offset)

proc checkedIoctl(fd: cint, request: culong, argument: pointer) =
  if deviceIoctl(fd, request, argument) < 0:
    raiseOSError(osLastError())

proc openFramebuffer*(path: string, rotation = 0): Framebuffer =
  if rotation notin [0, 90, 180, 270]:
    raise newException(ValueError, "Rotation must be 0, 90, 180 or 270")
  result = Framebuffer(fd: -1, rotation: rotation)
  result.fd = posix.open(path.cstring, O_RDWR or O_CLOEXEC)
  if result.fd < 0:
    raiseOSError(osLastError(), path)
  try:
    checkedIoctl(result.fd, GetVariable, addr result.variable)
    checkedIoctl(result.fd, GetFixed, addr result.fixed)
    result.original = result.variable
    if result.variable.bits_per_pixel notin [16'u32, 24, 32] or
        result.variable.grayscale != 0 or result.fixed.`type` != 0 or result.fixed.visual != 2:
      raise newException(ValueError, "Expected a packed truecolor framebuffer")
    let
      width = int(result.variable.xres)
      height = int(result.variable.yres)
      stride = int(result.fixed.line_length)
      pixelBytes = int(result.variable.bits_per_pixel div 8)
    if width notin 1..8192 or height notin 1..8192 or
        stride < width * pixelBytes or stride > 131072:
      raise newException(ValueError, "Invalid framebuffer geometry")
    result.length = int(result.fixed.smem_len)
    if result.length < stride * height or result.length > 256 * 1024 * 1024:
      raise newException(ValueError, "Invalid framebuffer memory size")
    discard packPixel(0xffffff'u32, result.variable.red, result.variable.green,
      result.variable.blue, result.variable.transp)
    result.width = if rotation in [90, 270]: height else: width
    result.height = if rotation in [90, 270]: width else: height
    result.memory = mmap(nil, result.length, PROT_READ or PROT_WRITE, MAP_SHARED, result.fd, 0)
    if result.memory == MAP_FAILED:
      result.memory = nil
      raiseOSError(osLastError(), "Mapping framebuffer")
    result.saved = newSeq[byte](result.length)
    copyMem(addr result.saved[0], result.memory, result.length)
  except:
    if result.memory != nil:
      discard munmap(result.memory, result.length)
    discard posix.close(result.fd)
    raise

proc describe*(fb: Framebuffer): string =
  let v = fb.variable
  &"{v.xres}x{v.yres} visible, {v.xres_virtual}x{v.yres_virtual} virtual, " &
    &"{v.bits_per_pixel}bpp, stride={fb.fixed.line_length}, offsets={v.xoffset},{v.yoffset}, " &
    &"RGB={v.red.offset}:{v.red.length}/{v.green.offset}:{v.green.length}/{v.blue.offset}:{v.blue.length}"

proc present*(fb: Framebuffer, image: Image) =
  if image.width != fb.width or image.height != fb.height:
    raise newException(ValueError, "Canvas dimensions differ from framebuffer")
  let
    destination = cast[ptr UncheckedArray[byte]](fb.memory)
    bytesPerPixel = int(fb.variable.bits_per_pixel div 8)
    stride = int(fb.fixed.line_length)
  fb.touched = true
  for y in 0 ..< image.height:
    for x in 0 ..< image.width:
      let
        point = rotatedPoint(x, y, image.width, image.height, fb.rotation)
        offset = point.y * stride + point.x * bytesPerPixel
        pixel = packPixel(rgb(image.data[y * image.width + x]), fb.variable.red,
          fb.variable.green, fb.variable.blue, fb.variable.transp)
      for index in 0 ..< bytesPerPixel:
        destination[offset + index] = byte((pixel shr (index * 8)) and 255)
  if not fb.activated:
    fb.variable.xoffset = 0
    fb.variable.yoffset = 0
    if deviceIoctl(fb.fd, PanDisplay, addr fb.variable) < 0:
      fb.variable.activate = ActivateForce
      checkedIoctl(fb.fd, PutVariable, addr fb.variable)
    checkedIoctl(fb.fd, Blank, nil)
    fb.activated = true

proc close*(fb: Framebuffer) =
  if fb.memory != nil:
    var restoreResult = 0.cint
    if fb.touched:
      copyMem(fb.memory, addr fb.saved[0], fb.length)
    if fb.activated:
      restoreResult = deviceIoctl(fb.fd, PanDisplay, addr fb.original)
      if restoreResult < 0:
        restoreResult = deviceIoctl(fb.fd, PutVariable, addr fb.original)
    let unmapResult = munmap(fb.memory, fb.length)
    fb.memory = nil
    let closeResult = posix.close(fb.fd)
    fb.fd = -1
    if restoreResult < 0 or unmapResult < 0 or closeResult < 0:
      raise newException(IOError, "Unable to completely restore/close framebuffer")
