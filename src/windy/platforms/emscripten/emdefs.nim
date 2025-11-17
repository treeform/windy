# Allow Emscripten to do odd things with function pointers.
{.passC: "-Wno-incompatible-function-pointer-types".}

# Emscripten specific definitions

proc emscripten_set_main_loop*(f: proc() {.cdecl.}, a: cint, b: bool) {.importc.}

# Additional Emscripten functions that might be needed
proc emscripten_cancel_main_loop*() {.importc.}
proc emscripten_get_now*(): cdouble {.importc.}
proc emscripten_request_animation_frame_loop*(f: proc(time: cdouble): cint {.cdecl.}, userData: pointer): cint {.importc.}
proc emscripten_sleep*(ms: cuint) {.importc.}

# WebGL bindings
{.emit: """
#include <emscripten.h>
#include <emscripten/html5.h>
#include <GLES2/gl2.h>

EM_JS(int, get_canvas_width, (), {
  return Module.canvas.width;
});

EM_JS(int, get_canvas_height, (), {
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

EM_JS(void, setup_resize_observer, (void* userData), {
  // Store the userData pointer for resize callbacks
  Module.resizeUserData = userData;

  // Hook into the existing Module.setCanvasSize if it exists
  if (Module.setCanvasSize) {
    var originalSetCanvasSize = Module.setCanvasSize;
    Module.setCanvasSize = function(width, height) {
      // Call the original function
      originalSetCanvasSize.call(Module, width, height);
      // Trigger our resize callback
      if (typeof _onCanvasResize !== 'undefined') {
        _onCanvasResize(Module.resizeUserData);
      }
    };
  }

  // Also set up window resize listener as fallback
  if (!Module.resizeHandler) {
    Module.resizeHandler = function() {
      // Call the exported C function directly
      if (typeof _onCanvasResize !== 'undefined') {
        _onCanvasResize(Module.resizeUserData);
      }
    };
    window.addEventListener('resize', Module.resizeHandler);
  }

  // Monitor canvas size changes using ResizeObserver if available
  if (typeof ResizeObserver !== 'undefined' && Module.canvas) {
    if (!Module.canvasResizeObserver) {
      Module.canvasResizeObserver = new ResizeObserver(function(entries) {
        if (typeof _onCanvasResize !== 'undefined') {
          _onCanvasResize(Module.resizeUserData);
        }
      });
      Module.canvasResizeObserver.observe(Module.canvas);
    }
  }
});

EM_JS(void, set_document_title, (const char* title), {
  document.title = UTF8ToString(title);
});

EM_JS(int, get_window_url_length, (), {
  if (typeof location === 'undefined' || typeof location.href === 'undefined') return 1;
  var s = location.href;
  return lengthBytesUTF8(s) + 1; // include null terminator
});

EM_JS(int, get_window_url_into, (char* output, int maxLen), {
  var s = (typeof location !== 'undefined' && typeof location.href !== 'undefined') ? location.href : "";
  return stringToUTF8(s, output, maxLen);
});

EM_JS(void, open_temp_text_file, (const char* title, const char* text), {
  const win = window.open('', '_blank');
  if (!win) {
    console.error("Popup blocked");
    return;
  }
  const titleUtf8 = UTF8ToString(title);
  const textUtf8 = UTF8ToString(text);
  win.document.title = titleUtf8;
  const pre = win.document.createElement('pre');
  pre.innerText = textUtf8;
  win.document.body.appendChild(pre);
});
""".}

proc get_canvas_width*(): cint {.importc.}
proc get_canvas_height*(): cint {.importc.}
proc set_canvas_size*(width, height: cint) {.importc.}
proc make_canvas_focusable*() {.importc.}
proc setup_resize_observer*(userData: pointer) {.importc.}
proc set_document_title*(title: cstring) {.importc.}
proc get_window_url_length*(): cint {.importc.}
proc get_window_url_into*(output: cstring, maxLen: cint): cint {.importc.}
proc open_temp_text_file*(title, text: cstring) {.importc.}

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

# Event target constants (match html5.h sentinel pointers)
const EMSCRIPTEN_EVENT_TARGET_INVALID* = cast[cstring](0)
const EMSCRIPTEN_EVENT_TARGET_DOCUMENT* = cast[cstring](1)
const EMSCRIPTEN_EVENT_TARGET_WINDOW* = cast[cstring](2)
const EMSCRIPTEN_EVENT_TARGET_SCREEN* = cast[cstring](3)

# Fetch API bindings
type
  emscripten_fetch_t* {.importc: "emscripten_fetch_t", header: "<emscripten/fetch.h>".} = object
    id*: cuint
    userData*: pointer
    url*: cstring
    data*: pointer
    numBytes*: culonglong
    dataOffset*: culonglong
    totalBytes*: culonglong
    readyState*: cushort
    status*: cushort
    statusText*: array[64, char]
    responseHeaders*: cstring

  emscripten_fetch_attr_t* {.importc: "emscripten_fetch_attr_t", header: "<emscripten/fetch.h>".} = object
    requestMethod*: array[32, char]
    userData*: pointer
    onsuccess*: proc(fetch: ptr emscripten_fetch_t) {.cdecl.}
    onerror*: proc(fetch: ptr emscripten_fetch_t) {.cdecl.}
    onprogress*: proc(fetch: ptr emscripten_fetch_t) {.cdecl.}
    onreadystatechange*: proc(fetch: ptr emscripten_fetch_t) {.cdecl.}
    attributes*: cuint
    timeoutMSecs*: culong
    withCredentials*: EM_BOOL
    requestData*: pointer
    requestDataSize*: csize_t
    requestHeaders*: ptr cstring
    overriddenMimeType*: cstring
    userName*: cstring
    password*: cstring

const
  EMSCRIPTEN_FETCH_LOAD_TO_MEMORY* = 1.cuint
  EMSCRIPTEN_FETCH_STREAM_DATA* = 2.cuint
  EMSCRIPTEN_FETCH_PERSIST_FILE* = 4.cuint
  EMSCRIPTEN_FETCH_APPEND* = 8.cuint
  EMSCRIPTEN_FETCH_REPLACE* = 16.cuint
  EMSCRIPTEN_FETCH_NO_DOWNLOAD* = 32.cuint
  EMSCRIPTEN_FETCH_SYNCHRONOUS* = 64.cuint
  EMSCRIPTEN_FETCH_WAITABLE* = 128.cuint

proc emscripten_fetch_attr_init*(attr: ptr emscripten_fetch_attr_t) {.importc, header: "<emscripten/fetch.h>".}
proc emscripten_fetch*(attr: ptr emscripten_fetch_attr_t, url: cstring): ptr emscripten_fetch_t {.importc, header: "<emscripten/fetch.h>".}
proc emscripten_fetch_close*(fetch: ptr emscripten_fetch_t) {.importc, header: "<emscripten/fetch.h>".}
