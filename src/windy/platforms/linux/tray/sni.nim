import
  std/[monotimes, os, strutils, times, unicode],
  pixie,
  ../../../common,
  ./state,
  ./sni/dbus

type
  SniTray* = ref object
    connection: Connection
    state: TrayState
    owner: string
    querySerial, ownerSerial, registerSerial: uint32
    hostAvailable*, registered*: bool
    selecting*: bool
    deadline: MonoTime
    blockedOwner: string
    failedOwner*: string

const
  Watcher = "org.kde.StatusNotifierWatcher"
  WatcherPath = "/StatusNotifierWatcher"
  Item = "org.kde.StatusNotifierItem"
  ItemPath = "/StatusNotifierItem"
  Menu = "com.canonical.dbusmenu"
  MenuPath = "/Menu"
  ReplyTimeoutSeconds = 2
  EventBatchSize = 64
  Properties = "org.freedesktop.DBus.Properties"
  ItemProperties = [
    ("Category", "s"), ("Id", "s"), ("Title", "s"), ("Status", "s"),
    ("WindowId", "u"), ("IconName", "s"), ("IconPixmap", "a(iiay)"),
    ("OverlayIconName", "s"), ("OverlayIconPixmap", "a(iiay)"),
    ("AttentionIconName", "s"), ("AttentionIconPixmap", "a(iiay)"),
    ("AttentionMovieName", "s"), ("ToolTip", "(sa(iiay)ss)"),
    ("ItemIsMenu", "b"), ("Menu", "o")]
  MenuProperties = [("Version", "u"), ("Status", "s"),
    ("TextDirection", "s"), ("IconThemePath", "as")]
  IntrospectionHeader = "<node><interface name='org.freedesktop.DBus.Introspectable'><method name='Introspect'><arg type='s' direction='out'/></method></interface>" &
    "<interface name='org.freedesktop.DBus.Properties'><method name='Get'><arg type='s' direction='in'/><arg type='s' direction='in'/><arg type='v' direction='out'/></method>" &
    "<method name='GetAll'><arg type='s' direction='in'/><arg type='a{sv}' direction='out'/></method>" &
    "<method name='Set'><arg type='s' direction='in'/><arg type='s' direction='in'/><arg type='v' direction='in'/></method></interface>"
  ItemMethods = "<method name='Activate'><arg type='i' direction='in'/><arg type='i' direction='in'/></method>" &
    "<method name='SecondaryActivate'><arg type='i' direction='in'/><arg type='i' direction='in'/></method>" &
    "<method name='ContextMenu'><arg type='i' direction='in'/><arg type='i' direction='in'/></method>" &
    "<method name='Scroll'><arg type='i' direction='in'/><arg type='s' direction='in'/></method>" &
    "<signal name='NewIcon'/><signal name='NewToolTip'/><signal name='NewTitle'/>"
  MenuMethods = "<method name='GetLayout'><arg type='i' direction='in'/><arg type='i' direction='in'/><arg type='as' direction='in'/><arg type='u' direction='out'/><arg type='(ia{sv}av)' direction='out'/></method>" &
    "<method name='GetGroupProperties'><arg type='ai' direction='in'/><arg type='as' direction='in'/><arg type='a(ia{sv})' direction='out'/></method>" &
    "<method name='GetProperty'><arg type='i' direction='in'/><arg type='s' direction='in'/><arg type='v' direction='out'/></method>" &
    "<method name='Event'><arg type='i' direction='in'/><arg type='s' direction='in'/><arg type='v' direction='in'/><arg type='u' direction='in'/></method>" &
    "<method name='EventGroup'><arg type='a(isvu)' direction='in'/><arg type='ai' direction='out'/></method>" &
    "<method name='AboutToShow'><arg type='i' direction='in'/><arg type='b' direction='out'/></method>" &
    "<method name='AboutToShowGroup'><arg type='ai' direction='in'/><arg type='ai' direction='out'/><arg type='ai' direction='out'/></method>" &
    "<signal name='LayoutUpdated'><arg type='u'/><arg type='i'/></signal>" &
    "<signal name='ItemsPropertiesUpdated'><arg type='a(ia{sv})'/><arg type='a(ias)'/></signal>"

