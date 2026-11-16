import
  std/os,
  pixie, windy

when defined(windows):
  echo "This manual test replaces the clipboard with a small test image."
  let
    sample = newImage(2, 2)
    window = newWindow("Drop files here, then close to finish", ivec2(600, 400))
  sample[0, 0] = rgba(255, 0, 0, 255)
  sample[1, 0] = rgba(0, 255, 0, 128)
  sample[0, 1] = rgba(0, 0, 255, 255)
  sample[1, 1] = rgba(0, 0, 0, 0)
  setClipboardImage(sample)
  doAssert ImageContent in getClipboardContentKinds()
  let copied = getClipboardImage()
  doAssert copied != nil
  doAssert copied.width == sample.width and copied.height == sample.height
  doAssert copied.data == sample.data
  echo "Clipboard image round trip passed, including alpha and row order."
  window.onFileDropPaths = proc(paths: seq[string]) =
    ## Reports native paths without opening or loading the dropped files.
    echo "Dropped ", paths.len, " file paths at ", window.mousePos
    for path in paths:
      echo path
    window.title = "Received " & $paths.len & " paths"
  while not window.closeRequested:
    pollEvents()
    sleep(10)
  window.close()
else:
  echo "Run this manual test on Windows."
