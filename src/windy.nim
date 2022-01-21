import unicode, vmath, windy/common

when defined(windows):
  import windy/platforms/win32/platform
elif defined(macosx):
  import windy/platforms/macos/platform
elif defined(linux):
  import windy/platforms/linux/platform

export common, platform, unicode, vmath
