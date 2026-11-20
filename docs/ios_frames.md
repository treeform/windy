# iOS frame scheduling

UIKit owns the iOS event loop. Windows render continuously at 60 frames per
second by default, so existing games keep their normal frame callback.

Applications can opt into on-demand callbacks:

```nim
window.continuousRendering = false
window.onFrame = proc() =
  drawInterface()
  # Request another callback only when an animation or application timer needs it.
  window.requestFrame(500)
```

`requestFrame()` requests the next main-loop callback. A positive delay is in
milliseconds; later requests never postpone an earlier deadline. Requests
coalesce, and a callback may schedule another callback. With no pending request,
the MetalKit view is paused and no display-refresh callbacks occur.
Immediate requests retain the normal maximum cadence of 60 callbacks per second,
including animation requests made inside a frame. New input wakes the next
permitted callback instead of waiting for a longer animation deadline.

Touch, pointer, keyboard, text, resize, and focus events wake the window
automatically. Worker threads can call `wakeEvents()` to wake the application
callback. An application with polled background work must schedule its next
poll as well as its next UI animation. Deactivation cancels pending callbacks;
reactivation requests one frame so the application can renew its deadlines.

Run the platform bridge checks on macOS:

```sh
nim r --path:tests -d:windyIosTesting tests/ios_inputs.nim
clang -fobjc-arc -framework Foundation tests/ios_frames.m -o /tmp/windy-ios-frames
/tmp/windy-ios-frames
```

With a booted Apple Silicon iOS simulator, measure actual MetalKit callbacks:

```sh
python3 tools/test_ios_frames.py
```

The isolated test app measures one second of continuous callbacks followed by
one second of on-demand idle, and checks deadline, worker, and lifecycle wakes.
It counts callback work; it does not measure physical-device battery discharge.
