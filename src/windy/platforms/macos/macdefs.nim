import opengl, std/typetraits

{.passL: "-framework Cocoa".}

type
  BOOL* = cchar
  Class* = distinct int
  ID* = distinct int
  SEL* = distinct int
  Protocol* = distinct int
  IMP* = proc(self: ID, cmd: SEL): ID {.cdecl, varargs.}
  objc_super* = object
    receiver*: ID
    super_class*: Class

const
  YES* = BOOL(1)
  NO*  = BOOL(0)

{.push importc, cdecl, dynlib:"libobjc.dylib".}

proc objc_msgSend*(self: ID, op: SEL): ID {.varargs.}
proc objc_msgSend_fpret*(self: ID, op: SEL): float64 {.varargs.}
proc objc_msgSend_stret*(stretAddr: pointer, self: ID, op: SEL) {.varargs.}
proc objc_msgSendSuper*(super: ptr objc_super, op: SEL): ID {.varargs.}
proc objc_getClass*(name: cstring): Class
proc objc_getProtocol*(name: cstring): Protocol
proc objc_allocateClassPair*(super: Class, name: cstring, extraBytes = 0): Class
proc objc_registerClassPair*(cls: Class)
proc class_getName*(cls: Class): cstring
proc class_addMethod*(cls: Class, name: SEL, imp: IMP, types: cstring): BOOL
proc object_getClass*(id: ID): Class
proc sel_registerName*(s: cstring): SEL
proc sel_getName*(sel: SEL): cstring
proc class_addProtocol*(cls: Class, protocol: Protocol): BOOL

{.pop.}

template s*(s: string): SEL =
  sel_registerName(s.cstring)

template addClass*(className, superName: string, cls: Class, body: untyped) =
  block:
    cls = objc_allocateClassPair(
      objc_getClass(superName.cstring),
      className.cstring
    )

    template addProtocol(protocolName: string) =
      discard class_addProtocol(
        cls, objc_getProtocol(protocolName.cstring))

    template addMethod(methodName: string, fn: untyped) =
      discard class_addMethod(
        cls,
        s(methodName),
        cast[IMP](fn),
        "".cstring
      )

    body

    objc_registerClassPair(cls)

proc `$`*(cls: Class): string =
  $class_getName(cls)

proc `$`*(id: ID): string =
  $object_getClass(id)

proc `$`*(sel: SEL): string =
  $sel_getName(sel)

type
  CGPoint* {.bycopy.} = object
    x*, y*: float64

  CGSize* {.bycopy.} = object
    width*, height*: float64

  CGRect* {.bycopy.} = object
    origin*: CGPoint
    size*: CGSize

  NSRange* {.bycopy.} = object
    location*, length*: uint

  NSRangePointer* = ptr NSRange

type
  NSEventMask* = uint64
  NSWindowStyleMask* = uint
  NSBackingStoreType* = uint
  NSApplicationActivationPolicy* = int
  NSApplicationPresentationOptions* = uint
  NSOpenGLPixelFormatAttribute* = uint32
  NSOpenGLContextParameter* = int
  NSTrackingAreaOptions* = uint
  NSStringEncoding* = uint
  NSStringEncodingConversionOptions* = uint

  NSRect* = CGRect
  NSPoint* = CGPoint
  NSSize* = CGSize

  NSObject* = distinct int
  NSAutoreleasePool* = distinct NSObject
  NSString* = distinct NSObject
  NSAttributedString* = distinct NSObject
  NSData* = distinct NSObject
  NSError* = distinct NSObject
  NSArray* = distinct NSObject
  NSScreen* = distinct NSObject
  NSPasteboard* = distinct NSObject
  NSPasteboardType* = distinct NSString
  NSApplication* = distinct NSObject
  NSNotification* = distinct NSObject
  NSEvent* = distinct NSObject
  NSDate* = distinct NSObject
  NSRunLoopMode* = distinct NSString
  NSMenu* = distinct NSObject
  NSMenuItem* = distinct NSObject
  NSProcessInfo* = distinct NSObject
  NSWindow* = distinct NSObject
  NSView* = distinct NSObject
  NSOpenGLView* = distinct NSObject
  NSOpenGLPixelFormat* = distinct NSObject
  NSOpenGLContext* = distinct NSObject
  NSTrackingArea* = distinct NSObject
  NSImage* = distinct NSObject
  NSCursor* = distinct NSObject
  NSTextInputContext* = distinct NSObject

