// errors
// 1270 not 1280
// in pixels
// trigger leaks

#import <Cocoa/Cocoa.h>

static const NSInteger decoratedWindowMask = NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask;
static const NSInteger undecoratedWindowMask = NSBorderlessWindowMask | NSMiniaturizableWindowMask;

static const NSRange kEmptyRange = { NSNotFound, 0 };

static const int keyCodeMouseLeft = 0x1f0;
static const int keyCodeMouseRight = 0x1f1;
static const int keyCodeMouseMiddle = 0x1f2;
static const int keyCodeMouse4 = 0x1f3;
static const int keyCodeMouse5 = 0x1f4;

typedef void (*Handler)(void* windowPtr);
typedef void (*MouseHandler)(void* windowPtr, int x, int y);
typedef void (*ScrollHandler)(void* windowPtr, float x, float y);
typedef void (*KeyHandler)(void* windowPtr, int keyCode);
typedef void (*RuneHandler)(void* windowPtr, unsigned int rune);

void createMenuBar(void) {
    id menubar = [NSMenu new];
    id appMenuItem = [NSMenuItem new];
    [menubar addItem:appMenuItem];
    [NSApp setMainMenu:menubar];

    id appMenu = [NSMenu new];
    NSString* appName = [[NSProcessInfo processInfo] processName];
    id quitTitle = [@"Quit " stringByAppendingString:appName];
    id quitMenuItem = [[NSMenuItem alloc] initWithTitle:quitTitle
                                                 action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenu addItem:quitMenuItem];
    [appMenuItem setSubmenu:appMenu];
}

int pickOpenGLProfile(int majorVersion) {
    if (majorVersion == 4) {
        return NSOpenGLProfileVersion4_1Core;
    }
    if (majorVersion == 3) {
        return NSOpenGLProfileVersion3_2Core;
    }
    return NSOpenGLProfileVersionLegacy;
}

@interface WindyApplicationDelegate : NSObject <NSApplicationDelegate>
@end

@implementation WindyApplicationDelegate

- (void)applicationWillFinishLaunching:(NSNotification*)notification {
    createMenuBar();
}

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
}

@end

@interface WindyWindow : NSWindow <NSWindowDelegate>
@end

@interface WindyContentView : NSOpenGLView <NSTextInputClient>
{
    NSTrackingArea* trackingArea;
}
@end

WindyApplicationDelegate* appDelegate;

Handler onMove, onResize, onCloseRequested, onFocusChange;
MouseHandler onMouseMove;
ScrollHandler onScroll;
KeyHandler onKeyDown, onKeyUp, onFlagsChanged;
RuneHandler onRune;

char* clipboardString;

int convertY(WindyWindow* window, int y) {
    // Converts y from relative to the bottom of the screen to relative to the top of the screen.
    NSScreen* screen = [window screen];
    if (screen == nil) {
        return 0;
    }
    int screenHeight = (int)[[window screen] frame].size.height;
    // int screenHeight = (int)CGDisplayBounds(CGMainDisplayID()).size.height;
    return screenHeight - y - 1;
}

double innerGetDoubleClickInterval() {
    @autoreleasepool {
        return [NSEvent doubleClickInterval];
    }
}

bool innerGetVisible(WindyWindow* window) {
    @autoreleasepool {
        return window.isVisible;
    }
}

bool innerGetDecorated(WindyWindow* window) {
    @autoreleasepool {
        return (window.styleMask & NSTitledWindowMask) != 0;
    }
}

bool innerGetResizable(WindyWindow* window) {
    @autoreleasepool {
        return (window.styleMask & NSResizableWindowMask) != 0;
    }
}

void innerGetSize(WindyWindow* window, int* width, int* height) {
    @autoreleasepool {
        NSRect contentRect = [[window contentView] frame];
        *width = contentRect.size.width;
        *height = contentRect.size.height;
    }
}

void innerGetPos(WindyWindow* window, int* x, int* y) {
    @autoreleasepool {
        NSRect contentRect = [window contentRectForFrameRect:[window frame]];
        *x = contentRect.origin.x;
        *y = convertY(window, contentRect.origin.y + contentRect.size.height - 1);
    }
}

void innerGetFramebufferSize(WindyWindow* window, int* width, int* height) {
    @autoreleasepool {
        NSRect contentRect = [[window contentView] frame];
        NSRect backingRect = [[window contentView] convertRectToBacking:contentRect];
        *width = backingRect.size.width;
        *height = backingRect.size.height;
    }
}

