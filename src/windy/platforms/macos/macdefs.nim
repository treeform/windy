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
  NO* = BOOL(0)

{.push importc, cdecl, dynlib: "libobjc.dylib".}

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

{.emit: "#include <objc/Object.h>" .}

var
  objc_msgSendAddr: pointer
  objc_msgSendSuperAddr: pointer
  objc_msgSend_fpretAddr: pointer
  objc_msgSend_stretAddr: pointer
proc initObjc*() =
  {.emit: "`objc_msgSendAddr` = objc_msgSend;".}
  {.emit: "`objc_msgSendSuperAddr` = objc_msgSendSuper;".}
  when defined(amd64):
    {.emit: "`objc_msgSend_fpretAddr` = objc_msgSend_fpret;".}
    {.emit: "`objc_msgSend_stretAddr` = objc_msgSend_stret;".}
  else:
    {.emit: "`objc_msgSend_fpretAddr` = objc_msgSend;".}
    {.emit: "`objc_msgSend_stretAddr` = objc_msgSend;".}

template s*(s: string): SEL =
  sel_registerName(s.cstring)

template addClass*(className, superName: string, cls: Class, body: untyped) =
  block:
    cls = objc_allocateClassPair(
      objc_getClass(superName.cstring),
      className.cstring
    )

    template addProtocol(protocolName: string) =
      discard class_addProtocol(cls, objc_getProtocol(protocolName.cstring))

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
  let msgSend = cast[proc(self: ID, cmd: SEL): ID {.cdecl.}](objc_msgSendAddr)
  msgSend(
    cls.ID,
    s"new"
  )

proc alloc*(cls: Class): ID =
  let msgSend = cast[proc(self: ID, cmd: SEL): ID {.cdecl.}](objc_msgSendAddr)
  msgSend(
    cls.ID,
    s"alloc"
  )

proc isKindOfClass*(obj: NSObject, cls: Class): bool =
  let msgSend =
    cast[proc(self: ID, cmd: SEL, cls: Class): BOOL {.cdecl.}](objc_msgSendAddr)
  msgSend(
    obj.ID,
    s"isKindOfClass:",
    cls
  ) == YES

proc superclass*(obj: NSObject): Class =
  let msgSend = cast[proc(self: ID, cmd: SEL): ID {.cdecl.}](objc_msgSendAddr)
  msgSend(
    obj.ID,
    s"superclass"
  ).Class

proc callSuper*(sender: ID, cmd: SEL) =
  var super = objc_super(
    receiver: sender,
    super_class: sender.NSObject.superclass
  )
  let msgSendSuper = cast[
    proc(super: ptr objc_super, cmd: SEL) {.cdecl.}
  ](objc_msgSendSuperAddr)
  msgSendSuper(
    super.addr,
    cmd
  )

proc retain*(id: ID) =
  let msgSend = cast[proc(self: ID, cmd: SEL): ID {.cdecl.}](objc_msgSendAddr)
  discard msgSend(
    id,
    sel_registerName("retain".cstring)
  )

proc release*(id: ID) =
  let msgSend = cast[proc(self: ID, cmd: SEL) {.cdecl.}](objc_msgSendAddr)
  msgSend(
    id,
    s"release"
  )

template autoreleasepool*(body: untyped) =
  let pool = NSAutoreleasePool.getClass().new()
  try:
    body
  finally:
    pool.ID.release()

proc `@`*(s: string): NSString =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      s: cstring
    ): NSString {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    NSString.getClass().ID,
    s"stringWithUTF8String:",
    s.cstring
  )

proc UTF8String(s: NSString): cstring =
  let msgSend = cast[proc(self: ID, cmd: SEL): cstring {.cdecl.}](objc_msgSendAddr)
  msgSend(
    s.ID,
    s"UTF8String"
  )

proc `$`*(s: NSString): string =
  $s.UTF8String

