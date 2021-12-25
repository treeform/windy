import strutils
import vmath
import ../../../common
import protocol, sharedBuffer

type
  EglDisplay = ptr object
  EglConfig = ptr object
  EglSurface = ptr object
  EglContext = ptr object

  EglApi {.pure, size: 4.} = enum
    openglEs = 0x30A0
    openvg = 0x30A1
    opengl = 0x30A2

const
  eglExtensions = int32 0x3055

  eglSurfaceType = int32 0x3033
  eglWindowBit   = int32 0x0004

  eglRenderableType = int32 0x3040
  eglOpenglEs2Bit   = int32 0x0004

  eglAlphaSize  = int32 0x3021
  eglBlueSize   = int32 0x3022
  eglGreenSize  = int32 0x3023
  eglRedSize    = int32 0x3024

{.push, cdecl, dynlib: "libEGL.so(|.1)", importc.}

using d: EglDisplay

proc eglBindAPI(api: EglApi): bool
proc eglGetDisplay(native: pointer = nil): EglDisplay

proc eglInitialize(d; major: ptr int32 = nil, minor: ptr int32 = nil): bool
proc eglTerminate(d)

proc eglQueryString(d; n: int32): cstring

proc eglGetConfigs(d; retCfgs: ptr EglConfig, cfgSize: int32, retCfgCount: ptr int32): bool
proc eglChooseConfig(d; attrs: ptr int32, retCfgs: ptr EglConfig, cfgSize: int32, retCfgCount: ptr int32): bool

proc eglCreateContext(d; config: EglConfig, share: EglContext = nil, attrs: ptr int32 = nil): EglContext

proc eglCreateWindowSurface(d; config: EglConfig, win: pointer, attrs: ptr int32 = nil): EglSurface
proc eglCreatePbufferSurface(d; config: EglConfig, attrs: ptr int32 = nil): EglSurface
proc eglCreatePbufferFromClientBuffer(d; kind: uint32, buffer: pointer, config: EglConfig, attrs: ptr int32 = nil): EglSurface

{.pop.}


when isMainModule:
  template expect(x) =
    if not x: raise WindyError.newException(astToStr(x) & ": Error creating OpenGL ES context")

  expect eglBindAPI(EglApi.openglEs)
  let d = eglGetDisplay()
  expect d != nil

  expect d.eglInitialize

  # echo d.eglQueryString(eglExtensions).`$`.split

  var
    config: EglConfig
    configCount: int32
  var attrs = [
    eglSurfaceType,    eglWindowBit,
    eglRenderableType, eglOpenglEs2Bit,
    eglRedSize,        8,
    eglGreenSize,      8,
    eglBlueSize,       8,
    # eglAlphaSize,      8,
    0
  ]
  # expect d.eglChooseConfig(attrs[0].addr, config.addr, 1, configCount.addr)
  expect d.eglGetConfigs(config.addr, 1, configCount.addr)
  expect configCount == 1

  let ctx = d.eglCreateContext(config)

  # var i = (alloc(8), 1, 1)

  echo d.eglCreateWindowSurface(config, nil).repr
  # echo d.eglCreatePbufferSurface(config).repr


  # while true: sync display

  d.eglTerminate
