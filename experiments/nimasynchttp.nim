import windy, random, tables, times

import std/asyncdispatch
import std/httpclient {.all.}

proc asyncProc(): Future[AsyncResponse] {.async.} =
  var client = newAsyncHttpClient()
  let body = await client.get("https://dl3.pushbulletusercontent.com/m6hUaSK4JPsv2sB5WyL93ro4yaaKmAyC/Screenshot_20220212-170517.png")
  return body


# ------------------

# let r = waitFor asyncProc()
# let data = waitFor r.body
# echo data.len
# writeFile("tmp2.png", data)



# ------------------

# var asyncReq = asyncProc()
# while not asyncReq.finished():
#   poll()

# let req = asyncReq.read()
# echo req.status


# let asyncBody = req.body

# while not asyncBody.finished():
#   poll()

# let data = asyncBody.read()
# echo data.len

# writeFile("tmp.png", data)
# echo "write file"


# ----------------

# var asyncReq = asyncProc()
# var asyncBody: Future[string]

# while true:
#   poll()



#   if asyncBody != nil:
#     if asyncBody.finished():
#       let data = asyncBody.read()
#       echo data.len
#       writeFile("tmp.png", data)
#       break
#   else:
#     if asyncReq.finished():
#       let res = asyncReq.read()
#       echo res.status
#       asyncBody = res.body

type

  HttpResponse = ref object
    code: int
    body: string

  Handle = int

  HttpRequestState = ref object
    finished: bool
    client: AsyncHttpClient
    res: Future[AsyncResponse]
    asyncBody: Future[string]
    response: HttpResponse
    onResponse: proc(response: HttpResponse)
    errorMsg: string
    onError: proc(msg: string)
    cancelRequested: bool

var
  httpRequests: Table[Handle, HttpRequestState]

proc startHttpRequest(url: string): Handle {.raises:[].} =
  var state = HttpRequestState()
  result = rand(int.high)
  httpRequests[result] = state
  try:
    state.client = newAsyncHttpClient()
    state.res = state.client.request(url, "GET")
  except:
    state.errorMsg = getCurrentExceptionMsg()

proc `onResponse=`(handle: Handle, callback: proc(response: HttpResponse)) =
  if handle in httpRequests:
    httpRequests[handle].onResponse = callback

proc `onError=`(handle: Handle, callback: proc(msg: string)) =
  if handle in httpRequests:
    httpRequests[handle].onError = callback

proc cancel(handle: Handle) =
  if handle in httpRequests:
    httpRequests[handle].cancelRequested = true

# var req: Handle = nil
let req = startHttpRequest("http://pushbullet.com/")
echo "started"

proc pollHttp() =
  if hasPendingOperations():
    try:
      let start = epochTime()
      poll(0)
      if epochTime() - start > 0.001:
        echo epochTime() - start
    except:
      echo "bad poll"

  for handle, state in httpRequests:
    if not state.finished:

      # if state.cancelRequested:
      #   if state.client.connected:
      #     state.client.close()
      #     state.finished = true

      if state.errorMsg != "":
        if state.onError != nil:
          state.onError(state.errorMsg)
        state.finished = true

      elif state.asyncBody != nil:
        if state.asyncBody.finished():
          try:
            state.response.body = state.asyncBody.read()
            state.finished = true
            if state.onResponse != nil:
              state.onResponse(state.response)
          except:
            if state.onError != nil:
              state.onError(getCurrentExceptionMsg())
            state.finished = true

      else:
        if state.res.finished():
          var res: AsyncResponse
          try:
            res = state.res.read()
            echo res.status
            state.response = HttpResponse()
            state.response.code = res.code.ord
            state.asyncBody = res.body
          except:
            if state.onError != nil:
              state.onError(getCurrentExceptionMsg())
            state.finished = true

req.onError = proc(msg: string) =
  echo "onError: " & msg

req.onResponse = proc(response: HttpResponse) =
  echo "onResponse: code=", $response.code, ", len=", response.body.len

  echo response.body.len
  writeFile("tmp.png", response.body)




# Closing the window exits the demo
let window = newWindow("Windy Basic", ivec2(1280, 800))
while not window.closeRequested:
  pollEvents()
  pollHttp()

  req.cancel()
