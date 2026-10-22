import
  std/[os, posix],
  pixie,
  ../../../common,
  ./[framebuffer, pixels]

type
  Event {.importc: "struct input_event", header: "<linux/input.h>", bycopy.} = object
    time: Timeval
    kind {.importc: "type".}: uint16
    code: uint16
    value: int32
  Axis {.importc: "struct input_absinfo", header: "<linux/input.h>", bycopy.} = object
    value, minimum, maximum, fuzz, flat, resolution: int32
  Slot* = object
    id*, x*, y*: int32
  TouchReader* = ref object
    fd: cint
    path*: string
    minimumX*, maximumX*, minimumY*, maximumY*: int32
    slotMinimum, slot: int
    multitouch, dropped: bool
    pending*, previous*: seq[Slot]
    width*, height*, rotation*: int

proc getAxis(code: cint): culong {.importc: "EVIOCGABS", header: "<linux/input.h>".}
proc getSlots(length: cint): culong {.importc: "EVIOCGMTSLOTS", header: "<linux/input.h>".}
proc getKeys(length: cint): culong {.importc: "EVIOCGKEY", header: "<linux/input.h>".}
proc getBits(kind, length: cint): culong {.importc: "EVIOCGBIT", header: "<linux/input.h>".}

proc contact(reader: TouchReader, slot: Slot): TouchContact =
  let
    rawWidth = if reader.rotation in [90, 270]: reader.height else: reader.width
    rawHeight = if reader.rotation in [90, 270]: reader.width else: reader.height
    x = int((int64(clamp(slot.x, reader.minimumX, reader.maximumX)) - reader.minimumX) *
      (rawWidth - 1) div (int64(reader.maximumX) - reader.minimumX))
    y = int((int64(clamp(slot.y, reader.minimumY, reader.maximumY)) - reader.minimumY) *
      (rawHeight - 1) div (int64(reader.maximumY) - reader.minimumY))
    point = rotatedPoint(x, y, rawWidth, rawHeight, reader.rotation)
  TouchContact(id: slot.id, position: vec2(point.x.float32, point.y.float32))

proc report*(reader: TouchReader): seq[TouchEvent] =
  ## Publish a coherent report, ending replaced contacts before beginning new ones.
  for index, old in reader.previous:
    let current = reader.pending[index]
    if old.id >= 0 and old.id != current.id:
      result.add TouchEvent(contact: reader.contact(old), phase: TouchEnd)
  for index, current in reader.pending:
    let old = reader.previous[index]
    if current.id >= 0:
      if old.id != current.id:
        result.add TouchEvent(contact: reader.contact(current), phase: TouchBegin)
      elif old.x != current.x or old.y != current.y:
        result.add TouchEvent(contact: reader.contact(current), phase: TouchMove)
  reader.previous = reader.pending

proc cancel*(reader: TouchReader): seq[TouchEvent] =
  for old in reader.previous:
    if old.id >= 0:
      result.add TouchEvent(contact: reader.contact(old), phase: TouchCancel)
  for slot in reader.pending.mitems:
    slot.id = -1
  reader.previous = reader.pending

