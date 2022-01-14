import pixie, windy

when defined(windows):
  # Displays API only currently supported on Windows

  let displays = getDisplays()
  for display in displays:
    echo display
