import x, xlib

{.pragma: libx11, cdecl, dynlib: libX11, importc.}

type
  IfEventProc* = proc (d: Display, event: ptr XEvent, p: pointer): cint {.cdecl.}

  XKeyEvent* = object
    theType*: cint
    serial*: culong
    send_event*: cint
    display*: Display
    window*: Window
    root*: Window
    subwindow*: Window
    time*: Time
    x*, y*: cint
    x_root*, y_root*: cint
    state*: cuint
    keycode*: cuint
    same_screen*: cint

  XButtonEvent* = object
    theType*: cint
    serial*: culong
    send_event*: cint
    display*: Display
    window*: Window
    root*: Window
    subwindow*: Window
    time*: Time
    x*, y*: cint
    x_root*, y_root*: cint
    state*: cuint
    button*: cuint
    same_screen*: cint

  XMotionEvent* = object
    theType*: cint
    serial*: culong
    send_event*: cint
    display*: Display
    window*: Window
    root*: Window
    subwindow*: Window
    time*: Time
    x*, y*: cint
    x_root*, y_root*: cint
    state*: cuint
    is_hint*: cchar
    same_screen*: cint

  XCrossingEvent* = object
    theType*: cint
    serial*: culong
    send_event*: cint
    display*: Display
    window*: Window
    root*: Window
    subwindow*: Window
    time*: Time
    x*, y*: cint
    x_root*, y_root*: cint
    mode*: cint
    detail*: cint
    same_screen*: bool
    focus*: bool
    state*: cuint

  XFocusChangeEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    window*: Window
    mode*: cint
    detail*: cint

  XKeymapEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    window*: Window
    key_vector*: array[0..31, cchar]

  XExposeEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    window*: Window
    x*, y*: cint
    width*, height*: cint
    count*: cint

  XGraphicsExposeEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    drawable*: Drawable
    x*, y*: cint
    width*, height*: cint
    count*: cint
    major_code*: cint
    minor_code*: cint

  XNoExposeEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    drawable*: Drawable
    major_code*: cint
    minor_code*: cint

  XVisibilityEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    window*: Window
    state*: cint

  XCreateWindowEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    parent*: Window
    window*: Window
    x*, y*: cint
    width*, height*: cint
    border_width*: cint
    override_redirect*: bool

  XDestroyWindowEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    event*: Window
    window*: Window

  XUnmapEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    event*: Window
    window*: Window
    from_configure*: bool

  XMapEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    event*: Window
    window*: Window
    override_redirect*: bool

  XMapRequestEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    parent*: Window
    window*: Window

  XReparentEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    event*: Window
    window*: Window
    parent*: Window
    x*, y*: cint
    override_redirect*: bool

  XConfigureEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    event*: Window
    window*: Window
    x*, y*: cint
    width*, height*: cint
    border_width*: cint
    above*: Window
    override_redirect*: bool

  XGravityEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    event*: Window
    window*: Window
    x*, y*: cint

  XResizeRequestEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    window*: Window
    width*, height*: cint

  XConfigureRequestEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    parent*: Window
    window*: Window
    x*, y*: cint
    width*, height*: cint
    border_width*: cint
    above*: Window
    detail*: cint
    value_mask*: culong

  XCirculateEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    event*: Window
    window*: Window
    place*: cint

  XCirculateRequestEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    parent*: Window
    window*: Window
    place*: cint

  XPropertyEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    window*: Window
    atom*: Atom
    time*: Time
    state*: cint

  XSelectionClearEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    window*: Window
    selection*: Atom
    time*: Time

  XSelectionRequestEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    owner*: Window
    requestor*: Window
    selection*: Atom
    target*: Atom
    property*: Atom
    time*: Time

  XSelectionEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    requestor*: Window
    selection*: Atom
    target*: Atom
    property*: Atom
    time*: Time

  XColormapEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    window*: Window
    colormap*: Colormap
    c_new*: bool
    state*: cint

  XClientMessageData* {.union.} = object
    b*: array[20, cchar]
    s*: array[10, cshort]
    l*: array[5, clong]

  XClientMessageEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    window*: Window
    message_type*: Atom
    format*: cint
    data*: XClientMessageData

  XMappingEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    window*: Window
    request*: cint
    first_keycode*: cint
    count*: cint

  XErrorEvent* = object
    theType*: cint
    display*: Display
    resourceid*: XID
    serial*: culong
    error_code*: cuchar
    request_code*: cuchar
    minor_code*: cuchar

  XAnyEvent* = object
    theType*: cint
    serial*: culong
    send_event*: bool
    display*: Display
    window*: Window

  XGenericEvent* = object
    theType*: cint             ## of event. Always GenericEvent
    serial*: culong            ## of last request processed
    send_event*: bool          ## true if from SendEvent request
    display*: Display          ## Display the event was read from
    extension*: cint           ## major opcode of extension that caused the event
    evtype*: cint              ## actual event type.

  XGenericEventCookie* = object
    theType*: cint             ## of event. Always GenericEvent
    serial*: culong            ## of last request processed
    send_event*: bool          ## true if from SendEvent request
    display*: Display          ## Display the event was read from
    extension*: cint           ## major opcode of extension that caused the event
    evtype*: cint              ## actual event type.
    cookie*: cuint
    data*: pointer

  XEvent* {.union.} = object
    theType*: cint
    xany*: XAnyEvent
    xkey*: XKeyEvent
    xbutton*: XButtonEvent
    xmotion*: XMotionEvent
    xcrossing*: XCrossingEvent
    xfocus*: XFocusChangeEvent
    xexpose*: XExposeEvent
    xgraphicsexpose*: XGraphicsExposeEvent
    xnoexpose*: XNoExposeEvent
    xvisibility*: XVisibilityEvent
    xcreatewindow*: XCreateWindowEvent
    xdestroywindow*: XDestroyWindowEvent
    xunmap*: XUnmapEvent
    xmap*: XMapEvent
    xmaprequest*: XMapRequestEvent
    xreparent*: XReparentEvent
    xconfigure*: XConfigureEvent
    xgravity*: XGravityEvent
    xresizerequest*: XResizeRequestEvent
    xconfigurerequest*: XConfigureRequestEvent
    xcirculate*: XCirculateEvent
    xcirculaterequest*: XCirculateRequestEvent
    xproperty*: XPropertyEvent
    xselectionclear*: XSelectionClearEvent
    xselectionrequest*: XSelectionRequestEvent
    xselection*: XSelectionEvent
    xcolormap*: XColormapEvent
    xclient*: XClientMessageEvent
    xmapping*: XMappingEvent
    xerror*: XErrorEvent
    xkeymap*: XKeymapEvent
    xgeneric*: XGenericEvent
    xcookie*: XGenericEventCookie
    pad: array[0..23, clong]


proc XCheckIfEvent*(d: Display, e: ptr XEvent, cb: IfEventProc, userData: pointer): cint {.libx11.}
