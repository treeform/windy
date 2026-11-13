import
  std/[monotimes, os, posix, times],
  ../src/windy/platforms/linux/native/waits

proc delayedWake() {.thread.} =
  ## Posts an explicit wake after the main thread starts waiting.
  sleep(40)
  wakeNativeEvents()

proc delayedInput(descriptor: cint) {.thread.} =
  ## Makes an input descriptor readable without posting an explicit wake.
  sleep(40)
  var value = 'x'
  doAssert posix.write(descriptor, addr value, 1) == 1

proc testWaits() =
  ## Verifies idle blocking, queued waking, and descriptor readiness.
  initEventWait()
  block:
    let started = getMonoTime()
    waitNativeEvents(60, [])
    doAssert (getMonoTime() - started).inMilliseconds >= 40
  block:
    for i in 0 ..< 1000:
      wakeNativeEvents()
    let started = getMonoTime()
    waitNativeEvents(600, [])
    doAssert (getMonoTime() - started).inMilliseconds < 200
  block:
    var worker: Thread[void]
    createThread(worker, delayedWake)
    let started = getMonoTime()
    waitNativeEvents(600, [])
    let elapsed = (getMonoTime() - started).inMilliseconds
    joinThread(worker)
    doAssert elapsed >= 20 and elapsed < 400
  block:
    var
      descriptors: array[2, cint]
      worker: Thread[cint]
    doAssert posix.pipe(descriptors) == 0
    defer:
      discard posix.close(descriptors[0])
      discard posix.close(descriptors[1])
    createThread(worker, delayedInput, descriptors[1])
    let started = getMonoTime()
    waitNativeEvents(600, [descriptors[0]])
    let elapsed = (getMonoTime() - started).inMilliseconds
    joinThread(worker)
    doAssert elapsed >= 20 and elapsed < 400
    var value: char
    doAssert posix.read(descriptors[0], addr value, 1) == 1
    doAssert value == 'x'
  echo "Native event pipe tests passed."

testWaits()