proc stringWithString*(_: typedesc[NSString], s: NSString): NSString =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      s: NSString
    ): NSString {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    NSString.getClass().ID,
    s"stringWithString:",
    s
  )

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
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      buffer: pointer,
      maxLength: uint,
      usedLength: uint,
      encoding: NSStringEncoding,
      options: NSStringEncodingConversionOptions,
      range: NSRange,
      remainingRange: NSRangePointer
    ): BOOL {.cdecl.}
  ](objc_msgSend_stretAddr)
  msgSend(
    s.ID,
    s"getBytes:maxLength:usedLength:encoding:options:range:remainingRange:",
    buffer,
    maxLength,
    usedLength,
    encoding,
    options,
    range,
    remainingRange
  ) == YES

proc str*(s: NSAttributedString): NSString =
  let msgSend = cast[proc(self: ID, cmd: SEL): NSString {.cdecl.}](objc_msgSendAddr)
  msgSend(
    s.ID,
    s"string"
  )

proc doubleClickInterval*(_: typedesc[NSEvent]): float64 =
  let msgSend = cast[proc(self: ID, cmd: SEL): float64 {.cdecl.}](objc_msgSend_fpretAddr)
  msgSend(
    NSEvent.getClass().ID,
    s"doubleClickInterval"
  )

proc scrollingDeltaX*(event: NSEvent): float64 =
  let msgSend = cast[proc(self: ID, cmd: SEL): float64 {.cdecl.}](objc_msgSend_fpretAddr)
  msgSend(
    event.ID,
    s"scrollingDeltaX"
  )

proc scrollingDeltaY*(event: NSEvent): float64 =
  let msgSend = cast[proc(self: ID, cmd: SEL): float64 {.cdecl.}](objc_msgSend_fpretAddr)
  msgSend(
    event.ID,
    s"scrollingDeltaY"
  )

proc hasPreciseScrollingDeltas*(event: NSEvent): bool =
  let msgSend = cast[proc(self: ID, cmd: SEL): BOOL {.cdecl.}](objc_msgSendAddr)
  msgSend(
    event.ID,
    s"hasPreciseScrollingDeltas"
  ) == YES

proc locationInWindow*(event: NSEvent): NSPoint =
  let msgSend = cast[proc(self: ID, op: SEL): NSPoint {.cdecl.}](objc_msgSend_fpretAddr)
  msgSend(
    event.ID,
    sel_registerName("locationInWindow".cstring)
  )

proc buttonNumber*(event: NSEvent): int =
  let msgSend = cast[proc(self: ID, cmd: SEL): int {.cdecl.}](objc_msgSendAddr)
  msgSend(
    event.ID,
    s"buttonNumber"
  )

proc keyCode*(event: NSEvent): uint16 =
  let msgSend = cast[proc(self: ID, cmd: SEL): uint16 {.cdecl.}](objc_msgSendAddr)
  msgSend(
    event.ID,
    s"keyCode"
  )

proc dataWithBytes*(_: typedesc[NSData], bytes: pointer, len: int): NSData =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      bytes: pointer,
      len: int
    ): NSData {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    NSData.getClass().ID,
    s"dataWithBytes:length:",
    bytes,
    len
  )

proc length*(obj: NSData | NSString): uint =
  let msgSend = cast[proc(self: ID, cmd: SEL): uint {.cdecl.}](objc_msgSendAddr)
  msgSend(
    obj.ID,
    s"length"
  )

proc array*(_: typedesc[NSArray]): NSArray =
  let msgSend = cast[proc(self: ID, cmd: SEL): NSArray {.cdecl.}](objc_msgSendAddr)
  msgSend(
    NSArray.getClass().ID,
    s"array"
  )

proc count*(arr: NSArray): int =
  let msgSend = cast[proc(self: ID, cmd: SEL): uint {.cdecl.}](objc_msgSendAddr)
  msgSend(
    arr.ID,
    s"count"
  ).int

proc objectAtIndex*(arr: NSArray, index: int): ID =
  let msgSend = cast[proc(self: ID, cmd: SEL, index: uint): ID {.cdecl.}](objc_msgSendAddr)
  msgSend(
    arr.ID,
    s"objectAtIndex:",
    index.uint
  )

proc `[]`*(arr: NSArray, index: int): ID =
  arr.objectAtIndex(index)

proc containsObject*(arr: NSArray, o: ID): bool =
  let msgSend = cast[proc(self: ID, cmd: SEL, o: ID): BOOL {.cdecl.}](objc_msgSendAddr)
  msgSend(
    arr.ID,
    s"containsObject:",
    o
  ) == YES

