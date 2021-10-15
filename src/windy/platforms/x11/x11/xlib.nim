import x

const libX11* =
  when defined(macosx): "libX11.dylib"
  else: "libX11.so(|.6)"

{.pragma: libx11, cdecl, dynlib: libX11, importc.}

type
  Display* = ptr object
  GC* = ptr object
  XIM* = ptr object
  XIC* = ptr object

  XExtData* = object
    number*: cint
    next*: ptr XExtData
    freePrivate*: proc (extension: ptr XExtData): cint {.cdecl.}
    private_data*: pointer

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
    width*, height*: cint
    mwidth*, mheight*: cint
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

  XPrivDisplay* = object
    ext_data*: ptr XExtData
    private1*: pointer
    fd*: cint
    private2*: cint
    protoMajorVersion*: cint
    protoMinorVersion*: cint
    vendor*: cstring
    private3*: XID
    private4*: XID
    private5*: XID
    private6*: cint
    resourceAlloc*: proc (d: Display): XID {.cdecl.}
    byteOrder*: cint
    bitmapUnit*: cint
    bitmapPad*: cint
    bitmapBitOrder*: cint
    nformats*: cint
    pixmapFormat*: pointer
    private8*: cint
    release*: cint
    private9*, private10*: pointer
    qlen*: cint
    lastRequestRead*: culong
    request*: culong
    private11*: pointer
    private12*: pointer
    private13*: pointer
    private14*: pointer
    maxRequestSize*: cuint
    db*: pointer
    private15*: proc (d: Display): cint {.cdecl.}
    displayName*: cstring
    defaultScreen*: cint
    nscreens*: cint
    screens*: ptr Screen
    motion_buffer*: culong
    private16*: culong
    minKeycode*: cint
    maxKeycode*: cint
    private17*: pointer
    private18*: pointer
    private19*: cint
    xdefaults*: cstring

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
    tsXOrigin*: cint
    tsYOrigin*: cint
    font*: Font
    subwindowMode*: cint
    graphicsExposures*: cint
    clipXOrigin*: cint
    clipYOrigin*: cint
    clipMask*: Pixmap
    dashOffset*: cint
    dashes*: cchar
  
  XSizeHints* = object
    flags*: clong
    x*, y*: cint
    width*, height*: cint
    minWidth*, minHeight*: cint
    maxWidth*, maxHeight*: cint
    widthInc*, heightInc*: cint
    minAspect*, maxAspect*: tuple[x, y: cint]
    baseWidth*, baseHeight*: cint
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


proc XOpenDisplay*(displayName: cstring): Display {.libx11.}

proc XFree*(x: pointer) {.libx11.}

proc XRaiseWindow*(d: Display, window: Window) {.libx11.}
proc XLowerWindow*(d: Display, window: Window) {.libx11.}

proc screen(d: Display, id: cint): ptr Screen =
  cast[ptr Screen](cast[int](cast[ptr XPrivDisplay](d)[].screens) + id * Screen.sizeof)

proc defaultScreen*(d: Display): cint =
  cast[ptr XPrivDisplay](d)[].defaultScreen

proc defaultRootWindow*(d: Display): Window =
  d.screen(d.defaultScreen).root

proc XCreateColormap*(d: Display, root: Window, visual: ptr Visual, flags: cint): Colormap {.libx11.}

proc XCreateWindow*(
  d: Display,
  root: Window,
  x, y: cint,
  w, h: cuint,
  borderWidth: cuint,
  depth: cuint,
  class: cuint,
  visual: ptr Visual,
  valueMask: culong,
  attributes: ptr XSetWindowAttributes
): Window {.libx11.}
proc XDestroyWindow*(d: Display, window: Window) {.libx11.}

proc XMapWindow*(d: Display, window: Window) {.libx11.}
proc XSetWMProtocols*(d: Display, window: Window, wmProtocols: ptr Atom, len: cint) {.libx11.}
proc XSelectInput*(d: Display, window: Window, inputs: clong) {.libx11.}

proc XChangeProperty*(
  d: Display, window: Window, property: Atom, kind: Atom,
  format: cint, mode: PropMode, data: cstring, len: cint
) {.libx11.}

proc XGetWindowProperty*(
  d: Display, window: Window, property: Atom,
  offset: clong, len: clong, delete: bool, requiredKind: Atom,
  kindReturn: ptr Atom, formatReturn: ptr cint, lenReturn: ptr culong,
  bytesAfterReturn: ptr culong, dataReturn: ptr cstring
) {.libx11.}

proc Xutf8SetWMProperties*(
  d: Display, window: Window,
  name: cstring, iconName: cstring,
  argv: ptr cstring, argc: cint,
  normalHints: pointer, wmHints: pointer, classHints: pointer
) {.libx11.}

proc XInternAtom*(d: Display, name: cstring, onlyIfExist: cint): Atom {.libx11.}

proc XOpenIM*(d: Display, db: pointer = nil, resName: cstring = nil, resClass: cstring = nil): XIM {.libx11.}
proc XCloseIM*(im: XIM) {.libx11.}

proc XCreateIC*(im: XIM): XIC {.varargs, libx11.}
proc XDestroyIC*(ic: XIC) {.libx11.}
proc XSetICFocus*(ic: XIC) {.libx11.}
proc XUnsetICFocus*(ic: XIC) {.libx11.}

proc XCreateGC*(d: Display, o: Drawable, flags: culong, gcv: ptr XGCValues): GC {.libx11.}
proc XFreeGC*(d: Display, gc: GC) {.libx11.}

proc XMatchVisualInfo*(d: Display, screen: cint, depth: cint, flags: cint, result: ptr XVisualInfo) {.libx11.}

proc XSetTransientForHint*(d: Display, window: Window, root: Window) {.libx11.}

proc XSetNormalHints*(d: Display, window: Window, hints: ptr XSizeHints) {.libx11.}
