import x, vmath

const libX11* =
  when defined(macosx): "libX11.dylib"
  else: "libX11.so(|.6)"

type
  Display* = ptr object
    ext_data*: ptr XExtData
    p1: pointer
    fd*: cint
    p2: cint
    protoMajorVersion*: cint
    protoMinorVersion*: cint
    vendor*: cstring
    p3: XID
    p4: XID
    p5: XID
    p6: cint
    resourceAlloc*: proc (d: Display): XID {.cdecl.}
    byteOrder*: cint
    bitmapUnit*: cint
    bitmapPad*: cint
    bitmapBitOrder*: cint
    nformats*: cint
    pixmapFormat*: pointer
    p8: cint
    release*: cint
    p9, p10: pointer
    qlen*: cint
    lastRequestRead*: culong
    request*: culong
    p11: pointer
    p12: pointer
    p13: pointer
    p14: pointer
    maxRequestSize*: cuint
    db*: pointer
    p15: proc (d: Display): cint {.cdecl.}
    displayName*: cstring
    defaultScreen*: cint
    nscreens*: cint
    screens*: ptr Screen
    motion_buffer*: culong
    p16: culong
    minKeycode*: cint
    maxKeycode*: cint
    p17: pointer
    p18: pointer
    p19: cint
    xdefaults: cstring
  
  GC* = ptr object
  XIM* = ptr object
  XIC* = ptr object

  XExtData* = object
    number*: cint
    next*: ptr XExtData
    freePrivate*: proc (extension: ptr XExtData): cint {.cdecl.}
    privateData*: pointer

  Visual* = object
    extData*: ptr XExtData
    visualid*: VisualID
    cClass*: cint
    redMask*, greenMask*, blueMask*: culong
    bitsPerRgb*: cint
    mapEntries*: cint

  XVisualInfo* = object
    visual*: ptr Visual
    visualid*: culong
    screen*: cint
    depth*: cint
    class*: cint
    redMask*, greenMask*, blueMask*: culong
    colormapSize*: cint
    bitsPerRgb*: cint

  Depth* = object
    depth*: cint
    nvisuals*: cint
    visuals*: ptr Visual
  
  Screen* = object
    extData*: ptr XExtData
    display*: Display
    root*: Window
    size*: IVec2
    msize*: IVec2
    ndepths*: cint
    depths*: ptr Depth
    rootDepth*: cint
    rootVisual*: ptr Visual
    defaultGC*: GC
    cmap*: Colormap
    whitePixel*, blackPixel*: culong
    maxMaps*, minMaps*: cint
    backingStore*: cint
    saveUnders*: cint
    rootInputMask*: clong

  XSetWindowAttributes* = object
    backgroundPixmap*: Pixmap
    backgroundPixel*: culong
    borderPixmap*: Pixmap
    borderPixel*: culong
    bitGravity*: cint
    winGravity*: cint
    backingStore*: cint
    backingPlanes*: culong
    backingPixel*: culong
    saveUnder*: cint
    eventMask*: clong
    doNotPropagateMask*: clong
    overrideRedirect*: cint
    colormap*: Colormap
    cursor*: Cursor
  
  XGCValues* = object
    function*: cint
    planeMask*: culong
    foreground*: culong
    background*: culong
    lineWidth*: cint
    lineStyle*: cint
    capStyle*: cint
    joinStyle*: cint
    fillStyle*: cint
    fillRule*: cint
    arcMode*: cint
    tile*: Pixmap
    stipple*: Pixmap
    tsOrigin*: IVec2
    font*: Font
    subwindowMode*: cint
    graphicsExposures*: cint
    clipOrigin*: IVec2
    clipMask*: Pixmap
    dashOffset*: cint
    dashes*: cchar
  
  XSizeHints* = object
    flags*: clong
    pos*: IVec2
    size*: IVec2
    minSize*, maxSize*: IVec2
    incSize*: IVec2
    minAspect*, maxAspect*: IVec2
    baseSize*: IVec2
    winGravity*: cint

