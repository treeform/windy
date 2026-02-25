when defined(wayland):
  include wayland
else:
  include x11
  # include x11_2
