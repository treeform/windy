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
""".}

proc canvas_get_width*(): cint {.importc.}
proc canvas_get_height*(): cint {.importc.}
proc set_canvas_size*(width, height: cint) {.importc.}

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