void innerGetContentScale(WindyWindow* window, float* scale) {
    @autoreleasepool {
        NSRect contentRect = [[window contentView] frame];
        NSRect backingRect = [[window contentView] convertRectToBacking:contentRect];
        *scale = backingRect.size.width / contentRect.size.width;
    }
}

bool innerGetFocused(WindyWindow* window) {
    @autoreleasepool {
        return [window isKeyWindow];
    }
}

bool innerGetMinimized(WindyWindow* window) {
    @autoreleasepool {
        return [window isMiniaturized];
    }
}

bool innerGetMaximized(WindyWindow* window) {
    @autoreleasepool {
        return [window isZoomed];
    }
}

void innerSetTitle(WindyWindow* window, char* title) {
    @autoreleasepool {
        [window setTitle:@(title)];
        [window setMiniwindowTitle:@(title)];
    }
}

void innerSetVisible(WindyWindow* window, bool visible) {
    @autoreleasepool {
        if (visible) {
            [window orderFront:nil];
        } else {
            [window orderOut:nil];
        }
    }
}

void innerSetDecorated(WindyWindow* window, bool decorated) {
    window.styleMask = decorated ? decoratedWindowMask : undecoratedWindowMask;
}

void innerSetResizable(WindyWindow* window, bool resizable) {
    if (!innerGetDecorated(window)) {
        return;
    }

    @autoreleasepool {
        if (resizable) {
            window.styleMask |= NSResizableWindowMask;
        } else {
            window.styleMask &= ~NSResizableWindowMask;
        }
    }
}

void innerSetSize(WindyWindow* window, int width, int height) {
    @autoreleasepool {
        NSRect contentRect = [window contentRectForFrameRect:[window frame]];
        contentRect.origin.y += contentRect.size.height - height;
        contentRect.size = NSMakeSize(width, height);
        [window setFrame:[window frameRectForContentRect:contentRect]
                                                 display:YES];
    }
}

void innerSetPos(WindyWindow* window, int x, int y) {
    @autoreleasepool {
        NSRect contentRect = [[window contentView] frame];
        NSRect rect = NSMakeRect(x, convertY(window, y + contentRect.size.height - 1), 0, 0);
        [window setFrameOrigin:rect.origin];
    }
}

void innerSetMinimized(WindyWindow* window, bool minimized) {
    @autoreleasepool {
        if (minimized && !innerGetMinimized(window)) {
            [window miniaturize:nil];
        } else if (!minimized && innerGetMinimized(window)) {
            [window deminiaturize:nil];
        }
    }
}

void innerSetMaximized(WindyWindow* window, bool maximized) {
    @autoreleasepool {
        if (maximized && !innerGetMinimized(window)) {
            [window zoom:nil];
        } else if (!maximized && innerGetMaximized(window)) {
            [window zoom:nil];
        }
    }
}

void innerInit(
    Handler handleMove,
    Handler handleResize,
    Handler handleCloseRequested,
    Handler handleFocusChange,
    MouseHandler handleMouseMove,
    ScrollHandler handleScroll,
    KeyHandler handleKeyDown,
    KeyHandler handleKeyUp,
    KeyHandler handleFlagsChanged,
    RuneHandler handleRune
) {
    onMove = handleMove;
    onResize = handleResize;
    onCloseRequested = handleCloseRequested;
    onFocusChange = handleFocusChange;
    onMouseMove = handleMouseMove;
    onScroll = handleScroll;
    onKeyDown = handleKeyDown;
    onKeyUp = handleKeyUp;
    onFlagsChanged = handleFlagsChanged;
    onRune = handleRune;

    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp setPresentationOptions:NSApplicationPresentationDefault];
        [NSApp activateIgnoringOtherApps:YES];

        appDelegate = [[WindyApplicationDelegate alloc] init];
        [NSApp setDelegate:appDelegate];

        [NSApp finishLaunching];
    }
}

void innerPollEvents() {
    @autoreleasepool {
        while (true) {
            NSEvent* event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                                untilDate:[NSDate distantPast]
                                                   inMode:NSDefaultRunLoopMode
                                                  dequeue:YES];
            if (event == nil) {
                break;
            }

            [NSApp sendEvent:event];
        }
    }
}

@implementation WindyWindow

- (BOOL)canBecomeKeyWindow {
    return YES;
}

- (void)windowDidResize:(NSNotification*)notification {
    onResize(self);
}

- (void)windowDidMove:(NSNotification*)notification {
    onMove(self);
}