proc screens*(_: typedesc[NSScreen]): NSArray =
  let msgSend = cast[proc(self: ID, cmd: SEL): NSArray {.cdecl.}](objc_msgSendAddr)
  msgSend(
    NSScreen.getClass().ID,
    s"screens"
  )

proc frame*(obj: NSScreen | NSWindow | NSView): NSRect =
  let msgSend = cast[proc(self: ID, cmd: SEL): NSRect {.cdecl.}](objc_msgSend_stretAddr)
  msgSend(
    obj.ID,
    s"frame"
  )

proc generalPasteboard*(_: typedesc[NSPasteboard]): NSPasteboard =
  let msgSend = cast[proc(self: ID, cmd: SEL): NSPasteboard {.cdecl.}](objc_msgSendAddr)
  msgSend(
    NSPasteboard.getClass().ID,
    s"generalPasteboard"
  )

proc types*(pboard: NSPasteboard): NSArray =
  let msgSend = cast[proc(self: ID, cmd: SEL): NSArray {.cdecl.}](objc_msgSendAddr)
  msgSend(
    pboard.ID,
    s"types"
  )

proc stringForType*(pboard: NSPasteboard, t: NSPasteboardType): NSString =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      t: NSPasteboardType
    ): NSString {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    pboard.ID,
    s"stringForType:",
    t
  )

proc clearContents*(pboard: NSPasteboard) =
  let msgSend = cast[proc(self: ID, cmd: SEL): int {.cdecl.}](objc_msgSendAddr)
  discard msgSend(
    pboard.ID,
    s"clearContents",
  )

proc setString*(pboard: NSPasteboard, s: NSString, dataType: NSPasteboardType) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      s: NSString,
      dataType: NSPasteboardType
    ): BOOL {.cdecl.}
  ](objc_msgSendAddr)
  discard msgSend(
    pboard.ID,
    s"setString:forType:",
    s,
    dataType
  )

proc processInfo*(_: typedesc[NSProcessInfo]): NSProcessInfo =
  let msgSend = cast[proc(self: ID, cmd: SEL): NSProcessInfo {.cdecl.}](objc_msgSendAddr)
  msgSend(
    NSProcessInfo.getClass().ID,
    s"processInfo",
  )

proc processName*(processInfo: NSProcessInfo): NSString =
  let msgSend = cast[proc(self: ID, cmd: SEL): NSString {.cdecl.}](objc_msgSendAddr)
  msgSend(
    processInfo.ID,
    s"processName",
  )

proc sharedApplication*(_: typedesc[NSApplication]) =
  let msgSend = cast[proc(self: ID, cmd: SEL): ID {.cdecl.}](objc_msgSendAddr)
  discard msgSend(
    NSApplication.getClass().ID,
    s"sharedApplication",
  )

proc setActivationPolicy*(
  app: NSApplication,
  policy: NSApplicationActivationPolicy
) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      policy: NSApplicationActivationPolicy
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    app.ID,
    s"setActivationPolicy:",
    policy
  )

proc setPresentationOptions*(
  app: NSApplication,
  options: NSApplicationPresentationOptions
) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      options: NSApplicationPresentationOptions
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    app.ID,
    s"setPresentationOptions:",
    options
  )

proc activateIgnoringOtherApps*(app: NSApplication, flag: BOOL) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      flag: BOOL
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    app.ID,
    s"activateIgnoringOtherApps:",
    flag
  )

proc setDelegate*(obj: NSApplication | NSWindow, delegate: ID) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      delegate: ID
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    obj.ID,
    s"setDelegate:",
    delegate
  )

proc setMainMenu*(app: NSApplication, menu: NSMenu) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      menu: NSMenu
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    app.ID,
    s"setMainMenu:",
    menu
  )

proc finishLaunching*(app: NSApplication) =
  let msgSend = cast[proc(self: ID, cmd: SEL) {.cdecl.}](objc_msgSendAddr)
  msgSend(
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
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      mask: NSEventMask,
      expiration: NSDate,
      mode: NSRunLoopMode,
      deqFlag: BOOL
    ): NSEvent {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    app.ID,
    s"nextEventMatchingMask:untilDate:inMode:dequeue:",
    mask,
    expiration,
    mode,
    deqFlag
  )

