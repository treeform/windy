import windy

# WebSockets do not block.

# All callbacks are called on the main thread.

# You can have many WebSockets open at the same time.

# Calling openWebSocket never throws an exception.
# If there is any error, onError will be called during
# the next pollEvents (or later).

let ws = openWebSocket("wss://stream.pushbullet.com/websocket/test")

ws.onError = proc(msg: string) =
  echo "onError: " & msg

ws.onOpen = proc() =
  echo "onOpen"

ws.onMessage = proc(msg: string, kind: WebSocketMessageKind) =
  echo "onMessage: ", msg

ws.onClose = proc() =
  echo "onClose"

# Closing the window exits the demo
let window = newWindow("Windy Basic", ivec2(1280, 800))
while not window.closeRequested:
  pollEvents()
