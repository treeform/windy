import genny, windy

var lastError: ref WindyError

proc takeError(): string =
  result = lastError.msg
  lastError = nil

proc checkError(): bool =
  result = lastError != nil

exportProcs:
  checkError
  takeError

exportRefObject Window:
  fields:
    visible
    decorated
    resizable
    size
    pos
  constructor:
    newWindow
  procs:
    makeContextCurrent
    swapBuffers

exportProcs:
  init
  pollEvents

writeFiles("bindings/generated", "Windy")

include generated/internal