proc introspection(isMenu: bool): string =
  ## Describes only the interfaces implemented at the requested object path.
  result = IntrospectionHeader
  result.add "<interface name='" & (if isMenu: Menu else: Item) & "'>"
  if isMenu:
    for (name, signature) in MenuProperties:
      result.add "<property name='" & name & "' type='" & signature & "' access='read'/>"
    result.add MenuMethods
  else:
    for (name, signature) in ItemProperties:
      result.add "<property name='" & name & "' type='" & signature & "' access='read'/>"
    result.add ItemMethods
  result.add "</interface></node>"

proc pixmaps(i: var Iter, state: TrayState, present: bool) =
  ## Serializes straight-alpha ARGB pixels in network byte order.
  container(i, 'a', "(iiay)", images):
    if present:
      container(images, 'r', nil, image):
        image.addInt state.icon.width.int32
        image.addInt state.icon.height.int32
        container(image, 'a', "y", bytes):
          for pixel in state.icon.data:
            let c = pixel.rgba()
            bytes.addByte c.a
            bytes.addByte c.r
            bytes.addByte c.g
            bytes.addByte c.b

proc propertyValue(i: var Iter, state: TrayState, name, signature: string) =
  ## Writes a supported property as a D-Bus variant.
  container(i, 'v', signature.cstring, value):
    case name
    of "Category": value.addString "ApplicationStatus"
    of "Id":
      let name = getAppFilename().extractFilename()
      value.addString(if name.validateUtf8() == -1: name else: "windy")
    of "Title": value.addString state.tooltip
    of "Status": value.addString "Active"
    of "WindowId": value.addUint 0
    of "Version": value.addUint 4
    of "ItemIsMenu": value.addBool false
    of "Menu": value.addString MenuPath, 'o'
    of "TextDirection": value.addString "ltr"
    of "IconThemePath":
      container(value, 'a', "s", paths): discard
    of "ToolTip":
      container(value, 'r', nil, tooltip):
        tooltip.addString ""
        tooltip.pixmaps(state, false)
        tooltip.addString state.tooltip
        tooltip.addString ""
    of "IconPixmap", "AttentionIconPixmap", "OverlayIconPixmap":
      value.pixmaps(state, name == "IconPixmap")
    else: value.addString ""

proc error(tray: SniTray, call: Message, name, text: string) =
  ## Replies with a protocol error instead of passing bad arguments to libdbus.
  discard tray.connection.send(messageNewError(call, ("org.freedesktop.DBus.Error." & name).cstring, text.cstring))

proc validId(state: TrayState, id: int32): bool =
  ## Accepts the root and currently published menu IDs.
  id == 0 or (id >= state.firstMenuId and id - state.firstMenuId < state.menu.len)

proc strings(i: var Iter): seq[string] =
  ## Copies a validated array of strings before the native message is released.
  var child = i.recurse()
  while messageIterGetArgType(child.addr) == 's'.cint:
    result.add child.stringValue()
    child.next()

proc ids(i: var Iter): seq[int32] =
  ## Copies a validated array of menu IDs.
  var child = i.recurse()
  while messageIterGetArgType(child.addr) == 'i'.cint:
    result.add child.intValue()
    child.next()

proc menuProperty(i: var Iter, state: TrayState, id: int32, name: string): bool =
  ## Writes one property for the deliberately flat menu model.
  let index = id - state.firstMenuId
  let separator = id > 0 and state.menu[index].kind == TrayMenuSeparator
  case name
  of "label":
    container(i, 'v', "s", value):
      value.addString(if id > 0 and not separator: state.menu[index].text.replace("_", "__") else: "")
  of "type":
    container(i, 'v', "s", value):
      value.addString(if separator: "separator" else: "standard")
  of "enabled", "visible":
    container(i, 'v', "b", value): value.addBool true
  of "children-display":
    container(i, 'v', "s", value): value.addString(if id == 0: "submenu" else: "")
  else: return false
  true

