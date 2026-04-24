import
  std/[locks, os, times],
  mummy, windy

const
  ServerHost = "127.0.0.1"
  ServerPortNumber = 17891
  ServerPort = Port(ServerPortNumber)
  TestTimeout = 5.0
  TestMessage = "windy ping"
  TestReply = "mummy pong: " & TestMessage

var
  stateLock: Lock
  serverOpened: bool
  serverReceived: bool
  serverClosed: bool
  clientOpened: bool
  clientReceived: bool
  clientClosed: bool
  clientError: string
  clientReply: string

proc withState(body: proc() {.gcsafe.}) {.gcsafe.} =
  ## Runs a state update while holding the test lock.
  withLock stateLock:
    body()

proc serverHasOpened(): bool =
  ## Returns whether Mummy reported the WebSocket open event.
  withLock stateLock:
    result = serverOpened

proc serverHasReceived(): bool =
  ## Returns whether Mummy received the expected binary message.
  withLock stateLock:
    result = serverReceived

proc serverHasClosed(): bool =
  ## Returns whether Mummy reported the WebSocket close event.
  withLock stateLock:
    result = serverClosed

proc pollUntil(done: proc(): bool, server: Server) =
  ## Polls Windy networking until the condition is true.
  let start = epochTime()
  while not done():
    pollHttp()
    if clientError.len > 0:
      raise newException(CatchableError, clientError)
    if epochTime() - start > TestTimeout:
      server.close()
      raise newException(
        CatchableError,
        "Timed out waiting for WebSocket test"
      )
    sleep(1)

proc httpHandler(request: Request) {.gcsafe.} =
  ## Upgrades WebSocket requests and rejects everything else.
  if request.path == "/ws" and request.httpMethod == "GET":
    discard request.upgradeToWebSocket()
  else:
    request.respond(404, emptyHttpHeaders(), "Not found")

proc websocketHandler(
  websocket: WebSocket,
  event: WebSocketEvent,
  message: Message
) {.gcsafe.} =
  ## Echoes one binary message back to the Windy client.
  case event
  of OpenEvent:
    withState(proc() {.gcsafe.} =
      serverOpened = true
    )
  of MessageEvent:
    withState(proc() {.gcsafe.} =
      serverReceived = message.kind == mummy.BinaryMessage and
        message.data == TestMessage
    )
    websocket.send(TestReply, mummy.BinaryMessage)
  of ErrorEvent:
    discard
  of CloseEvent:
    withState(proc() {.gcsafe.} =
      serverClosed = true
    )

proc serveThread(server: Server) {.thread.} =
  ## Runs Mummy until the main test thread closes it.
  server.serve(ServerPort, ServerHost)

proc main() =
  ## Tests Windy WebSocket send, receive, and close against Mummy.
  initLock(stateLock)
  defer:
    deinitLock(stateLock)

  let server = newServer(
    httpHandler,
    websocketHandler,
    workerThreads = 1,
    wsNoDelay = true
  )

  var worker: Thread[Server]
  createThread(worker, serveThread, server)
  server.waitUntilReady()

  let ws = openWebSocket(
    "ws://" & ServerHost & ":" & $ServerPortNumber & "/ws",
    noDelay = true
  )

  ws.onError = proc(msg: string) =
    clientError = msg

  ws.onOpen = proc() =
    clientOpened = true
    ws.send(TestMessage, windy.BinaryMessage)

  ws.onMessage = proc(msg: string, kind: WebSocketMessageKind) =
    clientReceived = kind == windy.BinaryMessage and msg == TestReply
    clientReply = msg
    ws.close()

  ws.onClose = proc() =
    clientClosed = true

  try:
    pollUntil(proc(): bool = clientOpened, server)
    doAssert clientOpened, "Windy WebSocket should open"

    pollUntil(proc(): bool = clientReceived, server)
    doAssert serverHasOpened(), "Mummy should receive an open event"
    doAssert serverHasReceived(), "Mummy should receive Windy binary message"
    doAssert clientReply == TestReply, "Windy should receive Mummy reply"

    pollUntil(proc(): bool = clientClosed and serverHasClosed(), server)
    doAssert clientClosed, "Windy should receive a close event"
    doAssert serverHasClosed(), "Mummy should receive a close event"
  finally:
    ws.close()
    server.close()
    joinThread(worker)

  echo "WebSocket send receive close ok"

when isMainModule:
  main()
