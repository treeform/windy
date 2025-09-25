import pixie, windy

when defined(windows) or defined(macosx):
  # Custom cursor API only currently supported on Windows and macOS

  let window = newWindow("Windy Cursor", ivec2(1280, 800))
  window.makeContextCurrent()

  echo window.cursor

  let
    cursor = newImage(32, 32)
    path = newPath()
  path.rect(rect(0, 0, 32, 32))
  cursor.fillPath(path, color(0.3, 0.6, 0.9, 1))

  window.cursor = Cursor(kind: CustomCursor, image: cursor)

  echo window.cursor

  window.onButtonPress = proc(button: Button) =
    if button == MouseLeft:
      echo "Toggling cursor"
      case window.cursor.kind:
      of ArrowCursor:
        window.cursor = Cursor(kind: CustomCursor, image: cursor)
      else:
        window.cursor = Cursor(kind: ArrowCursor)

  while not window.closeRequested:
    pollEvents()