proc resync(reader: TouchReader) =
  if reader.multitouch:
    var axis: Axis
    if deviceIoctl(reader.fd, getAxis(47), addr axis) < 0:
      raiseOSError(osLastError(), reader.path)
    reader.slot = int(axis.value) - reader.slotMinimum
    for code in [57'i32, 53, 54]:
      var values = newSeq[int32](reader.pending.len + 1)
      values[0] = code
      if deviceIoctl(reader.fd, getSlots(cint(values.len * sizeof(int32))), addr values[0]) < 0:
        raiseOSError(osLastError(), reader.path)
      for index in 0 ..< reader.pending.len:
        case code
        of 57: reader.pending[index].id = values[index + 1]
        of 53: reader.pending[index].x = values[index + 1]
        of 54: reader.pending[index].y = values[index + 1]
        else: discard
  else:
    var
      keys: array[96, byte]
      x, y: Axis
    if deviceIoctl(reader.fd, getKeys(cint(keys.len)), addr keys[0]) < 0 or
        deviceIoctl(reader.fd, getAxis(0), addr x) < 0 or
        deviceIoctl(reader.fd, getAxis(1), addr y) < 0:
      raiseOSError(osLastError(), reader.path)
    reader.pending[0] = Slot(id: (if (keys[330 div 8] and (1'u8 shl (330 mod 8))) != 0: 0'i32 else: -1'i32),
      x: x.value, y: y.value)

proc close*(reader: TouchReader) =
  if reader.fd >= 0:
    let fd = reader.fd
    reader.fd = -1
    if posix.close(fd) < 0:
      raiseOSError(osLastError(), reader.path)

proc openTouch*(path: string, width, height, rotation: int): TouchReader =
  discard rotatedPoint(0, 0, width, height, rotation)
  result = TouchReader(fd: -1, path: path, width: width, height: height, rotation: rotation)
  result.fd = posix.open(path.cstring, O_RDONLY or O_NONBLOCK or O_CLOEXEC)
  if result.fd < 0:
    raiseOSError(osLastError(), path)
  try:
    var
      bits: array[8, byte]
      slots, x, y: Axis
    if deviceIoctl(result.fd, getBits(3, cint(bits.len)), addr bits[0]) < 0:
      raiseOSError(osLastError(), path)
    result.multitouch = (bits[47 div 8] and (1'u8 shl (47 mod 8))) != 0
    if result.multitouch:
      if deviceIoctl(result.fd, getAxis(47), addr slots) < 0:
        raiseOSError(osLastError(), path)
      result.slotMinimum = int(slots.minimum)
    let
      count = if result.multitouch: int(slots.maximum - slots.minimum + 1) else: 1
      xCode = if result.multitouch: 53 else: 0
      yCode = if result.multitouch: 54 else: 1
    if count notin 1 .. 32:
      raise newException(WindyError, "Unsupported touch slot count")
    if deviceIoctl(result.fd, getAxis(cint(xCode)), addr x) < 0 or
        deviceIoctl(result.fd, getAxis(cint(yCode)), addr y) < 0:
      raiseOSError(osLastError(), path)
    if x.maximum <= x.minimum or y.maximum <= y.minimum:
      raise newException(WindyError, "Invalid touchscreen coordinate ranges")
    result.minimumX = x.minimum
    result.maximumX = x.maximum
    result.minimumY = y.minimum
    result.maximumY = y.maximum
    result.pending = newSeq[Slot](count)
    for slot in result.pending.mitems:
      slot.id = -1
    result.previous = result.pending
    result.resync()
  except:
    result.close()
    raise

proc poll*(reader: TouchReader): seq[TouchEvent] =
  if reader.fd < 0:
    return
  result = reader.report()
  while true:
    var event: Event
    let count = posix.read(reader.fd, addr event, sizeof(event))
    if count < 0:
      let error = osLastError()
      if error == OSErrorCode(EAGAIN): break
      if error == OSErrorCode(EINTR): continue
      if error == OSErrorCode(ENODEV):
        result.add reader.cancel()
        reader.close()
        break
      raiseOSError(error, reader.path)
    if count == 0:
      result.add reader.cancel()
      reader.close()
      break
    if count != sizeof(event):
      raise newException(WindyError, "Incomplete touchscreen event")
    if event.kind == 0 and event.code == 3:
      result.add reader.cancel()
      reader.dropped = true
    elif reader.dropped:
      if event.kind == 0 and event.code == 0:
        reader.resync()
        reader.dropped = false
        result.add reader.report()
    elif event.kind == 0 and event.code == 0:
      result.add reader.report()
    elif event.kind == 3:
      if event.code == 47 and reader.multitouch:
        let slot = int(event.value) - reader.slotMinimum
        if slot notin 0 ..< reader.pending.len:
          raise newException(WindyError, "Invalid touchscreen slot")
        reader.slot = slot
      elif reader.slot in 0 ..< reader.pending.len:
        case event.code
        of 57: reader.pending[reader.slot].id = event.value
        of 53: reader.pending[reader.slot].x = event.value
        of 54: reader.pending[reader.slot].y = event.value
        of 0:
          if not reader.multitouch: reader.pending[0].x = event.value
        of 1:
          if not reader.multitouch: reader.pending[0].y = event.value
        else: discard
    elif event.kind == 1 and event.code == 330 and not reader.multitouch:
      reader.pending[0].id = if event.value == 0: -1 else: 0
