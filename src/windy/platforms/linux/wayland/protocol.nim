include basic

type
  Registry* = ref object of Proxy
    onGlobal*: proc(name: Id, iface: string, version: uint32): Future[void]
    onGlobalRemove*: proc(name: Id): Future[void]

  Callback* = ref object of Proxy
    onDone*: proc(cbData: uint32): Future[void]


template d: Display = x.display


proc sync*(x: Display): Future[Callback] {.async.} =
  result = d.new(Callback)
  await x.marshal(0, result.id)

proc registry*(x: Display): Future[Registry] {.async.} =
  result = d.new(Registry)
  await x.marshal(1, result.id)

method unmarshal(x: Display, op: int, data: seq[uint32]) {.async.} =
  case op
  of 0:
    let (objId, code, message) = data.deserialize((Id, DisplayErrorCode, string))
    if x.onError != nil: await x.onError(objId, code, message)
  of 1:
    let id = data.deserialize(Id)
    if x.onDeleteId != nil: await x.onDeleteId(id)
  else: discard


proc bindInterface*[T: Proxy](x: Registry, name: Id, iface: string, version: uint32): Future[T] {.async.} =
  result = d.extern(T, name)
  await d.marshal(0, (name, iface, version))

method unmarshal(x: Registry, op: int, data: seq[uint32]) {.async.} =
  case op
  of 0:
    let (name, iface, version) = data.deserialize((Id, string, uint32))
    if x.onGlobal != nil: await x.onGlobal(name, iface, version)
  of 1:
    let name = data.deserialize(Id)
    if x.onGlobalRemove != nil: await x.onGlobalRemove(name)
  else: discard


when isMainModule:
  let display = connect()
  display.onError = proc(objId: Id, code: DisplayErrorCode, message: string) {.async.} =
    echo "Error for ", objId.uint32, ": ", code, ", ", message
  let reg = display.registry.waitFor
  reg.onGlobal = proc(name: Id, iface: string, version: uint32) {.async.} =
    echo (id: name.uint32, iface: iface, version: version)
  waitFor listen display
