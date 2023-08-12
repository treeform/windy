import opengl, objc
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
  NSBitmapImageFileType* = uint
  NSWindowLevel* = int

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
  NSBitmapImageRep* = distinct NSObject
  NSDictionary* = distinct NSObject

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
  NSOpenGLContextParameterSurfaceOpacity* = 236
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
  NSBitmapImageFileTypePNG* = 4.NSBitmapImageFileType
  NSNormalWindowLevel* = 0.NSWindowLevel
  NSFloatingWindowLevel* = 3.NSWindowLevel

var
  NSApp* {.importc.}: NSApplication
  NSPasteboardTypeString* {.importc.}: NSPasteboardType
  NSPasteboardTypeTIFF* {.importc.}: NSPasteboardType
  NSDefaultRunLoopMode* {.importc.}: NSRunLoopMode

objc:
  proc isKindOfClass*(self: NSObject, obj: Class): bool
  proc superclass*(self: NSObject): Class
  proc retain*(self: ID)
  proc release*(self: ID)
  proc stringWithString*(class: typedesc[NSString], obj: NSString): NSString
  proc getBytes*(
    self: NSString,
    obj: pointer,
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
  proc dataWithBytes*(class: typedesc[NSData], obj: pointer, length: int): NSData
  proc length*(self: NSData): uint
  proc bytes*(self: NSData): pointer
  proc length*(self: NSString): uint
  proc array*(class: typedesc[NSArray]): NSArray
  proc count*(self: NSArray): uint
  proc objectAtIndex*(self: NSArray, obj: uint): ID
  proc containsObject*(self: NSArray, obj: ID): bool
  proc screens*(class: typedesc[NSScreen]): NSArray
  proc frame*(self: NSScreen): NSRect
  proc frame*(self: NSWindow): NSRect
  proc frame*(self: NSView): NSRect
  proc generalPasteboard*(class: typedesc[NSPasteboard]): NSPasteboard
  proc types*(self: NSPasteboard): NSArray
  proc stringForType*(self: NSPasteboard, obj: NSPasteboardType): NSString
  proc dataForType*(self: NSPasteboard, obj: NSPasteboardType): NSData
  proc clearContents*(self: NSPasteboard)
  proc setString*(self: NSPasteboard, obj: NSString, forType: NSPasteboardType)
  proc processInfo*(class: typedesc[NSProcessInfo]): NSProcessInfo
  proc processName*(self: NSProcessInfo): NSString
  proc sharedApplication*(class: typedesc[NSApplication]): NSApplication
  proc setActivationPolicy*(
    self: NSApplication,
    obj: NSApplicationActivationPolicy
  )
  proc setPresentationOptions*(
    self: NSApplication,
    obj: NSApplicationPresentationOptions
  )
  proc activateIgnoringOtherApps*(self: NSApplication, obj: bool)
  proc setDelegate*(self: NSApplication, obj: ID)
  proc setDelegate*(self: NSWindow, obj: ID)
  proc setMainMenu*(self: NSApplication, obj: NSMenu)
  proc finishLaunching*(self: NSApplication)
  proc nextEventMatchingMask*(
    self: NSApplication,
    obj: NSEventMask,
    untilDate: NSDate,
    inMode: NSRunLoopMode,
    dequeue: bool
  ): NSEvent
  proc sendEvent*(self: NSApplication, obj: NSEvent)
  proc distantPast*(class: typedesc[NSDate]): NSDate
  proc addItem*(self: NSMenu, obj: NSMenuItem)
  proc initWithTitle*(
    self: NSMenuItem,
    obj: NSString,
    action: SEL,
    keyEquivalent: NSString
  ): NSMenuItem
  proc setSubmenu*(self: NSMenuItem, obj: NSMenu)
  proc initWithContentRect*(
    self: NSWindow,
    obj: NSRect,
    styleMask: NSWindowStyleMask,
    backing: NSBackingStoreType,
    defer_mangle: bool
  ): NSWindow
  proc orderFront*(self: NSWindow, obj: ID)
  proc orderOut*(self: NSWindow, obj: ID)
  proc setTitle*(self: NSWindow, obj: NSString)
  proc close*(self: NSWindow)
  proc isVisible*(self: NSWindow): bool
  proc miniaturize*(self: NSWindow, obj: ID)
  proc deminiaturize*(self: NSWindow, obj: ID)
  proc isMiniaturized*(self: NSWindow): bool
  proc zoom*(self: NSWindow, obj: ID)
  proc isZoomed*(self: NSWindow): bool
  proc isKeyWindow*(self: NSWindow): bool
  proc contentView*(self: NSWindow): NSView
  proc contentRectForFrameRect*(self: NSWindow, obj: NSRect): NSRect
  proc frameRectForContentRect*(self: NSWindow, obj: NSRect): NSRect
  proc setFrame*(self: NSWindow, obj: NSRect, display: bool)
  proc screen*(self: NSWindow): NSScreen
  proc setFrameOrigin*(self: NSWindow, obj: NSPoint)
  proc setRestorable*(self: NSWindow, obj: bool)
  proc setContentView*(self: NSWindow, obj: NSView)
  proc makeFirstResponder*(self: NSWindow, obj: NSView): bool
  proc styleMask*(self: NSWindow): NSWindowStyleMask
  proc setStyleMask*(self: NSWindow, obj: NSWindowStyleMask)
  proc toggleFullscreen*(self: NSWindow, obj: ID)
  proc invalidateCursorRectsForView*(self: NSWindow, obj: NSView)
  proc mouseLocationOutsideOfEventStream*(self: NSWindow): NSPoint
  proc level*(self: NSWindow): NSWindowLevel
  proc setLevel*(self: NSWindow, obj: NSWindowLevel)
  proc convertRectToBacking*(self: NSView, obj: NSRect): NSRect
  proc window*(self: NSView): NSWindow
  proc bounds*(self: NSView): NSRect
  proc removeTrackingArea*(self: NSView, obj: NSTrackingArea)
  proc addTrackingArea*(self: NSView, obj: NSTrackingArea)
  proc addCursorRect*(self: NSview, obj: NSRect, cursor: NSCursor)
  proc inputContext*(self: NSView): NSTextInputContext
  proc initWithAttributes*(
    self: NSOpenGLPixelFormat,
    obj: ptr NSOpenGLPixelFormatAttribute
  ): NSOpenGLPixelFormat
  proc initWithFrame*(
    self: NSOpenGLView,
    obj: NSRect,
    pixelFormat: NSOpenGLPixelFormat
  ): NSOpenGLView
  proc setWantsBestResolutionOpenGLSurface*(
    self: NSOpenGLView,
    obj: bool
  )
  proc openGLContext*(self: NSOpenGLView): NSOpenGLContext
  proc makeCurrentContext*(self: NSOpenGLContext)
  proc setValues*(
    self: NSOpenGLContext,
    obj: ptr GLint,
    forParameter: NSOpenGLContextParameter
  )
  proc getValues*(
    self: NSOpenGLContext,
    obj: ptr GLint,
    forParameter: NSOpenGLContextParameter
  )
  proc flushBuffer*(self: NSOpenGLContext)
  proc initWithRect*(
    self: NSTrackingArea,
    obj: NSRect,
    options: NSTrackingAreaOptions,
    owner: ID,
    userInfo: ID
  ): NSTrackingArea
  proc initWithData*(self: NSImage, obj: NSData): NSImage
  proc initWithImage*(self: NSCursor, obj: NSImage, hotSpot: NSPoint): NSCursor
  proc discardMarkedText*(self: NSTextInputContext)
  proc handleEvent*(self: NSTextInputContext, obj: NSEvent): bool
  proc deactivate*(self: NSTextInputContext)
  proc activate*(self: NSTextInputContext)
  proc insertText*(self: NSTextInputClient, obj: ID, replacementRange: NSRange)
  proc initWithData*(self: NSBitmapImageRep, obj: NSData): NSBitmapImageRep
  proc representationUsingType*(
    self: NSBitmapImageRep,
    obj: NSBitmapImageFileType,
    properties: NSDictionary
  ): NSData

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
