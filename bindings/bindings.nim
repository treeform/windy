import genny, windy

var lastError: ref WindyError

proc takeError(): string =
  result = lastError.msg
  lastError = nil

proc checkError(): bool =
  result = lastError != nil

proc isVisible(window: Window): bool =
  window.visible

proc show(window: Window) =
  window.visible = true

proc hide(window: Window) =
  window.visible = false

exportProcs:
  checkError
  takeError

exportRefObject App:
  discard

exportRefObject Window:
  constructor:
    newWindow
  procs:
    show
    hide
    isVisible
    makeContextCurrent
    swapBuffers

exportProcs:
  getApp
  init

writeFiles("bindings/generated", "Windy")

include generated/internal
