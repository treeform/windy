import windy, random, tables, times

import std/asyncdispatch
import std/httpclient {.all.}

type
  HttpResponse = ref object
    code: int
    body: string

  Handle = int

  HttpRequestState = ref object
    url: string
    client: AsyncHttpClient
    response: AsyncResponse
    onResponse: proc(response: HttpResponse)
    errorMsg: string
    onError: proc(msg: string)
    onDownloadProgress: proc(progress, total: int)
    canceled: bool

var
  httpRequests: Table[Handle, HttpRequestState]


proc cancel(handle: Handle) =
  if handle in httpRequests:
    httpRequests[handle].canceled = true
    httpRequests[handle].client.close()

proc httpTasklet(handle: Handle, state: HttpRequestState) {.async.} =
  await sleepAsync(0) # Sleep until next poll.
  echo "httpTasklet"
  if state.canceled:
    echo "exit before start"
    return
  try:
    state.client = newAsyncHttpClient()
    proc onProgressChanged(total, progress, speed: BiggestInt) {.async.} =
      if state.onDownloadProgress != nil:
        state.onDownloadProgress(progress.int, total.int)

    state.client.onProgressChanged = cast[ProgressChangedProc[Future[void]]](onProgressChanged)
    state.response = await state.client.request(state.url, "GET")

    if state.canceled:
      handle.cancel()
    else:
      let httpResponse = HttpResponse()
      httpResponse.code = state.response.code.int
      httpResponse.body = await state.response.body

      if state.onDownloadProgress != nil:
        state.onDownloadProgress(httpResponse.body.len, httpResponse.body.len)
      if state.onResponse != nil:
        state.onResponse(httpResponse)

  except:
    if not state.canceled and state.onError != nil:
      state.onError(getCurrentExceptionMsg())

  httpRequests.del(handle)

proc startHttpRequest(url: string): Handle {.raises:[].} =
  var state = HttpRequestState()
  state.url = url
  result = rand(int.high)
  httpRequests[result] = state
  try:
    asyncCheck httpTasklet(result, state)
  except:
    echo getCurrentExceptionMsg()

proc `onResponse=`(handle: Handle, callback: proc(response: HttpResponse)) =
  if handle in httpRequests:
    httpRequests[handle].onResponse = callback

proc `onError=`(handle: Handle, callback: proc(msg: string)) =
  if handle in httpRequests:
    httpRequests[handle].onError = callback

proc `onDownloadProgress=`(handle: Handle, callback: proc(progress, total: int)) =
  if handle in httpRequests:
    httpRequests[handle].onDownloadProgress = callback

proc pollHttp() {.raises:[].} =
  try:
    if hasPendingOperations():
      poll(0)
  except:
    echo getCurrentExceptionMsg()






# HTTP requests do not block.

# All callbacks are called on the main thread.

# You can have many requests in-flight at the same time.

# Calling startHttpRequest never throws an exception.
# If there is any error, onError will be called during
# the next pollEvents (or later).

let req = startHttpRequest("https://dl3.pushbulletusercontent.com/m6hUaSK4JPsv2sB5WyL93ro4yaaKmAyC/Screenshot_20220212-170517.png")

req.onError = proc(msg: string) =
  echo "onError: " & msg

req.onResponse = proc(response: HttpResponse) =
  echo "onResponse: code=", $response.code, ", len=", response.body.len
  writeFile("tmp.png", response.body)

req.onDownloadProgress = proc(progress, total: int) =
  echo("Downloaded ", progress, " of ", total)
  req.cancel()

echo "handles set"

# Closing the window exits the demo
let window = newWindow("Windy Basic", ivec2(1280, 800))
while not window.closeRequested:
  pollEvents()
  pollHttp()
