// gcc Cocoa.m -o OSXWindow -framework Cocoa -framework Quartz -framework OpenGL

#import <Cocoa/Cocoa.h>
#import <QuartzCore/CVDisplayLink.h>
#import <OpenGL/OpenGL.h>
#include <OpenGL/gl3.h>


@class View;
static CVReturn GlobalDisplayLinkCallback(CVDisplayLinkRef, const CVTimeStamp*, const CVTimeStamp*, CVOptionFlags, CVOptionFlags*, void*);

@interface View : NSOpenGLView <NSWindowDelegate> {
@public
	CVDisplayLinkRef displayLink;
	bool running;
	NSRect windowRect;
	NSRecursiveLock* appLock;
}
@end

@implementation View
- (id) initWithFrame: (NSRect) frame {

    printf("initWithFrame\n");

	running = true;

	// No multisampling
	int samples = 0;

	// Keep multisampling attributes at the start of the attribute lists
    // since code below assumes they are array elements 0 through 4.
	NSOpenGLPixelFormatAttribute windowedAttrs[] =
	{
		NSOpenGLPFAMultisample,
		NSOpenGLPFASampleBuffers, samples ? 1 : 0,
		NSOpenGLPFASamples, samples,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAColorSize, 32,
		NSOpenGLPFADepthSize, 24,
		NSOpenGLPFAAlphaSize, 8,
		NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
		0
	};

	// Try to choose a supported pixel format
	NSOpenGLPixelFormat* pf = [
        [NSOpenGLPixelFormat alloc]
        initWithAttributes:windowedAttrs
    ];

	if (!pf) {
		bool valid = false;
		while (!pf && samples > 0) {
			samples /= 2;
			windowedAttrs[2] = samples ? 1 : 0;
			windowedAttrs[4] = samples;
			pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:windowedAttrs];
			if (pf) {
				valid = true;
				break;
			}
		}

		if (!valid) {
			NSLog(@"OpenGL pixel format not supported.");
			return nil;
		}
	}

	self = [super initWithFrame:frame pixelFormat:[pf autorelease]];
	appLock = [[NSRecursiveLock alloc] init];

	return self;
}

- (void) prepareOpenGL {

    printf("prepareOpenGL\n");

	[super prepareOpenGL];

	[[self window] setLevel: NSNormalWindowLevel];
	[[self window] makeKeyAndOrderFront: self];

	// Make all the OpenGL calls to setup rendering and build the necessary rendering objects
	[[self openGLContext] makeCurrentContext];
	// Synchronize buffer swaps with vertical refresh rate
	GLint swapInt = 1; // Vsynch on!
	[[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];

	// Create a display link capable of being used with all active displays
	CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);

	// Set the renderer output callback function
	CVDisplayLinkSetOutputCallback(displayLink, &GlobalDisplayLinkCallback, self);

	CGLContextObj cglContext = (CGLContextObj)[[self openGLContext] CGLContextObj];
	CGLPixelFormatObj cglPixelFormat = (CGLPixelFormatObj)[[self pixelFormat] CGLPixelFormatObj];
	CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cglContext, cglPixelFormat);

	GLint dim[2] = {windowRect.size.width, windowRect.size.height};
	CGLSetParameter(cglContext, kCGLCPSurfaceBackingSize, dim);
	CGLEnable(cglContext, kCGLCESurfaceBackingSize);

	// Activate the display link
	CVDisplayLinkStart(displayLink);
}

// Tell the window to accept input events
- (BOOL)acceptsFirstResponder {
	return YES;
}

- (void)mouseMoved:(NSEvent*) event {
	[appLock lock];
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	// NSLog(@"mouseMoved: %lf, %lf", point.x, point.y);
	[appLock unlock];
}

- (void) mouseDragged: (NSEvent*) event {
	[appLock lock];
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	// NSLog(@"mouseDragged: %lf, %lf", point.x, point.y);
	[appLock unlock];
}

