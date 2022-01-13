import pixie, windy

when defined(windows):
  # Custom cursor API only currently supported on Windows

  let window = newWindow("Windy Cursor", ivec2(1280, 800))
  window.makeContextCurrent()

  let
    cursor = newImage(32, 32)
    path = newPath()
  path.rect(rect(0, 0, 32, 32))
  cursor.fillPath(path, color(0.3, 0.6, 0.9, 1))

  window.useCustomCursor(cursor, ivec2(0, 0))

  while not window.closeRequested:
    pollEvents()
