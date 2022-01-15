import windy

when defined(windows) or defined(macosx):
  # Screens API only currently supported on Windows and macOS

  let screens = getScreens()
  for screen in screens:
    echo screen
