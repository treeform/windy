#import <Cocoa/Cocoa.h>

NSInteger const decoratedWindowMask = NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask;
NSInteger const undecoratedWindowMask = NSBorderlessWindowMask | NSMiniaturizableWindowMask;

static void postEmptyEvent(void) {
    NSEvent* event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                        location:NSMakePoint(0, 0)
                                   modifierFlags:0
                                       timestamp:0
                                    windowNumber:0
                                         context:nil
                                         subtype:0
                                           data1:0
                                           data2:0];
    [NSApp postEvent:event atStart:YES];
}

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

@implementation WindyWindow

- (void)windowDidResize:(NSNotification*)notification {
}

- (void)windowDidMove:(NSNotification*)notification {
}

- (BOOL)windowShouldClose:(id)sender {
    return YES;
}

@end

@interface WindyContentView : NSOpenGLView
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

    [[self openGLContext] makeCurrentContext];

    GLint swapInterval = vsync ? 1 : 0;
    [[self openGLContext] setValues:&swapInterval forParameter:NSOpenGLCPSwapInterval];

    return self;
}

@end

WindyApplicationDelegate* appDelegate;

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

void innerInit() {
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
    bool visible,
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

    innerSetVisible(window, visible);

    innerPollEvents();

    *windowRet = window;
}