proc menuProperties(i: var Iter, state: TrayState, id: int32, requested: seq[string]) =
  ## Emits requested properties, or all properties for an empty filter.
  container(i, 'a', "{sv}", props):
    for name in ["label", "type", "enabled", "visible", "children-display"]:
      if requested.len == 0 or name in requested:
        container(props, 'e', nil, entry):
          entry.addString name
          discard entry.menuProperty(state, id, name)

proc layout(i: var Iter, state: TrayState, id, depth: int32, requested: seq[string]) =
  ## Emits the root and its flat children, respecting the requested depth.
  container(i, 'r', nil, node):
    node.addInt id
    node.menuProperties(state, id, requested)
    container(node, 'a', "v", children):
      if id == 0 and depth != 0:
        for index in 0..<state.menu.len:
          container(children, 'v', "(ia{sv}av)", child):
            child.layout(state, state.firstMenuId + index.int32, 0, requested)

proc methodCall(tray: SniTray, call: Message, callbacks: var seq[Callback]) =
  ## Handles property and menu calls without running application callbacks inline.
  let
    path = $messageGetPath(call)
    iface = $messageGetInterface(call)
    member = $messageGetMember(call)
    signature = $messageGetSignature(call)
    isMenu = path == MenuPath
  if path != ItemPath and not isMenu:
    tray.error(call, "UnknownObject", "Unknown tray object")
    return
  var args = call.reader()
  let reply = requireMessage(messageNewMethodReturn(call))
  defer: messageUnref(reply)
  var outArgs = reply.writer()
  template invalid() =
    tray.error(call, "InvalidArgs", "Invalid tray method arguments")
    return
  if iface == "org.freedesktop.DBus.Introspectable" and member == "Introspect":
    if signature != "": invalid()
    outArgs.addString introspection(isMenu)
  elif iface == "org.freedesktop.DBus.Peer" and member == "Ping":
    if signature != "": invalid()
  elif iface == Properties:
    if member == "Set":
      tray.error(call, "PropertyReadOnly", "Tray properties are read-only")
      return
    if (member == "Get" and signature != "ss") or
        (member == "GetAll" and signature != "s"):
      invalid()
    if member notin ["Get", "GetAll"]:
      tray.error(call, "UnknownMethod", "Unknown properties method")
      return
    let expected = if isMenu: Menu else: Item
    if args.stringValue() != expected:
      tray.error(call, "UnknownInterface", "Unknown tray interface")
      return
    args.next()
    let requested = args.stringValue()
    var properties: seq[(string, string)]
    if isMenu:
      properties = @MenuProperties
    else:
      properties = @ItemProperties
    if member == "Get":
      var found = false
      for (name, kind) in properties:
        if name == requested:
          if isMenu and name == "Status":
            container(outArgs, 'v', "s", value): value.addString "normal"
          else:
            outArgs.propertyValue(tray.state, name, kind)
          found = true
      if not found:
        tray.error(call, "UnknownProperty", "Unknown tray property")
        return
    else:
      container(outArgs, 'a', "{sv}", props):
        for (name, kind) in properties:
          container(props, 'e', nil, entry):
            entry.addString name
            if isMenu and name == "Status":
              container(entry, 'v', "s", value): value.addString "normal"
            else:
              entry.propertyValue(tray.state, name, kind)
  elif not isMenu and iface == Item:
    case member
    of "Activate", "SecondaryActivate", "ContextMenu":
      if signature != "ii": invalid()
      if member == "Activate" and tray.state.onClick != nil:
        callbacks.add tray.state.onClick
      # The host presents the exported Menu for ContextMenu.
    of "Scroll":
      if signature != "is": invalid()
    else:
      tray.error(call, "UnknownMethod", "Unknown status notifier method")
      return
  elif isMenu and iface == Menu:
    case member
    of "GetLayout":
      if signature != "iias": invalid()
      let id = args.intValue()
      args.next()
      let depth = args.intValue()
      args.next()
      if not tray.state.validId(id): invalid()
      outArgs.addUint tray.state.revision
      outArgs.layout(tray.state, id, depth, args.strings())
    of "GetGroupProperties":
      if signature != "aias": invalid()
      var selected = args.ids()
      args.next()
      let requested = args.strings()
      if selected.len == 0:
        selected.add 0
        for index in 0..<tray.state.menu.len:
          selected.add tray.state.firstMenuId + index.int32
      container(outArgs, 'a', "(ia{sv})", entries):
        for id in selected:
          if tray.state.validId(id):
            container(entries, 'r', nil, entry):
              entry.addInt id
              entry.menuProperties(tray.state, id, requested)
    of "GetProperty":
      if signature != "is": invalid()
      let id = args.intValue()
      args.next()
      if not tray.state.validId(id): invalid()
      if not outArgs.menuProperty(tray.state, id, args.stringValue()):
        tray.error(call, "UnknownProperty", "Unknown menu property")
        return
    of "AboutToShow":
      if signature != "i" or not tray.state.validId(args.intValue()): invalid()
      outArgs.addBool false
    of "AboutToShowGroup":
      if signature != "ai": invalid()
      container(outArgs, 'a', "i", updates): discard
      container(outArgs, 'a', "i", errors):
        for id in args.ids():
          if not tray.state.validId(id): errors.addInt id
    of "Event", "EventGroup":
      if (member == "Event" and signature != "isvu") or
          (member == "EventGroup" and signature != "a(isvu)"): invalid()
      template event(input: var Iter) =
        let id = input.intValue()
        input.next()
        if input.stringValue() == "clicked" and id > 0 and tray.state.validId(id):
          let callback = tray.state.menuCallback(id - tray.state.firstMenuId + 1)
          if callback != nil: callbacks.add callback
      if member == "Event":
        event(args)
      else:
        var events = args.recurse()
        container(outArgs, 'a', "i", errors):
          while messageIterGetArgType(events.addr) == 'r'.cint:
            var entry = events.recurse()
            let id = entry.intValue()
            if not tray.state.validId(id): errors.addInt id
            else: event(entry)
            events.next()
    else:
      tray.error(call, "UnknownMethod", "Unknown menu method")
      return
  else:
    tray.error(call, "UnknownInterface", "Unknown tray interface")
    return
  checked connectionSend(tray.connection, reply, nil)