proc sendEvent*(app: NSApplication, event: NSEvent) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      event:NSEvent
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    app.ID,
    s"sendEvent:",
    event
  )

proc distantPast*(_: typedesc[NSDate]): NSDate =
  let msgSend = cast[proc(self: ID, cmd: SEL): NSDate {.cdecl.}](objc_msgSendAddr)
  msgSend(
    NSDate.getClass().ID,
    s"distantPast",
  )

proc addItem*(menu: NSMenu, item: NSMenuItem) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      item: NSMenuItem
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
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
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      title: NSString,
      action: SEL,
      keyEquivalent: NSString
    ): ID {.cdecl.}
  ](objc_msgSendAddr)
  discard msgSend(
    menuItem.ID,
    s"initWithTitle:action:keyEquivalent:",
    title,
    action,
    keyEquivalent
  )

proc setSubmenu*(menuItem: NSMenuItem, subMenu: NSMenu) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      subMenu: NSMenu
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    menuItem.ID,
    s"setSubmenu:",
    subMenu
  )

proc initWithContentRect*(
  window: NSWindow,
  contentRect: NSRect,
  style: NSWindowStyleMask,
  backingStoreType: NSBackingStoreType,
  deferFlag: BOOL
) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      contentRect: NSRect,
      style: NSWindowStyleMask,
      backingStoreType: NSBackingStoreType,
      deferFlag: BOOL
    ): ID {.cdecl.}
  ](objc_msgSendAddr)
  discard msgSend(
    window.ID,
    s"initWithContentRect:styleMask:backing:defer:",
    contentRect,
    style,
    backingStoreType,
    deferFlag
  )

proc orderFront*(window: NSWindow, sender: ID) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      sender: ID
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"orderFront:",
    sender
  )

proc orderOut*(window: NSWindow, sender: ID) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      sender: ID
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"orderOut:",
    sender
  )

proc setTitle*(window: NSWindow, title: NSString) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      title: NSString
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"setTitle:",
    title
  )

proc close*(window: NSWindow) =
  let msgSend = cast[proc(self: ID, cmd: SEL) {.cdecl.}](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"close"
  )

proc isVisible*(window: NSWindow): bool =
  let msgSend = cast[proc(self: ID, cmd: SEL): BOOL {.cdecl.}](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"isVisible"
  ) == YES

proc miniaturize*(window: NSWindow, sender: ID) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      sender: ID
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"miniaturize:",
    sender
  )

proc deminiaturize*(window: NSWindow, sender: ID) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      sender: ID
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"deminiaturize:",
    sender
  )

proc isMiniaturized*(window: NSWindow): bool =
  let msgSend = cast[proc(self: ID, cmd: SEL): BOOL {.cdecl.}](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"isMiniaturized"
  ) == YES

proc zoom*(window: NSWindow, sender: ID) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      sender: ID
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"zoom:",
    sender
  )

proc isZoomed*(window: NSWindow): bool =
  let msgSend = cast[proc(self: ID, cmd: SEL): BOOL {.cdecl.}](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"isZoomed"
  ) == YES

proc isKeyWindow*(window: NSWindow): bool =
  let msgSend = cast[proc(self: ID, cmd: SEL): BOOL {.cdecl.}](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"isKeyWindow"
  ) == YES

proc contentView*(window: NSWindow): NSView =
  let msgSend = cast[proc(self: ID, cmd: SEL): NSView {.cdecl.}](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"contentView"
  )

proc contentRectForFrameRect*(window: NSWindow, frameRect: NSRect): NSRect =
  let msgSend = cast[proc(self: ID, cmd: SEL, frameRect: NSRect): NSRect {.cdecl.}](objc_msgSend_stretAddr)
  msgSend(
    window.ID,
    s"contentRectForFrameRect:",
    frameRect
  )

proc frameRectForContentRect*(window: NSWindow, contentRect: NSRect): NSRect =
  let msgSend = cast[proc(self: ID, cmd: SEL, frameRect: NSRect): NSRect {.cdecl.}](objc_msgSend_stretAddr)
  msgSend(
    window.ID,
    s"frameRectForContentRect:",
    contentRect
  )

