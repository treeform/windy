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
  NSResponder* = distinct NSObject
  NSImage* = distinct NSObject
  NSCursor* = distinct NSObject

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
    sel_registerName("new".cstring)
  )

proc alloc*(cls: Class): ID =
  objc_msgSend(
    cls.ID,
    sel_registerName("alloc".cstring)
  )

proc isKindOfClass*(obj: NSObject, cls: Class): bool =
  objc_msgSend(
    obj.ID,
    sel_registerName("isKindOfClass:".cstring),
    cls
  ).int != 0

proc superclass*(obj: NSObject): Class =
  objc_msgSend(
    obj.ID,
    sel_registerName("superclass".cstring)
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

proc release*(id: ID) =
  discard objc_msgSend(
    id,
    sel_registerName("release".cstring)
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
    sel_registerName("stringWithUTF8String:".cstring),
    s.cstring
  ).NSString

proc UTF8String(s: NSString): cstring =
  cast[cstring](objc_msgSend(
    s.ID,
    sel_registerName("UTF8String".cstring)
  ))

proc `$`*(s: NSString): string =
  $s.UTF8String

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
    sel_registerName("getBytes:maxLength:usedLength:encoding:options:range:remainingRange:".cstring),
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
    sel_registerName("string".cstring)
  ).NSString

proc localizedDescription(error: NSError): NSString =
  objc_msgSend(
    error.ID,
    sel_registerName("localizedDescription".cstring)
  ).NSString

proc doubleClickInterval*(_: typedesc[NSEvent]): float64 =
  objc_msgSend_fpret(
    objc_getClass("NSEvent".cstring).ID,
    sel_registerName("doubleClickInterval".cstring)
  ).float64

proc locationInWindow*(event: NSEvent): NSPoint =
  proc send(self: ID, op: SEL): NSPoint
    {.importc:"objc_msgSend_fpret", cdecl, dynlib:"libobjc.dylib".}
  send(
    event.ID,
    sel_registerName("locationInWindow".cstring)
  )

proc scrollingDeltaX*(event: NSEvent): float64 =
  objc_msgSend_fpret(
    event.ID,
    sel_registerName("scrollingDeltaX".cstring)
  )

proc scrollingDeltaY*(event: NSEvent): float64 =
  objc_msgSend_fpret(
    event.ID,
    sel_registerName("scrollingDeltaY".cstring)
  )

proc hasPreciseScrollingDeltas*(event: NSEvent): bool =
  objc_msgSend(
    event.ID,
    sel_registerName("hasPreciseScrollingDeltas".cstring)
  ).int != 0

proc buttonNumber*(event: NSEvent): int =
  objc_msgSend(
    event.ID,
    sel_registerName("buttonNumber".cstring)
  ).int

proc keyCode*(event: NSEvent): uint16 =
  objc_msgSend(
    event.ID,
    sel_registerName("keyCode".cstring)
  ).uint16

proc `$`*(error: NSError): string =
  $error.localizedDescription

proc code*(error: NSError): int =
  objc_msgSend(
    error.ID,
    sel_registerName("code".cstring)
  ).int

proc dataWithBytes*(_: typedesc[NSData], bytes: pointer, len: int): NSData =
  objc_msgSend(
    objc_getClass("NSData".cstring).ID,
    sel_registerName("dataWithBytes:length:".cstring),
    bytes,
    len
  ).NSData

proc bytes*(data: NSData): pointer =
  cast[pointer](objc_msgSend(
    data.ID,
    sel_registerName("bytes".cstring)
  ))

proc length*(obj: NSData | NSString): int =
  objc_msgSend(
    obj.ID,
    sel_registerName("length".cstring)
  ).int

proc array*(_: typedesc[NSArray]): NSArray =
  objc_msgSend(
    objc_getClass("NSArray".cstring).ID,
    sel_registerName("array".cstring)
  ).NSArray

proc arrayWithObject*(_: typedesc[NSArray], obj: ID): NSArray =
  objc_msgSend(
    objc_getClass("NSArray".cstring).ID,
    sel_registerName("arrayWithObject:".cstring),
    obj
  ).NSArray

proc count*(arr: NSArray): int =
  objc_msgSend(
    arr.ID,
    sel_registerName("count".cstring)
  ).int

