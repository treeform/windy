import os, posix, nativesockets, net, tables
import ../../../common

type
  Id* = distinct uint32

  Proxy* = ref object of RootObj
    display: Display
    id: Id

  Display* = ref object of Proxy
    onError*: proc(objId: Id, code: DisplayErrorCode, message: string)
    onDeleteId*: proc(id: Id)

    socket: Socket
    ids: Table[uint32, Proxy]
    lastId: Id
  
  DisplayErrorCode* {.pure.} = enum
    InvalidObject
    InvalidMethod
    NoMemory
    Implementation


proc `//>`[T: SomeInteger](a, b: T): T =
  ## div roundup
  (a + b - 1) div b

proc asSeq[A](x: A, B: type = uint8): seq[B] =
  if x.len == 0: return
  result = newSeq[B](A.sizeof //> B.sizeof)
  copyMem(result[0].addr, x.unsafeaddr, A.sizeof)

proc asSeq(s: string, T: type): seq[T] =
  if s.len == 0: return
  result = newSeq[T](s.len //> T.sizeof)
  copyMem(result[0].addr, s[0].unsafeaddr, s.len)

proc asSeq[A](x: openarray[A], B: type): seq[B] =
  if x.len == 0: return
  result = newSeq[B]((x.len * A.sizeof) //> B.sizeof)
  copyMem(result[0].addr, x[0].unsafeaddr, x.len * A.sizeof)

proc asString[T](x: openarray[T]): string =
  cast[string](x.asSeq(char))


proc connect*(name = getEnv("WAYLAND_SOCKET")): Display =
  new result, (proc(d: Display) = close d.socket)
  
  result.display = result
  result.id = Id 1
  result.lastId = Id 1
  result.ids[1] = result

  let d = result
  result.onDeleteId = proc(id: Id) =
    d.ids.del id.uint32
  
  var name =
    if name != "": $name
    else: "wayland-0"
  
  if not name.isAbsolute:
    var runtimeDir = getEnv("XDG_RUNTIME_DIR")
    if runtimeDir == "": raise WindyError.newException("XDG_RUNTIME_DIR not set in the environment")
    name = runtimeDir / name

  let sock = createNativeSocket(posix.AF_UNIX, posix.SOCK_STREAM or posix.SOCK_CLOEXEC, 0)
  if sock == osInvalidSocket: raise WindyError.newException("Failed to create socket")

  var a = "\1\0" & name
  
  if sock.connect(cast[ptr SockAddr](a[0].addr), uint32 name.len + 2) < 0:
    close sock
    raise WindyError.newException("Failed to connect to wayland server")
  
  result.socket = newSocket(sock, nativesockets.AF_UNIX, nativesockets.SOCK_STREAM, nativesockets.IPPROTO_IP)


proc new(d: Display, t: type): t =
  inc d.lastId
  new result
  result.display = d
  result.id = d.lastId
  d.ids[d.lastId.uint32] = result

proc extern(d: Display, t: type, id: Id): t =
  new result
  let id = Id id.uint32 or 0xff000000
  result.display = d
  result.id = id
  d.ids[id.uint32] = result

proc destroy*(d: Display, x: Proxy) =
  d.ids.del x.id.uint32


proc serialize[T](x: T): seq[uint32] =
  when x is uint32|int32|Id|enum|float32:
    result.add cast[uint32](x)

  elif x is string:
    let x = x & '\0'
    result.add x.len.uint32
    result.add x.asSeq(uint32)

  elif x is seq:
    type T = typeof(x[0])
    result.add (x.len * T.sizeof).uint32
    result.add x.asSeq(uint32)

  elif x is tuple|object:
    for x in x.fields:
      result.add x.serialize

  else: {.error.}


proc deserialize(x: seq[uint32], T: type, i: var uint32): T =
  when result is uint32|int32|Id|enum|float32:
    result = cast[T](x[i]); i += 1

  elif result is string:
    let len = x[i]; i += 1
    let lenAligned = len //> uint32.sizeof.uint32
    result = x[i ..< i + lenAligned].asString; i += lenAligned
    result.setLen len - 1

  elif result is seq:
    type T = typeof(x[0])
    let len = x[i]; i += 1
    let lenAligned = (len * T.sizeof) //> uint32.sizeof.uint32
    result = x[i ..< i + lenAligned].asSeq(T); i += lenAligned

  elif result is tuple|object:
    for v in result.fields:
      v = x.deserialize(typeof(v), i)

  else: {.error.}

proc deserialize(x: seq[uint32], T: type): T =
  var i: uint32
  deserialize(x, T, i)


proc marshal[T](x: Proxy, op: int, data: T) =
  var d = data.serialize
  d.insert ((d.len.uint32 * uint32.sizeof.uint32 + 8) shl 16) or (op.uint32 and 0x0000ffff)
  d.insert x.id.uint32
  assert x.display.socket.send(d[0].addr, d.len * uint32.sizeof) == d.len * uint32.sizeof

method unmarshal(x: Proxy, op: int, data: seq[uint32]) {.base, locks: "unknown".} = discard


proc pollNextEvent*(d: Display) =
  let head = d.socket.recv(2 * uint32.sizeof).asSeq(uint32)
  let id = head[0]
  let op = head[1] and 0xffff
  let len = int (head[1] shr 16)
  assert len >= 8

  let data = d.socket.recv(len - 8).asSeq(uint32)

  if not d.ids.hasKey id: return # event for destroyed object
  d.ids[id].unmarshal(op.int, data)