proc queryHost(tray: SniTray) =
  ## Asynchronously resolves the watcher before trusting its signals or replies.
  let call = requireMessage(messageNewMethodCall("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner"))
  var args = call.writer()
  args.addString Watcher
  tray.ownerSerial = tray.connection.send(call)
  tray.selecting = true
  tray.deadline = getMonoTime() + initDuration(seconds = ReplyTimeoutSeconds)

proc newSniTray*(state: TrayState, blockedOwner = ""): SniTray =
  ## Starts optional session-bus discovery without requiring an X11 display.
  result = SniTray(state: state, blockedOwner: blockedOwner)
  if not loadDbus(): return
  result.connection = busGetPrivate(0, nil)
  if result.connection == nil: return
  try:
    connectionSetExitOnDisconnect(result.connection, 0)
    busAddMatch(result.connection, "type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='org.kde.StatusNotifierWatcher'", nil)
    busAddMatch(result.connection, "type='signal',interface='org.kde.StatusNotifierWatcher'", nil)
    result.queryHost()
  except:
    connectionClose(result.connection)
    connectionUnref(result.connection)
    result.connection = nil
    raise

proc setActive*(tray: SniTray, active: bool) =
  ## Registers only the selected backend, using the connection's unique bus name.
  if active and tray.hostAvailable and not tray.selecting and
      tray.registerSerial == 0 and not tray.registered:
    let call = requireMessage(messageNewMethodCall(Watcher, WatcherPath, Watcher, "RegisterStatusNotifierItem"))
    var args = call.writer()
    args.addString ItemPath
    tray.registerSerial = tray.connection.send(call)
    tray.deadline = getMonoTime() + initDuration(seconds = ReplyTimeoutSeconds)

