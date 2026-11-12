import
  std/dynlib,
  ../../../../common

type
  Connection* = ptr object
  Message* = ptr object
  Iter* = object
    # Public libdbus iterator storage; pointer-sized fields preserve the C ABI.
    dummy1, dummy2: pointer
    dummy3: uint32
    dummy4, dummy5, dummy6, dummy7, dummy8, dummy9, dummy10, dummy11: cint
    pad1: cint
    pad2, pad3: pointer

var
  library: LibHandle
  busGetPrivate*: proc(kind: cint, error: pointer): Connection {.cdecl.}
  busAddMatch*: proc(c: Connection, rule: cstring, error: pointer) {.cdecl.}
  connectionSetExitOnDisconnect*: proc(c: Connection, enabled: uint32) {.cdecl.}
  connectionReadWrite*: proc(c: Connection, timeout: cint): uint32 {.cdecl.}
  connectionPopMessage*: proc(c: Connection): Message {.cdecl.}
  connectionSend*: proc(c: Connection, m: Message, serial: ptr uint32): uint32 {.cdecl.}
  connectionClose*: proc(c: Connection) {.cdecl.}
  connectionUnref*: proc(c: Connection) {.cdecl.}
  messageNewMethodCall*: proc(dest, path, iface, name: cstring): Message {.cdecl.}
  messageNewMethodReturn*: proc(m: Message): Message {.cdecl.}
  messageNewError*: proc(m: Message, name, text: cstring): Message {.cdecl.}
  messageNewSignal*: proc(path, iface, name: cstring): Message {.cdecl.}
  messageUnref*: proc(m: Message) {.cdecl.}
  messageGetType*: proc(m: Message): cint {.cdecl.}
  messageGetReplySerial*: proc(m: Message): uint32 {.cdecl.}
  messageGetPath*: proc(m: Message): cstring {.cdecl.}
  messageGetInterface*: proc(m: Message): cstring {.cdecl.}
  messageGetMember*: proc(m: Message): cstring {.cdecl.}
  messageGetSender*: proc(m: Message): cstring {.cdecl.}
  messageGetSignature*: proc(m: Message): cstring {.cdecl.}
  messageIterInitAppend*: proc(m: Message, i: ptr Iter) {.cdecl.}
  messageIterInit*: proc(m: Message, i: ptr Iter): uint32 {.cdecl.}
  messageIterGetArgType*: proc(i: ptr Iter): cint {.cdecl.}
  messageIterGetBasic*: proc(i: ptr Iter, value: pointer) {.cdecl.}
  messageIterNext*: proc(i: ptr Iter): uint32 {.cdecl.}
  messageIterRecurse*: proc(i, child: ptr Iter) {.cdecl.}
  messageIterAppendBasic*: proc(i: ptr Iter, kind: cint, value: pointer): uint32 {.cdecl.}
  messageIterOpenContainer*: proc(i: ptr Iter, kind: cint, signature: cstring, child: ptr Iter): uint32 {.cdecl.}
  messageIterCloseContainer*: proc(i, child: ptr Iter): uint32 {.cdecl.}
  messageIterAbandonContainer*: proc(i, child: ptr Iter) {.cdecl.}

proc loadDbus*(): bool =
  ## Loads the optional runtime library without requiring development headers.
  if library != nil:
    return true
  let handle = loadLib("libdbus-1.so.3")
  if handle == nil:
    return false
  template bindProc(name: untyped, symbol: string) =
    name = cast[typeof(name)](symAddr(handle, symbol))
    if name == nil:
      unloadLib(handle)
      return false
  bindProc(busGetPrivate, "dbus_bus_get_private")
  bindProc(busAddMatch, "dbus_bus_add_match")
  bindProc(connectionSetExitOnDisconnect, "dbus_connection_set_exit_on_disconnect")
  bindProc(connectionReadWrite, "dbus_connection_read_write")
  bindProc(connectionPopMessage, "dbus_connection_pop_message")
  bindProc(connectionSend, "dbus_connection_send")
  bindProc(connectionClose, "dbus_connection_close")
  bindProc(connectionUnref, "dbus_connection_unref")
  bindProc(messageNewMethodCall, "dbus_message_new_method_call")
  bindProc(messageNewMethodReturn, "dbus_message_new_method_return")
  bindProc(messageNewError, "dbus_message_new_error")
  bindProc(messageNewSignal, "dbus_message_new_signal")
  bindProc(messageUnref, "dbus_message_unref")
  bindProc(messageGetType, "dbus_message_get_type")
  bindProc(messageGetReplySerial, "dbus_message_get_reply_serial")
  bindProc(messageGetPath, "dbus_message_get_path")
  bindProc(messageGetInterface, "dbus_message_get_interface")
  bindProc(messageGetMember, "dbus_message_get_member")
  bindProc(messageGetSender, "dbus_message_get_sender")
  bindProc(messageGetSignature, "dbus_message_get_signature")
  bindProc(messageIterInitAppend, "dbus_message_iter_init_append")
  bindProc(messageIterInit, "dbus_message_iter_init")
  bindProc(messageIterGetArgType, "dbus_message_iter_get_arg_type")
  bindProc(messageIterGetBasic, "dbus_message_iter_get_basic")
  bindProc(messageIterNext, "dbus_message_iter_next")
  bindProc(messageIterRecurse, "dbus_message_iter_recurse")
  bindProc(messageIterAppendBasic, "dbus_message_iter_append_basic")
  bindProc(messageIterOpenContainer, "dbus_message_iter_open_container")
  bindProc(messageIterCloseContainer, "dbus_message_iter_close_container")
  bindProc(messageIterAbandonContainer, "dbus_message_iter_abandon_container")
  library = handle
  true

