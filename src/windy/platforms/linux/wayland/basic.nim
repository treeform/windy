import os, posix, nativesockets, asyncnet, asyncdispatch
import ../../../common

type
  Proxy* = ref object of RootObj
    display: Display
    version: int
    id: Id

  Display* = ref object of Proxy
    socket: AsyncSocket
    lastId: Id

  Registry* = ref object of Proxy

  Id = distinct uint32


proc asSeq[A](x: A, B: type = uint8): seq[B] =
  if x.len == 0: return
  result = newSeq[B]((A.sizeof + B.sizeof - 1) div B.sizeof)
  copyMem(result[0].addr, x.unsafeaddr, A.sizeof)

proc asSeq(s: string, T: type = uint8): seq[T] =
  if s.len == 0: return
  result = newSeq[T]((s.len + T.sizeof - 1) div T.sizeof)
  copyMem(result[0].addr, s[0].unsafeaddr, s.len)

proc asSeq[A](x: seq[A], B: type = uint8): seq[B] =
  if x.len == 0: return
  result = newSeq[B]((x.len * A.sizeof + B.sizeof - 1) div B.sizeof)
  copyMem(result[0].addr, x[0].unsafeaddr, x.len * A.sizeof)


proc openLocalSocket: SocketHandle =
  const
    localDomain = posix.AF_UNIX
    stream = posix.SOCK_STREAM
    closeex = posix.SOCK_CLOEXEC
    einval = 22

  result = createNativeSocket(localDomain, stream or closeex, 0)
  if result != osInvalidSocket: return

  var errno {.importc.}: cint
  if errno == einval: raise WindyError.newException("Failed to create socket")

  result = createNativeSocket(localDomain, stream, 0)
  if result == osInvalidSocket: raise WindyError.newException("Failed to create socket")

  let flags = fcntl(result.cint, F_GETFD)
  if flags == -1: 
    close result
    raise WindyError.newException("Failed to create socket")
  
  if fcntl(result.cint, F_SETFD, flags or FD_CLOEXEC) == -1: 
    close result
    raise WindyError.newException("Failed to create socket")


proc connect*(name = getEnv("WAYLAND_SOCKET")): Display =
  new result, (proc(d: Display) = close d.socket)
  
  result.display = result
  
  var name =
    if name != "": $name
    else: "wayland-0"
  
  if not name.isAbsolute:
    var runtimeDir = getEnv("XDG_RUNTIME_DIR")
    if runtimeDir == "": raise WindyError.newException("XDG_RUNTIME_DIR not set in the environment")
    name = runtimeDir / name

  let sock = openLocalSocket()
  var a = "\1\0" & name
  
  if sock.connect(cast[ptr SockAddr](a[0].addr), uint32 name.len + 2) < 0:
    close sock
    raise WindyError.newException("Failed to connect to wayland server")
  
  register sock.AsyncFD
  result.socket = newAsyncSocket(sock.AsyncFD, nativesockets.AF_UNIX, nativesockets.SOCK_STREAM, nativesockets.IPPROTO_IP)


template sock: AsyncSocket = this.display.socket

proc newId(d: Display): Id =
  inc d.lastId
  d.lastId


proc serialize[T](x: T): seq[uint32] =
  when x is uint32|int32|Id:
    result.add cast[uint32](x)
  elif x is string:
    let x = x & '\0'
    result.add x.len
    result.add x.asSeq(uint32)
  elif x is seq:
    type T = typeof(x[0])
    result.add x.len * T.sizeof
    result.add x.asSeq(uint32)
  elif x is tuple|object:
    for x in x.fields:
      result.add x.serialize
  elif x is ref|ptr:
    {.error: "cannot serialize non-value object".}
  else:
    result.add x.asSeq(uint32)


proc marshal[T](this: Proxy, op: int, data: T) {.async.} =
  var d = data.serialize
  d = @[this.id.uint32, (d.len.uint32 shl 16) or (op.uint32 and 0x0000ffff)] & data.serialize
  await sock.send(d[0].addr, d.len * uint32.sizeof)


proc registry*(d: Display): Future[Registry] {.async.} =
  result = Registry(display: d, id: d.newId)
  await d.marshal(1, result.id)