proc objectAtIndex*(arr: NSArray, index: int): ID =
  objc_msgSend(
    arr.ID,
    sel_registerName("objectAtIndex:".cstring),
    index
  )

proc `[]`*(arr: NSArray, index: int): ID =
  arr.objectAtIndex(index)

proc containsObject*(arr: NSArray, o: ID): bool =
  objc_msgSend(
    arr.ID,
    sel_registerName("containsObject:".cstring),
    o
  ).int != 0

proc screens*(_: typedesc[NSScreen]): NSArray =
  objc_msgSend(
    objc_getClass("NSScreen".cstring).ID,
    sel_registerName("screens".cstring)
  ).NSArray

proc frame*(obj: NSScreen | NSWindow | NSView): NSRect =
  objc_msgSend_stret(
    result.addr,
    obj.ID,
    sel_registerName("frame".cstring)
  )

proc generalPasteboard*(_: typedesc[NSPasteboard]): NSPasteboard =
  objc_msgSend(
    objc_getClass("NSPasteboard".cstring).ID,
    sel_registerName("generalPasteboard".cstring)
  ).NSPasteboard

proc types*(pboard: NSPasteboard): NSArray =
  objc_msgSend(
    pboard.ID,
    sel_registerName("types".cstring)
  ).NSArray

proc stringForType*(pboard: NSPasteboard, t: NSPasteboardType): NSString =
  objc_msgSend(
    pboard.ID,
    sel_registerName("stringForType:".cstring),
    t
  ).NSString

proc clearContents*(pboard: NSPasteboard) =
  discard objc_msgSend(
    pboard.ID,
    sel_registerName("clearContents".cstring),
  )

proc setString*(pboard: NSPasteboard, s: NSString, dataType: NSPasteboardType) =
  discard objc_msgSend(
    pboard.ID,
    sel_registerName("setString:forType:".cstring),
    s,
    dataType
  )

proc processInfo*(_: typedesc[NSProcessInfo]): NSProcessInfo =
  objc_msgSend(
    objc_getClass("NSProcessInfo".cstring).ID,
    sel_registerName("processInfo".cstring),
  ).NSProcessInfo

proc processName*(processInfo: NSProcessInfo): NSString =
  objc_msgSend(
    processInfo.ID,
    sel_registerName("processName".cstring),
  ).NSString

proc sharedApplication*(_: typedesc[NSApplication]) =
  discard objc_msgSend(
    objc_getClass("NSApplication".cstring).ID,
    sel_registerName("sharedApplication".cstring),
  )

proc setActivationPolicy*(
  app: NSApplication,
  policy: NSApplicationActivationPolicy
) =
  discard objc_msgSend(
    app.ID,
    sel_registerName("setActivationPolicy:".cstring),
    policy
  )

proc setPresentationOptions*(
  app: NSApplication,
  options: NSApplicationPresentationOptions
) =
  discard objc_msgSend(
    app.ID,
    sel_registerName("setPresentationOptions:".cstring),
    options
  )

proc activateIgnoringOtherApps*(app: NSApplication, flag: BOOL) =
  discard objc_msgSend(
    app.ID,
    sel_registerName("activateIgnoringOtherApps:".cstring),
    flag
  )

proc setDelegate*(app: NSApplication, delegate: ID) =
  discard objc_msgSend(
    app.ID,
    sel_registerName("setDelegate:".cstring),
    delegate
  )

proc setMainMenu*(app: NSApplication, menu: NSMenu) =
  discard objc_msgSend(
    app.ID,
    sel_registerName("setMainMenu:".cstring),
    menu
  )

proc finishLaunching*(app: NSApplication) =
  discard objc_msgSend(
    app.ID,
    sel_registerName("finishLaunching".cstring),
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
    sel_registerName("nextEventMatchingMask:untilDate:inMode:dequeue:".cstring),
    mask,
    expiration,
    mode,
    deqFlag
  ).NSEvent

proc sendEvent*(app: NSApplication, event: NSEvent) =
  discard objc_msgSend(
    app.ID,
    sel_registerName("sendEvent:".cstring),
    event
  )

