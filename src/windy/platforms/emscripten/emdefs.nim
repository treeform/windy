# Emscripten specific definitions

proc emscripten_set_main_loop*(f: proc() {.cdecl.}, a: cint, b: bool) {.importc.}

# Additional Emscripten functions that might be needed
proc emscripten_cancel_main_loop*() {.importc.}
proc emscripten_get_now*(): cdouble {.importc.}
proc emscripten_request_animation_frame_loop*(f: proc(time: cdouble): cint {.cdecl.}, userData: pointer): cint {.importc.}
