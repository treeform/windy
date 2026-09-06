when defined(linux):
  include ../src/windy/platforms/linux/x11

  ## Plays the window manager side of the _NET_WM_SYNC_REQUEST handshake so
  ## it runs under a bare Xvfb. The rule under test: the sync counter is only
  ## updated after the ConfigureNotify for the request was handled and a
  ## frame has gone by, never before, and never without a request.

  proc counterValue(window: Window): XSyncValue =
    doAssert display.XSyncQueryCounter(window.xSyncCounter, result.addr) != 0

  proc sendSyncRequest(window: Window, lo: uint32, hi: int32) =
    ## Sends what a window manager sends right before resizing the window.
    let xaWMProtocols = display.XInternAtom("WM_PROTOCOLS", 0)
    let message = newClientMessage(
      window.handle,
      xaWMProtocols,
      [xaNetWMSyncRequest.clong, 0.clong, lo.clong, hi.clong]
    )
    window.handle.send(message)
    display.XSync()

  proc resize(window: Window, size: IVec2) =
    display.XResizeWindow(window.handle, size.x.uint32, size.y.uint32)
    display.XSync()

  proc testSyncRequestAck() =
    let window = newWindow("Sync", ivec2(200, 100), visible = false)
    doAssert window.xSyncCounter.int != 0, "Xvfb lacks the SYNC extension"

    var resizes: seq[IVec2]
    window.onResize = proc() =
      resizes.add window.size

    doAssert window.counterValue.lo == 0
    doAssert window.syncState == SyncIdle

    # A resize without a request never touches the counter.
    window.resize(ivec2(210, 110))
    pollEvents()
    doAssert resizes == @[ivec2(210, 110)]
    doAssert window.counterValue.lo == 0
    doAssert window.syncState == SyncIdle

    # Request and ConfigureNotify in one poll: the ack waits for a frame.
    window.sendSyncRequest(1, 0)
    window.resize(ivec2(300, 200))
    pollEvents()
    doAssert resizes[^1] == ivec2(300, 200)
    doAssert window.syncState == SyncConfigured
    doAssert window.counterValue.lo == 0, "acked before the resized frame"
    pollEvents()
    doAssert window.syncState == SyncIdle
    doAssert window.counterValue.lo == 1

    # Request in one poll, ConfigureNotify in a later one. The poll that saw
    # the request must not ack, and must not wait longer than the timeout.
    window.sendSyncRequest(2, 0)
    let start = epochTime()
    pollEvents()
    doAssert epochTime() - start < 1.0, "poll did not give up waiting"
    doAssert window.syncState == SyncRequested
    doAssert window.counterValue.lo == 1, "acked without a ConfigureNotify"
    pollEvents()
    doAssert window.counterValue.lo == 1
    window.resize(ivec2(400, 300))
    pollEvents()
    doAssert resizes[^1] == ivec2(400, 300)
    doAssert window.syncState == SyncConfigured
    doAssert window.counterValue.lo == 1
    pollEvents()
    doAssert window.syncState == SyncIdle
    doAssert window.counterValue.lo == 2

    # The full 64-bit value round-trips and a newer request wins.
    window.sendSyncRequest(3, 0)
    window.sendSyncRequest(5, 1)
    window.resize(ivec2(500, 400))
    pollEvents()
    pollEvents()
    let value = window.counterValue
    doAssert value.lo == 5 and value.hi == 1

    # Once idle, polling leaves the counter alone.
    pollEvents()
    doAssert window.counterValue.lo == 5
    doAssert window.syncState == SyncIdle

    window.close()

  testSyncRequestAck()
  echo "test_x11 passed"
