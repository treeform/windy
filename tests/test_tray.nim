when defined(linux) and not defined(emscripten):
  import
    std/[os, osproc, monotimes, streams, times, strutils, tables],
    pixie, windy,
    windy/platforms/linux/tray/sni/dbus,
    windy/platforms/linux/tray/xembed/xlib

  type
    Host = object
      bus: Connection
      item: string
      registrations: int
      attempts: int
      replies: Table[uint32, Message]
      available: bool
      reject: bool

  const
    Watcher = "org.kde.StatusNotifierWatcher"
    Item = "org.kde.StatusNotifierItem"
    Properties = "org.freedesktop.DBus.Properties"
    Menu = "com.canonical.dbusmenu"
    WaitSeconds = 15

  proc requestName(c: Connection, name: cstring, flags: uint32, error: pointer): cint
      {.cdecl, dynlib: "libdbus-1.so.3", importc: "dbus_bus_request_name".}
    ## Owns the mock watcher's well-known name on the private test bus.

  proc reparent(d: Display, window, parent: xlib.Window, x, y: cint): cint
      {.cdecl, dynlib: libX11, importc: "XReparentWindow".}
    ## Embeds the test plug into the independent host window.

  proc children(d: Display, window: xlib.Window, root, parent: ptr xlib.Window,
      windows: ptr ptr UncheckedArray[xlib.Window], count: ptr cuint): cint
      {.cdecl, dynlib: libX11, importc: "XQueryTree".}
    ## Enumerates windows to find the popup without inspecting implementation state.

  proc icon(): Image =
    ## Includes transparency and unequal color channels to expose channel mistakes.
    result = newImage(12, 8)
    result.fill(rgba(200, 40, 80, 128))

  proc app() =
    ## Runs the real public API in another process, including callback replacement.
    var done = false
    var clicks = 0
    proc clicked() =
      ## Replaces the icon from inside its own activation callback.
      inc clicks
      let green = newImage(10, 10)
      green.fill(rgba(0, 255, 0, 255))
      showTrayIcon(green, "Updated", clicked, @[
        TrayMenuEntry(kind: TrayMenuOption, text: "Quit_now", onClick: proc() =
          hideTrayIcon()
          hideTrayIcon()
          done = true
        )])
    showTrayIcon(icon(), "Initial", clicked, @[
      TrayMenuEntry(kind: TrayMenuOption, text: "Café_one", onClick: clicked),
      TrayMenuEntry(kind: TrayMenuSeparator),
      TrayMenuEntry(kind: TrayMenuOption, text: "Last", onClick: clicked)])
    let deadline = getMonoTime() + initDuration(seconds = WaitSeconds)
    while not done and getMonoTime() < deadline:
      pollEvents()
      sleep(1)
    hideTrayIcon()
    doAssert done, "The host did not finish the tray test"
    doAssert clicks == 1

  proc newHost(): Host =
    ## Creates the watcher on an isolated session bus.
    result.bus = busGetPrivate(0, nil)
    doAssert result.bus != nil
    connectionSetExitOnDisconnect(result.bus, 0)
    doAssert requestName(result.bus, Watcher, 4, nil) == 1
    result.available = true

  proc close(host: var Host) =
    ## Releases outstanding replies and ownership before restarting the watcher.
    for message in host.replies.values: messageUnref(message)
    host.replies.clear()
    connectionClose(host.bus)
    connectionUnref(host.bus)
    host.bus = nil

  proc pump(host: var Host) =
    ## Answers the same watcher methods that a desktop host exposes.
    doAssert connectionReadWrite(host.bus, 0) != 0
    for unused in 0..<128:
      let message = connectionPopMessage(host.bus)
      if message == nil: break
      let kind = messageGetType(message)
      if kind in [2.cint, 3.cint]:
        host.replies[messageGetReplySerial(message)] = message
        continue
      if kind == 1:
        let member = $messageGetMember(message)
        let reply = requireMessage(messageNewMethodReturn(message))
        var args = reply.writer()
        if member == "Get":
          container(args, 'v', "b", value): value.addBool host.available
        elif member == "RegisterStatusNotifierItem":
          inc host.attempts
          if host.reject:
            messageUnref(reply)
            discard host.bus.send(messageNewError(message,
              "org.freedesktop.DBus.Error.Failed", "Rejected by test watcher"))
            messageUnref(message)
            continue
          var input = message.reader()
          doAssert input.stringValue() == "/StatusNotifierItem"
          host.item = $messageGetSender(message)
          inc host.registrations
        discard host.bus.send(reply)
      messageUnref(message)

  proc hostSignal(host: var Host, member: string) =
    ## Announces a host change through the watcher's normal signal interface.
    discard host.bus.send(messageNewSignal("/StatusNotifierWatcher", Watcher, member.cstring))

  proc settle(host: var Host) =
    ## Gives both processes time to handle a negative discovery result.
    let deadline = getMonoTime() + initDuration(milliseconds = 150)
    while getMonoTime() < deadline:
      host.pump()
      sleep(1)

  proc waitRegistration(host: var Host) =
    ## Waits for actual client registration, with a bounded test deadline.
    let deadline = getMonoTime() + initDuration(seconds = 5)
    while host.item.len == 0 and getMonoTime() < deadline:
      host.pump()
      sleep(1)
    doAssert host.item.len > 0, "No SNI registration received"

  proc call(host: var Host, path, iface, member: string): Message =
    ## Allocates a call addressed by the client's unique name, as real hosts do.
    requireMessage(messageNewMethodCall(host.item.cstring, path.cstring, iface.cstring, member.cstring))

  proc response(host: var Host, call: Message, expected = 2): Message =
    ## Waits for one reply while continuing to service watcher requests.
    let serial = host.bus.send(call)
    let deadline = getMonoTime() + initDuration(seconds = 5)
    while serial notin host.replies and getMonoTime() < deadline:
      host.pump()
      sleep(1)
    doAssert serial in host.replies, "Missing D-Bus reply"
    result = host.replies[serial]
    host.replies.del(serial)
    doAssert messageGetType(result) == expected.cint

  proc property(host: var Host, iface, name: string, menu = false): Message =
    ## Reads a property through the public D-Bus interface.
    let call = host.call(if menu: "/Menu" else: "/StatusNotifierItem", Properties, "Get")
    var args = call.writer()
    args.addString iface
    args.addString name
    host.response(call)

  proc propertyText(host: var Host, name: string, menu = false): string =
    ## Decodes a text property from its variant.
    let reply = host.property(if menu: Menu else: Item, name, menu)
    defer: messageUnref(reply)
    var args = reply.reader()
    var value = args.recurse()
    value.stringValue()

  proc testSni() =
    ## Verifies real bus messages, late hosts, restart, updates, and callback cleanup.
    doAssert loadDbus()
    let previousDisplay = getEnv("DISPLAY")
    defer: putEnv("DISPLAY", previousDisplay)
    putEnv("DISPLAY", "")
    let child = startProcess(getAppFilename(), args = ["--app"], options = {poParentStreams})
    defer: child.close()
    sleep(100)
    var host = newHost()
    defer: host.close()
    host.reject = true
    let attemptDeadline = getMonoTime() + initDuration(seconds = 5)
    while host.attempts == 0 and getMonoTime() < attemptDeadline:
      host.pump()
      sleep(1)
    host.settle()
    doAssert host.attempts == 1, "A failed registration was retried without a host change"
    doAssert host.registrations == 0
    host.reject = false
    host.hostSignal("StatusNotifierHostRegistered")
    host.waitRegistration()
    doAssert host.propertyText("Title") == "Initial"
    doAssert host.propertyText("Status", true) == "normal"
    let all = host.call("/StatusNotifierItem", Properties, "GetAll")
    var allArgs = all.writer()
    allArgs.addString Item
    let allReply = host.response(all)
    doAssert $messageGetSignature(allReply) == "a{sv}"
    messageUnref(allReply)
    let imageReply = host.property(Item, "IconPixmap")
    var args = imageReply.reader()
    var value = args.recurse()
    var images = value.recurse()
    var image = images.recurse()
    doAssert image.intValue() == 12
    image.next()
    doAssert image.intValue() == 8
    image.next()
    var bytes = image.recurse()
    let c = icon().data[0].rgba()
    for expected in [c.a, c.r, c.g, c.b]:
      var actual: uint8
      doAssert messageIterGetArgType(bytes.addr) == 'y'.cint
      messageIterGetBasic(bytes.addr, actual.addr)
      doAssert actual == expected
      bytes.next()
    messageUnref(imageReply)
    let bad = host.call("/StatusNotifierItem", Item, "Activate")
    messageUnref(host.response(bad, 3))
    let introspect = host.call("/Menu", "org.freedesktop.DBus.Introspectable", "Introspect")
    let description = host.response(introspect)
    args = description.reader()
    doAssert "GetLayout" in args.stringValue()
    messageUnref(description)
    let layoutCall = host.call("/Menu", Menu, "GetLayout")
    var layoutArgs = layoutCall.writer()
    layoutArgs.addInt 0
    layoutArgs.addInt -1
    container(layoutArgs, 'a', "s", names): discard
    let layoutReply = host.response(layoutCall)
    doAssert $messageGetSignature(layoutReply) == "u(ia{sv}av)"
    messageUnref(layoutReply)
    let labelCall = host.call("/Menu", Menu, "GetProperty")
    var labelArgs = labelCall.writer()
    labelArgs.addInt 1
    labelArgs.addString "label"
    let labelReply = host.response(labelCall)
    args = labelReply.reader()
    value = args.recurse()
    doAssert value.stringValue() == "Café__one"
    messageUnref(labelReply)
    host.item = ""
    host.available = false
    host.hostSignal("StatusNotifierHostUnregistered")
    host.settle()
    let registrations = host.registrations
    host.available = true
    host.hostSignal("StatusNotifierHostRegistered")
    host.waitRegistration()
    doAssert host.registrations == registrations + 1
    host.close()
    host = newHost()
    host.waitRegistration()
    doAssert host.propertyText("Title") == "Initial"
    let activate = host.call("/StatusNotifierItem", Item, "Activate")
    var activationArgs = activate.writer()
    activationArgs.addInt 0
    activationArgs.addInt 0
    messageUnref(host.response(activate))
    doAssert host.propertyText("Title") == "Updated"
    let stale = host.call("/Menu", Menu, "Event")
    var staleArgs = stale.writer()
    staleArgs.addInt 1
    staleArgs.addString "clicked"
    container(staleArgs, 'v', "i", data): data.addInt 0
    staleArgs.addUint 0
    messageUnref(host.response(stale))
    doAssert child.running(), "A stale menu event invoked a replacement action"
    let quit = host.call("/Menu", Menu, "Event")
    var quitArgs = quit.writer()
    quitArgs.addInt 4
    quitArgs.addString "clicked"
    container(quitArgs, 'v', "i", data): data.addInt 0
    quitArgs.addUint 0
    messageUnref(host.response(quit))
    doAssert child.waitForExit(5000) == 0

  proc sendButton(d: Display, window: xlib.Window, button: cuint, release = true,
      x = 10, y = 10) =
    ## Sends input through the server to the client's selected event mask.
    var event: XEvent
    event.button = XButtonEvent(kind: if release: xeButtonRelease else: xeButtonPress,
      display: d, window: window, root: d.defaultRootWindow(),
      pos: ivec2(x.int32, y.int32), rootPos: ivec2(40, 40), button: button, same_screen: 1)
    d.XSendEvent(window, false, if release: ButtonReleaseMask else: ButtonPressMask, event.addr)
    d.XFlush()

  proc sendKey(d: Display, window: xlib.Window, keysym: KeySym) =
    ## Sends a keyboard command to the popup through the independent connection.
    proc keycode(d: Display, symbol: KeySym): uint8
        {.cdecl, importc: "XKeysymToKeycode", dynlib: libX11.}
    var event: XEvent
    event.key = XKeyEvent(kind: xeKeyPress, display: d, window: window,
      root: d.defaultRootWindow(), keycode: keycode(d, keysym).cuint, same_screen: 1)
    d.XSendEvent(window, false, KeyPressMask, event.addr)
    d.XFlush()

  proc testXembed(withSni = false) =
    ## Acts as a tray manager on Xvfb, validating windows, pixels, menus, and restart.
    let previousBus = getEnv("DBUS_SESSION_BUS_ADDRESS")
    defer: putEnv("DBUS_SESSION_BUS_ADDRESS", previousBus)
    if not withSni:
      putEnv("DBUS_SESSION_BUS_ADDRESS", "unix:path=/nonexistent-windy-tray-test")
    let d = XOpenDisplay(nil)
    doAssert d != nil
    defer: discard d.XCloseDisplay()
    let root = d.defaultRootWindow()
    let selection = d.XInternAtom(("_NET_SYSTEM_TRAY_S" & $d.defaultScreen()).cstring, 0)
    let managerAtom = d.XInternAtom("MANAGER", 0)
    let opcode = d.XInternAtom("_NET_SYSTEM_TRAY_OPCODE", 0)
    var manager: xlib.Window
    var plug: xlib.Window
    proc createManager(useAlpha = false) =
      ## Publishes a manager and announces its appearance after the client starts.
      manager = d.XCreateSimpleWindow(root, 0, 0, 100, 60, 0, 0, 0xffffff)
      if useAlpha:
        var info: XVisualInfo
        d.XMatchVisualInfo(d.defaultScreen(), 32, 4, info.addr)
        doAssert info.visual != nil, "Xvfb must expose an ARGB visual"
        d.XChangeProperty(manager, d.XInternAtom("_NET_SYSTEM_TRAY_VISUAL", 0),
          d.XInternAtom("VISUALID", 0), 32, pmReplace, info.visualid.addr, 1)
      d.XSetSelectionOwner(selection, manager)
      d.XMapWindow(manager)
      var event: XEvent
      event.client = XClientMessageEvent(kind: xeClientMessage, window: root,
        message_type: managerAtom, format: 32)
      event.client.data.l[1] = selection.clong
      event.client.data.l[2] = manager.clong
      d.XSendEvent(root, false, StructureNotifyMask, event.addr)
      d.XSync()
    proc waitDock() =
      ## Handles a real docking request and embeds the advertised plug.
      let deadline = getMonoTime() + initDuration(seconds = 5)
      plug = 0
      while plug == 0 and getMonoTime() < deadline:
        while d.XPending() > 0:
          var event: XEvent
          d.XNextEvent(event.addr)
          if event.kind == xeClientMessage and event.client.message_type == opcode:
            doAssert event.client.data.l[1] == 0
            plug = event.client.data.l[2].culong
            discard d.reparent(plug, manager, 0, 0)
            d.XResizeWindow(plug, 32, 24)
            d.XMapWindow(plug)
            var embedded: XEvent
            embedded.client = XClientMessageEvent(kind: xeClientMessage, window: plug,
              message_type: d.XInternAtom("_XEMBED", 0), format: 32)
            embedded.client.data.l[3] = manager.clong
            d.XSendEvent(plug, false, NoEventMask, embedded.addr)
            d.XSync()
        sleep(1)
      doAssert plug != 0, "No XEmbed docking request received"
    proc pixel(): culong =
      ## Reads the rendered center pixel without inspecting backend state.
      let image = d.XGetImage(plug, 16, 12, 1, 1, high(culong), 2)
      doAssert image != nil
      result = XGetPixel(image, 0, 0)
      discard XDestroyImage(image)
    var host: Host
    if withSni:
      host = newHost()
      createManager()
    let child = startProcess(getAppFilename(), args = ["--app"], options = {poParentStreams})
    defer: child.close()
    sleep(100)
    if withSni:
      host.waitRegistration()
      doAssert host.propertyText("Title") == "Initial"
      while d.XPending() > 0:
        var event: XEvent
        d.XNextEvent(event.addr)
        doAssert event.kind != xeClientMessage or event.client.message_type != opcode,
          "Both tray backends registered an icon"
      host.close()
    else:
      createManager()
    waitDock()
    let firstDeadline = getMonoTime() + initDuration(seconds = 5)
    while pixel() != 0xe393a7 and getMonoTime() < firstDeadline: sleep(1)
    doAssert pixel() == 0xe393a7, "Transparent icon did not blend with the tray background"
    d.XDestroyWindow(manager)
    d.XSync()
    sleep(100)
    createManager(true)
    waitDock()
    let alphaDeadline = getMonoTime() + initDuration(seconds = 5)
    while pixel() != 0x80641428.culong and getMonoTime() < alphaDeadline: sleep(1)
    doAssert pixel() == 0x80641428.culong, "ARGB visual did not preserve premultiplied alpha"
    sendButton(d, plug, 1)
    let deadline = getMonoTime() + initDuration(seconds = 5)
    while (pixel() and 0xffffff) != 0x00ff00 and getMonoTime() < deadline: sleep(1)
    doAssert (pixel() and 0xffffff) == 0x00ff00, "Updated icon was not painted"
    sendButton(d, plug, 3)
    var popup: xlib.Window
    while popup == 0 and getMonoTime() < deadline:
      var rootOut, parent: xlib.Window
      var windows: ptr UncheckedArray[xlib.Window]
      var count: cuint
      discard d.children(root, rootOut.addr, parent.addr, windows.addr, count.addr)
      for index in 0..<count.int:
        let candidate = windows[index]
        if candidate != manager:
          var attrs: XWindowAttributes
          d.XGetWindowAttributes(candidate, attrs.addr)
          if attrs.overrideRedirect and attrs.mapState == 2:
            popup = candidate
      if windows != nil: XFree(windows)
      sleep(1)
    doAssert popup != 0, "No XEmbed popup menu was displayed"
    sendKey(d, popup, 0xff1b)
    sleep(30)
    doAssert d.XGrabPointer(root, 0, ButtonPressMask, GrabModeAsync,
      GrabModeAsync, 0, 0, CurrentTime) == GrabSuccess, "Popup retained its grab after Escape"
    d.XUngrabPointer(CurrentTime)
    d.XSync()
    sendButton(d, plug, 3)
    sleep(30)
    var rootOut, parent: xlib.Window
    var windows: ptr UncheckedArray[xlib.Window]
    var count: cuint
    discard d.children(root, rootOut.addr, parent.addr, windows.addr, count.addr)
    popup = 0
    for index in 0..<count.int:
      if windows[index] != manager:
        var attrs: XWindowAttributes
        d.XGetWindowAttributes(windows[index], attrs.addr)
        if attrs.overrideRedirect and attrs.mapState == 2: popup = windows[index]
    if windows != nil: XFree(windows)
    doAssert popup != 0
    if withSni:
      sendKey(d, popup, 0xff54)
      sendKey(d, popup, 0xff0d)
    else:
      sendButton(d, popup, 1, false)
      sendButton(d, popup, 1)
    doAssert child.waitForExit(5000) == 0
    d.XDestroyWindow(manager)
    d.XSync()

  proc testPending() =
    ## Checks input validation and removal while neither tray host is present.
    hideTrayIcon()
    var failed = false
    try: showTrayIcon(nil, "", nil)
    except WindyError: failed = true
    doAssert failed
    failed = false
    try: showTrayIcon(icon(), "\xff", nil)
    except WindyError: failed = true
    doAssert failed
    showTrayIcon(icon(), "Pending", nil)
    for unused in 0..<20:
      pollEvents()
      sleep(1)
    hideTrayIcon()
    hideTrayIcon()

  proc suite() =
    ## Starts a private X server; the outer process supplies a private session bus.
    let server = startProcess("Xvfb", args = ["-displayfd", "1", "-screen", "0",
      "1280x720x24", "-nolisten", "tcp"], options = {poUsePath})
    defer:
      server.terminate()
      discard server.waitForExit(5000)
      server.close()
    let displayNumber = server.outputStream.readLine()
    doAssert displayNumber.len > 0 and displayNumber.allCharsInSet({'0'..'9'})
    putEnv("DISPLAY", ":" & displayNumber)
    testPending()
    testSni()
    when HasX11:
      testXembed()
      testXembed(true)

  if paramCount() > 0 and paramStr(1) == "--app":
    app()
  elif paramCount() > 0 and paramStr(1) == "--isolated":
    suite()
  else:
    # Never acquire tray ownership or create windows on the user's session.
    let isolated = startProcess("dbus-run-session", args = ["--", getAppFilename(),
      "--isolated"], options = {poUsePath, poParentStreams})
    defer: isolated.close()
    doAssert isolated.waitForExit(90000) == 0
