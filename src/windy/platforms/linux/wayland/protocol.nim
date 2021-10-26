include basic

type
  Registry* = ref object of Proxy
    onGlobal*: proc(name: Id, iface: string, version: uint32)
    onGlobalRemove*: proc(name: Id)

  Callback* = ref object of Proxy
    onDone*: proc(cbData: uint32)


template d: Display = x.display


proc sync*(x: Display): Callback =
  result = d.new(Callback)
  x.marshal(0, result.id)

proc registry*(x: Display): Registry =
  result = d.new(Registry)
  x.marshal(1, result.id)

method unmarshal(x: Display, op: int, data: seq[uint32]) =
  case op
  of 0:
    let (objId, code, message) = data.deserialize((Id, DisplayErrorCode, string))
    if x.onError != nil: x.onError(objId, code, message)
  of 1:
    let id = data.deserialize(Id)
    if x.onDeleteId != nil: x.onDeleteId(id)
  else: discard


proc bindInterface*[T: Proxy](x: Registry, name: Id, iface: string, version: uint32): T =
  result = d.extern(T, name)
  d.marshal(0, (name, iface, version))

method unmarshal(x: Registry, op: int, data: seq[uint32]) =
  case op
  of 0:
    let (name, iface, version) = data.deserialize((Id, string, uint32))
    if x.onGlobal != nil: x.onGlobal(name, iface, version)
  of 1:
    let name = data.deserialize(Id)
    if x.onGlobalRemove != nil: x.onGlobalRemove(name)
  else: discard


when isMainModule:
  let display = connect()
  display.onError = proc(objId: Id, code: DisplayErrorCode, message: string) =
    echo "Error for ", objId.uint32, ": ", code, ", ", message
  
  let reg = display.registry
  reg.onGlobal = proc(name: Id, iface: string, version: uint32) =
    echo (id: name.uint32, iface: iface, version: version)
  
  display.pollEvents
