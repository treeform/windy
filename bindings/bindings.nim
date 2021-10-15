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
  constructor:
    newWindow
  procs:
    makeContextCurrent
    swapBuffers

exportProcs:
  init

writeFiles("bindings/generated", "Windy")

include generated/internal