const
  NSNotFound* = int.high
  kEmptyRange* = NSRange(location: cast[uint](NSNotFound), length: 0)
  NSEventMaskAny* = uint64.high.NSEventMask
  NSWindowStyleMaskBorderless* = 0.NSWindowStyleMask
  NSWindowStyleMaskTitled* = (1 shl 0).NSWindowStyleMask
  NSWindowStyleMaskClosable* = (1 shl 1).NSWindowStyleMask
  NSWindowStyleMaskMiniaturizable* = (1 shl 2).NSWindowStyleMask
  NSWindowStyleMaskResizable* = (1 shl 3).NSWindowStyleMask
  NSWindowStyleMaskFullScreen* = (1 shl 14).NSWindowStyleMask
  NSBackingStoreBuffered* = 2.NSBackingStoreType
  NSApplicationActivationPolicyRegular* = 0.NSApplicationActivationPolicy
  NSApplicationPresentationDefault* = 0.NSApplicationPresentationOptions
  NSOpenGLPFAMultisample* = 59.NSOpenGLPixelFormatAttribute
  NSOpenGLPFASampleBuffers* = 55.NSOpenGLPixelFormatAttribute
  NSOpenGLPFASamples* = 56.NSOpenGLPixelFormatAttribute
  NSOpenGLPFAAccelerated* = 73.NSOpenGLPixelFormatAttribute
  NSOpenGLPFADoubleBuffer* = 5.NSOpenGLPixelFormatAttribute
  NSOpenGLPFAColorSize* = 8.NSOpenGLPixelFormatAttribute
  NSOpenGLPFAAlphaSize* = 11.NSOpenGLPixelFormatAttribute
  NSOpenGLPFADepthSize* = 12.NSOpenGLPixelFormatAttribute
  NSOpenGLPFAStencilSize* = 13.NSOpenGLPixelFormatAttribute
  NSOpenGLPFAOpenGLProfile* = 99.NSOpenGLPixelFormatAttribute
  NSOpenGLProfileVersionLegacy* = 0x1000
  NSOpenGLProfileVersion3_2Core* = 0x3200
  NSOpenGLProfileVersion4_1Core* = 0x4100
  NSOpenGLContextParameterSwapInterval* = 222
  NSTrackingMouseEnteredAndExited* = 0x01.NSTrackingAreaOptions
  NSTrackingMouseMoved* = 0x02.NSTrackingAreaOptions
  NSTrackingCursorUpdate* = 0x04.NSTrackingAreaOptions
  NSTrackingActiveWhenFirstResponder* = 0x10.NSTrackingAreaOptions
  NSTrackingActiveInKeyWindow* = 0x20.NSTrackingAreaOptions
  NSTrackingActiveInActiveApp* = 0x40.NSTrackingAreaOptions
  NSTrackingActiveAlways* = 0x80.NSTrackingAreaOptions
  NSTrackingAssumeInside* = 0x100.NSTrackingAreaOptions
  NSTrackingInVisibleRect* = 0x200.NSTrackingAreaOptions
  NSTrackingEnabledDuringMouseDrag* = 0x400.NSTrackingAreaOptions
  NSUTF32StringEncoding* = 0x8c000100.NSStringEncoding

var
  NSApp* {.importc.}: NSApplication
  NSPasteboardTypeString* {.importc.}: NSPasteboardType
  NSDefaultRunLoopMode* {.importc.}: NSRunLoopMode

proc locationInWindow*(event: NSEvent): NSPoint =
  proc send(self: ID, op: SEL): NSPoint
    {.importc:"objc_msgSend_fpret", cdecl, dynlib:"libobjc.dylib".}
  send(
    event.ID,
    sel_registerName("locationInWindow".cstring)
  )

{.push inline.}

proc NSMakeRect*(x, y, w, h: float64): NSRect =
  CGRect(
    origin: CGPoint(x: x, y: y),
    size: CGSIze(width: w, height: h)
  )

proc NSMakeSize*(w, h: float64): NSSize =
  CGSize(width: w, height: h)

proc NSMakeRange*(loc, len: uint): NSRange =
  NSRange(location: loc, length: len)

proc NSMakePoint*(x, y: float): NSPoint =
  NSPoint(x: x, y: y)

proc getClass*(t: typedesc): Class =
  objc_getClass(t.name.cstring)

proc new*(cls: Class): ID =
  objc_msgSend(
    cls.ID,
    s"new"
  )

proc alloc*(cls: Class): ID =
  objc_msgSend(
    cls.ID,
    s"alloc"
  )

