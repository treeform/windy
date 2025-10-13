import common, internal, std/asyncdispatch, std/httpclient, std/random, std/strutils, std/tables, ws, std/times, zippy

when defined(emscripten):
  {.error: "windy/http is not supported on emscripten".}

type
  HttpRequestState = ref object
    url, verb: string
    headers: seq[HttpHeader]
    requestBody: string
    deadline: float64
    canceled: bool

    onError: HttpErrorCallback
    onResponse: HttpResponseCallback
    onUploadProgress: HttpProgressCallback
    onDownloadProgress: HttpProgressCallback

    client: AsyncHttpClient

  WebSocketState = ref object
    url: string
    deadline: float64
    closed: bool

    onError: HttpErrorCallback
    onOpen, onClose: common.Callback
    onMessage: WebSocketMessageCallback

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

proc newHttpRequestHandle(): HttpRequestHandle =
  let state = HttpRequestState()

  while true:
    result = windyRand.rand(int.high).HttpRequestHandle
    if result notin httpRequests and result.WebSocketHandle notin webSockets:
      httpRequests[result] = state
      break

proc newWebSocketHandle(): WebSocketHandle =
  let state = WebSocketState()

  while true:
    result = windyRand.rand(int.high).WebSocketHandle
    if result.HttpRequestHandle notin httpRequests and result notin webSockets:
      webSockets[result] = state
      break

proc cancel*(handle: HttpRequestHandle) {.raises: [].} =
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil:
    return
  state.canceled = true
  try:
    state.client.close()
  except:
    discard

proc close*(handle: WebSocketHandle) {.raises: [].} =
  let state = webSockets.getOrDefault(handle, nil)
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

  let state = httpRequests.getOrDefault(handle, nil)
  if state.canceled:
    return

  state.client = newAsyncHttpClient()

  let onProgressChanged = proc(total, progress, speed: BiggestInt) {.async.} =
    if not state.canceled and state.onDownloadProgress != nil:
      let total = if total == 0: -1 else: total.int
      try:
        state.onDownloadProgress(progress.int, total.int)
      except:
        handle.cancel()
        httpRequests.del(handle)
        if state.onError != nil:
          state.onError(getCurrentExceptionMsg())

  state.client.onProgressChanged =
    cast[ProgressChangedProc[Future[void]]](onProgressChanged)

  let headers = newHttpHeaders()
  for header in state.headers:
    headers[header.key] = header.value

  let httpResponse = HttpResponse()

  try:
    let verb =
      case state.verb.toUpperAscii():
      of "GET": HttpGet
      of "POST": HttpPost
      of "PUT": HttpPut
      of "PATCH": HttpPatch
      of "DELETE": HttpDelete
      else:
        raise newException(ValueError, "Invalid verb: " & state.verb)
    let response = await state.client.request(
      state.url,
      verb,
      state.requestBody,
      headers
    )

    if state.canceled:
      handle.cancel()
    else:
      httpResponse.code = response.code.int
      httpResponse.body = await response.body

      for key, value in response.headers:
        httpResponse.headers[key] = value

      if httpResponse.headers["content-encoding"].toLowerAscii() == "gzip":
        httpResponse.body = uncompress(httpResponse.body, dfGzip)

      if not state.canceled and state.onDownloadProgress != nil:
        state.onDownloadProgress(httpResponse.body.len, httpResponse.body.len)
      if not state.canceled and state.onResponse != nil:
        state.onResponse(httpResponse)

    # Handle is always removed after all callbacks (but before onError)
    httpRequests.del(handle)
  except:
    httpRequests.del(handle)
    if not state.canceled and state.onError != nil:
      state.onError(getCurrentExceptionMsg())

proc webSocketTasklet(handle: WebSocketHandle) {.async.} =
  await sleepAsync(0) # Sleep until next poll

  let state = webSockets.getOrDefault(handle, nil)
  if state.closed:
    return

  var onOpenCalled: bool
  try:
    state.webSocket = await newWebSocket(state.url)
    if state.closed:
      state.webSocket.hangup()
    else:
      onOpenCalled = true
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
    webSockets.del(handle)
    if not state.closed and state.onError != nil:
      state.onError(getCurrentExceptionMsg())

  webSockets.del(handle)

  if state.webSocket != nil and state.webSocket.readyState != Closed:
    try:
        state.webSocket.hangup()
    except:
      discard

  if onOpenCalled and state.onClose != nil:
    state.onClose()

proc startTasklet(handle: HttpRequestHandle) =
  try:
    usingHttpDispatcher:
      asyncCheck handle.httpRequestTasklet()
  except:
    quit("Failed to start HTTP request tasklet")

proc startTasklet(handle: WebSocketHandle) =
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

proc startHttpRequest*(
  url: string,
  verb = "GET",
  headers = newSeq[HttpHeader](),
  body = "",
  deadline = defaultHttpDeadline
): HttpRequestHandle {.raises: [].} =
  result = newHttpRequestHandle()

  var headers = headers
  headers.addDefaultHeaders()

  let state = httpRequests.getOrDefault(result, nil)
  state.url = url
  state.verb = verb
  state.headers = headers
  state.requestBody = body
  state.deadline = deadline

  result.startTasklet()

proc deadline*(handle: HttpRequestHandle): float64 =
    let state = httpRequests.getOrDefault(handle, nil)
    if state == nil:
      return
    state.deadline

proc `deadline=`*(handle: HttpRequestHandle, deadline: float64) =
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil:
    return
  state.deadline = deadline

proc `onError=`*(
  handle: HttpRequestHandle,
  callback: HttpErrorCallback
) =
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil:
    return
  state.onError = callback

proc `onResponse=`*(
  handle: HttpRequestHandle,
  callback: HttpResponseCallback
) =
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil:
    return
  state.onResponse = callback

proc `onUploadProgress=`*(
  handle: HttpRequestHandle,
  callback: HttpProgressCallback
) =
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil:
    return
  state.onUploadProgress = callback

proc `onDownloadProgress=`*(
  handle: HttpRequestHandle,
  callback: HttpProgressCallback
) =
  let state = httpRequests.getOrDefault(handle, nil)
  if state == nil:
    return
  state.onDownloadProgress = callback

proc openWebSocket*(
  url: string,
  deadline = defaultHttpDeadline
): WebSocketHandle {.raises: [].} =
  result = newWebSocketHandle()

  let state = webSockets.getOrDefault(result, nil)
  state.url = url
  state.deadline = deadline

  result.startTasklet()

proc `onError=`*(
  handle: WebSocketHandle,
  callback: HttpErrorCallback
) =
  let state = webSockets.getOrDefault(handle, nil)
  if state == nil:
    return
  state.onError = callback

proc `onOpen=`*(
  handle: WebSocketHandle,
  callback: common.Callback
) =
  let state = webSockets.getOrDefault(handle, nil)
  if state == nil:
    return
  state.onOpen = callback

proc `onMessage=`*(
  handle: WebSocketHandle,
  callback: WebSocketMessageCallback
) =
  let state = webSockets.getOrDefault(handle, nil)
  if state == nil:
    return
  state.onMessage = callback

proc `onClose=`*(
  handle: WebSocketHandle,
  callback: common.Callback
) =
  let state = webSockets.getOrDefault(handle, nil)
  if state == nil:
    return
  state.onClose = callback
