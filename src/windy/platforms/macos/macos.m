// errors
// memory
// 1270 not 1280

#import <Cocoa/Cocoa.h>

NSInteger const decoratedWindowMask = NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask;
NSInteger const undecoratedWindowMask = NSBorderlessWindowMask | NSMiniaturizableWindowMask;

typedef void (*Handler)(void* windowPtr);
typedef void (*MouseHandler)(void* windowPtr, int x, int y);
typedef void (*ScrollHandler)(void* windowPtr, float x, float y);

static void createMenuBar(void) {
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

static int pickOpenGLProfile(int majorVersion) {
    if (majorVersion == 4) {
        return NSOpenGLProfileVersion4_1Core;
    }
    if (majorVersion == 3) {
        return NSOpenGLProfileVersion3_2Core;
    }
    return NSOpenGLProfileVersionLegacy;
}

static int convertY(int y) {
    // Converts y from relative to the bottom of the screen to relative to the top of the screen.
    int screenHeight = (int)CGDisplayBounds(CGMainDisplayID()).size.height;
    return screenHeight - y - 1;
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

@interface WindyContentView : NSOpenGLView
{
    NSTrackingArea* trackingArea;
}
@end

WindyApplicationDelegate* appDelegate;

Handler onMove, onResize, onCloseRequested, onFocusChange;
MouseHandler onMouseMove;
ScrollHandler onScroll;

bool innerGetVisible(WindyWindow* window) {
    return window.isVisible;
}

bool innerGetDecorated(WindyWindow* window) {
    return (window.styleMask & NSTitledWindowMask) != 0;
}

bool innerGetResizable(WindyWindow* window) {
    return (window.styleMask & NSResizableWindowMask) != 0;
}

void innerGetSize(WindyWindow* window, int* width, int* height) {
    NSRect contentRect = [[window contentView] frame];
    *width = contentRect.size.width;
    *height = contentRect.size.height;
}

void innerGetPos(WindyWindow* window, int* x, int* y) {
    NSRect contentRect = [window contentRectForFrameRect:[window frame]];
    *x = contentRect.origin.x;
    *y = convertY(contentRect.origin.y + contentRect.size.height - 1);
}

void innerGetFramebufferSize(WindyWindow* window, int* width, int* height) {
    NSRect contentRect = [[window contentView] frame];
    NSRect backingRect = [[window contentView] convertRectToBacking:contentRect];
    *width = backingRect.size.width;
    *height = backingRect.size.height;
}

void innerGetContentScale(WindyWindow* window, float* scale) {
    NSRect contentRect = [[window contentView] frame];
    NSRect backingRect = [[window contentView] convertRectToBacking:contentRect];
    *scale = backingRect.size.width / contentRect.size.width;
}

bool innerGetFocused(WindyWindow* window) {
    return [window isKeyWindow];
}

bool innerGetMinimized(WindyWindow* window) {
    return [window isMiniaturized];
}

bool innerGetMaximized(WindyWindow* window) {
    return [window isZoomed];
}

void innerSetTitle(WindyWindow* window, char* title) {
    NSString* nsTitle = [NSString stringWithUTF8String:title];
    [window setTitle:nsTitle];
    [window setMiniwindowTitle:nsTitle];
}

void innerSetVisible(WindyWindow* window, bool visible) {
    if (visible) {
        [window orderFront:nil];
    } else {
        [window orderOut:nil];
    }
}

void innerSetDecorated(WindyWindow* window, bool decorated) {
    window.styleMask = decorated ? decoratedWindowMask : undecoratedWindowMask;
}

void innerSetResizable(WindyWindow* window, bool resizable) {
    if (!innerGetDecorated(window)) {
        return;
    }

    if (resizable) {
        window.styleMask |= NSResizableWindowMask;
    } else {
        window.styleMask &= ~NSResizableWindowMask;
    }
}

void innerSetSize(WindyWindow* window, int width, int height) {
    NSRect contentRect = [window contentRectForFrameRect:[window frame]];
    contentRect.origin.y += contentRect.size.height - height;
    contentRect.size = NSMakeSize(width, height);
    [window setFrame:[window frameRectForContentRect:contentRect]
                                             display:YES];
}

void innerSetPos(WindyWindow* window, int x, int y) {
    NSRect contentRect = [[window contentView] frame];
    NSRect rect = NSMakeRect(x, convertY(y + contentRect.size.height - 1), 0, 0);
    [window setFrameOrigin:rect.origin];
}

void innerSetMinimized(WindyWindow* window, bool minimized) {
    if (minimized && !innerGetMinimized(window)) {
        [window miniaturize:nil];
    } else if (!minimized && innerGetMinimized(window)) {
        [window deminiaturize:nil];
    }
}

void innerSetMaximized(WindyWindow* window, bool maximized) {
    if (maximized && !innerGetMinimized(window)) {
        [window zoom:nil];
    } else if (!maximized && innerGetMaximized(window)) {
        [window zoom:nil];
    }
}

void innerInit(
    Handler handleMove,
    Handler handleResize,
    Handler handleCloseRequested,
    Handler handleFocusChange,
    MouseHandler handleMouseMove,
    ScrollHandler handleScroll
) {
    onMove = handleMove;
    onResize = handleResize;
    onCloseRequested = handleCloseRequested;
    onFocusChange = handleFocusChange;
    onMouseMove = handleMouseMove;
    onScroll = handleScroll;

    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp setPresentationOptions:NSApplicationPresentationDefault];
    [NSApp activateIgnoringOtherApps:YES];

    appDelegate = [[WindyApplicationDelegate alloc] init];
    [NSApp setDelegate:appDelegate];

    [NSApp finishLaunching];
}

void innerPollEvents() {
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

@implementation WindyWindow

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
                                    // NSTrackingEnabledDuringMouseDrag |
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

- (BOOL)acceptsFirstMouse:(NSEvent*)event {
    return YES;
}

- (void)mouseMoved:(NSEvent*)event {
    NSRect contentRect = [self frame];
    NSPoint pos = [event locationInWindow];

    onMouseMove(self.window, round(pos.x), round(contentRect.size.height - pos.y));
}

- (void)mouseDragged:(NSEvent*)event {
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

@end

void innerMakeContextCurrent(WindyWindow* window) {
    [[[window contentView] openGLContext] makeCurrentContext];
}

void innerSwapBuffers(WindyWindow* window) {
    [[[window contentView] openGLContext] flushBuffer];
}

void innerNewWindow(
    char* title,
    int width,
    int height,
    bool vsync,
    int openglMajorVersion,
    int openglMinorVersion,
    int msaa,
    int depthBits,
    int stencilBits,
    WindyWindow** windowRet
) {
    NSRect contentRect = NSMakeRect(0, 0, width, height);

    WindyWindow* window = [[WindyWindow alloc] initWithContentRect:contentRect
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

    [window setContentView:view];
    [window setTitle:[NSString stringWithUTF8String:title]];
    [window setDelegate:window];

    innerPollEvents();

    *windowRet = window;
}