proc update*(tray: SniTray, state: TrayState) =
  ## Replaces the snapshot and notifies hosts that cached content changed.
  tray.state = state
  if tray.connection == nil: return
  for name in ["NewIcon", "NewToolTip", "NewTitle"]:
    discard tray.connection.send(messageNewSignal(ItemPath, Item, name.cstring))
  let signal = requireMessage(messageNewSignal(MenuPath, Menu, "LayoutUpdated"))
  var args = signal.writer()
  args.addUint state.revision
  args.addInt 0
  discard tray.connection.send(signal)

proc poll*(tray: SniTray): seq[Callback] =
  ## Processes a bounded batch without waiting for bus traffic or method replies.
  if tray.connection == nil: return
  if (tray.selecting or tray.registerSerial != 0) and getMonoTime() > tray.deadline:
    if tray.registerSerial != 0:
      tray.failedOwner = tray.owner
    tray.selecting = false
    tray.hostAvailable = false
    tray.ownerSerial = 0
    tray.querySerial = 0
    tray.registerSerial = 0
  if connectionReadWrite(tray.connection, 0) == 0:
    tray.hostAvailable = false
    tray.registered = false
    tray.selecting = false
    return
  for unused in 0..<EventBatchSize:
    let message = connectionPopMessage(tray.connection)
    if message == nil: break
    try:
      let
        kind = messageGetType(message)
        serial = messageGetReplySerial(message)
      var args = message.reader()
      if kind in [2.cint, 3.cint]:
        if serial == tray.ownerSerial:
          tray.ownerSerial = 0
          tray.owner = if kind == 2: args.stringValue() else: ""
          tray.hostAvailable = false
          if tray.owner.len > 0:
            let call = requireMessage(messageNewMethodCall(tray.owner.cstring, WatcherPath, Properties, "Get"))
            var query = call.writer()
            query.addString Watcher
            query.addString "IsStatusNotifierHostRegistered"
            tray.querySerial = tray.connection.send(call)
          else: tray.selecting = false
        elif serial == tray.querySerial:
          tray.querySerial = 0
          tray.selecting = false
          if kind == 2 and $messageGetSignature(message) == "v":
            var value = args.recurse()
            if messageIterGetArgType(value.addr) == 'b'.cint:
              var available: uint32
              messageIterGetBasic(value.addr, available.addr)
              tray.hostAvailable = available != 0 and tray.owner != tray.blockedOwner
        elif serial == tray.registerSerial:
          tray.registerSerial = 0
          tray.registered = kind == 2
          if kind != 2:
            tray.hostAvailable = false
            tray.failedOwner = tray.owner
      elif kind == 4:
        let iface = $messageGetInterface(message)
        if iface == "org.freedesktop.DBus" and
            $messageGetMember(message) == "NameOwnerChanged" and
            $messageGetSender(message) == "org.freedesktop.DBus" and
            $messageGetSignature(message) == "sss" and args.stringValue() == Watcher:
          tray.registered = false
          tray.registerSerial = 0
          tray.blockedOwner = ""
          tray.querySerial = 0
          tray.queryHost()
        elif iface == Watcher and $messageGetSender(message) == tray.owner:
          if $messageGetMember(message) in ["StatusNotifierHostRegistered", "StatusNotifierHostUnregistered"]:
            tray.registered = false
            tray.blockedOwner = ""
            tray.queryHost()
      elif kind == 1:
        tray.methodCall(message, result)
    finally:
      messageUnref(message)

proc close*(tray: SniTray) =
  ## Removes registration by closing the private connection and releases bus state.
  if tray != nil and tray.connection != nil:
    connectionClose(tray.connection)
    connectionUnref(tray.connection)
    tray.connection = nil
  if tray != nil:
    tray.registered = false
    tray.hostAvailable = false