proc isKindOfClass*(obj: NSObject, cls: Class): bool =
  objc_msgSend(
    obj.ID,
    s"isKindOfClass:",
    cls
  ).int != 0

proc superclass*(obj: NSObject): Class =
  objc_msgSend(
    obj.ID,
    s"superclass"
  ).Class

proc callSuper*(sender: ID, cmd: SEL) =
  var super = objc_super(
    receiver: sender,
    super_class: sender.NSObject.superclass
  )
  discard objc_msgSendSuper(
    super.addr,
    cmd
  )

proc retain*(id: ID) =
  discard objc_msgSend(
    id,
    sel_registerName("retain".cstring)
  )

proc release*(id: ID) =
  discard objc_msgSend(
    id,
    s"release"
  )

template autoreleasepool*(body: untyped) =
  let pool = NSAutoreleasePool.getClass().new().NSAutoreleasePool
  try:
    body
  finally:
    pool.ID.release()

proc `@`*(s: string): NSString =
  objc_msgSend(
    objc_getClass("NSString".cstring).ID,
    s"stringWithUTF8String:",
    s.cstring
  ).NSString

proc UTF8String(s: NSString): cstring =
  cast[cstring](objc_msgSend(
    s.ID,
    s"UTF8String"
  ))

proc `$`*(s: NSString): string =
  $s.UTF8String

proc stringWithString*(_: typedesc[NSString], s: NSString): NSString =
  objc_msgSend(
    objc_getClass("NSString".cstring).ID,
    s"stringWithString:",
    s
  ).NSString

proc getBytes*(
  s: NSString,
  buffer: pointer,
  maxLength: uint,
  usedLength: uint,
  encoding: NSStringEncoding,
  options: NSStringEncodingConversionOptions,
  range: NSRange,
  remainingRange: NSRangePointer
): bool =
  objc_msgSend(
    s.ID,
    s"getBytes:maxLength:usedLength:encoding:options:range:remainingRange:",
    buffer,
    maxLength,
    usedLength,
    encoding,
    options,
    range,
    remainingRange
  ).int != 0

proc str*(s: NSAttributedString): NSString =
  objc_msgSend(
    s.ID,
    s"string"
  ).NSString

proc localizedDescription(error: NSError): NSString =
  objc_msgSend(
    error.ID,
    s"localizedDescription"
  ).NSString

proc doubleClickInterval*(_: typedesc[NSEvent]): float64 =
  objc_msgSend_fpret(
    objc_getClass("NSEvent".cstring).ID,
    s"doubleClickInterval"
  ).float64

proc scrollingDeltaX*(event: NSEvent): float64 =
  objc_msgSend_fpret(
    event.ID,
    s"scrollingDeltaX"
  )

proc scrollingDeltaY*(event: NSEvent): float64 =
  objc_msgSend_fpret(
    event.ID,
    s"scrollingDeltaY"
  )

proc hasPreciseScrollingDeltas*(event: NSEvent): bool =
  objc_msgSend(
    event.ID,
    s"hasPreciseScrollingDeltas"
  ).int != 0

proc buttonNumber*(event: NSEvent): int =
  objc_msgSend(
    event.ID,
    s"buttonNumber"
  ).int

proc keyCode*(event: NSEvent): uint16 =
  objc_msgSend(
    event.ID,
    s"keyCode"
  ).uint16

proc `$`*(error: NSError): string =
  $error.localizedDescription

proc code*(error: NSError): int =
  objc_msgSend(
    error.ID,
    s"code"
  ).int

proc dataWithBytes*(_: typedesc[NSData], bytes: pointer, len: int): NSData =
  objc_msgSend(
    objc_getClass("NSData".cstring).ID,
    s"dataWithBytes:length:",
    bytes,
    len
  ).NSData

proc bytes*(data: NSData): pointer =
  cast[pointer](objc_msgSend(
    data.ID,
    s"bytes"
  ))

proc length*(obj: NSData | NSString): uint =
  objc_msgSend(
    obj.ID,
    s"length"
  ).uint

proc array*(_: typedesc[NSArray]): NSArray =
  objc_msgSend(
    objc_getClass("NSArray".cstring).ID,
    s"array"
  ).NSArray

proc arrayWithObject*(_: typedesc[NSArray], obj: ID): NSArray =
  objc_msgSend(
    objc_getClass("NSArray".cstring).ID,
    s"arrayWithObject:",
    obj
  ).NSArray

