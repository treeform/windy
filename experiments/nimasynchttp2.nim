
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
    response: AsyncResponse
    onResponse: proc(response: HttpResponse)
    errorMsg: string
    onError: proc(msg: string)
    cancelRequested: bool

var
  httpRequests: Table[Handle, HttpRequestState]

proc httpTasklet(state: HttpRequestState) {.async.} =
  try:
    let client = newAsyncHttpClient()
    state.response = await client.request(state.url, "GET")
    let httpResponse = HttpResponse()
    httpResponse.code = state.response.code.int
    httpResponse.body = await state.response.body
    if state.onResponse != nil:
      state.onResponse(httpResponse)
  except:
    if state.onError != nil:
      state.onError(getCurrentExceptionMsg())

proc startHttpRequest(url: string): Handle {.raises:[].} =
  var state = HttpRequestState()
  state.url = url
  result = rand(int.high)
  httpRequests[result] = state
  try:
    asyncCheck httpTasklet(state)
  except:
    echo getCurrentExceptionMsg()

proc `onResponse=`(handle: Handle, callback: proc(response: HttpResponse)) =
  if handle in httpRequests:
    httpRequests[handle].onResponse = callback

proc `onError=`(handle: Handle, callback: proc(msg: string)) =
  if handle in httpRequests:
    httpRequests[handle].onError = callback

proc cancel(handle: Handle) =
  if handle in httpRequests:
    httpRequests[handle].cancelRequested = true

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

# Closing the window exits the demo
let window = newWindow("Windy Basic", ivec2(1280, 800))
while not window.closeRequested:
  pollEvents()
  pollHttp()
