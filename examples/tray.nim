import pixie, windy

when defined(windows):
  # Tray API only currently supported on Windows

  let window = newWindow("Windy Tray Icon", ivec2(1280, 800))
  window.makeContextCurrent()

  let
    icon = newImage(64, 64)
    path = newPath()
  path.circle(circle(vec2(32, 32), 26))
  icon.fillPath(path, color(0.3, 0.6, 0.9, 1))

  proc onTrayIconClick() =
    echo "Tray icon clicked"

  var menu: seq[TrayMenuEntry]
  menu.add(TrayMenuEntry(
    kind: TrayMenuOption,
    text: "Option 1",
    onClick: proc() =
      echo "Option 1 clicked"
  ))
  menu.add(TrayMenuEntry(
    kind: TrayMenuOption,
    text: "Option 2",
    onClick: proc() =
      echo "Option 2 clicked"
  ))
  menu.add(TrayMenuEntry(kind: TrayMenuSeparator))
  menu.add(TrayMenuEntry(
    kind: TrayMenuOption,
    text: "Quit Demo",
    onClick: proc() =
      window.closeRequested = true
  ))

  showTrayIcon(icon, "Demo", onTrayIconClick, menu)

  while not window.closeRequested:
    pollEvents()

  hideTrayIcon()
