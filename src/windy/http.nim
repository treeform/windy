import common, internal, std/asyncdispatch, std/httpclient, std/random, std/strutils, std/tables, ws, std/times

type
  HttpRequestState* = ref object
    url*, verb*: string
    headers*: seq[HttpHeader]
    requestBody*: string
    deadline*: float64
    canceled*: bool

    onError*: HttpErrorCallback
    onResponse*: HttpResponseCallback
    onUploadProgress*: HttpProgressCallback
    onDownloadProgress*: HttpProgressCallback

    client: AsyncHttpClient

  WebSocketState* = ref object
    url*: string
    deadline*: float64
    closed*: bool

    onError*: HttpErrorCallback
    onOpen*, onClose*: common.Callback
    onMessage*: WebSocketMessageCallback

    webSocket: WebSocket

let httpDispatcher = newDispatcher()

var
  httpRequests: Table[HttpRequestHandle, HttpRequestState]
  webSockets: Table[WebSocketHandle, WebSocketState]

template usingHttpDispatcher(body: untyped) =
  let prevDispatcher = getGlobalDispatcher()
  setGlobalDispatcher(httpDispatcher)
  try:
    body
  finally:
    setGlobalDispatcher(prevDispatcher)

proc newHttpRequestHandle*(): HttpRequestHandle =
  let state = HttpRequestState()

  while true:
    result = windyRand.rand(int.high).HttpRequestHandle
    if result notin httpRequests and result.WebSocketHandle notin webSockets:
      httpRequests[result] = state
      break

proc newWebSocketHandle*(): WebSocketHandle =
  let state = WebSocketState()

  while true:
    result = windyRand.rand(int.high).WebSocketHandle
    if result.HttpRequestHandle notin httpRequests and result notin webSockets:
      webSockets[result] = state
      break

proc getState*(handle: HttpRequestHandle): HttpRequestState =
  httpRequests.getOrDefault(handle, nil)

proc getState*(handle: WebSocketHandle): WebSocketState =
  webSockets.getOrDefault(handle, nil)

proc cancel*(handle: HttpRequestHandle) =
  let state = handle.getState()
  if state == nil:
    return
  state.canceled = true
  state.client.close()

proc close*(handle: WebSocketHandle) =
  let state = handle.getState()
  if state == nil:
    return
  state.closed = true
  if state.webSocket != nil:
    try:
      state.webSocket.hangup()
    except:
      discard

proc httpRequestTasklet(handle: HttpRequestHandle) {.async.} =
  await sleepAsync(0) # Sleep until next poll

  let state = handle.getState()
  if state.canceled:
    return

  state.client = newAsyncHttpClient()

  let onProgressChanged = proc(total, progress, speed: BiggestInt) {.async.} =
    if state.onDownloadProgress != nil:
      let total = if total == 0: -1 else: total.int
      state.onDownloadProgress(progress.int, total.int)

  state.client.onProgressChanged =
    cast[ProgressChangedProc[Future[void]]](onProgressChanged)

  let headers = newHttpHeaders()
  for header in state.headers:
    headers[header.key] = header.value

  let httpResponse = HttpResponse()

  try:
    let response = await state.client.request(
      state.url,
      state.verb.toUpperAscii(),
      state.requestBody,
      headers
    )

    if state.canceled:
      handle.cancel()
    else:
      httpResponse.code = response.code.int
      httpResponse.body = await response.body
  except:
    if not state.canceled and state.onError != nil:
      state.onError(getCurrentExceptionMsg())
    httpRequests.del(handle)
    return

  if not state.canceled and state.onDownloadProgress != nil:
    state.onDownloadProgress(httpResponse.body.len, httpResponse.body.len)
  if not state.canceled and state.onResponse != nil:
    state.onResponse(httpResponse)

  httpRequests.del(handle)

proc webSocketTasklet(handle: WebSocketHandle) {.async.} =
  await sleepAsync(0) # Sleep until next poll

  let state = handle.getState()
  if state.closed:
    return

  var skipOnClose: bool
  try:
    state.webSocket = await newWebSocket(state.url)
    if state.closed:
      skipOnClose = true
      state.webSocket.hangup()
    else:
      if state.onOpen != nil:
        state.onOpen()
      while not state.closed:
        let (opcode, data) = await state.webSocket.receivePacket()
        case opcode:
        of Text:
          if state.onMessage != nil:
            state.onMessage(data, Utf8Message)
        of Binary:
          if state.onMessage != nil:
            state.onMessage(data, BinaryMessage)
        of Ping:
          await state.webSocket.send(data, Pong)
        of Pong:
          discard
        of Cont:
          discard
        of Close:
          state.webSocket.hangup()
          break
  except:
    if not state.closed and state.onError != nil:
      state.onError(getCurrentExceptionMsg())

  try:
    if state.webSocket.readyState != Closed:
      state.webSocket.hangup()
  except:
    discard

  if not skipOnClose and state.onClose != nil:
    state.onClose()

  webSockets.del(handle)

proc startTasklet*(handle: HttpRequestHandle) =
  try:
    usingHttpDispatcher:
      asyncCheck handle.httpRequestTasklet()
  except:
    quit("Failed to start HTTP request tasklet")

proc startTasklet*(handle: WebSocketHandle) =
  try:
    usingHttpDispatcher:
      asyncCheck handle.webSocketTasklet()
  except:
    quit("Failed to start WebSocket tasklet")

proc pollHttp*() =
  usingHttpDispatcher:
    if hasPendingOperations():
      poll(0)

  let now = epochTime()

  for handle, state in httpRequests:
    if state.deadline > 0 and state.deadline <= now:
      let msg = "Deadline of " & $state.deadline & " exceeded, time is " & $now
      handle.cancel()
      if state.onError != nil:
        state.onError(msg)

  for handle, state in webSockets:
    if state.deadline > 0 and state.deadline <= now and state.webSocket == nil:
      let msg = "Deadline of " & $state.deadline & " exceeded, time is " & $now
      handle.close()
      if state.onError != nil:
        state.onError(msg)
