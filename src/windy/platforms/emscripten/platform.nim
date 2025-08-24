import ../../common, ../../internal, vmath, pixie, unicode, times
import emdefs

type
  Window* = ref object
    onCloseRequest*: Callback
    onFrame*: Callback
    onMove*: Callback
    onResize*: Callback
    onFocusChange*: Callback
    onMouseMove*: Callback
    onScroll*: Callback
    onButtonPress*: ButtonCallback
    onButtonRelease*: ButtonCallback
    onRune*: RuneCallback
    onImeChange*: Callback

    size: IVec2
    title: string
    isCloseRequested: bool
    canvas: cstring

# WebGL bindings
{.emit: """
#include <emscripten.h>
#include <emscripten/html5.h>
#include <GLES2/gl2.h>

EM_JS(int, canvas_get_width, (), {
  return Module.canvas.width;
});

EM_JS(int, canvas_get_height, (), {
  return Module.canvas.height;
});

EM_JS(void, set_canvas_size, (int width, int height), {
  Module.canvas.width = width;
  Module.canvas.height = height;
});
""".}

proc canvas_get_width(): cint {.importc.}
proc canvas_get_height(): cint {.importc.}
proc set_canvas_size(width, height: cint) {.importc.}

type
  EMSCRIPTEN_RESULT = cint
  EMSCRIPTEN_WEBGL_CONTEXT_HANDLE = cint

  EmscriptenWebGLContextAttributes {.importc: "EmscriptenWebGLContextAttributes", header: "<emscripten/html5.h>".} = object
    alpha: bool
    depth: bool
    stencil: bool
    antialias: bool
    premultipliedAlpha: bool
    preserveDrawingBuffer: bool
    powerPreference: cint
    failIfMajorPerformanceCaveat: bool
    majorVersion: cint
    minorVersion: cint
    enableExtensionsByDefault: bool
    explicitSwapControl: bool
    proxyContextToMainThread: cint
    renderViaOffscreenBackBuffer: bool

# Emscripten WebGL context functions - use header definitions
proc emscripten_webgl_init_context_attributes(attrs: ptr EmscriptenWebGLContextAttributes) {.importc, header: "<emscripten/html5.h>".}
proc emscripten_webgl_create_context(target: cstring, attrs: ptr EmscriptenWebGLContextAttributes): EMSCRIPTEN_WEBGL_CONTEXT_HANDLE {.importc, header: "<emscripten/html5.h>".}
proc emscripten_webgl_make_context_current(context: EMSCRIPTEN_WEBGL_CONTEXT_HANDLE): EMSCRIPTEN_RESULT {.importc, header: "<emscripten/html5.h>".}

var
  quitRequested*: bool
  onQuitRequest*: Callback
  multiClickInterval*: Duration = initDuration(milliseconds = 200)
  multiClickRadius*: float = 4

  initialized: bool
  windows: seq[Window]
  currentContext: EMSCRIPTEN_WEBGL_CONTEXT_HANDLE

proc init =
  if initialized:
    return
  initialized = true

proc newWindow*(
  title = "",
  size = ivec2(1280, 720),
  pos = ivec2(0, 0),
  screen = 0,
  visible = true,
  vsync = true,
  openglVersion = OpenGL3Dot3,
  msaa = msaaDisabled,
  depthBits = 24,
  stencilBits = 8,
  redBits = 8,
  greenBits = 8,
  blueBits = 8,
  alphaBits = 8,
  decorated = true,
  transparent = false,
  floating = false,
  resizable = true,
  maximized = false,
  minimized = false,
  fullscreen = false,
  focus = true
): Window =
  init()

  result = Window()
  result.title = title
  result.size = size
  result.canvas = "#canvas"

  # Create WebGL context
  var attrs: EmscriptenWebGLContextAttributes
  emscripten_webgl_init_context_attributes(attrs.addr)

  attrs.alpha = alphaBits > 0
  attrs.depth = depthBits > 0
  attrs.stencil = stencilBits > 0
  attrs.antialias = msaa != msaaDisabled
  attrs.premultipliedAlpha = true
  attrs.preserveDrawingBuffer = false
  attrs.majorVersion = 2  # WebGL 2.0
  attrs.minorVersion = 0
  attrs.enableExtensionsByDefault = true

  currentContext = emscripten_webgl_create_context(result.canvas, attrs.addr)
  if currentContext == 0:
    # Try WebGL 1.0 if 2.0 fails
    attrs.majorVersion = 1
    currentContext = emscripten_webgl_create_context(result.canvas, attrs.addr)
    if currentContext == 0:
      raise WindyError.newException("Failed to create WebGL context")

  # Set canvas size
  set_canvas_size(size.x.cint, size.y.cint)

  windows.add(result)

proc makeContextCurrent*(window: Window) =
  if currentContext != 0:
    discard emscripten_webgl_make_context_current(currentContext)

proc swapBuffers*(window: Window) =
  # In Emscripten/WebGL, swapping is automatic
  discard

