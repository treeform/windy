import windy

# HTTP requests do not block.

# All callbacks are called on the main thread.

# You can have many requests in-flight at the same time.

# Calling startHttpRequest never throws an exception.
# If there is any error, onError will be called during
# the next pollEvents (or later).

when not defined(emscripten):
  let req = startHttpRequest("https://www.google.com")
else:
  # Fetch from the root directory.
  let req = startHttpRequest("/")

req.onError = proc(msg: string) =
  echo "onError: " & msg

req.onResponse = proc(response: HttpResponse) =
  echo "onResponse: code=", $response.code, ", len=", response.body.len

# Closing the window exits the demo
let window = newWindow("Windy Basic", ivec2(1280, 800))
while not window.closeRequested:
  pollHttp()
  pollEvents()
