// gcc Cocoa.m -o OSXWindow -framework Cocoa -framework Quartz -framework OpenGL

#import <Cocoa/Cocoa.h>
#import <QuartzCore/CVDisplayLink.h>
#import <OpenGL/OpenGL.h>
#include <OpenGL/gl3.h>


@class View;

@interface View : NSOpenGLView <NSWindowDelegate> {
@public
	CVDisplayLinkRef displayLink;
	bool running;
	NSRect windowRect;
}
@end

@implementation View
- (id) initWithFrame: (NSRect) frame {

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

	return self;
}

- (void) prepareOpenGL {
	[super prepareOpenGL];

	// Make all the OpenGL calls to setup rendering and build the necessary rendering objects
	[[self openGLContext] makeCurrentContext];
	// Synchronize buffer swaps with vertical refresh rate
	GLint swapInt = 1; // Vsynch on!
	[[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];

	// Create a display link capable of being used with all active displays
	CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);

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
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	// NSLog(@"mouseMoved: %lf, %lf", point.x, point.y);
}

- (void) mouseDragged: (NSEvent*) event {
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	// NSLog(@"mouseDragged: %lf, %lf", point.x, point.y);
}

- (void)scrollWheel: (NSEvent*) event  {
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Mouse wheel at: %lf, %lf. Delta: %lf", point.x, point.y, [event deltaY]);
}

- (void) mouseDown: (NSEvent*) event {
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Left mouse down: %lf, %lf", point.x, point.y);
}

- (void) mouseUp: (NSEvent*) event {
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Left mouse up: %lf, %lf", point.x, point.y);
}

- (void) rightMouseDown: (NSEvent*) event {
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Right mouse down: %lf, %lf", point.x, point.y);
}

- (void) rightMouseUp: (NSEvent*) event {
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Right mouse up: %lf, %lf", point.x, point.y);
}

- (void)otherMouseDown: (NSEvent*) event {
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Middle mouse down: %lf, %lf", point.x, point.y);
}

- (void)otherMouseUp: (NSEvent*) event {
	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSLog(@"Middle mouse up: %lf, %lf", point.x, point.y);
}

- (void) mouseEntered: (NSEvent*)event {
	NSLog(@"Mouse entered");
}

- (void) mouseExited: (NSEvent*)event {
	NSLog(@"Mouse left");
}

- (void) keyDown: (NSEvent*) event {
	if ([event isARepeat] == NO) {
		NSLog(@"Key down: %d", [event keyCode]);
	}
}

- (void) keyUp: (NSEvent*) event {
	NSLog(@"Key up: %d", [event keyCode]);
}


// Resize
- (void)windowDidResize:(NSNotification*)notification {
	NSSize size = [ [ self.window contentView ] frame ].size;
	[[self openGLContext] makeCurrentContext];
	CGLLockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
	NSLog(@"Window resize: %lf, %lf", size.width, size.height);
	// Temp
	windowRect.size.width = size.width;
	windowRect.size.height = size.height;
	glViewport(0, 0, windowRect.size.width, windowRect.size.height);
	// End temp
	CGLUnlockContext((CGLContextObj)[[self openGLContext] CGLContextObj]);
}

- (void)resumeDisplayRenderer  {
    CVDisplayLinkStop(displayLink);
}

- (void)haltDisplayRenderer  {
    CVDisplayLinkStop(displayLink);
}

// Terminate window when the red X is pressed
-(void)windowWillClose:(NSNotification *)notification {
	if (running) {
		running = false;

		NSLog(@"Cleanup");

		CVDisplayLinkStop(displayLink);
		CVDisplayLinkRelease(displayLink);

	}

	[NSApp terminate:self];
}

// Cleanup
- (void) dealloc {
	[super dealloc];
}
@end

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