proc setFrame*(window: NSWindow, frameRect: NSRect, flag: BOOL) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      frameRect: NSRect,
      flag: BOOL
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"setFrame:display:",
    frameRect,
    flag
  )

proc screen*(window: NSWindow): NSScreen =
  let msgSend =
    cast[proc(self: ID, cmd: SEL): NSScreen {.cdecl.}](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"screen"
  )

proc setFrameOrigin*(window: NSWindow, origin: NSPoint) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      origin: NSPoint
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"setFrameOrigin:",
    origin
  )

proc setRestorable*(window: NSWindow, flag: BOOL) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      flag: BOOL
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"setRestorable:",
    flag
  )

proc setContentView*(window: NSWindow, view: NSView) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      view: NSView
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"setContentView:",
    view
  )

proc makeFirstResponder*(window: NSWindow, view: NSView): bool =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      view: NSView
    ): BOOL {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"makeFirstResponder:",
    view
  ) == YES

proc styleMask*(window: NSWindow): NSWindowStyleMask =
  let msgSend =
    cast[proc(self: ID, cmd: SEL): NSWindowStyleMask {.cdecl.}](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"styleMask"
  )

proc setStyleMask*(window: NSWindow, styleMask: NSWindowStyleMask) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      styleMask: NSWindowStyleMask
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"setStyleMask:",
    styleMask
  )

proc toggleFullscreen*(window: NSWindow, sender: ID) =
  let msgSend =
    cast[proc(self: ID, cmd: SEL, sender: ID) {.cdecl.}](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"toggleFullScreen:",
    sender
  )

proc invalidateCursorRectsForView*(window: NSWindow, view: NSView) =
  let msgSend =
    cast[proc(self: ID, cmd: SEL, view: NSView) {.cdecl.}](objc_msgSendAddr)
  msgSend(
    window.ID,
    s"invalidateCursorRectsForView:",
    view
  )

proc convertRectToBacking*(view: NSView, rect: NSRect): NSRect =
  let msgSend = cast[proc(self: ID, cmd: SEL, rect: NSRect): NSRect {.cdecl.}](objc_msgSend_stretAddr)
  msgSend(
    view.ID,
    s"convertRectToBacking:",
    rect
  )

proc window*(view: NSView): NSWindow =
  let msgSend = cast[proc(self: ID, cmd: SEL): NSWindow {.cdecl.}](objc_msgSendAddr)
  msgSend(
    view.ID,
    s"window"
  )

proc bounds*(view: NSView): NSRect =
  let msgSend = cast[proc(self: ID, cmd: SEL): NSRect {.cdecl.}](objc_msgSend_stretAddr)
  msgSend(
    view.ID,
    s"bounds"
  )

proc removeTrackingArea*(view: NSView, trackingArea: NSTrackingArea) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      trackingArea: NSTrackingArea
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    view.ID,
    s"removeTrackingArea:",
    trackingArea
  )

proc addTrackingArea*(view: NSView, trackingArea: NSTrackingArea) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      trackingArea: NSTrackingArea
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    view.ID,
    s"addTrackingArea:",
    trackingArea
  )

proc addCursorRect*(view: NSview, rect: NSRect, cursor: NSCursor) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      rect: NSRect,
      cursor: NSCursor
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    view.ID,
    s"addCursorRect:cursor:",
    rect,
    cursor
  )

proc inputContext*(view: NSView): NSTextInputContext =
  let msgSend = cast[proc(self: ID, cmd: SEL): NSTextInputContext {.cdecl.}](objc_msgSendAddr)
  msgSend(
    view.ID,
    s"inputContext"
  )

proc initWithAttributes*(
  pixelFormat: NSOpenGLPixelFormat,
  attribs: ptr NSOpenGLPixelFormatAttribute
) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      attribs: ptr NSOpenGLPixelFormatAttribute
    ): ID {.cdecl.}
  ](objc_msgSendAddr)
  discard msgSend(
    pixelFormat.ID,
    s"initWithAttributes:",
    attribs
  )

proc initWithFrame*(
  view: NSOpenGLView,
  frameRect: NSRect,
  pixelFormat: NSOpenGLPixelFormat
) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      rect: NSRect,
      pixelFormat:NSOpenGLPixelFormat
    ): ID {.cdecl.}
  ](objc_msgSendAddr)
  discard msgSend(
    view.ID,
    s"initWithFrame:pixelFormat:",
    frameRect,
    pixelFormat
  )

