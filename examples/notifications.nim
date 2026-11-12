import
  std/[monotimes, os, times],
  opengl, pixie, windy

when defined(linux) and not defined(emscripten):
  let
    window = newWindow("Notifications: N send, U update, D dismiss, Q quit", ivec2(640, 240))
    icon = newImage(32, 32)
  icon.fill(rgba(50, 130, 220, 255))
  loadExtensions()
  var notification: Notification

  proc clicked() =
    ## Reports a notification click without assuming the desktop permits focusing.
    echo "Notification clicked"
    window.title = "Notification clicked - N send, U update, D dismiss, Q quit"

  proc failed(message: string) =
    ## Shows asynchronous delivery errors in the example window and terminal.
    echo message
    window.title = message

  while not window.closeRequested:
    pollEvents()
    if window.buttonPressed[KeyN]:
      notification = sendNotification("Windy notification", "Click this notification to test the callback.",
        icon, clicked, failed)
    if window.buttonPressed[KeyU] and not notification.closed:
      notification.update("Windy notification updated", "This replaces the previous notification.", icon)
    if window.buttonPressed[KeyD]: notification.close()
    if window.buttonPressed[KeyQ]: window.closeRequested = true
    glClearColor(0.12, 0.16, 0.22, 1)
    glClear(GL_COLOR_BUFFER_BIT)
    window.swapBuffers()

  notification.close()
  let deadline = getMonoTime() + initDuration(seconds = 6)
  while notification.pending and getMonoTime() < deadline:
    pollEvents()
    sleep(10)
  window.close()