proc count*(arr: NSArray): int =
  objc_msgSend(
    arr.ID,
    s"count"
  ).int

proc objectAtIndex*(arr: NSArray, index: int): ID =
  objc_msgSend(
    arr.ID,
    s"objectAtIndex:",
    index
  )

proc `[]`*(arr: NSArray, index: int): ID =
  arr.objectAtIndex(index)

proc containsObject*(arr: NSArray, o: ID): bool =
  objc_msgSend(
    arr.ID,
    s"containsObject:",
    o
  ).int != 0

proc screens*(_: typedesc[NSScreen]): NSArray =
  objc_msgSend(
    objc_getClass("NSScreen".cstring).ID,
    s"screens"
  ).NSArray

proc frame*(obj: NSScreen | NSWindow | NSView): NSRect =
  objc_msgSend_stret(
    result.addr,
    obj.ID,
    s"frame"
  )

proc generalPasteboard*(_: typedesc[NSPasteboard]): NSPasteboard =
  objc_msgSend(
    objc_getClass("NSPasteboard".cstring).ID,
    s"generalPasteboard"
  ).NSPasteboard

proc types*(pboard: NSPasteboard): NSArray =
  objc_msgSend(
    pboard.ID,
    s"types"
  ).NSArray

proc stringForType*(pboard: NSPasteboard, t: NSPasteboardType): NSString =
  objc_msgSend(
    pboard.ID,
    s"stringForType:",
    t
  ).NSString

proc clearContents*(pboard: NSPasteboard) =
  discard objc_msgSend(
    pboard.ID,
    s"clearContents",
  )

proc setString*(pboard: NSPasteboard, s: NSString, dataType: NSPasteboardType) =
  discard objc_msgSend(
    pboard.ID,
    s"setString:forType:",
    s,
    dataType
  )

proc processInfo*(_: typedesc[NSProcessInfo]): NSProcessInfo =
  objc_msgSend(
    objc_getClass("NSProcessInfo".cstring).ID,
    s"processInfo",
  ).NSProcessInfo

proc processName*(processInfo: NSProcessInfo): NSString =
  objc_msgSend(
    processInfo.ID,
    s"processName",
  ).NSString

proc sharedApplication*(_: typedesc[NSApplication]) =
  discard objc_msgSend(
    objc_getClass("NSApplication".cstring).ID,
    s"sharedApplication",
  )

proc setActivationPolicy*(
  app: NSApplication,
  policy: NSApplicationActivationPolicy
) =
  discard objc_msgSend(
    app.ID,
    s"setActivationPolicy:",
    policy
  )

proc setPresentationOptions*(
  app: NSApplication,
  options: NSApplicationPresentationOptions
) =
  discard objc_msgSend(
    app.ID,
    s"setPresentationOptions:",
    options
  )

proc activateIgnoringOtherApps*(app: NSApplication, flag: BOOL) =
  discard objc_msgSend(
    app.ID,
    s"activateIgnoringOtherApps:",
    flag
  )

proc setDelegate*(app: NSApplication, delegate: ID) =
  discard objc_msgSend(
    app.ID,
    s"setDelegate:",
    delegate
  )

proc setMainMenu*(app: NSApplication, menu: NSMenu) =
  discard objc_msgSend(
    app.ID,
    s"setMainMenu:",
    menu
  )

proc finishLaunching*(app: NSApplication) =
  discard objc_msgSend(
    app.ID,
    s"finishLaunching",
  )

proc nextEventMatchingMask*(
  app: NSApplication,
  mask: NSEventMask,
  expiration: NSDate,
  mode: NSRunLoopMode,
  deqFlag: BOOL
): NSEvent =
  objc_msgSend(
    app.ID,
    s"nextEventMatchingMask:untilDate:inMode:dequeue:",
    mask,
    expiration,
    mode,
    deqFlag
  ).NSEvent

proc sendEvent*(app: NSApplication, event: NSEvent) =
  discard objc_msgSend(
    app.ID,
    s"sendEvent:",
    event
  )

proc distantPast*(_: typedesc[NSDate]): NSDate =
  objc_msgSend(
    objc_getClass("NSDate".cstring).ID,
    s"distantPast",
  ).NSDate

proc addItem*(menu: NSMenu, item: NSMenuItem) =
  discard objc_msgSend(
    menu.ID,
    s"addItem:",
    item
  )

