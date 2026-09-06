when defined(macosx):
  include ../src/windy/platforms/macos/platform

  objc:
    proc retainCount(self: ID): uint

  when defined(useCpu):
    proc testCpuImages() =
      ## Checks image ownership after replacement and repeated close.
      let
        window = newWindow("CPU ownership", ivec2(32, 32), visible = false)
        image = newImage(32, 32)
      window.presentPixels(image)
      let first = window.cpuImage.ID
      first.retain()
      defer:
        first.release()
      let firstCount = first.retainCount()
      window.presentPixels(image)
      doAssert first.retainCount() == firstCount - 1
      let last = window.cpuImage.ID
      last.retain()
      defer:
        last.release()
      let lastCount = last.retainCount()
      window.close()
      doAssert last.retainCount() == lastCount - 1
      doAssert window.cpuImage.int == 0
      window.close()
      window.presentPixels(image)
      doAssert window.cpuImage.int == 0

    testCpuImages()

  proc testFrameClosures() =
    ## Checks closing and creating windows during frame callbacks.
    let
      first = newWindow("First", ivec2(32, 32), visible = false)
      second = newWindow("Second", ivec2(32, 32), visible = false)
      third = newWindow("Third", ivec2(32, 32), visible = false)
    var
      child: Window
      thirdFrames, childFrames: int
    first.onFrame = proc() =
      ## Closes the current and next windows and creates another window.
      first.close()
      second.close()
      child = newWindow("Child", ivec2(32, 32), visible = false)
      child.onFrame = proc() =
        ## Counts frames for the newly created window.
        inc childFrames
    second.onFrame = proc() =
      ## Rejects callbacks for a window closed earlier in this frame.
      doAssert false, "Closed window received a frame"
    third.onFrame = proc() =
      ## Counts frames for the surviving window.
      inc thirdFrames
    pollEvents()
    doAssert first.closed and second.closed
    doAssert thirdFrames == 1 and childFrames == 0
    pollEvents()
    doAssert thirdFrames == 2 and childFrames == 1
    third.close()
    child.close()

  testFrameClosures()

  proc testWindowOwnership() =
    ## Checks that closing releases the view and its tracking area.
    let
      window = newWindow("View ownership", ivec2(32, 32), visible = false)
      view = window.inner.contentView.ID
    view.retain()
    defer:
      view.release()
    autoreleasepool:
      discard updateTrackingAreas(view, s"updateTrackingAreas")
    let tracking = window.trackingArea.ID
    doAssert tracking.int != 0
    tracking.retain()
    defer:
      tracking.release()
    window.close()
    for i in 0 ..< 5:
      drainEvents()
    doAssert view.retainCount() == 1
    doAssert tracking.retainCount() == 1
    doAssert window.trackingArea.int == 0

  testWindowOwnership()
  echo "Windy macOS regression tests passed"
else:
  echo "Windy macOS regression tests skipped"
