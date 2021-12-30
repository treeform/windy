import vmath
import ../../../common

type
  OpenglContext* = object
    ctx: EglContext
    srf: EglSurface

  EglDisplay = ptr object
  EglConfig = ptr object
  EglSurface = ptr object
  EglContext = ptr object

  EglError {.pure, size: 4.} = enum
    badAccess = 0x3002
    badAlloc = 0x3003
    badAttribute = 0x3004
    badConfig = 0x3005
    badContext = 0x3006
    badCurrentSurface = 0x3007
    badDisplay = 0x3008
    badMatch = 0x3009
    badNativePixmap = 0x300A
    badNativeWindow = 0x300B
    badParameter = 0x300C
    badSurface = 0x300D


const
  eglSurfaceType = int32 0x3033
  eglPBufferBit  = int32 0x0001

  eglRenderableType = int32 0x3040
  eglOpenglEs2Bit   = int32 0x0004

  eglAlphaSize = int32 0x3021
  eglBlueSize  = int32 0x3022
  eglGreenSize = int32 0x3023
  eglRedSize   = int32 0x3024

  eglWidth  = int32 0x3057
  eglHeight = int32 0x3056

  eglNone = int32 0x3038


{.push, cdecl, dynlib: "libEGL.so(|.1)", importc.}

using d: EglDisplay

proc eglGetError(): EglError
proc eglGetDisplay(native: pointer = nil): EglDisplay

proc eglInitialize(d; major: ptr int32 = nil, minor: ptr int32 = nil): bool
proc eglTerminate(d)

proc eglChooseConfig(d; attrs: ptr int32, retConfigs: ptr EglConfig, maxConfigs: int32, retConfigCount: ptr int32): bool

proc eglCreateContext(d; config: EglConfig, share: EglContext = nil, attrs: ptr int32 = nil): EglContext

proc eglCreatePbufferSurface(d; config: EglConfig, attrs: ptr int32 = nil): EglSurface

proc eglMakeCurrent(d; draw, read: EglSurface, ctx: EglContext): bool

{.pop.}


template expect(x) =
  if not x: raise WindyError.newException("Error creating OpenGL context (" & $eglGetError() & ")")


var d: EglDisplay

proc initEgl* =
  d = eglGetDisplay()
  expect d != nil
  expect d.eglInitialize


proc newOpenglContext*: OpenglContext =
  ## creates opengl context (on new dummy surface)
  var
    config: EglConfig
    configCount: int32
  var attrs = [
    eglSurfaceType,    eglPBufferBit,
    eglRenderableType, eglOpenglEs2Bit,
    eglRedSize,        8,
    eglGreenSize,      8,
    eglBlueSize,       8,
    eglAlphaSize,      8,
    eglNone
  ]
  expect d.eglChooseConfig(attrs[0].addr, config.addr, 1, configCount.addr)
  expect configCount == 1

  result.ctx = d.eglCreateContext(config)
  expect result.ctx != nil

  var attrs2 = [
    eglWidth, 1,
    eglHeight, 1,
    eglNone
  ]
  result.srf = d.eglCreatePbufferSurface(config, attrs2[0].addr)
  expect result.srf != nil


proc makeCurrent*(context: OpenglContext) =
  if not d.eglMakeCurrent(context.srf, context.srf, context.ctx):
    raise WindyError.newException("Error creating OpenGL context (" & $eglGetError() & ")")


proc terminateEgl* =
  d.eglTerminate