proc initWithTitle*(
  menuItem: NSMenuItem,
  title: NSString,
  action: SEL,
  keyEquivalent: NSString
) =
  discard objc_msgSend(
    menuItem.ID,
    s"initWithTitle:action:keyEquivalent:",
    title,
    action,
    keyEquivalent
  )

proc setSubmenu*(menuItem: NSMenuItem, subMenu: NSMenu) =
  discard objc_msgSend(
    menuItem.ID,
    s"setSubmenu:",
    subMenu
  )

proc initWithContentRect*(
  window: NSWindow,
  contentRect:NSRect,
  style: NSWindowStyleMask,
  backingStoreType: NSBackingStoreType,
  deferFlag: BOOL
) =
  discard objc_msgSend(
    window.ID,
    s"initWithContentRect:styleMask:backing:defer:",
    contentRect,
    style,
    backingStoreType,
    deferFlag
  )

proc setDelegate*(window: NSWindow, delegate: ID) =
  discard objc_msgSend(
    window.ID,
    s"setDelegate:",
    delegate
  )

proc orderFront*(window: NSWindow, sender: ID) =
  discard objc_msgSend(
    window.ID,
    s"orderFront:",
    sender
  )

proc orderOut*(window: NSWindow, sender: ID) =
  discard objc_msgSend(
    window.ID,
    s"orderOut:",
    sender
  )

proc setTitle*(window: NSWindow, title: NSString) =
  discard objc_msgSend(
    window.ID,
    s"setTitle:",
    title
  )

proc close*(window: NSWindow) =
  discard objc_msgSend(
    window.ID,
    s"close"
  )

proc isVisible*(window: NSWindow): bool =
  objc_msgSend(
    window.ID,
    s"isVisible"
  ).int != 0

proc miniaturize*(window: NSWindow, sender: ID) =
  discard objc_msgSend(
    window.ID,
    s"miniaturize:",
    sender
  )

proc deminiaturize*(window: NSWindow, sender: ID) =
  discard objc_msgSend(
    window.ID,
    s"deminiaturize:",
    sender
  )

proc isMiniaturized*(window: NSWindow): bool =
  objc_msgSend(
    window.ID,
    s"isMiniaturized"
  ).int != 0

proc zoom*(window: NSWindow, sender: ID) =
  discard objc_msgSend(
    window.ID,
    s"zoom:",
    sender
  )

proc isZoomed*(window: NSWindow): bool =
  objc_msgSend(
    window.ID,
    s"isZoomed"
  ).int != 0

proc isKeyWindow*(window: NSWindow): bool =
  objc_msgSend(
    window.ID,
    s"isKeyWindow"
  ).int != 0

proc contentView*(window: NSWindow): NSView =
  objc_msgSend(
    window.ID,
    s"contentView"
  ).NSView

proc contentRectForFrameRect*(window: NSWindow, frameRect: NSRect): NSRect =
  objc_msgSend_stret(
    result.addr,
    window.ID,
    s"contentRectForFrameRect:",
    frameRect
  )

proc frameRectForContentRect*(window: NSWindow, contentRect: NSRect): NSRect =
  objc_msgSend_stret(
    result.addr,
    window.ID,
    s"frameRectForContentRect:",
    contentRect
  )

proc setFrame*(window: NSWindow, frameRect: NSRect, flag: BOOL) =
  discard objc_msgSend(
    window.ID,
    s"setFrame:display:",
    frameRect,
    flag
  )

proc screen*(window: NSWindow): NSScreen =
  objc_msgSend(
    window.ID,
    s"screen"
  ).NSScreen

proc setFrameOrigin*(window: NSWindow, origin: NSPoint) =
  discard objc_msgSend(
    window.ID,
    s"setFrameOrigin:",
    origin
  )

proc setRestorable*(window: NSWindow, flag: BOOL) =
  discard objc_msgSend(
    window.ID,
    s"setRestorable:",
    flag
  )

proc setContentView*(window: NSWindow, view: NSView) =
  discard objc_msgSend(
    window.ID,
    s"setContentView:",
    view
  )

proc makeFirstResponder*(window: NSWindow, view: NSView): bool =
  objc_msgSend(
    window.ID,
    s"makeFirstResponder:",
    view
  ).int != 0

proc styleMask*(window: NSWindow): NSWindowStyleMask =
  objc_msgSend(
    window.ID,
    s"styleMask"
  ).NSWindowStyleMask

proc setStyleMask*(window: NSWindow, styleMask: NSWindowStyleMask) =
  discard objc_msgSend(
    window.ID,
    s"setStyleMask:",
    styleMask
  )

