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
  eglExtensions = int32 0x3055

  eglSurfaceType = int32 0x3033
  eglPBufferBit  = int32 0x0001
  eglWindowBit   = int32 0x0004

  eglRenderableType = int32 0x3040
  eglOpenglEs2Bit   = int32 0x0004

  eglAlphaSize = int32 0x3021
  eglBlueSize  = int32 0x3022
  eglGreenSize = int32 0x3023
  eglRedSize   = int32 0x3024

  eglWidth  = int32 0x3057
  eglHeight = int32 0x3056

  eglOpenVGImage = uint32 0x3096

  eglNone = int32 0x3038

{.push, cdecl, dynlib: "libEGL.so(|.1)", importc.}

using d: EglDisplay

proc eglGetError(): EglError
proc eglBindAPI(api: EglApi): bool
proc eglGetDisplay(native: pointer = nil): EglDisplay

proc eglInitialize(d; major: ptr int32 = nil, minor: ptr int32 = nil): bool
proc eglTerminate(d)

proc eglQueryString(d; n: int32): cstring

proc eglGetConfigs(d; retConfigs: ptr EglConfig, maxConfigs: int32, retCfgCount: ptr int32): bool
proc eglChooseConfig(d; attrs: ptr int32, retConfigs: ptr EglConfig, maxConfigs: int32, retConfigCount: ptr int32): bool

proc eglCreateContext(d; config: EglConfig, share: EglContext = nil, attrs: ptr int32 = nil): EglContext

proc eglCreateWindowSurface(d; config: EglConfig, win: pointer, attrs: ptr int32 = nil): EglSurface
proc eglCreatePbufferSurface(d; config: EglConfig, attrs: ptr int32 = nil): EglSurface
proc eglCreatePbufferFromClientBuffer(d; kind: uint32, buffer: pointer, config: EglConfig, attrs: ptr int32 = nil): EglSurface

{.pop.}


when isMainModule:
  template expect(x) =
    if not x: raise WindyError.newException(astToStr(x) & ": Error creating OpenGL context (" & $eglGetError() & ")")

  expect eglBindAPI(EglApi.openglEs)
  let d = eglGetDisplay()
  expect d != nil

  expect d.eglInitialize

  # echo d.eglQueryString(eglExtensions).`$`.split

  var
    config: EglConfig
    configCount: int32
  var attrs = [
    eglSurfaceType,    eglPBufferBit,
    eglRenderableType, eglOpenglEs2Bit,
    eglRedSize,        8,
    eglGreenSize,      8,
    eglBlueSize,       8,
    # eglAlphaSize,      8,
    eglNone
  ]
  expect d.eglChooseConfig(attrs[0].addr, config.addr, 1, configCount.addr)
  # expect d.eglGetConfigs(config.addr, 1, configCount.addr)
  expect configCount == 1

  let ctx = d.eglCreateContext(config)
  expect ctx != nil

  var buff = alloc(32*32*4*8)

  var winAttrs = [
    eglWidth, 32,
    eglHeight, 32,
    eglNone
  ]

  # let win = d.eglCreateWindowSurface(config, i.addr)
  # let win = d.eglCreatePbufferSurface(config, winAttrs[0].addr)
  let win = d.eglCreatePbufferFromClientBuffer(0x308E, buff, config, winAttrs[0].addr)
  expect win != nil

  

  # while true: sync display

  d.eglTerminate