const
  XIMPreeditArea* = 1 shl 0
  XIMPreeditCallbacks* = 1 shl 1
  XIMPreeditPosition* = 1 shl 2
  XIMPreeditNothing* = 1 shl 3
  XIMPreeditNone* = 1 shl 4
  XIMStatusArea* = 1 shl 8
  XIMStatusCallbacks* = 1 shl 9
  XIMStatusNothing* = 1 shl 10
  XIMStatusNone* = 1 shl 11
  XBufferOverflow* = -1
  XLookupNone* = 1
  XLookupChars* = 2
  XLookupKeySymVal* = 3
  XLookupBoth* = 4


using d: Display


proc screen(d; id: cint): ptr Screen =
  cast[ptr Screen](cast[int](d.screens) + id * Screen.sizeof)

proc defaultScreen*(d): cint =
  d.defaultScreen

proc defaultRootWindow*(d): Window =
  d.screen(d.defaultScreen).root


{.push, cdecl, dynlib: libX11, importc.}

proc XOpenDisplay*(displayName: cstring): Display
proc XSync*(d; disc = false)

proc XFree*(x: pointer)

proc XInternAtom*(d; name: cstring, onlyIfExist: cint): Atom

proc XCreateColormap*(d; root: Window, visual: ptr Visual, flags: cint): Colormap

proc XCreateWindow*(
  d;
  root: Window,
  x, y: cint,
  w, h: cuint,
  borderWidth: cuint,
  depth: cuint,
  class: cuint,
  visual: ptr Visual,
  valueMask: culong,
  attributes: ptr XSetWindowAttributes
): Window
proc XDestroyWindow*(d; window: Window)

proc XMapWindow*(d; window: Window)
proc XUnmapWindow*(d; window: Window)

proc XRaiseWindow*(d; window: Window)
proc XLowerWindow*(d; window: Window)
proc XIconifyWindow*(d; window: Window, screen: cint)

proc XSetWMProtocols*(d; window: Window, wmProtocols: ptr Atom, len: cint)
proc XSelectInput*(d; window: Window, inputs: clong)

proc XChangeProperty*(
  d; window: Window, property: Atom, kind: Atom,
  format: cint, mode: PropMode, data: cstring, len: cint
)

proc XGetWindowProperty*(
  d; window: Window, property: Atom,
  offset: clong, len: clong, delete: bool, requiredKind: Atom,
  kindReturn: ptr Atom, formatReturn: ptr cint, lenReturn: ptr culong,
  bytesAfterReturn: ptr culong, dataReturn: ptr cstring
)

proc Xutf8SetWMProperties*(
  d; window: Window,
  name: cstring, iconName: cstring,
  argv: ptr cstring, argc: cint,
  normalHints: pointer, wmHints: pointer, classHints: pointer
)

proc XOpenIM*(d; db: pointer = nil, resName: cstring = nil, resClass: cstring = nil): XIM
proc XCloseIM*(im: XIM)

proc XCreateIC*(im: XIM): XIC {.varargs.}
proc XDestroyIC*(ic: XIC)
proc XSetICFocus*(ic: XIC)
proc XUnsetICFocus*(ic: XIC)

proc XCreateGC*(d; o: Drawable, flags: culong, gcv: ptr XGCValues): GC
proc XFreeGC*(d; gc: GC)

proc XMatchVisualInfo*(d; screen: cint, depth: cint, flags: cint, result: ptr XVisualInfo)

proc XSetTransientForHint*(d; window: Window, root: Window)

proc XSetNormalHints*(d; window: Window, hints: ptr XSizeHints)
proc XGetNormalHints*(d; window: Window, res: ptr XSizeHints)

proc XGetGeometry*(
  d; window: Drawable,
  root: ptr Window,
  x, y: ptr int32,
  w, h: ptr uint32,
  borderW: ptr uint32,
  depth: ptr uint32
)

proc XResizeWindow*(d; window: Window; w, h: uint32)
proc XMoveWindow*(d; window: Window; x, y: int32)

proc XGetInputFocus*(d; window: ptr Window, revertTo: ptr RevertTo)
proc XSetInputFocus*(d; window: Window, revertTo: RevertTo, time: int32 = CurrentTime)

{.pop.}