proc toggleFullscreen*(window: NSWindow, sender: ID) =
  discard objc_msgSend(
    window.ID,
    s"toggleFullScreen:",
    sender
  )

proc invalidateCursorRectsForView*(window: NSWindow, view: NSView) =
  discard objc_msgSend(
    window.ID,
    s"invalidateCursorRectsForView:",
    view.ID
  )

proc convertRectToBacking*(view: NSView, rect: NSRect): NSRect =
  objc_msgSend_stret(
    result.addr,
    view.ID,
    s"convertRectToBacking:",
    rect
  )

proc window*(view: NSView): NSWindow =
  objc_msgSend(
    view.ID,
    s"window"
  ).NSWindow

proc bounds*(view: NSView): NSRect =
  objc_msgSend_stret(
    result.addr,
    view.ID,
    s"bounds"
  )

proc removeTrackingArea*(view: NSView, trackingArea: NSTrackingArea) =
  discard objc_msgSend(
    view.ID,
    s"removeTrackingArea:",
    trackingArea
  )

proc addTrackingArea*(view: NSView, trackingArea: NSTrackingArea) =
  discard objc_msgSend(
    view.ID,
    s"addTrackingArea:",
    trackingArea
  )

proc addCursorRect*(view: NSview, rect: NSRect, cursor: NSCursor) =
  discard objc_msgSend(
    view.ID,
    s"addCursorRect:cursor:",
    rect,
    cursor
  )

proc inputContext*(view: NSView): NSTextInputContext =
  objc_msgSend(
    view.ID,
    s"inputContext"
  ).NSTextInputContext

proc initWithAttributes*(
  pixelFormat: NSOpenGLPixelFormat,
  attribs: ptr NSOpenGLPixelFormatAttribute
) =
  discard objc_msgSend(
    pixelFormat.ID,
    s"initWithAttributes:",
    attribs
  )

proc initWithFrame*(
  view: NSOpenGLView,
  frameRect: NSRect,
  pixelFormat: NSOpenGLPixelFormat
) =
  discard objc_msgSend(
    view.ID,
    s"initWithFrame:pixelFormat:",
    frameRect,
    pixelFormat
  )

proc setWantsBestResolutionOpenGLSurface*(
  view: NSOpenGLView,
  flag: BOOL
) =
  discard objc_msgSend(
    view.ID,
    s"setWantsBestResolutionOpenGLSurface:",
    flag
  )

proc openGLContext*(view: NSOpenGLView): NSOpenGLContext =
  objc_msgSend(
    view.ID,
    s"openGLContext"
  ).NSOpenGLContext

proc makeCurrentContext*(context: NSOpenGLContext) =
  discard objc_msgSend(
    context.ID,
    s"makeCurrentContext"
  )

proc setValues*(
  context: NSOpenGLContext,
  values: ptr GLint,
  param: NSOpenGLContextParameter
) =
  discard objc_msgSend(
    context.ID,
    s"setValues:forParameter:",
    values,
    param
  )

proc flushBuffer*(context: NSOpenGLContext) =
  discard objc_msgSend(
    context.ID,
    s"flushBuffer"
  )

proc initWithRect*(
  trackingArea: NSTrackingArea,
  rect: NSRect,
  options: NSTrackingAreaOptions,
  owner: ID
) =
  discard objc_msgSend(
    trackingArea.ID,
    s"initWithRect:options:owner:userInfo:",
    rect,
    options,
    owner,
    0.ID
  )

proc initWithData*(image: NSImage, data: NSData) =
  discard objc_msgSend(
    image.ID,
    s"initWithData:",
    data
  )

proc initWithImage*(cursor: NSCursor, image: NSImage, hotspot: NSPoint) =
  discard objc_msgSend(
    cursor.ID,
    s"initWithImage:hotSpot:",
    image,
    hotspot
  )

proc discardMarkedText*(context: NSTextInputContext) =
  discard objc_msgSend(
    context.ID,
    s"discardMarkedText",
  )

proc handleEvent*(context: NSTextInputContext, event: NSEvent): bool =
  objc_msgSend(
    context.ID,
    s"handleEvent:",
    event
  ).int != 0

proc deactivate*(context: NSTextInputContext) =
  discard objc_msgSend(
    context.ID,
    s"deactivate",
  )

proc activate*(context: NSTextInputContext) =
  discard objc_msgSend(
    context.ID,
    s"activate",
  )

{.pop.}