- (BOOL)windowShouldClose:(id)sender {
    onCloseRequested(self);
    return NO;
}

- (void)windowDidBecomeKey:(NSNotification*)notification {
    onFocusChange(self);
}

- (void)windowDidResignKey:(NSNotification*)notification {
    onFocusChange(self);
}

@end

@implementation WindyContentView

- (id) initWithFrameAndConfig:(NSRect)frame
                        vsync:(bool)vsync
           openglMajorVersion:(int)openglMajorVersion
           openglMinorVersion:(int)openglMinorVersion
                         msaa:(int)msaa
                    depthBits:(int)depthBits
                  stencilBits:(int)stencilBits {
    NSOpenGLPixelFormatAttribute attribs[] = {
        NSOpenGLPFAMultisample,
        NSOpenGLPFASampleBuffers, msaa > 0 ? 1 : 0,
        NSOpenGLPFASamples, msaa,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADepthSize, depthBits,
        NSOpenGLPFAStencilSize, stencilBits,
        NSOpenGLPFAOpenGLProfile, pickOpenGLProfile(openglMajorVersion),
        0
    };

    NSOpenGLPixelFormat* pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];

    self = [super initWithFrame:frame pixelFormat:pf];

    self.wantsBestResolutionOpenGLSurface = YES;

    [[self openGLContext] makeCurrentContext];

    GLint swapInterval = vsync ? 1 : 0;
    [[self openGLContext] setValues:&swapInterval forParameter:NSOpenGLCPSwapInterval];

    return self;
}

- (BOOL)canBecomeKeyView {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent*)event {
    return YES;
}

- (void)viewDidChangeBackingProperties
{
    [super viewDidChangeBackingProperties];

    onResize(self.window);
}

- (void)updateTrackingAreas {
    if (trackingArea != nil) {
        [self removeTrackingArea:trackingArea];
        [trackingArea release];
    }

    NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited |
                                    NSTrackingMouseMoved |
                                    NSTrackingActiveInKeyWindow |
                                    NSTrackingCursorUpdate |
                                    NSTrackingInVisibleRect |
                                    NSTrackingAssumeInside;

    trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds]
                                                options:options
                                                  owner:self
                                               userInfo:nil];

    [self addTrackingArea:trackingArea];
    [super updateTrackingAreas];
}

- (void)mouseMoved:(NSEvent*)event {
    NSRect contentRect = [self frame];
    NSPoint pos = [event locationInWindow];

    onMouseMove(self.window, round(pos.x), round(contentRect.size.height - pos.y));
}

- (void)mouseDragged:(NSEvent*)event {
    [self mouseMoved:event];
}

- (void)rightMouseDragged:(NSEvent*)event {
    [self mouseMoved:event];
}

- (void)otherMouseDragged:(NSEvent*)event {
    [self mouseMoved:event];
}

- (void)scrollWheel:(NSEvent*)event {
    double deltaX = [event scrollingDeltaX];
    double deltaY = [event scrollingDeltaY];

    if ([event hasPreciseScrollingDeltas]){
        deltaX *= 0.1;
        deltaY *= 0.1;
    }

    if (fabs(deltaX) > 0.0 || fabs(deltaY) > 0.0) {
        onScroll(self.window, deltaX, deltaY);
    }
}

- (void)mouseDown:(NSEvent*)event {
    onKeyDown(self.window, keyCodeMouseLeft);
}

- (void)mouseUp:(NSEvent*)event {
    onKeyUp(self.window, keyCodeMouseLeft);
}

- (void)rightMouseDown:(NSEvent*)event {
    onKeyDown(self.window, keyCodeMouseRight);
}

- (void)rightMouseUp:(NSEvent*)event {
    onKeyUp(self.window, keyCodeMouseRight);
}

- (void)otherMouseDown:(NSEvent*)event {
    if (event.buttonNumber == 2) {
        onKeyDown(self.window, keyCodeMouseMiddle);
    } else if (event.buttonNumber == 3) {
        onKeyDown(self.window, keyCodeMouse4);
    } else if (event.buttonNumber == 4) {
        onKeyDown(self.window, keyCodeMouse5);
    }
}

- (void)otherMouseUp:(NSEvent*)event {
    if (event.buttonNumber == 2) {
        onKeyUp(self.window, keyCodeMouseMiddle);
    } else if (event.buttonNumber == 3) {
        onKeyUp(self.window, keyCodeMouse4);
    } else if (event.buttonNumber == 4) {
        onKeyUp(self.window, keyCodeMouse5);
    }
}

