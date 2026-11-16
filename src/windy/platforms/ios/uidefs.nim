import ../apple/objc
export objc

{.passL: "-framework UIKit -framework Foundation -framework CoreGraphics".}
{.passL: "-framework Metal -framework MetalKit -framework QuartzCore".}

type
  CGPoint* {.pure, bycopy.} = object
    x*, y*: float64
  CGSize* {.pure, bycopy.} = object
    width*, height*: float64
  CGRect* {.pure, bycopy.} = object
    origin*: CGPoint
    size*: CGSize
  UIEdgeInsets* {.pure, bycopy.} = object
    top*, left*, bottom*, right*: float64
  NSPoint* = CGPoint
  NSSize* = CGSize
  NSRect* = CGRect

  NSObject* = distinct int
  UIResponder* = distinct int
  UIApplication* = distinct int
  UIScene* = distinct int
  UIWindowScene* = distinct int
  UISceneSession* = distinct int
  UISceneConfiguration* = distinct int
  UIWindow* = distinct int
  UIViewController* = distinct int
  UIView* = distinct int
  MTKView* = distinct int
  UIScreen* = distinct int
  UITouch* = distinct int
  UIEvent* = distinct int
  UIPress* = distinct int
  UIKey* = distinct int
  NSSet* = distinct int
  NSMutableSet* = distinct int
  NSArray* = distinct int
  NSNumber* = distinct int
  NSEnumerator* = distinct int
  UIPasteboard* = distinct int
  UIColor* = distinct int
  UIGestureRecognizer* = distinct int
  UIHoverGestureRecognizer* = distinct int
  UIPanGestureRecognizer* = distinct int

converter asView*(view: MTKView): UIView =
  ## Exposes the UIView methods inherited by a MetalKit view.
  UIView(view.int)

converter asView*(window: UIWindow): UIView =
  ## Exposes the UIView methods inherited by a UIKit window.
  UIView(window.int)

converter asResponder*(view: UIView): UIResponder =
  ## Exposes responder-chain methods inherited by a view.
  UIResponder(view.int)

converter asResponder*(controller: UIViewController): UIResponder =
  ## Exposes responder-chain methods inherited by a controller.
  UIResponder(controller.int)

converter asSet*(mutableSet: NSMutableSet): NSSet =
  ## Exposes immutable set operations on a mutable set.
  NSSet(mutableSet.int)

converter asScene*(scene: UIWindowScene): UIScene =
  ## Exposes scene activation methods on a window scene.
  UIScene(scene.int)

converter asGesture*(gesture: UIHoverGestureRecognizer): UIGestureRecognizer =
  ## Exposes common gesture methods on a hover recognizer.
  UIGestureRecognizer(gesture.int)

converter asGesture*(gesture: UIPanGestureRecognizer): UIGestureRecognizer =
  ## Exposes common gesture methods on a pan recognizer.
  UIGestureRecognizer(gesture.int)

proc UIApplicationMain*(
  argc: cint,
  argv: ptr cstring,
  principalClassName: NSString,
  delegateClassName: NSString
): cint {.importc, cdecl.}
  ## Starts UIKit's main event loop using the registered delegate class.

proc MTLCreateSystemDefaultDevice*(): ID {.importc, cdecl.}
  ## Creates the default Metal device as an opaque Objective-C handle.

