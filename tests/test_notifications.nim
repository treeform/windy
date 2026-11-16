when defined(linux) and not defined(emscripten):
  import
    std/[json, monotimes, os, osproc, strutils, tables, tempfiles, times],
    pixie, windy,
    windy/platforms/linux/dbus

  type
    SentNotification = object
      sender, appName, title, body: string
      replaces, id: uint32
      actions: seq[string]
      width, height, stride, bits, channels, timeout: int32
      alpha: uint32
      pixels: seq[uint8]

    Host = ref object
      connection: Connection
      child: Process
      directory: string
      step: int
      caps: seq[string]
      sent: seq[SentNotification]
      dismissed: seq[uint32]
      held: seq[Message]
      nextId: uint32
      replyIds: Table[uint32, uint32]
      holdCapabilities, holdNotify, failNotify, invalidId: bool
      capCalls: int

  const
    Service = "org.freedesktop.Notifications"
    ObjectPath = "/org/freedesktop/Notifications"
    TestTimeoutSeconds = 8

  proc requestName(c: Connection, name: cstring, flags: uint32, error: pointer): cint
      {.cdecl, dynlib: "libdbus-1.so.3", importc: "dbus_bus_request_name".}
    ## Gives the isolated mock the desktop notification service name.

  proc messageSerial(message: Message): uint32
      {.cdecl, dynlib: "libdbus-1.so.3", importc: "dbus_message_get_serial".}
    ## Identifies a held request independently of its contents.

  proc atomicWrite(path, value: string) =
    ## Keeps command and status readers from observing partial JSON files.
    writeFile(path & ".new", value)
    moveFile(path & ".new", path)

  proc fixtureImage(): Image =
    ## Uses different channels and transparency to expose wire-format mistakes.
    result = newImage(2, 1)
    result[0, 0] = rgba(200, 40, 80, 128)
    result[1, 0] = rgba(20, 240, 10, 255)

  proc client(directory: string) =
    ## Exercises the public API in a separate process without any display connection.
    putEnv("DISPLAY", "")
    var
      notes: array[4, Notification]
      clicks: array[4, int]
      errors, unhandled: seq[string]
      step: int
      done: bool
    proc clickCallback(slot: int, mode: string): Callback =
      ## Gives each notification its own callback captures.
      result = proc() =
        inc clicks[slot]
        if mode == "update" and not notes[slot].closed:
          notes[slot].update("From click", "Updated safely")
        elif mode == "close": notes[slot].close()
        elif mode == "recursive": pollEvents()
    let deadline = getMonoTime() + initDuration(seconds = 90)
    while not done and getMonoTime() < deadline:
      try: pollEvents()
      except WindyError: unhandled.add getCurrentExceptionMsg()
      let path = directory / "command.json"
      if fileExists(path):
        let cmd = parseJson(readFile(path))
        if cmd["step"].getInt() != step:
          step = cmd["step"].getInt()
          let slot = cmd.getOrDefault("slot").getInt()
          case cmd["action"].getStr()
          of "send":
            let
              image = if cmd.getOrDefault("image").getBool(): fixtureImage() else: nil
              clickMode = cmd.getOrDefault("clickMode").getStr()
              callback = clickCallback(slot, clickMode)
              errorCallback = if cmd.getOrDefault("unhandled").getBool():
                nil
              else:
                proc(message: string) = errors.add message
            notes[slot] = sendNotification(cmd["title"].getStr(),
              cmd.getOrDefault("body").getStr(), image, callback, errorCallback)
            if clickMode == "cancel": notes[slot].close()
            if image != nil: image.fill(rgba(0, 0, 0, 255))
          of "update": notes[slot].update(cmd["title"].getStr(), cmd.getOrDefault("body").getStr())
          of "close":
            notes[slot].close()
            notes[slot].close()
          of "invalid":
            var rejected = 0
            try: discard sendNotification("\xff", "bad")
            except WindyError: inc rejected
            try: discard sendNotification("bad", "embedded\0null")
            except WindyError: inc rejected
            doAssert rejected == 2
          of "snapshot": discard
          of "quit": done = true
          else: doAssert false, "Unknown test command"
          var closedStates: seq[bool]
          for note in notes: closedStates.add note.closed()
          atomicWrite(directory / "status.json", $(%*{
            "step": step, "closed": closedStates, "clicks": clicks,
            "pending": notes[slot].pending,
            "errors": errors, "unhandled": unhandled
          }))
      sleep(1)
    doAssert done, "Notification client timed out"

  proc decode(message: Message): SentNotification =
    ## Independently reads the Notify signature and payload received over D-Bus.
    doAssert $messageGetSignature(message) == "susssasa{sv}i"
    result.sender = $messageGetSender(message)
    var args = message.reader()
    result.appName = args.stringValue()
    args.next()
    result.replaces = args.uintValue()
    args.next()
    doAssert args.stringValue() == ""
    args.next()
    result.title = args.stringValue()
    args.next()
    result.body = args.stringValue()
    args.next()
    var actions = args.recurse()
    while messageIterGetArgType(actions.addr) == 's'.cint:
      result.actions.add actions.stringValue()
      actions.next()
    args.next()
    var hints = args.recurse()
    while messageIterGetArgType(hints.addr) == 'e'.cint:
      var entry = hints.recurse()
      let name = entry.stringValue()
      entry.next()
      var value = entry.recurse()
      if name == "image-data":
        var image = value.recurse()
        result.width = image.intValue()
        image.next()
        result.height = image.intValue()
        image.next()
        result.stride = image.intValue()
        image.next()
        doAssert messageIterGetArgType(image.addr) == 'b'.cint
        messageIterGetBasic(image.addr, result.alpha.addr)
        image.next()
        result.bits = image.intValue()
        image.next()
        result.channels = image.intValue()
        image.next()
        var data = image.recurse()
        while messageIterGetArgType(data.addr) == 'y'.cint:
          var pixel: uint8
          messageIterGetBasic(data.addr, pixel.addr)
          result.pixels.add pixel
          data.next()
      hints.next()
    args.next()
    result.timeout = args.intValue()

  proc answer(host: Host, message: Message) =
    ## Implements standard desktop methods with configurable replies for failure tests.
    let member = $messageGetMember(message)
    if member == "Notify" and host.failNotify:
      discard host.connection.send(messageNewError(message,
        "org.freedesktop.DBus.Error.Failed", "Fixture rejected notification"))
      return
    let reply = requireMessage(messageNewMethodReturn(message))
    var args = reply.writer()
    case member
    of "GetCapabilities":
      container(args, 'a', "s", caps):
        for cap in host.caps: caps.addString cap
    of "Notify":
      if host.invalidId:
        args.addString "invalid ID"
      else:
        args.addUint host.replyIds[messageSerial(message)]
    of "CloseNotification": discard
    else: doAssert false, "Unexpected notification method: " & member
    discard host.connection.send(reply)

  proc pump(host: Host) =
    ## Services a bounded batch without using the real desktop's notification daemon.
    if host.connection == nil: return
    doAssert connectionReadWrite(host.connection, 0) != 0
    for unused in 0..<128:
      let message = connectionPopMessage(host.connection)
      if message == nil: break
      if messageGetType(message) != 1:
        messageUnref(message)
        continue
      doAssert $messageGetPath(message) == ObjectPath
      doAssert $messageGetInterface(message) == Service
      let member = $messageGetMember(message)
      var keep = false
      case member
      of "GetCapabilities":
        inc host.capCalls
        keep = host.holdCapabilities
      of "Notify":
        var sent = decode(message)
        if sent.replaces == 0:
          inc host.nextId
          sent.id = host.nextId
        else: sent.id = sent.replaces
        host.sent.add sent
        host.replyIds[messageSerial(message)] = sent.id
        keep = host.holdNotify
      of "CloseNotification":
        var args = message.reader()
        doAssert $messageGetSignature(message) == "u"
        host.dismissed.add args.uintValue()
      else: doAssert false
      if keep: host.held.add message
      else:
        host.answer(message)
        messageUnref(message)

  proc waitFor(host: Host, predicate: proc(): bool) =
    ## Keeps the mock responsive while waiting for observable client behavior.
    let deadline = getMonoTime() + initDuration(seconds = TestTimeoutSeconds)
    while not predicate() and getMonoTime() < deadline:
      host.pump()
      doAssert host.child.running(), "Notification client exited unexpectedly"
      sleep(1)
    doAssert predicate(), "Notification test condition timed out: " &
      (if fileExists(host.directory / "status.json"): readFile(host.directory / "status.json") else: "no status")

  proc command(host: Host, action: string, slot = 0, title = "", body = "",
      image = false, clickMode = "", unhandled = false): JsonNode =
    ## Issues a test action and returns the client's public observations.
    inc host.step
    atomicWrite(host.directory / "command.json", $(%*{
      "step": host.step, "action": action, "slot": slot, "title": title,
      "body": body, "image": image, "clickMode": clickMode, "unhandled": unhandled
    }))
    host.waitFor(proc(): bool =
      fileExists(host.directory / "status.json") and
        parseJson(readFile(host.directory / "status.json"))["step"].getInt() == host.step
    )
    parseJson(readFile(host.directory / "status.json"))

  proc newHost(caps = @["actions", "body", "body-markup", "icon-static"]): Host =
    ## Starts the client against a mock service on the already isolated session bus.
    doAssert loadDbus()
    result = Host(connection: busGetPrivate(0, nil), caps: caps, nextId: 1000,
      directory: createTempDir("windy-notifications-", ""))
    doAssert result.connection != nil
    connectionSetExitOnDisconnect(result.connection, 0)
    doAssert requestName(result.connection, Service, 4, nil) == 1
    result.child = startProcess(getAppFilename(), args = ["--client", result.directory],
      options = {poParentStreams})

  proc close(host: Host) =
    ## Cleans up the test process and only its own temporary files and connection.
    if host.child.running():
      host.child.terminate()
      discard host.child.waitForExit(5000)
    host.child.close()
    for message in host.held: messageUnref(message)
    if host.connection != nil:
      connectionClose(host.connection)
      connectionUnref(host.connection)
    removeDir(host.directory)

  proc release(host: Host) =
    ## Replies to held calls after the test has exercised pending operations.
    let messages = host.held
    host.held = @[]
    for message in messages:
      host.answer(message)
      messageUnref(message)
    host.pump()

  proc emit(host: Host, member: string, id: uint32, text = "default",
      source: Connection = nil) =
    ## Sends lifecycle events, optionally from an unrelated bus connection.
    let message = requireMessage(messageNewSignal(ObjectPath, Service, member.cstring))
    var args = message.writer()
    args.addUint id
    if member == "ActionInvoked": args.addString text
    else: args.addUint 2
    let connection = if source != nil: source else: host.connection
    discard connection.send(message)
    discard connectionReadWrite(connection, 0)

  proc waitErrors(host: Host, count = 1, unhandled = false): JsonNode =
    ## Waits for an error callback or the documented unhandled WindyError.
    let field = if unhandled: "unhandled" else: "errors"
    let deadline = getMonoTime() + initDuration(seconds = TestTimeoutSeconds)
    while getMonoTime() < deadline:
      result = host.command("snapshot")
      if result[field].len >= count: return
      sleep(1)
    doAssert false, "Expected notification error was not delivered"

  proc testLifecycle() =
    ## Covers payloads, replacements, click dispatch, and repeatable dismissal.
    let host = newHost()
    defer: host.close()
    discard host.command("invalid")
    discard host.command("send", title = "Initial", body = "<b>A & B</b>", image = true)
    host.waitFor(proc(): bool = host.sent.len == 1)
    let sent = host.sent[0]
    doAssert sent.title == "Initial" and sent.body == "&lt;b&gt;A &amp; B&lt;/b&gt;"
    doAssert sent.appName.len > 0 and sent.replaces == 0 and sent.timeout == -1
    doAssert sent.actions == @["default", "Open"]
    doAssert (sent.width, sent.height, sent.stride, sent.alpha, sent.bits, sent.channels) ==
      (2.int32, 1.int32, 8.int32, 1.uint32, 8.int32, 4.int32)
    var expected: seq[uint8]
    for pixel in fixtureImage().data:
      let c = pixel.rgba()
      expected.add [c.r, c.g, c.b, c.a]
    doAssert sent.pixels == expected, "Image must use an owned straight RGBA snapshot"
    discard host.command("update", title = "Replacement", body = "new body")
    host.waitFor(proc(): bool = host.sent.len == 2)
    doAssert host.sent[1].replaces == sent.id and host.sent[1].pixels.len == 0
    host.emit("ActionInvoked", sent.id, "unknown-action")
    let foreign = busGetPrivate(0, nil)
    host.emit("ActionInvoked", sent.id, source = foreign)
    connectionClose(foreign)
    connectionUnref(foreign)
    sleep(30)
    doAssert host.command("snapshot")["clicks"][0].getInt() == 0
    host.emit("ActionInvoked", sent.id)
    var status: JsonNode
    host.waitFor(proc(): bool =
      status = host.command("snapshot")
      status["clicks"][0].getInt() == 1
    )
    discard host.command("close")
    host.waitFor(proc(): bool = host.dismissed.len == 1)
    doAssert host.dismissed[0] == sent.id
    doAssert host.command("snapshot")["closed"][0].getBool()
    doAssert host.command("snapshot")["errors"].len == 0

  proc testPending() =
    ## Holds replies to prove discovery and Notify do not block subsequent commands.
    let host = newHost()
    defer: host.close()
    host.holdCapabilities = true
    doAssert host.command("send", slot = 1, title = "Canceled", clickMode = "cancel")["closed"][1].getBool()
    doAssert host.capCalls == 0 and host.sent.len == 0
    discard host.command("send", title = "Before discovery")
    host.waitFor(proc(): bool = host.held.len == 1)
    discard host.command("update", title = "Latest before discovery")
    discard host.command("send", slot = 1, title = "Canceled during discovery")
    discard host.command("close", slot = 1)
    doAssert host.sent.len == 0
    host.holdCapabilities = false
    host.holdNotify = true
    host.release()
    host.waitFor(proc(): bool = host.sent.len == 1 and host.held.len == 1)
    doAssert host.sent[0].title == "Latest before discovery"
    host.emit("ActionInvoked", 0)
    host.emit("NotificationClosed", 0)
    let pendingStatus = host.command("snapshot")
    doAssert pendingStatus["pending"].getBool() and not pendingStatus["closed"][0].getBool()
    doAssert pendingStatus["clicks"][0].getInt() == 0
    let foreign = busGetPrivate(0, nil)
    let forged = requireMessage(messageNewMethodReturn(host.held[0]))
    var forgedArgs = forged.writer()
    forgedArgs.addUint 9000
    discard foreign.send(forged)
    discard connectionReadWrite(foreign, 0)
    doAssert host.command("snapshot")["pending"].getBool()
    connectionClose(foreign)
    connectionUnref(foreign)
    discard host.command("update", title = "Discard this update")
    discard host.command("update", title = "Latest pending update")
    doAssert host.sent.len == 1
    host.release()
    host.waitFor(proc(): bool = host.sent.len == 2 and host.held.len == 1)
    doAssert host.sent[1].title == "Latest pending update"
    doAssert host.sent[1].replaces == host.sent[0].id
    discard host.command("close")
    host.holdNotify = false
    host.release()
    host.waitFor(proc(): bool = host.dismissed.len == 1)
    doAssert host.sent.len == 2

  proc testCapabilitiesAndCallbacks() =
    ## Checks plain-text fallback and reentrant callbacks using the same public API.
    let host = newHost(@["body"])
    defer: host.close()
    discard host.command("send", title = "No actions", body = "<literal>&")
    host.waitFor(proc(): bool = host.sent.len == 1)
    doAssert host.sent[0].actions.len == 0
    doAssert host.sent[0].body == "<literal>&"
    host.emit("NotificationClosed", host.sent[0].id)
    host.waitFor(proc(): bool = host.command("snapshot")["closed"][0].getBool())
    doAssert host.command("snapshot")["unhandled"].len == 0

  proc testCallbackUpdate() =
    ## Lets callbacks update or dismiss their handles without dispatching native code inline.
    let host = newHost()
    defer: host.close()
    discard host.command("send", title = "Clickable", clickMode = "update")
    host.waitFor(proc(): bool = host.sent.len == 1)
    host.emit("ActionInvoked", host.sent[0].id)
    host.waitFor(proc(): bool = host.sent.len == 2)
    doAssert host.sent[1].title == "From click" and host.sent[1].replaces == host.sent[0].id
    discard host.command("send", slot = 1, title = "Close from callback", clickMode = "close")
    host.waitFor(proc(): bool = host.sent.len == 3)
    host.emit("ActionInvoked", host.sent[2].id)
    host.waitFor(proc(): bool = host.dismissed.len == 1)
    host.emit("ActionInvoked", host.sent[0].id)
    host.emit("NotificationClosed", host.sent[0].id)
    host.waitFor(proc(): bool = host.command("snapshot")["closed"][0].getBool())
    let status = host.command("snapshot")
    doAssert status["clicks"][0].getInt() == 2 and status["unhandled"].len == 0, $status

  proc testCanceledDiscovery() =
    ## Drains discovery replies after every initial handle has been canceled.
    let host = newHost()
    defer: host.close()
    host.holdCapabilities = true
    discard host.command("send", title = "Canceled while querying")
    host.waitFor(proc(): bool = host.held.len == 1)
    discard host.command("close")
    host.holdCapabilities = false
    host.release()
    discard host.command("snapshot")
    doAssert host.sent.len == 0
    discard host.command("send", title = "Later request", clickMode = "recursive")
    host.waitFor(proc(): bool = host.sent.len == 1)
    doAssert host.capCalls == 1
    host.emit("ActionInvoked", host.sent[0].id)
    host.waitFor(proc(): bool = host.command("snapshot")["clicks"][0].getInt() == 1)

  proc testMissingService() =
    ## A missing service reports failure without replaying when one later appears.
    let host = newHost()
    defer: host.close()
    connectionClose(host.connection)
    connectionUnref(host.connection)
    host.connection = nil
    discard host.command("send", title = "Unavailable")
    let status = host.waitErrors()
    doAssert status["closed"][0].getBool() and not status["pending"].getBool()
    host.connection = busGetPrivate(0, nil)
    doAssert requestName(host.connection, Service, 4, nil) == 1
    discard host.command("snapshot")
    doAssert host.sent.len == 0
    discard host.command("send", title = "Explicit retry")
    host.waitFor(proc(): bool = host.sent.len == 1)
    doAssert host.sent[0].title == "Explicit retry"

  proc testIdleRestart() =
    ## Keeps ownership monitoring active when no notification handles remain live.
    let host = newHost()
    defer: host.close()
    discard host.command("send", title = "Before idle")
    host.waitFor(proc(): bool = host.sent.len == 1)
    discard host.command("close")
    host.waitFor(proc(): bool = not host.command("snapshot")["pending"].getBool())
    connectionClose(host.connection)
    connectionUnref(host.connection)
    host.connection = nil
    # A command round trip lets the client pump the ownership change while idle.
    discard host.command("snapshot")
    host.connection = busGetPrivate(0, nil)
    doAssert requestName(host.connection, Service, 4, nil) == 1
    discard host.command("send", title = "After idle restart")
    host.waitFor(proc(): bool = host.sent.len == 2)
    doAssert host.sent[^1].replaces == 0
    doAssert host.command("snapshot")["errors"].len == 0

  proc testFailures() =
    ## Checks service errors, malformed replies, restart, and fresh requests afterward.
    let host = newHost()
    defer: host.close()
    host.failNotify = true
    discard host.command("send", title = "Rejected")
    var status = host.waitErrors()
    doAssert status["errors"][0].getStr().contains("Fixture rejected")
    doAssert status["closed"][0].getBool()
    host.failNotify = false
    host.invalidId = true
    discard host.command("send", title = "Malformed ID")
    status = host.waitErrors(2)
    doAssert status["errors"][1].getStr().contains("Invalid")
    host.invalidId = false
    discard host.command("send", title = "Before restart")
    host.waitFor(proc(): bool = host.sent.len == 3)
    connectionClose(host.connection)
    connectionUnref(host.connection)
    host.connection = nil
    status = host.waitErrors(3)
    doAssert status["closed"][0].getBool()
    host.connection = busGetPrivate(0, nil)
    doAssert requestName(host.connection, Service, 4, nil) == 1
    discard host.command("send", title = "After restart")
    host.waitFor(proc(): bool = host.sent.len == 4)
    doAssert host.sent[^1].replaces == 0
    host.failNotify = true
    discard host.command("send", slot = 1, title = "Unhandled", unhandled = true)
    status = host.waitErrors(unhandled = true)
    doAssert status["unhandled"].len == 1

  proc testTimeout() =
    ## Leaves Notify unanswered and verifies a later frame reports the bounded timeout.
    let host = newHost()
    defer: host.close()
    host.holdNotify = true
    discard host.command("send", title = "Timeout")
    host.waitFor(proc(): bool = host.sent.len == 1)
    let status = host.waitErrors()
    doAssert status["errors"][0].getStr().contains("timed out")
    doAssert status["closed"][0].getBool()

  if paramCount() > 0 and paramStr(1) == "--client":
    client(paramStr(2))
  elif paramCount() > 0 and paramStr(1) == "--suite":
    testLifecycle()
    testPending()
    testCapabilitiesAndCallbacks()
    testCallbackUpdate()
    testCanceledDiscovery()
    testMissingService()
    testIdleRestart()
    testFailures()
    testTimeout()
  else:
    let directory = createTempDir("windy-notifications-bus-", "")
    defer: removeDir(directory)
    let config = directory / "bus.conf"
    # No service directories: a missing mock must never activate a real desktop daemon.
    # Permit unsolicited replies so the foreign-sender test reaches Windy's own check.
    writeFile(config, """<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen>
      <auth>EXTERNAL</auth><policy context="default"><allow own="*"/>
      <allow send_destination="*"/><allow send_requested_reply="false"/>
      <allow receive_sender="*"/><allow receive_requested_reply="false"/>
      </policy></busconfig>""")
    let process = startProcess("dbus-run-session", args = ["--config-file=" & config, "--", getAppFilename(),
      "--suite"], options = {poUsePath, poParentStreams})
    defer: process.close()
    doAssert process.waitForExit(90000) == 0
