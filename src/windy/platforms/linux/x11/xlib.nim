import vmath, x

const libX11* =
  when defined(macosx):
    "libX11.dylib"
  else:
    "libX11.so(|.6)"

const libXExt* =
  when defined(macosx):
    "libXext.dylib"
  else:
    "libXext.so(|.6)"

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

  XWindowAttributes* = object
    pos*: IVec2
    size*: IVec2
    border_width*: cint
    depth*: cint
    visual*: ptr Visual
    root*: Window
    c_class*: cint
    bit_gravity*: cint
    win_gravity*: cint
    backing_store*: cint
    backing_planes*: culong
    backing_pixel*: culong
    save_under*: bool
    colormap*: Colormap
    map_installed*: bool
    map_state*: cint
    all_event_masks*: clong
    your_event_mask*: clong
    do_not_propagate_mask*: clong
    override_redirect*: bool
    screen*: ptr Screen

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

  XSyncValue* = object
    hi*: int32
    lo*: uint32

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

proc screen*(d: Display, id: cint): ptr Screen =
  cast[ptr Screen](cast[int](d.screens) + id * Screen.sizeof)

proc defaultScreen*(d: Display): cint =
  d.defaultScreen

proc defaultRootWindow*(d: Display): Window =
  d.screen(d.defaultScreen).root

{.push, cdecl, dynlib: libX11, importc.}

proc XOpenDisplay*(displayName: cstring): Display
proc XSync*(d: Display, disc = false)
proc XFlush*(d: Display)
proc XFree*(x: pointer)

proc XInternAtom*(d: Display, name: cstring; onlyIfExist: cint): Atom

proc XCreateColormap*(d: Display, root: Window; visual: ptr Visual;
    flags: cint): Colormap

proc XCreateWindow*(
  d: Display,
  root: Window;
  x, y: cint;
  w, h: cuint;
  borderWidth: cuint;
  depth: cuint;
  class: cuint;
  visual: ptr Visual;
  valueMask: culong;
  attributes: ptr XSetWindowAttributes
): Window
proc XDestroyWindow*(d: Display, window: Window)

proc DefaultScreen*(d: Display): Window
proc RootWindow*(d: Display, window: Window): Window

proc XCreateSimpleWindow*(
  d: Display,
  root: Window;
  x, y: cint;
  w, h: cuint;
  borderW: cuint;
  border, background: culong
): Window

proc XMapWindow*(d: Display, window: Window)
proc XUnmapWindow*(d: Display, window: Window)

proc XRaiseWindow*(d: Display, window: Window)
proc XLowerWindow*(d: Display, window: Window)
proc XIconifyWindow*(d: Display, window: Window; screen: cint)

proc XSetWMProtocols*(d: Display, window: Window; wmProtocols: ptr Atom; len: cint)
proc XSelectInput*(d: Display, window: Window; inputs: clong)

proc XGetWindowProperty*(
  d: Display, window: Window; property: Atom;
  offset: clong; len: clong; delete: bool; requiredKind: Atom;
  kindReturn: ptr Atom; formatReturn: ptr cint; lenReturn: ptr culong;
  bytesAfterReturn: ptr culong; dataReturn: ptr cstring
)
proc XChangeProperty*(
  d: Display, window: Window; property: Atom; kind: Atom;
  format: cint; mode: PropMode; data: cstring; len: cint
)
proc XChangeProperty*(
  d: Display, window: Window; property: Atom; kind: Atom;
  format: cint; mode: PropMode; data: pointer; len: cint
)
proc XDeleteProperty*(d: Display, window: Window; property: Atom)

proc Xutf8SetWMProperties*(
  d: Display, window: Window;
  name: cstring; iconName: cstring;
  argv: ptr cstring; argc: cint;
  normalHints: pointer; wmHints: pointer; classHints: pointer
)

proc XTranslateCoordinates*(
  d: Display, window: Window; root: Window; x, y: int32;
  xReturn, yReturn: ptr int32; childReturn: ptr Window
)

proc XGetWindowAttributes*(d: Display, window: Window; res: ptr XWindowAttributes)

proc XOpenIM*(d: Display, db: pointer = nil; resName: cstring = nil;
    resClass: cstring = nil): XIM
proc XCloseIM*(im: XIM)

proc XCreateIC*(im: XIM): XIC {.varargs.}
proc XDestroyIC*(ic: XIC)
proc XSetICFocus*(ic: XIC)
proc XUnsetICFocus*(ic: XIC)

proc XCreateGC*(d: Display, o: Drawable; flags: culong; gcv: ptr XGCValues): GC
proc XFreeGC*(d: Display, gc: GC)

proc XMatchVisualInfo*(d: Display, screen: cint; depth: cint; flags: cint;
    result: ptr XVisualInfo)

proc XSetTransientForHint*(d: Display, window: Window; root: Window)

proc XSetNormalHints*(d: Display, window: Window; hints: ptr XSizeHints)
proc XGetNormalHints*(d: Display, window: Window; res: ptr XSizeHints)

proc XGetGeometry*(
  d: Display, window: Drawable;
  root: ptr Window;
  x, y: ptr int32;
  w, h: ptr uint32;
  borderW: ptr uint32;
  depth: ptr uint32
)

proc XResizeWindow*(d: Display, window: Window; w, h: uint32)
proc XMoveWindow*(d: Display, window: Window; x, y: int32)

proc XGetInputFocus*(d: Display, window: ptr Window; revertTo: ptr RevertTo)
proc XSetInputFocus*(d: Display, window: Window; revertTo: RevertTo;
    time: int32 = CurrentTime)

proc XQueryKeymap*(d: Display, res: var array[32, char])
proc XKeycodeToKeysym*(d: Display, code: KeyCode; i: cint): KeySym

proc XGetSelectionOwner*(d: Display, kind: Atom): Window
proc XSetSelectionOwner*(d: Display, kind: Atom; window: Window;
    time: int32 = CurrentTime)
proc XConvertSelection*(d: Display, kind: Atom; to: Atom; resultProperty: Atom;
    window: Window; time: int32 = CurrentTime)

proc XCreateFontCursor*(d: Display, shape: cuint): x.Cursor
proc XDefineCursor*(d: Display, window: x.Window; cursor: x.Cursor)
proc XUndefineCursor*(d: Display, window: x.Window)
proc XFreeCursor*(d: Display, cursor: x.Cursor)

{.pop.}

{.push, cdecl, dynlib: libXExt, importc.}

proc XSyncQueryExtension*(d: Display, vEv, vEr: ptr cint): bool
proc XSyncInitialize*(d: Display, verMaj, verMin: ptr cint)

proc XSyncCreateCounter*(d: Display, v: XSyncValue): XSyncCounter
proc XSyncDestroyCounter*(d: Display, c: XSyncCounter)

proc XSyncSetCounter*(d: Display, c: XSyncCounter; v: XSyncValue)

{.pop.}