- (void)scrollWheel: (NSEvent*) event  {
	[appLock lock];
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Mouse wheel at: %lf, %lf. Delta: %lf", point.x, point.y, [event deltaY]);
	[appLock unlock];
}

- (void) mouseDown: (NSEvent*) event {
	[appLock lock];
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Left mouse down: %lf, %lf", point.x, point.y);
	[appLock unlock];
}

- (void) mouseUp: (NSEvent*) event {
	[appLock lock];
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Left mouse up: %lf, %lf", point.x, point.y);
	[appLock unlock];
}

- (void) rightMouseDown: (NSEvent*) event {
	[appLock lock];
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Right mouse down: %lf, %lf", point.x, point.y);
	[appLock unlock];
}

- (void) rightMouseUp: (NSEvent*) event {
	[appLock lock];
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Right mouse up: %lf, %lf", point.x, point.y);
	[appLock unlock];
}

- (void)otherMouseDown: (NSEvent*) event {
	[appLock lock];
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Middle mouse down: %lf, %lf", point.x, point.y);
	[appLock unlock];
}

- (void)otherMouseUp: (NSEvent*) event {
	[appLock lock];
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Middle mouse up: %lf, %lf", point.x, point.y);
	[appLock unlock];
}

- (void) mouseEntered: (NSEvent*)event {
	[appLock lock];
	NSLog(@"Mouse entered");
	[appLock unlock];
}

- (void) mouseExited: (NSEvent*)event {
	[appLock lock];
	NSLog(@"Mouse left");
	[appLock unlock];
}

- (void) keyDown: (NSEvent*) event {
	[appLock lock];
	if ([event isARepeat] == NO) {
		NSLog(@"Key down: %d", [event keyCode]);
	}
	[appLock unlock];
}

- (void) keyUp: (NSEvent*) event {
	[appLock lock];
	NSLog(@"Key up: %d", [event keyCode]);
	[appLock unlock];
}

// Update
- (CVReturn) getFrameForTime:(const CVTimeStamp*)outputTime {
	[appLock lock];

	[[self openGLContext] makeCurrentContext];
	CGLLockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);

	// NSLog(@"Update");

	CGLFlushDrawable((CGLContextObj)[[self openGLContext] CGLContextObj]);
    CGLUnlockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);

	[appLock unlock];

	return kCVReturnSuccess;
}

// Resize
- (void)windowDidResize:(NSNotification*)notification {
	NSSize size = [ [ self.window contentView ] frame ].size;
	[appLock lock];
	[[self openGLContext] makeCurrentContext];
	CGLLockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
	NSLog(@"Window resize: %lf, %lf", size.width, size.height);
	// Temp
	windowRect.size.width = size.width;
	windowRect.size.height = size.height;
	glViewport(0, 0, windowRect.size.width, windowRect.size.height);
	// End temp
	CGLUnlockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
	[appLock unlock];
}

- (void)resumeDisplayRenderer  {
    [appLock lock];
    CVDisplayLinkStop(displayLink);
    [appLock unlock];
}

- (void)haltDisplayRenderer  {
    [appLock lock];
    CVDisplayLinkStop(displayLink);
    [appLock unlock];
}

// Terminate window when the red X is pressed
-(void)windowWillClose:(NSNotification *)notification {
	if (running) {
		running = false;

		[appLock lock];
		NSLog(@"Cleanup");

		CVDisplayLinkStop(displayLink);
		CVDisplayLinkRelease(displayLink);

		[appLock unlock];
	}

	[NSApp terminate:self];
}

// Cleanup
- (void) dealloc {
	[appLock release];
	[super dealloc];
}
@end

static CVReturn GlobalDisplayLinkCallback(
    CVDisplayLinkRef displayLink,
    const CVTimeStamp* now,
    const CVTimeStamp* outputTime,
    CVOptionFlags flagsIn,
    CVOptionFlags* flagsOut,
    void* displayLinkContext
) {
	CVReturn result = [(View*)displayLinkContext getFrameForTime:outputTime];
	return result;
}

