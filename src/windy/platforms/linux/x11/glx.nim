import x, xlib

const
  GlxRgba* = 4'i32
  GlxDoublebuffer* = 5'i32
  GlxRedSize* = 8'i32
  GlxGreenSize* = 9'i32
  GlxBlueSize* = 10'i32
  GlxAlphaSize* = 11'i32
  GlxDepthSize* = 12'i32
  GlxStencilSize* = 13'i32
  GlxXVisualType* = 0x22'i32
  GlxTrueColor* = 0x8002'i32
  GlxDrawableType* = 0x8010'i32
  GlxRenderType* = 0x8011'i32
  GlxXRenderable* = 0x8012'i32
  GlxWindowBit* = 1'i32
  GlxRgbaBit* = 1'i32
  GlxSampleBuffers* = 100000'i32
  GlxSamples* = 100001'i32
  GlxContextMajorVersion* = 0x2091'i32
  GlxContextMinorVersion* = 0x2092'i32
  GlxContextProfileMask* = 0x9126'i32
  GlxContextCoreProfileBit* = 1'i32

  LibGLX =
    when defined(linux): "libGL.so.1"
    elif defined(windows): "GL.dll"
    elif defined(macosx): "/usr/X11R6/lib/libGL.dylib"
    else: "libGL.so"

type
  GlxContext* = ptr object
  GlxFbConfig* = ptr object
  GlxCreateContextAttribsProc* = proc(
    d: Display,
    config: GlxFbConfig,
    share: GlxContext,
    direct: cint,
    attributes: ptr cint
  ): GlxContext {.cdecl.}

{.pragma: libglx, cdecl, dynlib: LibGLX, importc.}

proc glXChooseFBConfig*(
  d: Display,
  screen: cint,
  attributes: ptr cint,
  count: ptr cint
): ptr UncheckedArray[GlxFbConfig] {.libglx.}
  ## Returns framebuffer configurations matching the supplied attributes.

proc glXGetVisualFromFBConfig*(
  d: Display,
  config: GlxFbConfig
): ptr XVisualInfo {.libglx.}
  ## Returns the X11 visual associated with a framebuffer configuration.

proc glXQueryExtensionsString*(
  d: Display,
  screen: cint
): cstring {.libglx.}
  ## Returns the GLX extensions supported by this screen.

proc glXGetProcAddressARB*(name: cstring): pointer {.libglx.}
  ## Resolves an OpenGL or GLX extension entry point.

proc glXChooseVisual*(d: Display, screen: cint,
    attribList: ptr int32): ptr XVisualInfo {.libglx.}

proc glXCreateContext*(d: Display, vis: ptr XVisualInfo, shareList: GlxContext,
    direct: cint): GlxContext {.libglx.}
proc glXDestroyContext*(d: Display, this: GlxContext) {.libglx.}

proc glXMakeCurrent*(d: Display, drawable: Drawable, ctx: GlxContext) {.libglx.}
proc glXGetCurrentContext*(): GlxContext {.libglx.}

proc glXSwapBuffers*(d: Display, drawable: Drawable) {.libglx.}

proc glXSwapIntervalEXT*(d: Display, drawable: Drawable,
    interval: cint) {.libglx.}
proc glXSwapIntervalMESA*(interval: cint) {.libglx.}
proc glXSwapIntervalSGI*(interval: cint) {.libglx.}
