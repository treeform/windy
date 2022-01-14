import windy

when defined(windows):
  # Monitors API only currently supported on Windows

  let monitors = getMonitors()
  for monitor in monitors:
    echo monitor