proc distantPast*(_: typedesc[NSDate]): NSDate =
  objc_msgSend(
    objc_getClass("NSDate".cstring).ID,
    sel_registerName("distantPast".cstring),
  ).NSDate

proc addItem*(menu: NSMenu, item: NSMenuItem) =
  discard objc_msgSend(
    menu.ID,
    sel_registerName("addItem:".cstring),
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
    sel_registerName("initWithTitle:action:keyEquivalent:".cstring),
    title,
    action,
    keyEquivalent
  )

proc setSubmenu*(menuItem: NSMenuItem, subMenu: NSMenu) =
  discard objc_msgSend(
    menuItem.ID,
    sel_registerName("setSubmenu:".cstring),
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
    sel_registerName("initWithContentRect:styleMask:backing:defer:".cstring),
    contentRect,
    style,
    backingStoreType,
    deferFlag
  )

proc setDelegate*(window: NSWindow, delegate: ID) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("setDelegate:".cstring),
    delegate
  )

proc orderFront*(window: NSWindow, sender: ID) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("orderFront:".cstring),
    sender
  )

proc orderOut*(window: NSWindow, sender: ID) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("orderOut:".cstring),
    sender
  )

proc setTitle*(window: NSWindow, title: NSString) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("setTitle:".cstring),
    title
  )

proc close*(window: NSWindow) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("close".cstring)
  )

proc isVisible*(window: NSWindow): bool =
  objc_msgSend(
    window.ID,
    sel_registerName("isVisible".cstring)
  ).int != 0

proc miniaturize*(window: NSWindow, sender: ID) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("miniaturize:".cstring),
    sender
  )

proc deminiaturize*(window: NSWindow, sender: ID) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("deminiaturize:".cstring),
    sender
  )

proc isMiniaturized*(window: NSWindow): bool =
  objc_msgSend(
    window.ID,
    sel_registerName("isMiniaturized".cstring)
  ).int != 0

proc zoom*(window: NSWindow, sender: ID) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("zoom:".cstring),
    sender
  )

proc isZoomed*(window: NSWindow): bool =
  objc_msgSend(
    window.ID,
    sel_registerName("isZoomed".cstring)
  ).int != 0

proc isKeyWindow*(window: NSWindow): bool =
  objc_msgSend(
    window.ID,
    sel_registerName("isKeyWindow".cstring)
  ).int != 0

proc contentView*(window: NSWindow): NSView =
  objc_msgSend(
    window.ID,
    sel_registerName("contentView".cstring)
  ).NSView

proc contentRectForFrameRect*(window: NSWindow, frameRect: NSRect): NSRect =
  objc_msgSend_stret(
    result.addr,
    window.ID,
    sel_registerName("contentRectForFrameRect:".cstring),
    frameRect
  )

proc frameRectForContentRect*(window: NSWindow, contentRect: NSRect): NSRect =
  objc_msgSend_stret(
    result.addr,
    window.ID,
    sel_registerName("frameRectForContentRect:".cstring),
    contentRect
  )

proc setFrame*(window: NSWindow, frameRect: NSRect, flag: BOOL) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("setFrame:display:".cstring),
    frameRect,
    flag
  )

proc screen*(window: NSWindow): NSScreen =
  objc_msgSend(
    window.ID,
    sel_registerName("screen".cstring)
  ).NSScreen

proc setFrameOrigin*(window: NSWindow, origin: NSPoint) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("setFrameOrigin:".cstring),
    origin
  )

proc setRestorable*(window: NSWindow, flag: BOOL) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("setRestorable:".cstring),
    flag
  )

proc setContentView*(window: NSWindow, view: NSView) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("setContentView:".cstring),
    view
  )

proc makeFirstResponder*(window: NSWindow, view: NSView): bool =
  objc_msgSend(
    window.ID,
    sel_registerName("makeFirstResponder:".cstring),
    view
  ).int != 0

proc styleMask*(window: NSWindow): NSWindowStyleMask =
  objc_msgSend(
    window.ID,
    sel_registerName("styleMask".cstring)
  ).NSWindowStyleMask

proc setStyleMask*(window: NSWindow, styleMask: NSWindowStyleMask) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("setStyleMask:".cstring),
    styleMask
  )

