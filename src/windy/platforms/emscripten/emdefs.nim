# Emscripten specific definitions

proc emscripten_set_main_loop*(f: proc() {.cdecl.}, a: cint, b: bool) {.importc.}

# Additional Emscripten functions that might be needed
proc emscripten_cancel_main_loop*() {.importc.}
proc emscripten_get_now*(): cdouble {.importc.}
proc emscripten_request_animation_frame_loop*(f: proc(time: cdouble): cint {.cdecl.}, userData: pointer): cint {.importc.}

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

EM_JS(void, make_canvas_focusable, (), {
  // Make canvas focusable by setting tabindex
  Module.canvas.tabIndex = 1;
  // Focus the canvas initially
  Module.canvas.focus();
});
""".}

proc canvas_get_width*(): cint {.importc.}
proc canvas_get_height*(): cint {.importc.}
proc set_canvas_size*(width, height: cint) {.importc.}
proc make_canvas_focusable*() {.importc.}

type
  EMSCRIPTEN_RESULT* = cint
  EMSCRIPTEN_WEBGL_CONTEXT_HANDLE* = cint

  EmscriptenWebGLContextAttributes* {.importc: "EmscriptenWebGLContextAttributes", header: "<emscripten/html5.h>".} = object
    alpha*: bool
    depth*: bool
    stencil*: bool
    antialias*: bool
    premultipliedAlpha*: bool
    preserveDrawingBuffer*: bool
    powerPreference*: cint
    failIfMajorPerformanceCaveat*: bool
    majorVersion*: cint
    minorVersion*: cint
    enableExtensionsByDefault*: bool
    explicitSwapControl*: bool
    proxyContextToMainThread*: cint
    renderViaOffscreenBackBuffer*: bool

# Emscripten WebGL context functions - use header definitions
proc emscripten_webgl_init_context_attributes*(attrs: ptr EmscriptenWebGLContextAttributes) {.importc, header: "<emscripten/html5.h>".}
proc emscripten_webgl_create_context*(target: cstring, attrs: ptr EmscriptenWebGLContextAttributes): EMSCRIPTEN_WEBGL_CONTEXT_HANDLE {.importc, header: "<emscripten/html5.h>".}
proc emscripten_webgl_make_context_current*(context: EMSCRIPTEN_WEBGL_CONTEXT_HANDLE): EMSCRIPTEN_RESULT {.importc, header: "<emscripten/html5.h>".}

# Mouse event handling
type
  EmscriptenMouseEvent* {.importc: "EmscriptenMouseEvent", header: "<emscripten/html5.h>".} = object
    timestamp*: cdouble
    screenX*, screenY*: clong
    clientX*, clientY*: clong
    ctrlKey*, shiftKey*, altKey*, metaKey*: bool
    button*: cushort
    buttons*: cushort
    movementX*, movementY*: clong
    targetX*, targetY*: clong
    canvasX*, canvasY*: clong
    padding*: clong

  EmscriptenWheelEvent* {.importc: "EmscriptenWheelEvent", header: "<emscripten/html5.h>".} = object
    mouse*: EmscriptenMouseEvent
    deltaX*, deltaY*, deltaZ*: cdouble
    deltaMode*: culong

  EmscriptenKeyboardEvent* {.importc: "EmscriptenKeyboardEvent", header: "<emscripten/html5.h>".} = object
    key*: array[32, char]
    code*: array[32, char]
    location*: culong
    ctrlKey*, shiftKey*, altKey*, metaKey*: bool
    repeat*: bool
    locale*: array[32, char]
    charValue*: array[32, char]
    charCode*: culong
    keyCode*: culong
    which*: culong

  EmscriptenFocusEvent* {.importc: "EmscriptenFocusEvent", header: "<emscripten/html5.h>".} = object
    nodeName*: array[128, char]
    id*: array[128, char]

  EmscriptenUiEvent* {.importc: "EmscriptenUiEvent", header: "<emscripten/html5.h>".} = object
    detail*: clong
    documentBodyClientWidth*: cint
    documentBodyClientHeight*: cint
    windowInnerWidth*: cint
    windowInnerHeight*: cint
    windowOuterWidth*: cint
    windowOuterHeight*: cint
    scrollTop*: cint
    scrollLeft*: cint

type
  EM_BOOL* = cint
  EmscriptenMouseEventCallback* = proc(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.}
  EmscriptenWheelEventCallback* = proc(eventType: cint, wheelEvent: ptr EmscriptenWheelEvent, userData: pointer): EM_BOOL {.cdecl.}
  EmscriptenKeyboardEventCallback* = proc(eventType: cint, keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer): EM_BOOL {.cdecl.}
  EmscriptenFocusEventCallback* = proc(eventType: cint, focusEvent: ptr EmscriptenFocusEvent, userData: pointer): EM_BOOL {.cdecl.}
  EmscriptenUiEventCallback* = proc(eventType: cint, uiEvent: ptr EmscriptenUiEvent, userData: pointer): EM_BOOL {.cdecl.}

proc emscripten_set_mousedown_callback_on_thread*(target: cstring, userData: pointer, useCapture: EM_BOOL, callback: EmscriptenMouseEventCallback, targetThread: pointer): EMSCRIPTEN_RESULT {.importc, header: "<emscripten/html5.h>".}
proc emscripten_set_mouseup_callback_on_thread*(target: cstring, userData: pointer, useCapture: EM_BOOL, callback: EmscriptenMouseEventCallback, targetThread: pointer): EMSCRIPTEN_RESULT {.importc, header: "<emscripten/html5.h>".}
proc emscripten_set_mousemove_callback_on_thread*(target: cstring, userData: pointer, useCapture: EM_BOOL, callback: EmscriptenMouseEventCallback, targetThread: pointer): EMSCRIPTEN_RESULT {.importc, header: "<emscripten/html5.h>".}
proc emscripten_set_wheel_callback_on_thread*(target: cstring, userData: pointer, useCapture: EM_BOOL, callback: EmscriptenWheelEventCallback, targetThread: pointer): EMSCRIPTEN_RESULT {.importc, header: "<emscripten/html5.h>".}
proc emscripten_set_keydown_callback_on_thread*(target: cstring, userData: pointer, useCapture: EM_BOOL, callback: EmscriptenKeyboardEventCallback, targetThread: pointer): EMSCRIPTEN_RESULT {.importc, header: "<emscripten/html5.h>".}
proc emscripten_set_keyup_callback_on_thread*(target: cstring, userData: pointer, useCapture: EM_BOOL, callback: EmscriptenKeyboardEventCallback, targetThread: pointer): EMSCRIPTEN_RESULT {.importc, header: "<emscripten/html5.h>".}
proc emscripten_set_keypress_callback_on_thread*(target: cstring, userData: pointer, useCapture: EM_BOOL, callback: EmscriptenKeyboardEventCallback, targetThread: pointer): EMSCRIPTEN_RESULT {.importc, header: "<emscripten/html5.h>".}
proc emscripten_set_blur_callback_on_thread*(target: cstring, userData: pointer, useCapture: EM_BOOL, callback: EmscriptenFocusEventCallback, targetThread: pointer): EMSCRIPTEN_RESULT {.importc, header: "<emscripten/html5.h>".}
proc emscripten_set_focus_callback_on_thread*(target: cstring, userData: pointer, useCapture: EM_BOOL, callback: EmscriptenFocusEventCallback, targetThread: pointer): EMSCRIPTEN_RESULT {.importc, header: "<emscripten/html5.h>".}
proc emscripten_set_resize_callback_on_thread*(target: cstring, userData: pointer, useCapture: EM_BOOL, callback: EmscriptenUiEventCallback, targetThread: pointer): EMSCRIPTEN_RESULT {.importc, header: "<emscripten/html5.h>".}

const
  EMSCRIPTEN_EVENT_KEYPRESS* = 1
  EMSCRIPTEN_EVENT_KEYDOWN* = 2
  EMSCRIPTEN_EVENT_KEYUP* = 3
  EMSCRIPTEN_EVENT_CLICK* = 4
  EMSCRIPTEN_EVENT_MOUSEDOWN* = 5
  EMSCRIPTEN_EVENT_MOUSEUP* = 6
  EMSCRIPTEN_EVENT_DBLCLICK* = 7
  EMSCRIPTEN_EVENT_MOUSEMOVE* = 8
  EMSCRIPTEN_EVENT_WHEEL* = 9
  EMSCRIPTEN_EVENT_RESIZE* = 10
  EMSCRIPTEN_EVENT_SCROLL* = 11
  EMSCRIPTEN_EVENT_BLUR* = 12
  EMSCRIPTEN_EVENT_FOCUS* = 13
  EMSCRIPTEN_EVENT_FOCUSIN* = 14
  EMSCRIPTEN_EVENT_FOCUSOUT* = 15

# Thread constants for event callbacks
# Using cast[pointer](1) for the main thread context
const EM_CALLBACK_THREAD_CONTEXT* = cast[pointer](1)

# Event target constants
const EMSCRIPTEN_EVENT_TARGET_WINDOW* = cstring(nil)
const EMSCRIPTEN_EVENT_TARGET_DOCUMENT* = cstring("#document")
const EMSCRIPTEN_EVENT_TARGET_SCREEN* = cstring("#screen")
