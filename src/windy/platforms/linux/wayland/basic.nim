import locks, os, nativesockets

type
  WaylandError* = object of CatchableError

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
    socket: SocketHandle
    lock: Lock


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


proc connect*(name = getEnv("WAYLAND_SOCKET")): Display =
  new result
  initLock result.lock
  
  var name =
    if name != "": $name
    else: "wayland-0"
  
  if not name.isAbsolute:
    var runtimeDir = getEnv("XDG_RUNTIME_DIR")
    if runtimeDir == "": raise WaylandError.newException("XDG_RUNTIME_DIR not set in the environment")
    name = runtimeDir / name
  
  result.socket = createNativeSocket(1, 2000001, 0)
  if result.socket == osInvalidSocket: raise WaylandError.newException("can't create socket")

  var a = cast[string](@[1.uint16]) & name
  
  if result.socket.bindAddr(cast[ptr SockAddr](a[0].addr), uint32 a.len + 1) < 0:
    close result.socket
    raise WaylandError.newException("can't bind socket address")
  
  result.iface = displayInterface
  result.display = result
  result.version = 1
  