proc toggleFullscreen*(window: NSWindow, sender: ID) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("toggleFullScreen:".cstring),
    sender
  )

proc invalidateCursorRectsForView*(window: NSWindow, view: NSView) =
  discard objc_msgSend(
    window.ID,
    sel_registerName("invalidateCursorRectsForView:".cstring),
    view.ID
  )

proc convertRectToBacking*(view: NSView, rect: NSRect): NSRect =
  objc_msgSend_stret(
    result.addr,
    view.ID,
    sel_registerName("convertRectToBacking:".cstring),
    rect
  )

proc window*(view: NSView): NSWindow =
  objc_msgSend(
    view.ID,
    sel_registerName("window".cstring)
  ).NSWindow

proc bounds*(view: NSView): NSRect =
  objc_msgSend_stret(
    result.addr,
    view.ID,
    sel_registerName("bounds".cstring)
  )

proc removeTrackingArea*(view: NSView, trackingArea: NSTrackingArea) =
  discard objc_msgSend(
    view.ID,
    sel_registerName("removeTrackingArea:".cstring),
    trackingArea
  )

proc addTrackingArea*(view: NSView, trackingArea: NSTrackingArea) =
  discard objc_msgSend(
    view.ID,
    sel_registerName("addTrackingArea:".cstring),
    trackingArea
  )

proc addCursorRect*(view: NSview, rect: NSRect, cursor: NSCursor) =
  discard objc_msgSend(
    view.ID,
    sel_registerName("addCursorRect:cursor:".cstring),
    rect,
    cursor
  )

proc initWithAttributes*(
  pixelFormat: NSOpenGLPixelFormat,
  attribs: ptr NSOpenGLPixelFormatAttribute
) =
  discard objc_msgSend(
    pixelFormat.ID,
    sel_registerName("initWithAttributes:".cstring),
    attribs
  )

proc initWithFrame*(
  view: NSOpenGLView,
  frameRect: NSRect,
  pixelFormat: NSOpenGLPixelFormat
) =
  discard objc_msgSend(
    view.ID,
    sel_registerName("initWithFrame:pixelFormat:".cstring),
    frameRect,
    pixelFormat
  )

proc setWantsBestResolutionOpenGLSurface*(
  view: NSOpenGLView,
  flag: BOOL
) =
  discard objc_msgSend(
    view.ID,
    sel_registerName("setWantsBestResolutionOpenGLSurface:".cstring),
    flag
  )

proc openGLContext*(view: NSOpenGLView): NSOpenGLContext =
  objc_msgSend(
    view.ID,
    sel_registerName("openGLContext".cstring)
  ).NSOpenGLContext

proc makeCurrentContext*(context: NSOpenGLContext) =
  discard objc_msgSend(
    context.ID,
    sel_registerName("makeCurrentContext".cstring)
  )

proc setValues*(
  context: NSOpenGLContext,
  values: ptr GLint,
  param: NSOpenGLContextParameter
) =
  discard objc_msgSend(
    context.ID,
    sel_registerName("setValues:forParameter:".cstring),
    values,
    param
  )

proc flushBuffer*(context: NSOpenGLContext) =
  discard objc_msgSend(
    context.ID,
    sel_registerName("flushBuffer".cstring)
  )

proc initWithRect*(
  trackingArea: NSTrackingArea,
  rect: NSRect,
  options: NSTrackingAreaOptions,
  owner: ID
) =
  discard objc_msgSend(
    trackingArea.ID,
    sel_registerName("initWithRect:options:owner:userInfo:".cstring),
    rect,
    options,
    owner,
    0.ID
  )

proc interpretKeyEvents*(responder: NSResponder, events: NSArray) =
  discard objc_msgSend(
    responder.ID,
    sel_registerName("interpretKeyEvents:".cstring),
    events
  )

proc initWithData*(image: NSImage, data: NSData) =
  discard objc_msgSend(
    image.ID,
    sel_registerName("initWithData:".cstring),
    data
  )

proc initWithImage*(cursor: NSCursor, image: NSImage, hotspot: NSPoint) =
  discard objc_msgSend(
    cursor.ID,
    sel_registerName("initWithImage:hotSpot:".cstring),
    image,
    hotspot
  )