- (void)keyDown:(NSEvent*)event {
    onKeyDown(self.window, event.keyCode);
    [self interpretKeyEvents:[NSArray arrayWithObject:event]];
}

- (void)keyUp:(NSEvent*)event {
    onKeyUp(self.window, event.keyCode);
}

- (void)flagsChanged:(NSEvent*)event {
    onFlagsChanged(self.window, event.keyCode);
}

- (BOOL)hasMarkedText {
    return NO;
}

- (NSRange)markedRange {
    return kEmptyRange;
}

- (NSRange)selectedRange {
    return kEmptyRange;
}

- (void)setMarkedText:(id)string
        selectedRange:(NSRange)selectedRange
     replacementRange:(NSRange)replacementRange {
}

- (void)unmarkText {
}

- (NSArray*)validAttributesForMarkedText {
    return [NSArray array];
}

- (NSAttributedString*)attributedSubstringForProposedRange:(NSRange)range
                                               actualRange:(NSRangePointer)actualRange {
    return nil;
}

- (void)insertText:(id)string replacementRange:(NSRange)replacementRange {
    NSString* characters;
    if ([string isKindOfClass:[NSAttributedString class]]) {
        characters = [string string];
    } else {
        characters = (NSString*) string;
    }

    NSRange range = NSMakeRange(0, [characters length]);
    while (range.length) {
        unsigned int codepoint = 0;
        if ([characters getBytes:&codepoint
                       maxLength:sizeof(codepoint)
                      usedLength:NULL
                        encoding:NSUTF32StringEncoding
                         options:0
                           range:range
                  remainingRange:&range]) {
            if (codepoint >= 0xf700 && codepoint <= 0xf7ff) {
                continue;
            }

            onRune(self.window, codepoint);
        }
    }
}

- (NSUInteger)characterIndexForPoint:(NSPoint)point {
    return 0;
}

- (NSRect)firstRectForCharacterRange:(NSRange)range
                         actualRange:(NSRangePointer)actualRange {
    return [self frame];
}

- (void)doCommandBySelector:(SEL)selector {
}

@end

void innerMakeContextCurrent(WindyWindow* window) {
    @autoreleasepool {
        [[[window contentView] openGLContext] makeCurrentContext];
    }
}

void innerSwapBuffers(WindyWindow* window) {
    @autoreleasepool {
        [[[window contentView] openGLContext] flushBuffer];
    }
}

void innerClose(WindyWindow* window) {
    @autoreleasepool {
        [window close];
    }
}

WindyWindow* innerNewWindow(
    char* title,
    int width,
    int height,
    bool vsync,
    int openglMajorVersion,
    int openglMinorVersion,
    int msaa,
    int depthBits,
    int stencilBits
) {
    WindyWindow* window;

    @autoreleasepool {
        NSRect contentRect = NSMakeRect(0, 0, width, height);

         window = [[WindyWindow alloc] initWithContentRect:contentRect
                                                 styleMask:decoratedWindowMask
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];

        WindyContentView* view = [[WindyContentView alloc] initWithFrameAndConfig:contentRect
                                                                            vsync:vsync
                                                               openglMajorVersion:openglMajorVersion
                                                               openglMinorVersion:openglMinorVersion
                                                                             msaa:msaa
                                                                        depthBits:depthBits
                                                                      stencilBits:stencilBits];

        [window setDelegate:window];
        [window setTitle:@(title)];
        [window setContentView:view];
        [window makeFirstResponder:view];
        [window setRestorable:NO];
    }

    innerPollEvents();

    return window;
}

char* innerGetClipboardString() {
    if (clipboardString) {
        free(clipboardString);
        clipboardString = nil;
    }

    @autoreleasepool {
        NSPasteboard* pboard = [NSPasteboard generalPasteboard];
        if (![[pboard types] containsObject:NSPasteboardTypeString]) {
            return nil;
        }
        NSString* value = [pboard stringForType:NSPasteboardTypeString];
        if (!value) {
            return nil;
        }

        char* utf8 = [value UTF8String];
        clipboardString = malloc(strlen(utf8) + 1);
        strcpy(clipboardString, utf8);
    }

    return clipboardString;
}

void innerSetClipboardString(char* value) {
    @autoreleasepool {
        NSPasteboard* pboard = [NSPasteboard generalPasteboard];
        [pboard clearContents];
        [pboard setString:@(value) forType:NSPasteboardTypeString];
    }
}
