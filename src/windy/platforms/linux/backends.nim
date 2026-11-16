import std/strutils

const
  windyBackends* {.strdefine.} = "x11"
  HasX11* = "x11" in windyBackends.split(',')
  HasFbdev* = "fbdev" in windyBackends.split(',')
  HasDrm* = "drm" in windyBackends.split(',')
  HasDirect* = HasFbdev or HasDrm

type
  LinuxBackend* = enum
    X11Backend, FbdevBackend, DrmBackend
  LinuxWindowOptions* = object
    device*, output*, touchDevice*: string
    rotation*, touchRotation*: int
    gpuPixels*: bool
      ## Opt into a double-buffered X11 OpenGL drawable in CPU pixel builds.

static:
  for backend in windyBackends.split(','):
    doAssert backend in ["x11", "fbdev", "drm"], "Unknown Windy backend"