proc checked*(ok: uint32) =
  ## Turns allocation failures into a Nim exception before using an invalid message.
  if ok == 0:
    raise newException(WindyError, "Unable to allocate D-Bus message storage")

proc requireMessage*(m: Message): Message =
  ## Checks message allocation before dereferencing the native pointer.
  if m == nil:
    raise newException(WindyError, "Unable to allocate D-Bus message")
  m

proc writer*(m: Message): Iter =
  ## Creates an append iterator for a message.
  messageIterInitAppend(m, result.addr)

proc reader*(m: Message): Iter =
  ## Creates a read iterator, including for an empty message.
  discard messageIterInit(m, result.addr)

proc addString*(i: var Iter, value: string, kind = 's') =
  ## Appends a string, object path, or signature.
  var value = value.cstring
  checked messageIterAppendBasic(i.addr, kind.cint, value.addr)

proc addInt*(i: var Iter, value: int32) =
  ## Appends a signed 32-bit integer.
  var value = value
  checked messageIterAppendBasic(i.addr, 'i'.cint, value.addr)

proc addUint*(i: var Iter, value: uint32) =
  ## Appends an unsigned 32-bit integer.
  var value = value
  checked messageIterAppendBasic(i.addr, 'u'.cint, value.addr)

proc addBool*(i: var Iter, value: bool) =
  ## Appends the 32-bit D-Bus boolean representation.
  var value = uint32(value)
  checked messageIterAppendBasic(i.addr, 'b'.cint, value.addr)

proc addByte*(i: var Iter, value: uint8) =
  ## Appends one byte.
  var value = value
  checked messageIterAppendBasic(i.addr, 'y'.cint, value.addr)

template container*(parent: var Iter, kind: char, signature: cstring,
    child: untyped, body: untyped) =
  block:
    var child: Iter
    checked messageIterOpenContainer(parent.addr, kind.cint, signature, child.addr)
    try:
      body
    except:
      messageIterAbandonContainer(parent.addr, child.addr)
      raise
    checked messageIterCloseContainer(parent.addr, child.addr)

proc stringValue*(i: var Iter): string =
  ## Reads a string only after verifying its native type.
  if messageIterGetArgType(i.addr) notin ['s'.cint, 'o'.cint, 'g'.cint]:
    return
  var value: cstring
  messageIterGetBasic(i.addr, value.addr)
  $value

proc intValue*(i: var Iter): int32 =
  ## Reads a signed integer from a validated argument.
  if messageIterGetArgType(i.addr) == 'i'.cint:
    messageIterGetBasic(i.addr, result.addr)

proc next*(i: var Iter) =
  ## Advances to the next argument.
  discard messageIterNext(i.addr)

proc recurse*(i: var Iter): Iter =
  ## Opens a container for reading after its type has been checked.
  if messageIterGetArgType(i.addr) in ['a'.cint, 'r'.cint, 'v'.cint, 'e'.cint]:
    messageIterRecurse(i.addr, result.addr)

proc send*(c: Connection, m: Message): uint32 =
  ## Queues a message and releases its reference without blocking on a reply.
  discard requireMessage(m)
  defer: messageUnref(m)
  checked connectionSend(c, m, result.addr)