proc setWantsBestResolutionOpenGLSurface*(
  view: NSOpenGLView,
  flag: BOOL
) =
  let msgSend = cast[
    proc(self: ID, cmd: SEL, flag: BOOL) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    view.ID,
    s"setWantsBestResolutionOpenGLSurface:",
    flag
  )

proc openGLContext*(view: NSOpenGLView): NSOpenGLContext =
  let msgSend =
    cast[proc(self: ID, cmd: SEL): NSOpenGLContext {.cdecl.}](objc_msgSendAddr)
  msgSend(
    view.ID,
    s"openGLContext"
  )

proc makeCurrentContext*(context: NSOpenGLContext) =
  let msgSend = cast[proc(self: ID, cmd: SEL) {.cdecl.}](objc_msgSendAddr)
  msgSend(
    context.ID,
    s"makeCurrentContext"
  )

proc setValues*(
  context: NSOpenGLContext,
  values: ptr GLint,
  param: NSOpenGLContextParameter
) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      values: ptr GLint,
      param: NSOpenGLContextParameter
    ) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    context.ID,
    s"setValues:forParameter:",
    values,
    param
  )

proc flushBuffer*(context: NSOpenGLContext) =
  let msgSend = cast[proc(self: ID, cmd: SEL) {.cdecl.}](objc_msgSendAddr)
  msgSend(
    context.ID,
    s"flushBuffer"
  )

proc initWithRect*(
  trackingArea: NSTrackingArea,
  rect: NSRect,
  options: NSTrackingAreaOptions,
  owner: ID
) =
  let msgSend = cast[
    proc(
      self: ID,
      cmd: SEL,
      rect: NSRect,
      options: NSTrackingAreaOptions,
      owner: ID,
      userInfo: ID
    ): ID {.cdecl.}
  ](objc_msgSendAddr)
  discard msgSend(
    trackingArea.ID,
    s"initWithRect:options:owner:userInfo:",
    rect,
    options,
    owner,
    0.ID
  )

proc initWithData*(image: NSImage, data: NSData) =
  let msgSend = cast[
    proc(self: ID, cmd: SEL, data: NSData): ID {.cdecl.}
  ](objc_msgSendAddr)
  discard msgSend(
    image.ID,
    s"initWithData:",
    data
  )

proc initWithImage*(cursor: NSCursor, image: NSImage, hotspot: NSPoint) =
  let msgSend = cast[
    proc(self: ID, cmd: SEL, image: NSImage, hotspot: NSPoint): ID {.cdecl.}
  ](objc_msgSendAddr)
  discard msgSend(
    cursor.ID,
    s"initWithImage:hotSpot:",
    image,
    hotspot
  )

proc discardMarkedText*(context: NSTextInputContext) =
  let msgSend = cast[proc(self: ID, cmd: SEL) {.cdecl.}](objc_msgSendAddr)
  msgSend(
    context.ID,
    s"discardMarkedText",
  )

proc handleEvent*(context: NSTextInputContext, event: NSEvent): bool =
  let msgSend = cast[
    proc(self: ID, cmd: SEL, event: NSEvent): BOOL {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    context.ID,
    s"handleEvent:",
    event
  ).BOOL == YES

proc deactivate*(context: NSTextInputContext) =
  let msgSend = cast[proc(self: ID, cmd: SEL) {.cdecl.}](objc_msgSendAddr)
  msgSend(
    context.ID,
    s"deactivate",
  )

proc activate*(context: NSTextInputContext) =
  let msgSend = cast[proc(self: ID, cmd: SEL) {.cdecl.}](objc_msgSendAddr)
  msgSend(
    context.ID,
    s"activate",
  )

proc insertText2*(client: NSTextInputClient, obj: ID, range: NSRange) =
  let msgSend = cast[
    proc(self: ID, cmd: SEL, obj: ID, range: NSRange) {.cdecl.}
  ](objc_msgSendAddr)
  msgSend(
    client.ID,
    s"insertText:replacementRange:",
    obj,
    range
  )

{.pop.}
