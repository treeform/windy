import windy

# WebSockets do not block.

# All callbacks are called on the main thread.

# You can have many WebSockets open at the same time.

# Calling openWebSocket never throws an exception.
# If there is any error, onError will be called during
# the next pollEvents (or later).

let req = openWebSocket("wss://stream.pushbullet.com/websocket/test")

req.onError = proc(msg: string) =
  echo "onError: " & msg

req.onOpen = proc() =
  echo "onOpen"

req.onMessage = proc(msg: string, kind: WebSocketMessageKind) =
  echo "onMessage: ", msg

req.onClose = proc() =
  echo "onClose"

# Closing the window exits the demo
let window = newWindow("Windy Basic", ivec2(1280, 800))
while not window.closeRequested:
  pollEvents()
