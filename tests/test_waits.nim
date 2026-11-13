import
  std/[atomics, monotimes, os, times],
  windy

when defined(windows):
  import std/winlean

proc processCpuTime(): float =
  ## Measures CPU consumption without Windows clock() counting elapsed time.
  when defined(windows):
    var created, exited, kernel, user: winlean.FILETIME
    doAssert getProcessTimes(
      getCurrentProcess(),
      created,
      exited,
      kernel,
      user
    ) != 0
    result = (rdFileTime(kernel) + rdFileTime(user)).float / 10_000_000
  else:
    result = cpuTime()

proc delayedWake(ready: ptr Atomic[bool]) {.thread.} =
  ## Wakes the event queue after the main thread enters its blocking wait.
  sleep(40)
  ready[].store(true)
  wakeEvents()

proc testWaits() =
  ## Checks a hidden native window sleeps and wakes without continuous frames.
  let window = newWindow("Hidden event wait test", ivec2(160), visible = false)
  defer:
    window.close()
  var frames = 0
  window.onFrame = proc() =
    ## Records callback ordering without presenting or drawing a frame.
    inc frames
  for i in 0 ..< 5:
    pollEvents()
  var waited = false
  for i in 0 ..< 10:
    let
      started = getMonoTime()
      beforeCpu = processCpuTime()
      beforeFrames = frames
    waitEvents(120)
    let
      elapsed = (getMonoTime() - started).inMilliseconds
      cpu = processCpuTime() - beforeCpu
    doAssert frames == beforeFrames + 1
    if elapsed >= 90:
      doAssert cpu < 0.03, "Native waiting should consume little CPU."
      echo "Idle wait: ", elapsed, " ms, CPU: ", cpu, " seconds"
      waited = true
      break
  doAssert waited, "The hidden event queue never became idle."
  block:
    wakeEvents()
    var started = getMonoTime()
    waitEvents(600)
    doAssert (getMonoTime() - started).inMilliseconds < 100
    var
      ready: Atomic[bool]
      poster: Thread[ptr Atomic[bool]]
    createThread(poster, delayedWake, addr ready)
    started = getMonoTime()
    while not ready.load():
      waitEvents(600)
      doAssert (getMonoTime() - started).inMilliseconds < 400,
        "The worker wake did not interrupt native waiting."
    let elapsed = (getMonoTime() - started).inMilliseconds
    joinThread(poster)
    doAssert elapsed >= 20 and elapsed < 400
    echo "Native wake: ", elapsed, " ms"
  echo "Hidden native wait tests passed."

testWaits()