void innerInit() {
    [NSApplication sharedApplication];
}

void innerPollEvents() {
    @autoreleasepool {
        while(true)
        {
            NSEvent* event = [NSApp
                nextEventMatchingMask:NSEventMaskAny
                untilDate:[NSDate distantPast]
                inMode:NSDefaultRunLoopMode
                dequeue:YES
            ];
            if (event == nil)
                break;
            [NSApp sendEvent:event];
        }
    }
}

void innerMakeContextCurrent(View* view) {
    [[view openGLContext] makeCurrentContext];
}

void innerSwapBuffers(View* view) {
    CGLFlushDrawable((CGLContextObj)[[view openGLContext] CGLContextObj]);
}

void innerLock(View* view) {
    [view->appLock lock];
}

void innerUnlock(View* view) {
    [view->appLock unlock];
}

void innerNewPlatformWindow(
    char* utf8Title,
    int w,
    int h,
    NSWindow **windowRet,
    View **viewRet
) {
	// Create a window:

	// Style flags
	NSUInteger windowStyle =
        NSTitledWindowMask |
        NSClosableWindowMask |
        NSResizableWindowMask |
        NSMiniaturizableWindowMask;

	// Window bounds (x, y, width, height)
	NSRect screenRect = [[NSScreen mainScreen] frame];
	NSRect viewRect = NSMakeRect(0, 0, w, h);
	NSRect windowRect = NSMakeRect(
        NSMidX(screenRect) - NSMidX(viewRect),
        NSMidY(screenRect) - NSMidY(viewRect),
        viewRect.size.width,
        viewRect.size.height
    );

	NSWindow* window = [[NSWindow alloc]
        initWithContentRect:windowRect
        styleMask:windowStyle
        backing:NSBackingStoreBuffered
        defer:NO
    ];
	[window autorelease];

	// Window controller
	NSWindowController * windowController =
        [[NSWindowController alloc] initWithWindow:window];
	[windowController autorelease];

	// Since Snow Leopard, programs without application bundles and Info.plist files don't get a menubar
	// and can't be brought to the front unless the presentation option is changed
	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

	// Next, we need to create the menu bar. You don't need to give the first item in the menubar a name
	// (it will get the application's name automatically)
	id menubar = [[NSMenu new] autorelease];
	id appMenuItem = [[NSMenuItem new] autorelease];
	[menubar addItem:appMenuItem];
	[NSApp setMainMenu:menubar];

	// Then we add the quit item to the menu. Fortunately the action is simple since terminate: is
	// already implemented in NSApplication and the NSApplication is always in the responder chain.
	id appMenu = [[NSMenu new] autorelease];
	id appName = [[NSProcessInfo processInfo] processName];
	id quitTitle = [@"Quit " stringByAppendingString:appName];
	id quitMenuItem = [[[NSMenuItem alloc] initWithTitle:quitTitle
		action:@selector(terminate:) keyEquivalent:@"q"] autorelease];
	[appMenu addItem:quitMenuItem];
	[appMenuItem setSubmenu:appMenu];

	// Create app delegate to handle system events
	View* view = [[[View alloc] initWithFrame:windowRect] autorelease];
	view->windowRect = windowRect;
	[window setAcceptsMouseMovedEvents:YES];
	[window setContentView:view];
	[window setDelegate:view];

	// Add fullscreen button
	[window setCollectionBehavior: NSWindowCollectionBehaviorFullScreenPrimary];

	// Show window and run event loop
    [NSApp activateIgnoringOtherApps:YES];
    [window makeKeyAndOrderFront: nil];

    NSString *title = [NSString stringWithUTF8String:utf8Title];
    [window setTitle:title];

    // Window need to process some events to initilize openGL
    innerPollEvents();

    windowRet[0] = window;
    viewRet[0] = view;

}
