import
  ../../../common,
  ../backends,
  ./[drm, framebuffer, touch]

type
  DirectWindowState* = ref object
    fb*: Framebuffer
    drm*: DrmDisplay
    screen*: DrmScreen
    touch*: TouchReader
    device*, title*: string
    backend*: LinuxBackend
    closed*, closeRequested*: bool
    contacts*: seq[TouchContact]
