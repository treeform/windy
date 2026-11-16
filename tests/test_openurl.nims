when defined(windows):
  # Link the test's ShellExecuteW recorder instead of loading shell32.dll.
  switch("dynlibOverride", "shell32.dll")