objc:
  proc init*(self: ID): ID
    ## Initializes an allocated Foundation or UIKit object.
  proc retain*(self: ID): ID
    ## Acquires ownership of an Objective-C object.
  proc release*(self: ID)
    ## Releases one ownership reference.
  proc autorelease*(self: ID): ID
    ## Defers releasing one ownership reference until the pool drains.
  proc isKindOfClass*(self: ID, x: Class): bool
    ## Tests an object's native class hierarchy.
  proc respondsToSelector*(self: ID, x: SEL): bool
    ## Tests whether a native object implements a selector.
  proc becomeFirstResponder*(self: UIResponder): bool
    ## Requests keyboard and responder-chain input.
  proc resignFirstResponder*(self: UIResponder): bool
    ## Relinquishes keyboard and responder-chain input.
  proc canBecomeFirstResponder*(self: UIResponder): bool
    ## Returns whether this responder can receive keyboard input.
  proc sharedApplication*(class: typedesc[UIApplication]): UIApplication
    ## Returns the process's UIKit application.
  proc applicationState*(self: UIApplication): int
    ## Returns the current UIApplicationState value.
  proc initWithName*(
    self: UISceneConfiguration, x: NSString, sessionRole: NSString
  ): UISceneConfiguration
    ## Creates a scene configuration for a session role.
  proc setDelegateClass*(self: UISceneConfiguration, x: Class)
    ## Sets the registered class used to manage the scene.
  proc role*(self: UISceneSession): NSString
    ## Returns the role assigned to a scene session.
  proc activationState*(self: UIScene): int
    ## Returns the current UISceneActivationState value.
  proc screen*(self: UIWindowScene): UIScreen
    ## Returns the screen displaying this scene.
  proc initWithWindowScene*(self: UIWindow, x: UIWindowScene): UIWindow
    ## Creates a UIKit window attached to the supplied scene.
  proc setRootViewController*(self: UIWindow, x: UIViewController)
    ## Installs the controller that owns the window's content.
  proc makeKeyAndVisible*(self: UIWindow)
    ## Displays the window and makes it receive keyboard input.
  proc windowScene*(self: UIWindow): UIWindowScene
    ## Returns the window's owning scene.
  proc screen*(self: UIWindow): UIScreen
    ## Returns the screen displaying this window.
  proc bounds*(self: UIView): CGRect
    ## Returns the view's bounds in UIKit points.
  proc frame*(self: UIView): CGRect
    ## Returns the view's frame in its parent's point coordinates.
  proc window*(self: UIView): UIWindow
    ## Returns the window containing the view.
  proc setFrame*(self: UIView, x: CGRect)
    ## Updates the view's frame in UIKit points.
  proc setHidden*(self: UIView, x: bool)
    ## Controls native view visibility.
  proc setContentScaleFactor*(self: UIView, x: float64)
    ## Sets framebuffer pixels per UIKit point.
  proc contentScaleFactor*(self: UIView): float64
    ## Returns framebuffer pixels per UIKit point.
  proc safeAreaInsets*(self: UIView): UIEdgeInsets
    ## Returns content insets in UIKit points.
  proc setMultipleTouchEnabled*(self: UIView, x: bool)
    ## Controls delivery of simultaneous touches.
  proc setUserInteractionEnabled*(self: UIView, x: bool)
    ## Controls delivery of interaction events.
  proc setAutoresizingMask*(self: UIView, x: uint)
    ## Selects UIKit's flexible dimension behavior.
  proc addGestureRecognizer*(self: UIView, x: UIGestureRecognizer)
    ## Attaches an owned recognizer to the view.
  proc becomeFirstResponder*(self: UIView): bool
    ## Requests keyboard and responder-chain input.
  proc resignFirstResponder*(self: UIView): bool
    ## Relinquishes keyboard and responder-chain input.
  proc setBackgroundColor*(self: UIView, x: UIColor)
    ## Sets the backing view's background color.
  proc setView*(self: UIViewController, x: UIView)
    ## Installs the controller's root view.
  proc view*(self: UIViewController): UIView
    ## Returns the controller's root view.
  proc initWithFrame*(
    self: MTKView, x: CGRect, device: ID
  ): MTKView
    ## Creates the native Metal view with the supplied rendering device.
  proc setDelegate*(self: MTKView, x: ID)
    ## Assigns the weak MetalKit rendering delegate.
  proc setPaused*(self: MTKView, x: bool)
    ## Pauses or resumes display-driven frame callbacks.
  proc isPaused*(self: MTKView): bool
    ## Returns whether frame callbacks are paused.
  proc setEnableSetNeedsDisplay*(self: MTKView, x: bool)
    ## Selects explicit invalidation or continuous drawing.
  proc setPreferredFramesPerSecond*(self: MTKView, x: int)
    ## Sets the desired frame callback frequency.
  proc setColorPixelFormat*(self: MTKView, x: uint)
    ## Sets the drawable's Metal color format.
  proc setDepthStencilPixelFormat*(self: MTKView, x: uint)
    ## Sets the optional depth and stencil texture format.
  proc setFramebufferOnly*(self: MTKView, x: bool)
    ## Restricts drawable textures to render-target usage.
  proc setAutoResizeDrawable*(self: MTKView, x: bool)
    ## Controls automatic drawable sizing after view layout.
  proc drawableSize*(self: MTKView): CGSize
    ## Returns the current drawable dimensions in framebuffer pixels.
  proc setDrawableSize*(self: MTKView, x: CGSize)
    ## Sets drawable dimensions in framebuffer pixels.
  proc device*(self: MTKView): ID
    ## Borrows the Metal device retained by this view.
  proc draw*(self: MTKView)
    ## Requests a frame immediately from MetalKit.
  proc mainScreen*(class: typedesc[UIScreen]): UIScreen
    ## Returns the primary screen before a scene is attached.
  proc scale*(self: UIScreen): float64
    ## Returns the screen's UIKit rendering scale.
  proc nativeScale*(self: UIScreen): float64
    ## Returns the screen's physical display scale.
  proc bounds*(self: UIScreen): CGRect
    ## Returns the screen bounds in UIKit points.
  proc maximumFramesPerSecond*(self: UIScreen): int
    ## Returns the screen's maximum refresh frequency.
  proc locationInView*(self: UITouch, x: UIView): CGPoint
    ## Returns a touch position in the supplied view's point coordinates.
  proc timestamp*(self: UITouch): float64
    ## Returns the touch's monotonic UIKit timestamp.
  proc phase*(self: UITouch): int
    ## Returns the current UITouchPhase value.
  proc `type`*(self: UITouch): int
    ## Returns the current UITouchType value.
  proc allObjects*(self: NSSet): NSArray
    ## Returns an autoreleased array of the set's objects.
  proc count*(self: NSSet): uint
    ## Returns the number of objects in the set.
  proc setWithCapacity*(class: typedesc[NSMutableSet], x: uint): NSMutableSet
    ## Creates an autoreleased mutable set with the expected capacity.
  proc addObject*(self: NSMutableSet, x: ID)
    ## Retains an object in the mutable set.
  proc count*(self: NSArray): uint
    ## Returns the number of objects in the array.
  proc objectAtIndex*(self: NSArray, x: uint): ID
    ## Borrows the object at an array index.
  proc array*(class: typedesc[NSArray]): NSArray
    ## Creates an empty autoreleased array.
  proc arrayWithObject*(class: typedesc[NSArray], x: ID): NSArray
    ## Creates a one-element autoreleased array.
  proc numberWithInteger*(class: typedesc[NSNumber], x: int): NSNumber
    ## Creates an autoreleased boxed integer.
  proc key*(self: UIPress): UIKey
    ## Borrows the hardware keyboard event associated with a press.
  proc phase*(self: UIPress): int
    ## Returns the current UIPressPhase value.
  proc keyCode*(self: UIKey): int
    ## Returns the keyboard's USB HID usage code.
  proc modifierFlags*(self: UIKey): uint
    ## Returns UIKit keyboard modifier flags.
  proc characters*(self: UIKey): NSString
    ## Returns text affected by the current keyboard modifiers.
  proc charactersIgnoringModifiers*(self: UIKey): NSString
    ## Returns text without keyboard modifier transformations.
  proc generalPasteboard*(class: typedesc[UIPasteboard]): UIPasteboard
    ## Returns the system pasteboard.
  proc string*(self: UIPasteboard): NSString
    ## Borrows the first text item on the pasteboard.
  proc setString*(self: UIPasteboard, x: NSString)
    ## Copies text to the system pasteboard.
  proc hasStrings*(self: UIPasteboard): bool
    ## Checks for text without retrieving its contents.
  proc blackColor*(class: typedesc[UIColor]): UIColor
    ## Returns UIKit's shared opaque black color.
  proc initWithTarget*(
    self: UIHoverGestureRecognizer, x: ID, action: SEL
  ): UIHoverGestureRecognizer
    ## Creates a hover recognizer targeting a native selector.
  proc initWithTarget*(
    self: UIPanGestureRecognizer, x: ID, action: SEL
  ): UIPanGestureRecognizer
    ## Creates a pan recognizer targeting a native selector.
  proc state*(self: UIGestureRecognizer): int
    ## Returns the current UIGestureRecognizerState value.
  proc locationInView*(self: UIGestureRecognizer, x: UIView): CGPoint
    ## Returns the gesture location in the view's point coordinates.
  proc setAllowedTouchTypes*(self: UIGestureRecognizer, x: NSArray)
    ## Selects the UIKit touch types accepted by the recognizer.
  proc setCancelsTouchesInView*(self: UIGestureRecognizer, x: bool)
    ## Controls whether recognizing a gesture cancels native touches.
  proc setDelaysTouchesBegan*(self: UIGestureRecognizer, x: bool)
    ## Controls whether a recognizer delays touch beginnings.
  proc setDelaysTouchesEnded*(self: UIGestureRecognizer, x: bool)
    ## Controls whether a recognizer delays touch endings.
  proc setAllowedScrollTypesMask*(self: UIPanGestureRecognizer, x: uint)
    ## Selects discrete and continuous pointer scrolling sources.
  proc translationInView*(self: UIPanGestureRecognizer, x: UIView): CGPoint
    ## Returns accumulated pan translation in UIKit points.
  proc setTranslation*(
    self: UIPanGestureRecognizer, x: CGPoint, inView: UIView
  )
    ## Resets pan translation after consuming a scroll delta.

proc init*[T](value: T): T =
  ## Initializes an allocated object while preserving its handle type.
  cast[T](init(cast[ID](value)))

proc retain*[T](value: T): T {.discardable.} =
  ## Acquires ownership while preserving the native handle type.
  cast[T](retain(cast[ID](value)))

proc release*[T](value: T) =
  ## Releases a native ownership reference; a nil handle is safe.
  release(cast[ID](value))

proc autorelease*[T](value: T): T {.discardable.} =
  ## Defers a native release while preserving the handle type.
  cast[T](autorelease(cast[ID](value)))

proc isKindOfClass*[T](value: T, nativeClass: Class): bool =
  ## Tests the native class hierarchy of a typed object handle.
  isKindOfClass(cast[ID](value), nativeClass)

proc respondsToSelector*[T](value: T, selector: SEL): bool =
  ## Tests whether a typed object handle implements a selector.
  respondsToSelector(cast[ID](value), selector)
