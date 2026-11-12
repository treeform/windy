import
  ../../x11/[x, xlib, xevent]

export x, xlib, xevent

type
  FontSet* = pointer
  XImage* = object
    width*, height*, xoffset*, format*: cint
    data*: cstring
    byteOrder*, bitmapUnit*, bitmapBitOrder*, bitmapPad*, depth*: cint
    bytesPerLine*, bitsPerPixel*: cint
    redMask*, greenMask*, blueMask*: culong
    obdata*: pointer
    functions*: array[6, pointer]

{.push cdecl, importc, dynlib: libX11.}
proc XCloseDisplay*(d: Display): cint
proc XPending*(d: Display): cint
proc XGetVisualInfo*(d: Display, mask: clong, info: ptr XVisualInfo, count: ptr cint): ptr XVisualInfo
proc XSetForeground*(d: Display, gc: GC, color: culong): cint
proc XFillRectangle*(d: Display, window: Drawable, gc: GC, x, y: cint, width, height: cuint): cint
proc XDrawLine*(d: Display, window: Drawable, gc: GC, x1, y1, x2, y2: cint): cint
proc XCreateImage*(d: Display, visual: ptr Visual, depth: cuint, format: cint,
    offset: cint, data: cstring, width, height: cuint, pad, stride: cint): ptr XImage
proc XGetImage*(d: Display, window: Drawable, x, y: cint, width, height: cuint,
    planes: culong, format: cint): ptr XImage
proc XPutImage*(d: Display, window: Drawable, gc: GC, image: ptr XImage,
    sourceX, sourceY, destX, destY: cint, width, height: cuint): cint
proc XPutPixel*(image: ptr XImage, x, y: cint, pixel: culong): cint
proc XGetPixel*(image: ptr XImage, x, y: cint): culong
proc XDestroyImage*(image: ptr XImage): cint
proc XClearArea*(d: Display, window: Window, x, y: cint, width, height: cuint, exposures: cint): cint
proc XCreateFontSet*(d: Display, names: cstring, missing: ptr ptr cstring,
    count: ptr cint, defaultString: ptr cstring): FontSet
proc XFreeFontSet*(d: Display, fonts: FontSet)
proc XFreeStringList*(strings: ptr cstring)
proc Xutf8TextEscapement*(fonts: FontSet, text: cstring, bytes: cint): cint
proc Xutf8DrawString*(d: Display, window: Drawable, fonts: FontSet, gc: GC,
    x, y: cint, text: cstring, bytes: cint)
proc XGrabKeyboard*(d: Display, window: Window, ownerEvents, pointerMode,
    keyboardMode: cint, time: Time): cint
proc XUngrabKeyboard*(d: Display, time: Time): cint
{.pop.}

proc calloc*(count, size: csize_t): pointer {.cdecl, importc, header: "<stdlib.h>".}
