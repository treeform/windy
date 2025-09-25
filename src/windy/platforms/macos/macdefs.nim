import opengl, objc
export objc

{.passL: "-framework Cocoa -framework GameController".}

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
  NSNotificationCenter* = distinct NSObject
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

  GCDevice* = distinct NSObject
  GCController* = distinct NSObject
  GCPhysicalInputProfile* = distinct NSObject
  GCControllerElement* = distinct NSObject
  GCControllerAxisInput* = distinct GCControllerElement
  GCControllerButtonInput* = distinct GCControllerElement
  GCControllerDirectionPad* = distinct GCControllerElement
  GCControllerTouchpad* = distinct GCControllerElement

  GCSystemGestureState* = enum
    GCSystemGestureStateEnabled
    GCSystemGestureStateAlwaysReceive
    GCSystemGestureStateDisabled

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

type
  NSEventType* = enum
    NSEventTypeKeyDown            = 10,
    NSEventTypeKeyUp              = 11,
    NSEventTypeFlagsChanged       = 12,

var
  NSApp* {.importc.}: NSApplication
  NSPasteboardTypeString* {.importc.}: NSPasteboardType
  NSPasteboardTypeTIFF* {.importc.}: NSPasteboardType
  NSDefaultRunLoopMode* {.importc.}: NSRunLoopMode
  GCControllerDidConnectNotification* {.importc.}: NSString
  GCControllerDidDisconnectNotification* {.importc.}: NSString
  GCInputLeftShoulder* {.importc.}: NSString
  GCInputRightShoulder* {.importc.}: NSString
  GCInputLeftBumper* {.importc.}: NSString
  GCInputRightBumper* {.importc.}: NSString
  GCInputLeftTrigger* {.importc.}: NSString
  GCInputRightTrigger* {.importc.}: NSString
  GCInputButtonMenu* {.importc.}: NSString
  GCInputButtonHome* {.importc.}: NSString
  GCInputButtonOptions* {.importc.}: NSString
  GCInputButtonA* {.importc.}: NSString
  GCInputButtonB* {.importc.}: NSString
  GCInputButtonX* {.importc.}: NSString
  GCInputButtonY* {.importc.}: NSString
  GCInputDirectionPad* {.importc.}: NSString
  GCInputLeftThumbstick* {.importc.}: NSString
  GCInputRightThumbstick* {.importc.}: NSString
  GCInputLeftThumbstickButton* {.importc.}: NSString
  GCInputRightThumbstickButton* {.importc.}: NSString

