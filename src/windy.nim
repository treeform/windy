import vmath, windy/common

export common, vmath

when defined(windows):
  import windy/platforms/win32/platform
elif defined(macosx):
  import windy/platforms/macos/platform
elif defined(linux):
  import windy/platforms/x11/platform

export platform
