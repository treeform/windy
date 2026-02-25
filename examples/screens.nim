import windy

when defined(windows) or defined(macosx) or defined(linux) or defined(emscripten):
  # Screens API supported on all major platforms; Linux uses X11 fallback for now.
  let screens = getScreens()
  for screen in screens:
    echo screen