proc close*(window: Window) =
  window.isCloseRequested = true
  let idx = windows.find(window)
  if idx != -1:
    windows.del(idx)

proc closeRequested*(window: Window): bool =
  window.isCloseRequested

proc pollEvents*() =
  # Emscripten handles events through callbacks
  # This is mostly a no-op but kept for API compatibility
  discard

proc size*(window: Window): IVec2 =
  window.size

proc `size=`*(window: Window, size: IVec2) =
  window.size = size
  set_canvas_size(size.x.cint, size.y.cint)

proc title*(window: Window): string =
  window.title

proc `title=`*(window: Window, title: string) =
  window.title = title
  # In browser context, we could set document.title here

proc visible*(window: Window): bool =
  true

proc `visible=`*(window: Window, visible: bool) =
  # Canvas is always visible in browser
  discard

proc runeInputEnabled*(window: Window): bool =
  true

proc `runeInputEnabled=`*(window: Window, enabled: bool) =
  discard

proc pos*(window: Window): IVec2 =
  ivec2(0, 0)  # Canvas position is controlled by HTML/CSS

proc `pos=`*(window: Window, pos: IVec2) =
  # Canvas position is controlled by HTML/CSS
  discard

proc framebufferSize*(window: Window): IVec2 =
  result.x = canvas_get_width().int32
  result.y = canvas_get_height().int32

proc contentScale*(window: Window): float32 =
  1.0  # Could be implemented to check devicePixelRatio

proc minimized*(window: Window): bool =
  false  # Not applicable in browser

proc `minimized=`*(window: Window, minimized: bool) =
  discard

proc maximized*(window: Window): bool =
  false  # Could check if fullscreen

proc `maximized=`*(window: Window, maximized: bool) =
  discard

proc fullscreen*(window: Window): bool =
  false  # Could be implemented with Fullscreen API

proc `fullscreen=`*(window: Window, fullscreen: bool) =
  discard

proc focused*(window: Window): bool =
  true  # Could be implemented with Page Visibility API

proc `focused=`*(window: Window, focused: bool) =
  discard

proc mousePos*(window: Window): Vec2 =
  vec2(0, 0)  # Would need to track from mouse events

proc mousePos*(window: Window, mouse: Vec2) =
  discard

proc screenToContent*(window: Window, v: Vec2): Vec2 =
  v

proc contentToScreen*(window: Window, v: Vec2): Vec2 =
  v

# Button state tracking
var buttonStates: array[Button, bool]

proc buttonDown*(button: Button): bool =
  buttonStates[button]

proc buttonPressed*(button: Button): bool =
  # Would need to track press events
  false

proc buttonReleased*(button: Button): bool =
  # Would need to track release events
  false

proc buttonToggle*(button: Button): bool =
  # Would need to track toggle state
  false

# Clipboard functions
proc clipboardContent*(): string =
  ""  # Would need JavaScript interop

proc `clipboardContent=`*(content: string) =
  discard  # Would need JavaScript interop

# Screen functions
proc getScreens*(): seq[Screen] =
  @[Screen(
    left: 0,
    right: 1920,  # Would need to query actual screen size
    top: 0,
    bottom: 1080,
    primary: true
  )]

# Cursor functions
proc cursor*(window: Window): Cursor =
  Cursor(kind: DefaultCursor)

proc `cursor=`*(window: Window, cursor: Cursor) =
  discard  # Would need CSS cursor manipulation

# Style functions
proc style*(window: Window): WindowStyle =
  DecoratedResizable

proc `style=`*(window: Window, style: WindowStyle) =
  discard

# Icon functions
proc icon*(window: Window): Image =
  nil

proc `icon=`*(window: Window, icon: Image) =
  discard

proc startDrag*(window: Window, pos: IVec2) =
  discard

proc stopDrag*(window: Window) =
  discard

proc startResize*(window: Window, pos: IVec2, direction: int) =
  discard

proc stopResize*(window: Window) =
  discard

proc vsync*(window: Window): bool =
  true  # Browser controls vsync

proc `vsync=`*(window: Window, vsync: bool) =
  discard

proc openglVersion*(window: Window): OpenGLVersion =
  OpenGL3Dot0  # WebGL 2.0 ~ OpenGL ES 3.0

proc msaa*(window: Window): MSAA =
  msaaDisabled

proc redBits*(window: Window): int =
  8

proc greenBits*(window: Window): int =
  8

proc blueBits*(window: Window): int =
  8

proc alphaBits*(window: Window): int =
  8

proc depthBits*(window: Window): int =
  24

proc stencilBits*(window: Window): int =
  8

# HTTP functions (if needed)
when defined(windyUseStdHttp):
  import ../../http
  export http

# OpenGL extension loading
proc loadExtensions*() =
  # Extensions are loaded automatically in WebGL
  discard

proc run*(window: Window, f: proc() {.cdecl.}) =
  ## This is the only way to run a loop in emscripten.
  emscripten_set_main_loop(f, 0, true)
