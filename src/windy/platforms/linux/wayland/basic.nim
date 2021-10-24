import locks, os, nativesockets, net, posix
import ../../../common

type
  Interface* = ref object
    name: string
    version: int
    methods: seq[Message]
    events: seq[Message]
  
  Message* = object
    name: string
    signature: string
    types: Interface

  Proxy* = ref object of RootObj
    iface: Interface
    version: int
    id: int
    display: Display
    flags: uint32
    impl: pointer

  Display* = ref object of Proxy
    socket: Socket
    lock: Lock

  Registry* = ref object of Proxy


let
  callbackInterface = Interface(
    name: "wl_callback", version: 1,
    events: @[
      Message(name: "done", signature: "u", types: nil),
    ]
  )

  registryInterface = Interface(
    name: "wl_registry", version: 1,
    methods: @[
      Message(name: "bind", signature: "usun", types: nil),
    ],
    events: @[
      Message(name: "global", signature: "usu", types: nil),
      Message(name: "global_remove", signature: "u", types: nil),
    ]
  )

  displayInterface = Interface(
    name: "wl_display", version: 1,
    methods: @[
      Message(name: "sync", signature: "n", types: callbackInterface),
      Message(name: "get_registry", signature: "n", types: registryInterface),
    ],
    events: @[
      Message(name: "error", signature: "ous", types: nil),
      Message(name: "delete_id", signature: "u", types: nil),
    ]
  )


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
  initLock result.lock
  
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
  
  result.socket = newSocket(sock, nativesockets.AF_UNIX, nativesockets.SOCK_STREAM, nativesockets.IPPROTO_IP)
  
  result.iface = displayInterface
  result.display = result
  result.version = 1
