import
  ../../../common,
  ../backends,
  ./touch

when HasFbdev:
  import ../fbdev
when HasDrm:
  import ../drm

type
  DirectWindowState* = ref object
    when HasFbdev:
      fb*: Framebuffer
    when HasDrm:
      drm*: DrmDisplay
      screen*: DrmScreen
    touch*: TouchReader
    device*, title*: string
    backend*: LinuxBackend
    closed*, closeRequested*: bool
    contacts*: seq[TouchContact]
