import x, xlib

type
  GlxContext* = ptr object

const
  GlxRgba* = 4'i32
  GlxDoublebuffer* = 5'i32
  GlxDepthSize* = 12'i32


const libGLX = 
  when defined(linux): "libGL.so.1"
  elif defined(windows): "GL.dll"
  elif defined(macosx): "/usr/X11R6/lib/libGL.dylib"
  else: "libGL.so"

{.pragma: libglx, cdecl, dynlib: libGLX, importc.}


proc glXChooseVisual*(d: Display, screen: cint, attribList: ptr int32): ptr XVisualInfo {.libglx.}

proc glXCreateContext*(d: Display, vis: ptr XVisualInfo, shareList: GlxContext, direct: cint): GlxContext {.libglx.}
proc glXDestroyContext*(d: Display, this: GlxContext) {.libglx.}

proc glXMakeCurrent*(d: Display, drawable: Drawable, ctx: GlxContext) {.libglx.}
proc glXGetCurrentContext*(): GlxContext {.libglx.}

proc glXSwapBuffers*(d: Display, drawable: Drawable) {.libglx.}

proc glXSwapIntervalEXT*(d: Display, drawable: Drawable, interval: cint) {.libglx.}
proc glXSwapIntervalMESA*(interval: cint) {.libglx.}
proc glXSwapIntervalSGI*(interval: cint) {.libglx.}
