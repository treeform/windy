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

  echo "Windy macOS regression tests passed"
else:
  echo "Windy macOS regression tests skipped"