objc:
  proc isKindOfClass*(self: NSObject, x: Class): bool
  proc superclass*(self: NSObject): Class
  proc retain*(self: ID)
  proc release*(self: ID)
  proc stringWithString*(class: typedesc[NSString], x: NSString): NSString
  proc getBytes*(
    self: NSString,
    x: pointer,
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
  proc type*(self: NSEvent): NSEventType
  proc window*(self: NSEvent): NSWindow
  proc dataWithBytes*(class: typedesc[NSData], x: pointer, length: int): NSData
  proc length*(self: NSData): uint
  proc bytes*(self: NSData): pointer
  proc length*(self: NSString): uint
  proc array*(class: typedesc[NSArray]): NSArray
  proc count*(self: NSArray): uint
  proc objectAtIndex*(self: NSArray, x: uint): ID
  proc containsObject*(self: NSArray, x: ID): bool
  proc valueForKey*(self: NSDictionary, x: NSString): ID
  proc screens*(class: typedesc[NSScreen]): NSArray
  proc frame*(self: NSScreen): NSRect
  proc frame*(self: NSWindow): NSRect
  proc frame*(self: NSView): NSRect
  proc generalPasteboard*(class: typedesc[NSPasteboard]): NSPasteboard
  proc types*(self: NSPasteboard): NSArray
  proc stringForType*(self: NSPasteboard, x: NSPasteboardType): NSString
  proc dataForType*(self: NSPasteboard, x: NSPasteboardType): NSData
  proc clearContents*(self: NSPasteboard)
  proc setString*(self: NSPasteboard, x: NSString, forType: NSPasteboardType)
  proc processInfo*(class: typedesc[NSProcessInfo]): NSProcessInfo
  proc processName*(self: NSProcessInfo): NSString
  proc sharedApplication*(class: typedesc[NSApplication]): NSApplication
  proc setActivationPolicy*(
    self: NSApplication,
    x: NSApplicationActivationPolicy
  )
  proc setPresentationOptions*(
    self: NSApplication,
    x: NSApplicationPresentationOptions
  )
  proc activateIgnoringOtherApps*(self: NSApplication, x: bool)
  proc setDelegate*(self: NSApplication, x: ID)
  proc setDelegate*(self: NSWindow, x: ID)
  proc setMainMenu*(self: NSApplication, x: NSMenu)
  proc finishLaunching*(self: NSApplication)
  proc nextEventMatchingMask*(
    self: NSApplication,
    x: NSEventMask,
    untilDate: NSDate,
    inMode: NSRunLoopMode,
    dequeue: bool
  ): NSEvent
  proc sendEvent*(self: NSApplication, x: NSEvent)
  proc distantPast*(class: typedesc[NSDate]): NSDate
  proc addItem*(self: NSMenu, x: NSMenuItem)
  proc initWithTitle*(
    self: NSMenuItem,
    x: NSString,
    action: SEL,
    keyEquivalent: NSString
  ): NSMenuItem
  proc setSubmenu*(self: NSMenuItem, x: NSMenu)
  proc initWithContentRect*(
    self: NSWindow,
    x: NSRect,
    styleMask: NSWindowStyleMask,
    backing: NSBackingStoreType,
    defer_mangle: bool
  ): NSWindow
  proc orderFront*(self: NSWindow, x: ID)
  proc orderOut*(self: NSWindow, x: ID)
  proc makeKeyAndOrderFront*(self: NSWindow, x: ID)
  proc setTitle*(self: NSWindow, x: NSString)
  proc close*(self: NSWindow)
  proc isVisible*(self: NSWindow): bool
  proc miniaturize*(self: NSWindow, x: ID)
  proc deminiaturize*(self: NSWindow, x: ID)
  proc isMiniaturized*(self: NSWindow): bool
  proc zoom*(self: NSWindow, x: ID)
  proc isZoomed*(self: NSWindow): bool
  proc isKeyWindow*(self: NSWindow): bool
  proc contentView*(self: NSWindow): NSView
  proc contentRectForFrameRect*(self: NSWindow, x: NSRect): NSRect
  proc frameRectForContentRect*(self: NSWindow, x: NSRect): NSRect
  proc setFrame*(self: NSWindow, x: NSRect, display: bool)
  proc screen*(self: NSWindow): NSScreen
  proc setFrameOrigin*(self: NSWindow, x: NSPoint)
  proc setRestorable*(self: NSWindow, x: bool)
  proc setContentView*(self: NSWindow, x: NSView)
  proc makeFirstResponder*(self: NSWindow, x: NSView): bool
  proc styleMask*(self: NSWindow): NSWindowStyleMask
  proc setStyleMask*(self: NSWindow, x: NSWindowStyleMask)
  proc toggleFullscreen*(self: NSWindow, x: ID)
  proc invalidateCursorRectsForView*(self: NSWindow, x: NSView)
  proc mouseLocationOutsideOfEventStream*(self: NSWindow): NSPoint
  proc level*(self: NSWindow): NSWindowLevel
  proc setLevel*(self: NSWindow, x: NSWindowLevel)
  proc convertRectToBacking*(self: NSView, x: NSRect): NSRect
  proc window*(self: NSView): NSWindow
  proc bounds*(self: NSView): NSRect
  proc removeTrackingArea*(self: NSView, x: NSTrackingArea)
  proc addTrackingArea*(self: NSView, x: NSTrackingArea)
  proc addCursorRect*(self: NSview, x: NSRect, cursor: NSCursor)
  proc inputContext*(self: NSView): NSTextInputContext
  proc initWithAttributes*(
    self: NSOpenGLPixelFormat,
    x: ptr NSOpenGLPixelFormatAttribute
  ): NSOpenGLPixelFormat
  proc initWithFrame*(
    self: NSOpenGLView,
    x: NSRect,
    pixelFormat: NSOpenGLPixelFormat
  ): NSOpenGLView
  proc setWantsBestResolutionOpenGLSurface*(
    self: NSOpenGLView,
    x: bool
  )
  proc openGLContext*(self: NSOpenGLView): NSOpenGLContext
  proc makeCurrentContext*(self: NSOpenGLContext)
  proc setValues*(
    self: NSOpenGLContext,
    x: ptr GLint,
    forParameter: NSOpenGLContextParameter
  )
  proc getValues*(
    self: NSOpenGLContext,
    x: ptr GLint,
    forParameter: NSOpenGLContextParameter
  )
  proc flushBuffer*(self: NSOpenGLContext)
  proc initWithRect*(
    self: NSTrackingArea,
    x: NSRect,
    options: NSTrackingAreaOptions,
    owner: ID,
    userInfo: ID
  ): NSTrackingArea
  proc initWithData*(self: NSImage, x: NSData): NSImage
  proc initWithImage*(self: NSCursor, x: NSImage, hotSpot: NSPoint): NSCursor
  proc arrowCursor*(class: typedesc[NSCursor]): NSCursor
  proc IBeamCursor*(class: typedesc[NSCursor]): NSCursor
  proc crosshairCursor*(class: typedesc[NSCursor]): NSCursor
  proc closedHandCursor*(class: typedesc[NSCursor]): NSCursor
  proc openHandCursor*(class: typedesc[NSCursor]): NSCursor
  proc pointingHandCursor*(class: typedesc[NSCursor]): NSCursor
  proc resizeLeftCursor*(class: typedesc[NSCursor]): NSCursor
  proc resizeRightCursor*(class: typedesc[NSCursor]): NSCursor
  proc resizeLeftRightCursor*(class: typedesc[NSCursor]): NSCursor
  proc resizeUpCursor*(class: typedesc[NSCursor]): NSCursor
  proc resizeDownCursor*(class: typedesc[NSCursor]): NSCursor
  proc resizeUpDownCursor*(class: typedesc[NSCursor]): NSCursor
  proc operationNotAllowedCursor*(class: typedesc[NSCursor]): NSCursor
  proc discardMarkedText*(self: NSTextInputContext)
  proc handleEvent*(self: NSTextInputContext, x: NSEvent): bool
  proc deactivate*(self: NSTextInputContext)
  proc activate*(self: NSTextInputContext)
  proc insertText*(self: NSTextInputClient, x: ID, replacementRange: NSRange)
  proc initWithData*(self: NSBitmapImageRep, x: NSData): NSBitmapImageRep
  proc representationUsingType*(
    self: NSBitmapImageRep,
    x: NSBitmapImageFileType,
    properties: NSDictionary
  ): NSData

  proc `object`*(self: NSNotification): ID

  proc defaultCenter*(class: typedesc[NSNotificationCenter]): NSNotificationCenter
  proc addObserver*(self: NSNotificationCenter, x: ID, selector: SEL, name: NSString, object_mangle: ID)

  proc vendorName*(self: GCDevice): NSString
  proc controllers*(class: typedesc[GCController]): NSArray
  proc startWirelessControllerDiscoveryWithCompletionHandler*(class: typedesc[GCController], x: ID)
  proc playerIndex*(self: GCController): int
  proc setPlayerIndex*(self: GCController, x: int)
  proc physicalInputProfile*(self: GCController): GCPhysicalInputProfile
  proc device*(self: GCPhysicalInputProfile): GCDevice
  proc lastEventTimestamp*(self: GCPhysicalInputProfile): float64
  proc buttons*(self: GCPhysicalInputProfile): NSDictionary
  proc dpads*(self: GCPhysicalInputProfile): NSDictionary
  proc setPreferredSystemGestureState*(self: GCControllerElement, x: GCSystemGestureState)
  proc left*(self: GCControllerDirectionPad): GCControllerButtonInput
  proc right*(self: GCControllerDirectionPad): GCControllerButtonInput
  proc up*(self: GCControllerDirectionPad): GCControllerButtonInput
  proc down*(self: GCControllerDirectionPad): GCControllerButtonInput
  proc xAxis*(self: GCControllerDirectionPad): GCControllerAxisInput
  proc yAxis*(self: GCControllerDirectionPad): GCControllerAxisInput
  proc value*(self: GCControllerAxisInput): float32
  proc value*(self: GCControllerButtonInput): float32
  proc isPressed*(self: GCControllerButtonInput): bool

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

proc `[]`*(dict: NSDictionary, key: NSString): ID =
  dict.valueForKey(key)

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
