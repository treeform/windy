import
  x, xlib

{.passL: "-lXcursor".}

type
  XcursorPixel* = uint32
  XcursorDim* = uint32
  XcursorBool* = cint

  XcursorImage* {.bycopy.} = object
    version*: uint32          # Version of the image data.
    size*: XcursorDim         # Nominal size for matching.
    width*: XcursorDim        # Actual width.
    height*: XcursorDim       # Actual height.
    xhot*: XcursorDim         # Hot spot x (must be inside image).
    yhot*: XcursorDim         # Hot spot y (must be inside image).
    delay*: uint32            # Animation delay to next frame (ms).
    pixels*: ptr XcursorPixel # Pointer to pixels.

proc XcursorImageCreate*(width, height: cint): ptr XcursorImage {.importc, cdecl.}
proc XcursorImageDestroy*(image: ptr XcursorImage) {.importc, cdecl.}
proc XcursorImageLoadCursor*(dpy: Display, image: ptr XcursorImage): Cursor {.importc, cdecl.}
