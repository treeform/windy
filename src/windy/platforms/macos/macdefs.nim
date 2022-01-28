import opengl, std/typetraits, objc
export objc

{.passL: "-framework Cocoa".}

type
  CGPoint* {.pure, bycopy.} = object
    x*, y*: float64

  CGSize* {.pure, bycopy.} = object
    width*, height*: float64

  CGRect* {.pure, bycopy.} = object
    origin*: CGPoint
    size*: CGSize

  NSRange* {.pure, bycopy.} = object
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
  NSAttributedString* = distinct NSObject
  NSData* = distinct NSObject
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
  NSTextInputClient* = distinct int

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

{.push inline.}

objc:
  proc isKindOfClass*(self: NSObject, _: Class): bool
  proc superclass*(self: NSObject): Class
  proc retain*(self: ID)
  proc release*(self: ID)
  proc stringWithString*(class: typedesc[NSString], _: NSString): NSString
  proc getBytes*(
    self: NSString,
    _: pointer,
    maxLength: uint,
    usedLength: ptr uint,
    encoding: NSStringEncoding,
    options: NSStringEncodingConversionOptions,
    range: NSRange,
    remainingRange: NSRangePointer
  ): bool
  proc string*(self: NSAttributedString): NSString
  proc doubleClickInterval*(class: typedesc[NSEvent]): float64
  proc scrollingDeltaX*(self: NSEvent): float64
  proc scrollingDeltaY*(self: NSEvent): float64
  proc hasPreciseScrollingDeltas*(self: NSEvent): bool
  proc locationInWindow*(self: NSEvent): NSPoint
  proc buttonNumber*(self: NSEvent): int
  proc keyCode*(self: NSEvent): uint16
  proc dataWithBytes*(class: typedesc[NSData], _: pointer, length: int): NSData
  proc length*(self: NSData): uint
  proc length*(self: NSString): uint
  proc array*(class: typedesc[NSArray]): NSArray
  proc count*(self: NSArray): uint
  proc objectAtIndex*(self: NSArray, _: uint): ID
  proc containsObject*(self: NSArray, _: ID): bool
  proc screens*(class: typedesc[NSScreen]): NSArray
  proc frame*(self: NSScreen): NSRect
  proc frame*(self: NSWindow): NSRect
  proc frame*(self: NSView): NSRect
  proc generalPasteboard*(class: typedesc[NSPasteboard]): NSPasteboard
  proc types*(self: NSPasteboard): NSArray
  proc stringForType*(self: NSPasteboard, _: NSPasteboardType): NSString
  proc clearContents*(self: NSPasteboard)
  proc setString*(self: NSPasteboard, _: NSString, forType: NSPasteboardType)
  proc processInfo*(class: typedesc[NSProcessInfo]): NSProcessInfo
  proc processName*(self: NSProcessInfo): NSString
  proc sharedApplication*(class: typedesc[NSApplication]): NSApplication
  proc setActivationPolicy*(
    self: NSApplication,
    _: NSApplicationActivationPolicy
  )
  proc setPresentationOptions*(
    self: NSApplication,
    _: NSApplicationPresentationOptions
  )
  proc activateIgnoringOtherApps*(self: NSApplication, _: BOOL)
  proc setDelegate*(self: NSApplication, _: ID)
  proc setDelegate*(self: NSWindow, _: ID)
  proc setMainMenu*(self: NSApplication, _: NSMenu)
  proc finishLaunching*(self: NSApplication)
  proc nextEventMatchingMask*(
    self: NSApplication,
    _: NSEventMask,
    untilDate: NSDate,
    inMode: NSRunLoopMode,
    dequeue: BOOL
  ): NSEvent
  proc sendEvent*(self: NSApplication, _: NSEvent)
  proc distantPast*(class: typedesc[NSDate]): NSDate
  proc addItem*(self: NSMenu, _: NSMenuItem)
  proc initWithTitle*(
    self: NSMenuItem,
    _: NSString,
    action: SEL,
    keyEquivalent: NSString
  )
  proc setSubmenu*(self: NSMenuItem, _: NSMenu)
  proc initWithContentRect*(
    self: NSWindow,
    _: NSRect,
    styleMask: NSWindowStyleMask,
    backing: NSBackingStoreType,
    defer_mangle: BOOL
  )
  proc orderFront*(self: NSWindow, _: ID)
  proc orderOut*(self: NSWindow, _: ID)
  proc setTitle*(self: NSWindow, _: NSString)
  proc close*(self: NSWindow)
  proc isVisible*(self: NSWindow): bool
  proc miniaturize*(self: NSWindow, _: ID)
  proc deminiaturize*(self: NSWindow, _: ID)
  proc isMiniaturized*(self: NSWindow): bool
  proc zoom*(self: NSWindow, _: ID)
  proc isZoomed*(self: NSWindow): bool
  proc isKeyWindow*(self: NSWindow): bool
  proc contentView*(self: NSWindow): NSView
  proc contentRectForFrameRect*(self: NSWindow, _: NSRect): NSRect
  proc frameRectForContentRect*(self: NSWindow, _: NSRect): NSRect
  proc setFrame*(self: NSWindow, _: NSRect, display: BOOL)
  proc screen*(self: NSWindow): NSScreen
  proc setFrameOrigin*(self: NSWindow, _: NSPoint)
  proc setRestorable*(self: NSWindow, _: BOOL)
  proc setContentView*(self: NSWindow, _: NSView)
  proc makeFirstResponder*(self: NSWindow, _: NSView): bool
  proc styleMask*(self: NSWindow): NSWindowStyleMask
  proc setStyleMask*(self: NSWindow, _: NSWindowStyleMask)
  proc toggleFullscreen*(self: NSWindow, _: ID)
  proc invalidateCursorRectsForView*(self: NSWindow, _: NSView)
  proc convertRectToBacking*(self: NSView, _: NSRect): NSRect
  proc window*(self: NSView): NSWindow
  proc bounds*(self: NSView): NSRect
  proc removeTrackingArea*(self: NSView, _: NSTrackingArea)
  proc addTrackingArea*(self: NSView, _: NSTrackingArea)
  proc addCursorRect*(self: NSview, _: NSRect, cursor: NSCursor)
  proc inputContext*(self: NSView): NSTextInputContext
  proc initWithAttributes*(
    self: NSOpenGLPixelFormat,
    _: ptr NSOpenGLPixelFormatAttribute
  )
  proc initWithFrame*(
    self: NSOpenGLView,
    _: NSRect,
    pixelFormat: NSOpenGLPixelFormat
  )
  proc setWantsBestResolutionOpenGLSurface*(
    self: NSOpenGLView,
    _: BOOL
  )
  proc openGLContext*(self: NSOpenGLView): NSOpenGLContext
  proc makeCurrentContext*(self: NSOpenGLContext)
  proc setValues*(
    self: NSOpenGLContext,
    _: ptr GLint,
    forParameter: NSOpenGLContextParameter
  )
  proc flushBuffer*(self: NSOpenGLContext)
  proc initWithRect*(
    self: NSTrackingArea,
    _: NSRect,
    options: NSTrackingAreaOptions,
    owner: ID,
    userInfo: ID
  )
  proc initWithData*(self: NSImage, _: NSData)
  proc initWithImage*(self: NSCursor, _: NSImage, hotSpot: NSPoint)
  proc discardMarkedText*(self: NSTextInputContext)
  proc handleEvent*(self: NSTextInputContext, _: NSEvent): bool
  proc deactivate*(self: NSTextInputContext)
  proc activate*(self: NSTextInputContext)
  proc insertText*(self: NSTextInputClient, _: ID, replacementRange: NSRange)

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

proc `[]`*(arr: NSArray, index: int): ID =
  arr.objectAtIndex(index.uint)

proc callSuper*(sender: ID, cmd: SEL) =
  var super = objc_super(
    receiver: sender,
    super_class: sender.NSObject.superclass
  )
  let msgSendSuper = cast[
    proc(super: ptr objc_super, cmd: SEL) {.cdecl.}
  ](objc_msgSendSuper)
  msgSendSuper(
    super.addr,
    cmd
  )

{.pop.}
