when not defined(windyIosTesting):
  {.error: "Run with -d:windyIosTesting to use the native host mock.".}

include ../src/windy/platforms/ios/platform

var window: Window
runApplication(proc() =
  window = newWindow("Native close test", ivec2(640, 480))
  doAssert window.surfaceReady
  doAssert window.metalView != nil
)
doAssert windyIosMain(0, nil) == 0
var closeRequests = 0
window.onCloseRequest = proc() =
  inc closeRequests
  if closeRequests == 1:
    window.closeRequested = false
window.onFrame = proc() =
  window.closeRequested = true
native.callbacks.onFrame()
doAssert closeRequests == 1
doAssert not window.closed
doAssert not native.renderingStopped
native.callbacks.onFrame()
doAssert closeRequests == 2
doAssert window.closed
doAssert native.renderingStopped
doAssert window.onFrame == nil
doAssert window.onCloseRequest == nil
doAssert native.textInput.id.len == 0
native.callbacks.onFrame()
doAssert closeRequests == 2
echo "Native iOS initialization and close-request checks passed."
